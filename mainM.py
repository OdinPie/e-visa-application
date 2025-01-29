from fastapi import FastAPI, UploadFile, Form, File, HTTPException,BackgroundTasks
from fastapi.responses import JSONResponse
import cv2
import mediapipe as mp
import numpy as np
from mediapipe.tasks.python import vision
from mediapipe.framework.formats.landmark_pb2 import NormalizedLandmarkList
import matplotlib.pyplot as plt
from fastapi.middleware.cors import CORSMiddleware
from deepface import DeepFace 
import shutil 
import os 
import time 
import tempfile
from datetime import datetime, timedelta
from typing import Optional, Dict
from minio import Minio
from minio.error import S3Error
from PIL import Image
from random import randint
import wsq
import uuid
import io
import base64
import json
from pydantic import BaseModel, EmailStr
from azure.cognitiveservices.vision.computervision import ComputerVisionClient
from azure.cognitiveservices.vision.computervision.models import OperationStatusCodes
from msrest.authentication import CognitiveServicesCredentials
from PIL import Image
import smtplib
from dotenv import load_dotenv
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
import logging
# uvicorn detectionAPI:app --host 0.0.0.0 --port 8000
# adb reverse tcp:8000 tcp:8000
load_dotenv()

EMAIL_ADDRESS = os.getenv("EMAIL_ADDRESS")
EMAIL_PASSWORD = os.getenv("EMAIL_PASSWORD")
subscription_key = os.getenv("AZURE_SUBSCRIPTION_KEY")
endpoint = os.getenv("AZURE_ENDPOINT")

computervision_client = ComputerVisionClient(endpoint, CognitiveServicesCredentials(subscription_key))

app = FastAPI()
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Update with specific domains for production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)
# Initialize the face landmarker
base_options = mp.tasks.BaseOptions(model_asset_buffer=open('face_landmarker.task', "rb").read())
options = vision.FaceLandmarkerOptions(
    base_options=base_options,
    output_face_blendshapes=True,
    output_facial_transformation_matrixes=True,
    num_faces=1
)
detector = vision.FaceLandmarker.create_from_options(options)
mp_face_detection = mp.solutions.face_detection
face_detection = mp_face_detection.FaceDetection(min_detection_confidence=0.4)
# recognition_model = DeepFace.build_model(model_name=)

# -----------------------email verificartion-----------------------

# In-memory OTP store (for testing; replace with a database for production)
# In-memory store for OTPs
otp_store = {}

app = FastAPI()

# Pydantic models
class OTPRequest(BaseModel):
    email: EmailStr

class OTPVerify(BaseModel):
    email: EmailStr
    otp: str

# Helper function to generate an OTP
def generate_otp() -> str:
    import random
    return f"{random.randint(100000, 999999)}"

# API to send OTP to email
@app.post("/send-otp/")
async def send_otp(request: OTPRequest):
    email = request.email
    otp = generate_otp()
    otp_store[email] = otp
    send_email(email, otp)  # Using the provided `send_email` function
    return {"message": f"OTP sent to {email}"}

# API to get OTP for a specific email
@app.get("/get-otp/")
async def get_otp(email: EmailStr):
    if email not in otp_store:
        raise HTTPException(status_code=404, detail="OTP not found for the given email")
    return {"email": email, "otp": otp_store[email]}

# Reuse the provided `send_email` function
def send_email(email: str, otp: str):
    try:
        message = MIMEMultipart()
        message["From"] = EMAIL_ADDRESS
        message["To"] = email
        message["Subject"] = "Your OTP Code"

        body = f"""
        <p>Your OTP code is: <strong>{otp}</strong></p>
        <p>This OTP is valid for 5 minutes.</p>
        """
        message.attach(MIMEText(body, "html"))

        with smtplib.SMTP("smtp.gmail.com", 587) as server: 
            server.starttls()
            server.login(EMAIL_ADDRESS, EMAIL_PASSWORD)
            server.sendmail(EMAIL_ADDRESS, email, message.as_string())
        print(f"OTP sent to {email}: {otp}")  # Debugging log
            
    except Exception as e:
        print(f"Error sending email: {e}")
        raise HTTPException(status_code=500, detail="Failed to send email")

# API endpoint to generate and send OTP
@app.post("/send-otp")
async def send_otp(request: OTPRequest, background_tasks: BackgroundTasks):
    try:
        email = request.email
        # Generate a random 6-digit OTP
        otp = str(randint(100000, 999999))

        # Store OTP data with expiration time
        otp_store[email] = {
            "otp": otp,
            "expires_at": datetime.utcnow() + timedelta(minutes=1)  # OTP expires in 5 minutes
        }

        # Send OTP via email in the background
        background_tasks.add_task(send_email, email, otp)

        return JSONResponse(content={"message": "OTP sent successfully! Please check your email."})
    except Exception as e:
        print(f"Error in /send-otp: {e}")
        raise HTTPException(status_code=500, detail="Internal Server Error")

# API endpoint to verify OTP
@app.post("/verify-otp")
async def verify_otp(request: OTPVerify):
    try:
        email = request.email
        otp = request.otp

        if email not in otp_store:
            raise HTTPException(status_code=400, detail="No OTP found for this email. Request a new OTP.")

        stored_data = otp_store[email]
        stored_otp = stored_data["otp"]
        expires_at = stored_data["expires_at"]

        if datetime.utcnow() > expires_at:
            del otp_store[email]
            raise HTTPException(status_code=400, detail="OTP has expired. Please request a new one.")

        if otp == stored_otp:
            del otp_store[email]
            return JSONResponse(content={"message": "OTP verified successfully!"})
        else:
            raise HTTPException(status_code=400, detail="Invalid OTP.")
    except Exception as e:
        print(f"Error in /verify-otp: {e}")
        raise HTTPException(status_code=500, detail="Internal Server Error")

# Helper function to detect emotion
def detect_emotion(face_blendshapes, emotion):
    print(emotion)
    if emotion == "smile":
        parameters = {
            "mouthSmileLeft": None,
            "mouthSmileRight": None
        }

        for blendshape in face_blendshapes:
            if blendshape.category_name in parameters:
                parameters[blendshape.category_name] = blendshape.score

        if(parameters["mouthSmileLeft"]>=0.8 and parameters["mouthSmileRight"]>=0.8):
           return True
        else:
            return False

    elif emotion == "head still, eyes left":
        parameters = {
            "eyeLookOutLeft": None,
            "eyeLookInRight": None,
            "mouthSmileLeft": None,
            "mouthSmileRight": None,
            "jawOpen": None
        }

        for blendshape in face_blendshapes:
            if blendshape.category_name in parameters:
                parameters[blendshape.category_name] = blendshape.score
        if parameters["mouthSmileLeft"] >= 0.6 and parameters["mouthSmileRight"] >= 0.6:
            return False  # Invalid due to smile
            # return JSONResponse(content={"error": "Do not smile please."}, status_code=200)  # Invalid due to smile
        elif parameters["jawOpen"] >= 0.6:
            return False  # Invalid due to open mouth
            # return JSONResponse(content={"error": "PLease close your mouth."}, status_code=200)  # Invalid due to open mouth
        else:
            if(parameters["eyeLookOutLeft"]>=0.7 and parameters["eyeLookInRight"]>=0.7):
                return True
            else:
                return False

    elif emotion == "head still, eyes right":
        parameters = {
            "eyeLookOutRight": None,
            "eyeLookInLeft": None,
            "mouthSmileLeft": None,
            "mouthSmileRight": None,
            "jawOpen": None
        }

        for blendshape in face_blendshapes:
            if blendshape.category_name in parameters:
                parameters[blendshape.category_name] = blendshape.score
        if(parameters["eyeLookOutRight"]>=0.7 and parameters["eyeLookInLeft"]>=0.7):
            return True
        else:
            return False

    return False

UPLOAD_FOLDER = "./uploads"
EXTRACTED_FOLDER = "./extracted_faces"
# Ensure upload and extracted folders exist
os.makedirs(UPLOAD_FOLDER, exist_ok=True)
os.makedirs(EXTRACTED_FOLDER, exist_ok=True)

def extract_face(image_path: str, face_path: str) -> str:
    # Load the image
    image = cv2.imread(image_path)
    if image is None:
        raise HTTPException(status_code=400, detail="Invalid image file")

    image_rgb = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)
    results = face_detection.process(image_rgb)  # Assuming `face_detection` is already initialized

    if results.detections:
        for detection in results.detections:
            bboxC = detection.location_data.relative_bounding_box
            h, w, _ = image.shape
            x = int(bboxC.xmin * w)
            y = int(bboxC.ymin * h)
            width = int(bboxC.width * w)
            height = int(bboxC.height * h)
            
            # Extract the face region
            face_image = image[y:y + height, x:x + width]
            
            # Resize the extracted face to 190x190
            resized_face = cv2.resize(face_image, (190, 190), interpolation=cv2.INTER_AREA)
            
            # Save the resized face image
            output_path = os.path.join(EXTRACTED_FOLDER, "face.jpg")
            cv2.imwrite(output_path, resized_face)
            return output_path
    return False

def compareFace(realfilepath: str):
    passport_photo = os.listdir(EXTRACTED_FOLDER)
    passport_extracted_face_path = os.path.join(EXTRACTED_FOLDER,passport_photo[0])
    try:
        result = DeepFace.verify(passport_extracted_face_path,realfilepath ,model_name="Facenet",threshold=0.5, distance_metric="cosine")
        if result["verified"]:
            print("✅ Face Matched!")
            return True
        else:
            print("❌ Face Not Matched.")
            return False
    except Exception as e:
        print(f"❌ Error occurred: {e}")

# face pose estimation

mp_face_mesh = mp.solutions.face_mesh
face_mesh = mp_face_mesh.FaceMesh(min_detection_confidence=0.5, min_tracking_confidence=0.5)

def analyze_head_pose(image: np.ndarray, command: str, realfilepath: str) -> bool:
    img_h, img_w, _ = image.shape
    face_3d = []
    face_2d = []

    results = face_mesh.process(cv2.cvtColor(cv2.flip(image, 1), cv2.COLOR_BGR2RGB))

    if results.multi_face_landmarks:
        for face_landmarks in results.multi_face_landmarks:
            for idx, lm in enumerate(face_landmarks.landmark):
                if idx in [33, 263, 1, 61, 291, 199]:
                    if idx == 1:
                        nose_2d = (lm.x * img_w, lm.y * img_h)
                        nose_3d = (lm.x * img_w, lm.y * img_h, lm.z * 3000)

                    x, y = int(lm.x * img_w), int(lm.y * img_h)
                    face_2d.append([x, y])
                    face_3d.append([x, y, lm.z])

            face_2d = np.array(face_2d, dtype=np.float64)
            face_3d = np.array(face_3d, dtype=np.float64)

            focal_length = 1 * img_w
            cam_matrix = np.array([
                [focal_length, 0, img_h / 2],
                [0, focal_length, img_w / 2],
                [0, 0, 1]
            ])
            dist_matrix = np.zeros((4, 1), dtype=np.float64)

            success, rot_vec, trans_vec = cv2.solvePnP(face_3d, face_2d, cam_matrix, dist_matrix)

            rmat, _ = cv2.Rodrigues(rot_vec)
            angles, _, _, _, _, _ = cv2.RQDecomp3x3(rmat)

            x_angle = angles[0] * 360
            y_angle = angles[1] * 360

            if command.lower() == "look forward":
                if(compareFace(realfilepath)):
                    return -10 <= y_angle <= 10 and -10 <= x_angle <= 20
                else:
                    print("Face not matched")
                    raise HTTPException(status_code=400, detail="Face did not match!!")
            elif command.lower() == "look left":
                return y_angle < -10
            elif command.lower() == "look right":
                return y_angle > 10
            # elif command.lower() == "looking up":
            #     return x_angle > 20
            # elif command.lower() == "looking down":
            #     return x_angle < -10

    return False

def resize_image(image_path, max_size=5 * 1024 * 1024, max_width=1024, max_height=1024):
    file_size = os.path.getsize(image_path)
    if file_size > max_size:
        # print(f"File is too large ({file_size} bytes), resizing...")

        # Open the image
        img = Image.open(image_path)

        # Resize the image while maintaining the aspect ratio
        img.thumbnail((max_width, max_height))

        # Save the image with reduced quality to compress it
        img.save(image_path, quality=80, optimize=True)

        # Log the new file size
        new_size = os.path.getsize(image_path)
        # print(f"Resized file size: {new_size} bytes")

@app.post("/ocr_check/")
async def ocr_check(file: UploadFile = File(...)):
    # Save the uploaded file to a temporary location
    file_location = f"temp_{file.filename}"
    with open(file_location, "wb") as f:
        f.write(await file.read())

    # Resize the image if necessary
    resize_image(file_location)

    # Open the saved (possibly resized) file and process it with Azure Computer Vision API
    with open(file_location, "rb") as local_image:
        read_response = computervision_client.read_in_stream(local_image, raw=True)

    # Get the operation location from the response header
    read_operation_location = read_response.headers["Operation-Location"]
    operation_id = read_operation_location.split("/")[-1]

    # Wait for the OCR result
    while True:
        read_result = computervision_client.get_read_result(operation_id)
        if read_result.status not in ['notStarted', 'running']:
            break
        time.sleep(1)

    # Check the status and extract the text if OCR succeeded
    extracted_text = []
    if read_result.status == OperationStatusCodes.succeeded:
        for text_result in read_result.analyze_result.read_results:
            for i, line in enumerate(text_result.lines):
                if "<<" in line.text:  # Check if the line contains '<<<<<'
                    extracted_text.append(line.text)
                    if i + 1 < len(text_result.lines):  # Check the next line
                        extracted_text.append(text_result.lines[i + 1].text)

    # Delete the temporary file after processing
    os.remove(file_location)

    # Return the extracted text
    if extracted_text:
        return extracted_text
    else:
        return {"error": "No relevant text found in the image."}

@app.post("/match_face/")
async def match_face(file: UploadFile = File(...)):
    
    try:
        with tempfile.NamedTemporaryFile(delete=False) as temp_file:
            temp_file.write(await file.read())
            temp_file_path = temp_file.name
            image = cv2.imread(temp_file_path)
            print("real face "+temp_file_path)
            if image is None:
                raise HTTPException(status_code=400, detail="Invalid image file")

        if(compareFace(temp_file_path)):
            return True
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"An error occurred: {e}")

@app.post("/upload_passport/")
async def upload_passport(file: UploadFile = File(...)):
    """
    Upload a passport image, detect the face, and extract the face as a separate image.
    """
    # Save the uploaded file to disk
    passport_path = os.path.join(UPLOAD_FOLDER, file.filename)
    with open(passport_path, "wb") as f:
        shutil.copyfileobj(file.file, f)

    # Path to save the extracted face
    face_path = os.path.join(EXTRACTED_FOLDER, f"face_{file.filename}")

    # Detect and extract face
    extracted_face = extract_face(passport_path, face_path)

    if extracted_face:
        return JSONResponse(
            {"message": "Passport face extracted successfully", "face_path": extracted_face}
        )
    else:
        raise HTTPException(status_code=400, detail="No face detected in passport image")

@app.post("/detect-emotion/")
async def detect_emotion_api(file: UploadFile, emotion: str = Form(...)):
    if(emotion.startswith("Look")):
        try:
            with tempfile.NamedTemporaryFile(delete=False) as temp_file:
                temp_file.write(await file.read())
                temp_file_path = temp_file.name

            image = cv2.imread(temp_file_path)
            print("real face "+temp_file_path)
            if image is None:
                raise HTTPException(status_code=400, detail="Invalid image file")

            result = analyze_head_pose(image, emotion,temp_file_path)
            print({"emotion": emotion, "result": result})
            return JSONResponse(content={"emotion": emotion, "result": result})

        except Exception as e:
            raise HTTPException(status_code=500, detail=f"An error occurred: {e}")
    else:
        try:
        
            image_data = await file.read()
            np_image = np.frombuffer(image_data, np.uint8)
            image = cv2.imdecode(np_image, cv2.IMREAD_COLOR)

            # Convert to RGB for Mediapipe processing
            rgb_image = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)
            mp_image = mp.Image(image_format=mp.ImageFormat.SRGB, data=rgb_image)

            # Detect landmarks
            detection_result = detector.detect(mp_image)
            if not detection_result.face_blendshapes:
                return JSONResponse(content={"error": "No face detected."}, status_code=400)

            # Process the detection result
            face_blendshapes = detection_result.face_blendshapes[0]
            result = detect_emotion(face_blendshapes, emotion)
            print({"emotion": emotion, "result": result})
            return {"emotion": emotion, "result": result}

        except Exception as e:
            return JSONResponse(content={"error": str(e)}, status_code=500)

    

# Directory to temporarily store uploaded files 

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

# Configure logging
logging.basicConfig(
    level=logging.DEBUG,  # Set logging level to DEBUG
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
    handlers=[
        logging.StreamHandler(),  # Print logs to the console
        logging.FileHandler("minio_client.log")  # Optionally, save logs to a file
    ]
)
    
# MinIO setup
MINIO_URL = "113.11.21.65:8096"
MINIO_ACCESS_KEY = "minioadmin"
MINIO_SECRET_KEY = "MINIOadmin"
BUCKET_NAME = "biometrics"

minio_client = Minio(
    MINIO_URL,
    access_key=MINIO_ACCESS_KEY,
    secret_key=MINIO_SECRET_KEY,
    secure=False,
    logger=logging.getLogger("minio")  # Enable logging for MinIO client
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
            for i in range(6)
            if locals()[f'face_{i}'] is not None
        }

        for face_name, base64_data in face_fields.items():
            try:
                # Check if base64 data is present
                if not base64_data:
                    print(f"{face_name} is missing base64 data")
                    continue

                # Clean the base64 string
                if ',' in base64_data:
                    base64_data = base64_data.split(',')[1]

                # Decode base64 to bytes
                try:
                    image_bytes = base64.b64decode(base64_data)
                except Exception as e:
                    print(f"Error decoding base64 data for {face_name}: {e}")
                    continue

                # Convert to PIL Image
                try:
                    img = Image.open(io.BytesIO(image_bytes))
                except Exception as e:
                    print(f"Error converting to PIL image for {face_name}: {e}")
                    continue

                # Convert to PNG format
                png_buffer = io.BytesIO()
                img.save(png_buffer, format='PNG')
                png_buffer.seek(0)
                png_data = png_buffer.getvalue()

                # Define object name for MinIO
                object_name = f"{id}/face/{face_name}.png"

                # Upload to MinIO
                try:
                    minio_client.put_object(
                        BUCKET_NAME,
                        object_name,
                        io.BytesIO(png_data),
                        length=len(png_data),
                        content_type='image/png'
                    )
                except Exception as e:
                    print(f"Error uploading {face_name} to MinIO: {e}")
                    continue

                # Generate URL
                url = minio_client.presigned_get_object(
                    BUCKET_NAME,
                    object_name,
                    expires=timedelta(days=7)
                )

                biometric_data["face"][face_name] = url

            except Exception as e:
                print(f"Error processing {face_name}: {str(e)}")
                continue

        # Process fingerprint images (existing code remains the same)
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
                img.save(png_buffer, format='PNG')
                png_buffer.seek(0)
                png_data = png_buffer.getvalue()

                # Save as WSQ
                wsq_buffer = io.BytesIO()
                img.save(wsq_buffer, format='WSQ')
                wsq_buffer.seek(0)
                wsq_data = wsq_buffer.getvalue()

                # Define object names
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

                # Generate URLs
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

        # Create metadata
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
        print(f"MinIO error: {str(e)}")
        raise HTTPException(status_code=500, detail=f"MinIO error: {str(e)}")
    except Exception as e:
        print(f"General error: {str(e)}")
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
