
# Builder stage
FROM python:3.11-slim AS builder

WORKDIR /install

COPY requirements.txt .

RUN pip install --no-cache-dir \
    --extra-index-url https://download.pytorch.org/whl/cpu \
    --prefix=/install \
    -r requirements.txt && \
    pip install --no-cache-dir \
    --prefix=/install \
    --no-deps \
    ultralytics



# Runtime stage

FROM python:3.11-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app

COPY --from=builder /install /usr/local

COPY main.py .
COPY inference.py .
COPY schemas.py .
COPY model/ model/

RUN useradd -m -s /bin/bash appuser
USER appuser

EXPOSE 8000

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]