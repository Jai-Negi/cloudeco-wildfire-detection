import asyncio
import logging
from concurrent.futures import ThreadPoolExecutor
from contextlib import asynccontextmanager


logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(name)s — %(message)s"
)


from fastapi import FastAPI, HTTPException

import inference
from schemas import (
    AnnotateResponse,
    BoundingBox,
    InferenceRequest,
    PredictResponse,
)

logger = logging.getLogger(__name__)

executor = ThreadPoolExecutor(max_workers=4)


@asynccontextmanager
async def lifespan(app: FastAPI):
    """
    Load the YOLO model before the app starts accepting requests.
    This ensures the readiness probe only passes after the model
    is fully loaded into memory.
    """
    inference.load_model()
    logger.info("Application startup complete — YOLO model ready")
    yield
    executor.shutdown(wait=True)


app = FastAPI(
    title="CloudEco — Wildfire & Smoke Detection API",
    description="YOLO-based environmental ML inference service for FIT5225.",
    version="1.0.0",
    lifespan=lifespan,
)



# Health check: Kubernetes readiness and liveness probe


@app.get("/health")
async def health():
    if inference.model is None:
        raise HTTPException(status_code=503, detail="Model not loaded")
    return {"status": "ok"}



# /api/predict


@app.post("/api/predict", response_model=PredictResponse)
async def predict(request: InferenceRequest):
    # decode image 
    try:
        image = inference.decode_base64_image(request.image)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))

    # YOLO inference offload to thread pool
    loop = asyncio.get_running_loop()
    try:
        result = await loop.run_in_executor(
            executor,
            inference.run_inference,
            image
        )
    except asyncio.CancelledError:
        logger.warning(f"Request {request.uuid} was cancelled by client")
        raise
    except Exception as e:
        logger.error(f"Inference failed for uuid {request.uuid}: {e}")
        raise HTTPException(status_code=500, detail="Inference failed")

    return PredictResponse(
        uuid=request.uuid,
        count=result["count"],
        detections=result["detections"],
        boxes=[BoundingBox(**box) for box in result["boxes"]],
        speed_preprocess_ms=result["speed_preprocess_ms"],
        speed_inference_ms=result["speed_inference_ms"],
        speed_postprocess_ms=result["speed_postprocess_ms"],
    )



# /api/annotate


@app.post("/api/annotate", response_model=AnnotateResponse)
async def annotate(request: InferenceRequest):
    # decode image 
    try:
        image = inference.decode_base64_image(request.image)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))

    # Stage 2 — YOLO inference + annotation (offload to thread pool)
    loop = asyncio.get_running_loop()
    try:
        result = await loop.run_in_executor(
            executor,
            inference.run_annotation,
            image
        )
    except asyncio.CancelledError:
        logger.warning(f"Request {request.uuid} was cancelled by client")
        raise
    except Exception as e:
        logger.error(f"Annotation failed for uuid {request.uuid}: {e}")
        raise HTTPException(status_code=500, detail="Annotation failed")

    return AnnotateResponse(
        uuid=request.uuid,
        annotated_image=result["annotated_image"],
        speed_preprocess_ms=result["speed_preprocess_ms"],
        speed_inference_ms=result["speed_inference_ms"],
        speed_postprocess_ms=result["speed_postprocess_ms"],
    )