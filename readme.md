CloudEco Wildfire and Smoke Detection API:

A FastAPI based YOLO inference service for wildfire and smoke detection, containerised with Docker and orchestrated on a Kubernetes cluster hosted on Google Cloud Platform.

Live API endpoint: http://34.151.83.173:30000

Project Structure:
cloudeco folder contains main.py which handles FastAPI routes and async concurrency management, inference.py which contains YOLO model loading and inference logic, schemas.py which has Pydantic request and response models, requirements.txt for Python dependencies, and the Dockerfile for the multi-stage production Docker build.

The model folder contains fire_m.pt which is the pre-trained YOLO wildfire detection model.

The k8s folder contains deployment.yaml which is the Kubernetes Deployment manifest with readiness and liveness probes, and service.yaml which is the Kubernetes NodePort Service manifest.

The locust folder contains locustfile.py which is the Locust load testing script and a test-images folder with images used for load generation.

The iac folder contains main.tf for Terraform infrastructure provisioning, variables.tf for Terraform configuration variables, and setup_cluster.sh which is the Kubernetes cluster bootstrap and application deployment script.

API Endpoints:
The API exposes three endpoints. GET /health returns the health status of the service and returns 503 if the YOLO model has not finished loading. POST /api/predict accepts a base64 encoded image and returns bounding box coordinates, detection labels and speed metrics. POST /api/annotate accepts the same payload and returns a base64 encoded annotated image with bounding boxes drawn.

The request payload format is a JSON object with two fields. The uuid field is a unique string identifier for the request. The image field is the base64 encoded JPEG image.

Running Locally with Docker:
Pull and run the pre-built image from Docker Hub.

docker pull jainegi02/cloudeco:latest
docker run -p 8000:8000 jainegi02/cloudeco:latest
Test the health endpoint:
curl http://localhost:8000/health
Test the predict endpoint with a local image:
curl -X POST http://localhost:8000/api/predict -H "Content-Type: application/json" -d "{"uuid": "test", "image": "$(base64 < image.jpeg)"}"
Building from Source
To build the Docker image locally from source code:
docker build -t cloudeco:latest .
docker run -p 8000:8000 cloudeco:latest

Infrastructure as Code with Terraform:
Terraform is used to provision three GCP virtual machines with Docker and Kubernetes automatically installed via startup scripts. You will need Terraform installed and a GCP account with the gcloud CLI authenticated.
Navigate to the iac folder and run the following commands:

terraform init
terraform plan
terraform apply

After terraform apply completes successfully, it will print the external IP addresses of the three VMs and a setup command. Run the cluster bootstrap script with those IPs:

bash setup_cluster.sh master-ip worker1-ip worker2-ip

The setup_cluster.sh script automatically initialises the Kubernetes cluster on the master node, joins both worker nodes to the cluster, installs Weave Net as the network overlay, creates the cloudeco namespace, and deploys the application using
kubectl apply.

Kubernetes Deployment:
If you have an existing Kubernetes cluster, you can deploy manually. First create the namespace, then apply both YAML files:

kubectl create namespace cloudeco
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml
kubectl get pods -n cloudeco
To scale the number of pods for load testing:
kubectl scale deployment cloudeco-deployment -n cloudeco --replicas=4

Load Testing with Locust:
Install Locust and Pillow on your machine:
pip install locust Pillow
Navigate to the locust folder and start Locust pointing at the live cluster:
locust -f locustfile.py --host=http://34.151.83.173:30000
Open http://localhost:8089 in your browser to configure the number of users and spawn rate, then start the load test.

Infrastructure Details:
The cluster runs on Google Cloud Platform in the australia-southeast1-a zone in Sydney. Each of the three virtual machines uses a custom configuration with 4 vCPU and 8GB RAM running Ubuntu 22.04 LTS. Kubernetes version 1.32.13 was installed using kubeadm with Weave Net v2.8.1 as the network overlay. The Docker image jainegi02/cloudeco:latest is built for linux/amd64 architecture. Each pod is constrained to a limit of 1.0 vCPU and 2GB RAM. The service is exposed via NodePort on port 30000.

Docker Image Details:
The Docker image uses a multi-stage build with a builder stage and a runtime stage. PyTorch is installed using the CPU-only index URL to avoid downloading the CUDA version which would add several gigabytes. opencv-python-headless is used instead of the standard OpenCV package to avoid requiring system GUI libraries. The container runs as a non-root user called appuser for security compliance.