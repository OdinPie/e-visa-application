from fastapi import FastAPI, UploadFile, File
from fastapi.responses import JSONResponse
from fastapi.middleware.cors import CORSMiddleware
import cv2
import numpy as np
import mediapipe as mp
import base64

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

# Process fingerprint function
import cv2
import numpy as np

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
    box_size = max(60, int(0.05 * h))
    x_min = max(0, x - box_size)
    y_min = max(0, y - box_size + 100)
    x_max = min(w, x + box_size)
    y_max = min(h, y + box_size + 100)
    cropped_fingertip = image[y_min:y_max, x_min:x_max]
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
                fingertips = {"Thumb": 4, "Index": 8, "Middle": 12, "Ring": 16, "Pinky": 20}

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
