from fastapi import FastAPI, UploadFile, File, Form
from fastapi.responses import JSONResponse
from fastapi.middleware.cors import CORSMiddleware
import cv2
import numpy as np
import mediapipe as mp
import base64
from datetime import datetime, timedelta
from typing import Optional, Dict
from minio import Minio
from minio.error import S3Error
from PIL import Image
import wsq
import uuid
import io
import base64
import json

app = FastAPI()

# Enable CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Replace "*" with specific origins in production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Initialize MediaPipe Hands
mp_hands = mp.solutions.hands
mp_drawing = mp.solutions.drawing_utils
hands = mp_hands.Hands(static_image_mode=True, max_num_hands=2)


def process_fingerprint(image):
    
    def remove_small_pixels(img, min_size=50):
       
        num_labels, labels, stats, centroids = cv2.connectedComponentsWithStats(img, connectivity=8)
        sizes = stats[1:, cv2.CC_STAT_AREA]  # Exclude background
        img_clean = np.zeros(labels.shape, np.uint8)

        for i in range(len(sizes)):
            if sizes[i] >= min_size:
                img_clean[labels == i + 1] = 255

        return img_clean

    # Step 1: Segment the hand region using skin color detection
    hsv = cv2.cvtColor(image, cv2.COLOR_BGR2HSV)
    lower = np.array([0, 20, 70], dtype="uint8")
    upper = np.array([20, 255, 255], dtype="uint8")
    mask = cv2.inRange(hsv, lower, upper)

    # Morphological transformations to clean the mask
    kernel = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (3, 3))
    mask = cv2.morphologyEx(mask, cv2.MORPH_CLOSE, kernel, iterations=2)

    # Remove small noise
    mask = remove_small_pixels(mask, min_size=5000)

    # Apply the mask to extract the segmented hand region
    segmented_hand = cv2.bitwise_and(image, image, mask=mask)

    # Step 2: Convert segmented hand to grayscale
    gray_image = cv2.cvtColor(segmented_hand, cv2.COLOR_BGR2GRAY)

    # Step 3: Remove background using thresholding
    _, no_background = cv2.threshold(gray_image, 245, 255, cv2.THRESH_TOZERO_INV)

    # Step 4: Apply histogram equalization for contrast enhancement
    equalized = cv2.equalizeHist(no_background)

    # Step 5: Apply a high-pass filter for sharpening
    kernel = np.array([[0, -1, 0], [-1, 5, -1], [0, -1, 0]])
    sharpened = cv2.filter2D(equalized, -1, kernel)

    # Step 6: Adaptive binarization
    binary = cv2.adaptiveThreshold(
        sharpened, 255, cv2.ADAPTIVE_THRESH_GAUSSIAN_C, cv2.THRESH_BINARY, 15, 8
    )

    # Step 7: Remove small noise and refine the fingerprint
    binary = remove_small_pixels(binary, min_size=100)

    # Return processed binary fingerprint image
    return binary


# Crop and process each fingerprint
def crop_and_process_fingerprint(image, hand_landmarks, landmark_index):
    h, w, _ = image.shape
    x = int(hand_landmarks.landmark[landmark_index].x * w)
    y = int(hand_landmarks.landmark[landmark_index].y * h)
    
    # Adjusted box sizes for different fingers
    if landmark_index == 4:  # Thumb
        box_size = int(0.07 * h)  # Larger box for thumb
        y_offset = 100  # Reduced y-offset for thumb
    else:
        box_size = int(0.05 * h)  # Standard size for other fingers
        y_offset = 120
    
    # Ensure minimum box size
    box_size = max(40, box_size)
    
    x_min = max(0, x - box_size)
    y_min = max(0, y - box_size + y_offset)
    x_max = min(w, x + box_size)
    y_max = min(h, y + box_size + y_offset)
    
    # Check if crop area is valid
    if x_max <= x_min or y_max <= y_min:
        return None
        
    cropped_fingertip = image[y_min:y_max, x_min:x_max]
    
    # Check if cropped image is valid
    if cropped_fingertip.size == 0:
        return None
        
    processed_fingerprint = process_fingerprint(cropped_fingertip)
    return processed_fingerprint

# Convert image to base64
def image_to_base64(image):
    _, buffer = cv2.imencode('.png', image)
    return base64.b64encode(buffer).decode('utf-8')

# Correct hand type based on position
def correct_handedness(hand_landmarks, image_width):
    # Compute the average x-coordinate of the wrist landmarks (landmark 0 and 17)
    wrist_x = hand_landmarks.landmark[0].x + hand_landmarks.landmark[17].x
    wrist_x /= 2

    # If the wrist is on the left half of the image, it's likely the right hand and vice versa
    return "Right" if wrist_x < 0.5 else "Left"

# Process the uploaded image
@app.post("/process-fingerprints/")
async def process_fingerprints(file: UploadFile = File(...)):
    try:
        # Read image
        contents = await file.read()
        image_np = np.frombuffer(contents, np.uint8)
        image = cv2.imdecode(image_np, cv2.IMREAD_COLOR)

        # Detect hands
        rgb_image = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)
        results = hands.process(rgb_image)

        if results.multi_hand_landmarks:
            # Prepare base64 images for processed fingerprints
            images_base64 = {}

            # Process each hand
            for hand_landmarks in results.multi_hand_landmarks:
                # Correct the hand type based on position
                hand_type = correct_handedness(hand_landmarks, image.shape[1])

                # Fingertip landmarks
                fingertips = {"Thumb": 4, "Index": 8, "Middle": 12, "Ring": 16, "Little": 20}

                for finger_name, landmark_index in fingertips.items():
                    # Process fingerprint
                    processed_fingerprint = crop_and_process_fingerprint(image, hand_landmarks, landmark_index)

                    # Convert to base64
                    base64_image = image_to_base64(processed_fingerprint)
                    # Add hand type (Left or Right) to the finger name
                    images_base64[f"{hand_type} {finger_name}"] = f"data:image/png;base64,{base64_image}"

            # Return base64 images in JSON response
            return JSONResponse(content={"status": "success", "images": images_base64})

        else:
            return JSONResponse(content={"status": "error", "message": "No hands detected."})

    except Exception as e:
        return JSONResponse(content={"status": "error", "message": str(e)})



    
    # MinIO setup
MINIO_URL = "113.11.21.65:8096"
MINIO_ACCESS_KEY = "minioadmin"
MINIO_SECRET_KEY = "MINIOadmin"
BUCKET_NAME = "biometrics"  # Changed bucket name to be more generic

minio_client = Minio(
    MINIO_URL,
    access_key=MINIO_ACCESS_KEY,
    secret_key=MINIO_SECRET_KEY,
    secure=False
)

if not minio_client.bucket_exists(BUCKET_NAME):
    minio_client.make_bucket(BUCKET_NAME)

@app.post("/upload/")
async def upload_biometrics(
    id: str = Form(...),
    capture_date: str = Form(...),
    # Face image fields
    face_0: Optional[str] = Form(None),
    face_1: Optional[str] = Form(None),
    face_2: Optional[str] = Form(None),
    face_3: Optional[str] = Form(None),
    face_4: Optional[str] = Form(None),
    face_5: Optional[str] = Form(None),
    # Fingerprint fields
    right_thumb: Optional[str] = Form(None),
    right_index: Optional[str] = Form(None),
    right_middle: Optional[str] = Form(None),
    right_ring: Optional[str] = Form(None),
    right_little: Optional[str] = Form(None),
    left_thumb: Optional[str] = Form(None),
    left_index: Optional[str] = Form(None),
    left_middle: Optional[str] = Form(None),
    left_ring: Optional[str] = Form(None),
    left_little: Optional[str] = Form(None)
):
    try:
        biometric_data = {
            "face": {},
            "fingerprints": {}
        }

        # Process face images
        face_fields = {
            f'face_{i}': locals()[f'face_{i}'] 
            for i in range(6)  # Assuming 6 face images
            if locals()[f'face_{i}'] is not None
        }

        for face_name, base64_data in face_fields.items():
            if base64_data:
                if ',' in base64_data:
                    base64_data = base64_data.split(',')[1]

                image_data = base64.b64decode(base64_data)
                img = Image.open(io.BytesIO(image_data))
                
                # Save as PNG
                buffer = io.BytesIO()
                img.save(buffer, format='PNG', optimize=False, quality=100)
                buffer.seek(0)
                img_data = buffer.getvalue()
                
                object_name = f"{id}/face/{face_name}.png"
                
                minio_client.put_object(
                    BUCKET_NAME,
                    object_name,
                    io.BytesIO(img_data),
                    length=len(img_data),
                    content_type='image/png'
                )
                
                # Generate URL with 7-day expiration
                url = minio_client.presigned_get_object(
                    BUCKET_NAME,
                    object_name,
                    expires=timedelta(days=7)
                )
                
                biometric_data["face"][face_name] = url

        # Process fingerprint images
        fingerprint_fields = {
            'right_thumb': right_thumb,
            'right_index': right_index,
            'right_middle': right_middle,
            'right_ring': right_ring,
            'right_little': right_little,
            'left_thumb': left_thumb,
            'left_index': left_index,
            'left_middle': left_middle,
            'left_ring': left_ring,
            'left_little': left_little
        }

        for finger_name, base64_data in fingerprint_fields.items():
            if base64_data:
                if ',' in base64_data:
                    base64_data = base64_data.split(',')[1]

                image_data = base64.b64decode(base64_data)
                img = Image.open(io.BytesIO(image_data))
               
                # Save as PNG
                png_buffer = io.BytesIO()
                img.save(png_buffer, format='PNG', optimize=False, quality=100)
                png_buffer.seek(0)
                png_data = png_buffer.getvalue()
                
                # Save as WSQ
                wsq_buffer = io.BytesIO()
                img.save(wsq_buffer, format='WSQ')
                wsq_buffer.seek(0)
                wsq_data = wsq_buffer.getvalue()
                
                png_object_name = f"{id}/fingerprints/{finger_name}.png"
                wsq_object_name = f"{id}/fingerprints/{finger_name}.wsq"
                
                # Upload PNG
                minio_client.put_object(
                    BUCKET_NAME,
                    png_object_name,
                    io.BytesIO(png_data),
                    length=len(png_data),
                    content_type='image/png'
                )
                
                # Upload WSQ
                minio_client.put_object(
                    BUCKET_NAME,
                    wsq_object_name,
                    io.BytesIO(wsq_data),
                    length=len(wsq_data),
                    content_type='application/octet-stream'
                )
                
                # Generate URLs with 7-day expiration
                png_url = minio_client.presigned_get_object(
                    BUCKET_NAME,
                    png_object_name,
                    expires=timedelta(days=7)
                )
                
                wsq_url = minio_client.presigned_get_object(
                    BUCKET_NAME,
                    wsq_object_name,
                    expires=timedelta(days=7)
                )
                
                biometric_data["fingerprints"][finger_name] = {
                    "png_url": png_url,
                    "wsq_url": wsq_url,
                    "formats": ["png", "wsq"]
                }

        metadata = {
            "id": id,
            "capture_date": capture_date,
            "face": biometric_data["face"],
            "fingerprints": biometric_data["fingerprints"],
            "last_updated": datetime.utcnow().isoformat()
        }
        
        # Save metadata
        metadata_json = json.dumps(metadata)
        metadata_stream = io.BytesIO(metadata_json.encode())
        
        minio_client.put_object(
            BUCKET_NAME,
            f"{id}/metadata.json",
            metadata_stream,
            length=len(metadata_json),
            content_type='application/json'
        )

        return metadata

    except S3Error as e:
        raise HTTPException(status_code=500, detail=f"MinIO error: {e}")
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/biometrics/")
async def get_biometrics():
    try:
        records = []
        objects = list(minio_client.list_objects(BUCKET_NAME, recursive=True))
        records_dict = {}
        
        for obj in objects:
            parts = obj.object_name.split('/')
            if len(parts) == 2 and parts[1] == 'metadata.json':
                record_id = parts[0]
                try:
                    data = minio_client.get_object(BUCKET_NAME, obj.object_name)
                    metadata = json.loads(data.read().decode('utf-8'))
                    
                    # Generate fresh URLs for face images
                    for face_name in metadata['face'].keys():
                        object_name = f"{record_id}/face/{face_name}.png"
                        url = minio_client.presigned_get_object(
                            BUCKET_NAME,
                            object_name,
                            expires=timedelta(days=7)
                        )
                        metadata['face'][face_name] = url
                    
                    # Generate fresh URLs for fingerprints
                    for finger_name, finger_data in metadata['fingerprints'].items():
                        png_object_name = f"{record_id}/fingerprints/{finger_name}.png"
                        wsq_object_name = f"{record_id}/fingerprints/{finger_name}.wsq"
                        
                        png_url = minio_client.presigned_get_object(
                            BUCKET_NAME,
                            png_object_name,
                            expires=timedelta(days=7)
                        )
                        wsq_url = minio_client.presigned_get_object(
                            BUCKET_NAME,
                            wsq_object_name,
                            expires=timedelta(days=7)
                        )
                        
                        finger_data['png_url'] = png_url
                        finger_data['wsq_url'] = wsq_url
                    
                    records_dict[record_id] = metadata
                except Exception as e:
                    print(f"Error processing metadata for {record_id}: {e}")
        
        records = list(records_dict.values())
        records.sort(key=lambda x: x['id'], reverse=True)
        return records

    except S3Error as e:
        raise HTTPException(status_code=500, detail=f"MinIO error: {e}")
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
