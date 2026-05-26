import base64
import logging
import os
import cv2
import numpy as np
from ultralytics import YOLO

logger = logging.getLogger(__name__)

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
MODEL_PATH = os.path.join(BASE_DIR, "model", "fire_m.pt")

# Model is None until load_model() is called from lifespan
model = None


def load_model():
    """
    Explicitly load the YOLO model. Called from FastAPI lifespan
    so the readiness probe only passes after the model is ready.
    """
    global model
    model = YOLO(MODEL_PATH)
    logger.info("YOLO model loaded successfully")


def decode_base64_image(image_b64: str) -> np.ndarray:
    """
    Decode a base64 string into an OpenCV (BGR) numpy array.
    base64 validity is already guaranteed by Pydantic field_validator
    in schemas.py — so we only need to handle image decode failure.
    """
    image_bytes = base64.b64decode(image_b64)
    np_array = np.frombuffer(image_bytes, dtype=np.uint8)
    image = cv2.imdecode(np_array, cv2.IMREAD_COLOR)
    if image is None:
        raise ValueError("Decoded bytes are not a recognised image format")
    return image


def encode_image_to_base64(image_array: np.ndarray) -> str:
    """
    Encode a numpy image array (RGB) to a base64 JPEG string.
    result.plot() returns RGB, convert to BGR before encoding.
    """
    bgr_image = cv2.cvtColor(image_array, cv2.COLOR_RGB2BGR)
    success, buffer = cv2.imencode(".jpg", bgr_image)
    if not success:
        raise ValueError("Failed to encode annotated image to JPEG.")
    return base64.b64encode(buffer).decode("utf-8")


def run_inference(image: np.ndarray) -> dict:
    """
    Run YOLO inference on a decoded image array.
    Returns count, detections, boxes and speed metrics.
    """
    results = model.predict(image, verbose=False, imgsz=256)
    result = results[0]

    boxes = []
    detections = []

    for box in result.boxes:
        x1, y1, x2, y2 = box.xyxy[0].tolist()
        conf = float(box.conf[0])
        cls = int(box.cls[0])
        label = model.names[cls]
        detections.append(label)
        boxes.append({
            "x": x1,
            "y": y1,
            "width": x2 - x1,
            "height": y2 - y1,
            "probability": conf
        })

    speed = result.speed
    return {
        "count": len(detections),
        "detections": detections,
        "boxes": boxes,
        "speed_preprocess_ms": speed.get("preprocess", 0),
        "speed_inference_ms": speed.get("inference", 0),
        "speed_postprocess_ms": speed.get("postprocess", 0)
    }


def run_annotation(image: np.ndarray) -> dict:
    """
    Run YOLO inference and return annotated image as base64 JPEG
    alongside speed metrics.
    """
    results = model.predict(image, verbose=False, imgsz=256)
    result = results[0]

    annotated_array = result.plot()
    annotated_b64 = encode_image_to_base64(annotated_array)

    speed = result.speed
    return {
        "annotated_image": annotated_b64,
        "speed_preprocess_ms": speed.get("preprocess", 0),
        "speed_inference_ms": speed.get("inference", 0),
        "speed_postprocess_ms": speed.get("postprocess", 0)
    }