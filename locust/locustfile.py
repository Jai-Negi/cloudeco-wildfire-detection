import base64
import os
import random
import uuid
from io import BytesIO

from locust import HttpUser, task, between
from PIL import Image


IMAGE_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "test-images")
TARGET_SIZE = (256, 256)


def load_and_resize_images():
    images = []
    for fname in sorted(os.listdir(IMAGE_DIR)):
        if fname.lower().endswith((".jpg", ".jpeg", ".png")):
            img = Image.open(os.path.join(IMAGE_DIR, fname))
            img = img.resize(TARGET_SIZE)
            buffer = BytesIO()
            img.save(buffer, format="JPEG")
            images.append(base64.b64encode(buffer.getvalue()).decode("utf-8"))
    return images


TEST_IMAGES = load_and_resize_images()


class CloudEcoUser(HttpUser):
    wait_time = between(0, 0)

    def on_start(self):
        response = self.client.get("/health")
        if response.status_code != 200:
            self.environment.runner.quit()

    @task(3)
    def predict(self):
        payload = {
            "uuid": str(uuid.uuid4()),
            "image": random.choice(TEST_IMAGES)
        }
        with self.client.post(
            "/api/predict",
            json=payload,
            catch_response=True,
            timeout=30
        ) as response:
            if response.status_code == 200:
                data = response.json()
                if "count" in data:
                    response.success()
                else:
                    response.failure("Missing count in response")
            else:
                response.failure(f"HTTP {response.status_code}")

    @task(1)
    def annotate(self):
        payload = {
            "uuid": str(uuid.uuid4()),
            "image": random.choice(TEST_IMAGES)
        }
        with self.client.post(
            "/api/annotate",
            json=payload,
            catch_response=True,
            timeout=30
        ) as response:
            if response.status_code == 200:
                data = response.json()
                if "annotated_image" in data:
                    response.success()
                else:
                    response.failure("Missing annotated_image in response")
            else:
                response.failure(f"HTTP {response.status_code}")