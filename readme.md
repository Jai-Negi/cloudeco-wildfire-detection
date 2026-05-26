CloudEco - Wildfire and Smoke Detection API

A production-grade wildfire and smoke detection service built with FastAPI and YOLOv8, containerised with Docker and deployed on a 3-node Kubernetes cluster on Google Cloud Platform. The service accepts base64-encoded images and returns bounding box detections with confidence scores in real time.

Docker Hub: jainegi02/cloudeco

---

Project Structure

main.py handles FastAPI routes and async concurrency management using ThreadPoolExecutor to prevent event loop blocking during CPU-bound YOLO inference.

inference.py handles YOLO model loading and inference logic including base64 image decoding, model prediction, and annotated image encoding.

schemas.py contains all Pydantic request and response models with field-level validation.

Dockerfile is a multi-stage production build that reduces image size through CPU-only PyTorch and headless OpenCV.

k8s/deployment.yaml is the Kubernetes Deployment manifest with readiness and liveness probes, resource limits, and horizontal scaling configuration.

k8s/service.yaml is the Kubernetes NodePort Service exposing the API on port 30000.

locust/locustfile.py is the load testing script that simulates concurrent users sending wildfire images to both endpoints.

iac/main.tf provisions three GCP virtual machines with firewall rules via Terraform.

iac/variables.tf abstracts all infrastructure configuration into variables.

iac/setup_cluster.sh bootstraps the Kubernetes cluster and deploys the application automatically after Terraform provisioning.

---

API Endpoints

GET /health returns status ok when the YOLO model is loaded and the service is ready. Returns 503 if the model is still initialising.

POST /api/predict accepts a base64 encoded image and returns bounding box coordinates, detection class labels, confidence scores, and YOLO speed metrics.

POST /api/annotate accepts the same payload and returns a base64 encoded JPEG with bounding boxes drawn on the image.

Request format:

{
  "uuid": "unique-request-id",
  "image": "base64-encoded-jpeg"
}

---

Running Locally

Pull the pre-built image from Docker Hub and run it:

docker pull jainegi02/cloudeco:latest

docker run -p 8000:8000 jainegi02/cloudeco:latest

Test the health endpoint:

curl http://localhost:8000/health

Test inference with a local image:

curl -X POST http://localhost:8000/api/predict -H "Content-Type: application/json" -d "{\"uuid\": \"test\", \"image\": \"$(base64 < image.jpeg)\"}"

---

Building from Source

docker build -t cloudeco:latest .

docker run -p 8000:8000 cloudeco:latest

The image must be built for linux/amd64 when deploying to GCP from an Apple Silicon Mac:

docker buildx build --platform linux/amd64 -t jainegi02/cloudeco:latest --push .

---

Infrastructure Provisioning with Terraform

Terraform provisions three GCP virtual machines and automatically installs Docker and Kubernetes on each via startup scripts. You need Terraform installed and gcloud authenticated before running these commands.

cd iac

terraform init

terraform plan

terraform apply

After apply completes, the output will print the external IP addresses and the exact setup command to run. Execute the cluster bootstrap script with those IPs:

bash setup_cluster.sh master-ip worker1-ip worker2-ip

The script automatically initialises the Kubernetes cluster on the master, joins both worker nodes, installs Weave Net as the network overlay, creates the cloudeco namespace, and deploys the application using kubectl apply. The entire cluster goes from zero to a running application with just these two commands.

Note: Authenticate with GCP before running Terraform using gcloud auth login and set your project with gcloud config set project YOUR_PROJECT_ID.

---

Kubernetes Deployment

If you already have a running Kubernetes cluster, deploy manually:

kubectl create namespace cloudeco

kubectl apply -f k8s/deployment.yaml

kubectl apply -f k8s/service.yaml

kubectl get pods -n cloudeco

Scale pods for load testing:

kubectl scale deployment cloudeco-deployment -n cloudeco --replicas=4

---

Load Testing with Locust

Install dependencies:

pip install locust Pillow

Run Locust against your cluster:

locust -f locust/locustfile.py --host=http://WORKER-NODE-IP:30000

Open http://localhost:8089 in your browser to configure concurrent users and start the load test. The script sends pre-resized 256x256 images to both endpoints with a 3 to 1 ratio of predict to annotate requests, reflecting realistic usage patterns. Requests exceeding 30 seconds are counted as failures to provide an objective breaking point definition.

---

Infrastructure Details

Cloud provider: Google Cloud Platform, australia-southeast1-a, Sydney

Virtual machines: 3 nodes, custom 4 vCPU and 8GB RAM each, Ubuntu 22.04 LTS

Kubernetes: v1.32.13 installed via kubeadm

Network overlay: Weave Net v2.8.1

Container runtime: Docker with cri-dockerd

Docker image: jainegi02/cloudeco:latest, linux/amd64, approximately 1.64GB

Pod resources: 1.0 vCPU limit, 2GB RAM limit per pod

Service: NodePort on port 30000

---

Docker Image Optimisations

Multi-stage build discards all build tools and pip caches from the final image. PyTorch is installed using the CPU-only index URL saving approximately 1.7GB compared to the default GPU build. opencv-python-headless replaces the standard OpenCV package eliminating system GUI library dependencies and saving approximately 285MB. The container runs as a non-root user called appuser following security best practices.