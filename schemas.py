import base64
from pydantic import BaseModel, field_validator


class InferenceRequest(BaseModel):
    uuid: str
    image: str

    @field_validator("image")
    @classmethod
    def image_must_be_valid_base64(cls, v):
        try:
            base64.b64decode(v, validate=True)
        except Exception:
            raise ValueError("image must be valid base64-encoded string")
        return v


class BoundingBox(BaseModel):
    x: float
    y: float
    width: float
    height: float
    probability: float


class PredictResponse(BaseModel):
    uuid: str
    count: int
    detections: list[str]
    boxes: list[BoundingBox]
    speed_preprocess_ms: float
    speed_inference_ms: float
    speed_postprocess_ms: float


class AnnotateResponse(BaseModel):
    uuid: str
    annotated_image: str
    speed_preprocess_ms: float
    speed_inference_ms: float
    speed_postprocess_ms: float