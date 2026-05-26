
# CloudEco Kubernetes Cluster Bootstrap Script
# Using script to streamline the process of setting up the cluster.

set -e

MASTER_IP=$1
WORKER1_IP=$2
WORKER2_IP=$3
SSH_KEY="~/.ssh/cloudeco_key"
SSH_USER="jainegi"
SSH_OPTS="-i $SSH_KEY -o StrictHostKeyChecking=no"
NAMESPACE="cloudeco"
DOCKER_IMAGE="jainegi02/cloudeco:latest"

echo " "
echo "CloudEco Cluster Bootstrap"
echo "Master:  $MASTER_IP"
echo "Worker1: $WORKER1_IP"
echo "Worker2: $WORKER2_IP"
echo " "


# Waiting for all VMs to finish startup script

wait_for_k8s_ready() {
  local ip=$1
  local name=$2
  echo "Waiting for $name to finish installing Kubernetes..."
  while ! ssh $SSH_OPTS $SSH_USER@$ip "test -f /tmp/k8s_ready" 2>/dev/null; do
    sleep 10
    echo "  Still waiting for $name..."
  done
  echo "  $name is ready!"
}

wait_for_k8s_ready $MASTER_IP "master"
wait_for_k8s_ready $WORKER1_IP "worker1"
wait_for_k8s_ready $WORKER2_IP "worker2"


# Initialise Kubernetes on master

echo ""
echo "Initialising Kubernetes cluster on master..."

MASTER_PRIVATE_IP=$(ssh $SSH_OPTS $SSH_USER@$MASTER_IP "ip addr show | grep 'inet ' | grep -v 127.0.0.1 | awk '{print \$2}' | cut -d/ -f1 | head -1")

ssh $SSH_OPTS $SSH_USER@$MASTER_IP "sudo kubeadm init \
  --pod-network-cidr=10.244.0.0/16 \
  --cri-socket=unix:///var/run/cri-dockerd.sock \
  --apiserver-advertise-address=$MASTER_PRIVATE_IP"


# Configure kubectl on master

echo ""
echo "Configuring kubectl on master..."

ssh $SSH_OPTS $SSH_USER@$MASTER_IP "
  mkdir -p \$HOME/.kube
  sudo cp -i /etc/kubernetes/admin.conf \$HOME/.kube/config
  sudo chown \$(id -u):\$(id -g) \$HOME/.kube/config
"


# Installing Weave Net network overlay

echo ""
echo "Installing Weave Net..."

ssh $SSH_OPTS $SSH_USER@$MASTER_IP "kubectl apply -f https://github.com/weaveworks/weave/releases/download/v2.8.1/weave-daemonset-k8s.yaml"


# Getting join command from master

echo ""
echo "Getting join command..."

JOIN_COMMAND=$(ssh $SSH_OPTS $SSH_USER@$MASTER_IP "sudo kubeadm token create --print-join-command")


# Joining workers to cluster

echo ""
echo "Joining worker1 to cluster..."
ssh $SSH_OPTS $SSH_USER@$WORKER1_IP "sudo $JOIN_COMMAND --cri-socket=unix:///var/run/cri-dockerd.sock"

echo "Joining worker2 to cluster..."
ssh $SSH_OPTS $SSH_USER@$WORKER2_IP "sudo $JOIN_COMMAND --cri-socket=unix:///var/run/cri-dockerd.sock"


# Waiting for all nodes to be Ready

echo ""
echo "Waiting for all nodes to be Ready..."
sleep 30

ssh $SSH_OPTS $SSH_USER@$MASTER_IP "kubectl get nodes"

# Deploying CloudEco application

echo ""
echo "Deploying CloudEco application..."

ssh $SSH_OPTS $SSH_USER@$MASTER_IP "kubectl create namespace $NAMESPACE"

# Copying and applying deployment YAML

scp $SSH_OPTS ~/cloudeco/k8s/deployment.yaml $SSH_USER@$MASTER_IP:~/deployment.yaml
scp $SSH_OPTS ~/cloudeco/k8s/service.yaml $SSH_USER@$MASTER_IP:~/service.yaml

ssh $SSH_OPTS $SSH_USER@$MASTER_IP "
  kubectl apply -f ~/deployment.yaml
  kubectl apply -f ~/service.yaml
"

# Waiting for pods to be ready

echo ""
echo "Waiting for pods to be ready..."
ssh $SSH_OPTS $SSH_USER@$MASTER_IP "kubectl rollout status deployment/cloudeco-deployment -n $NAMESPACE"

# Final status

echo " "
echo "Deployment complete!"
echo " "
ssh $SSH_OPTS $SSH_USER@$MASTER_IP "kubectl get pods -n $NAMESPACE"
echo " "
echo "Your API is accessible at:"
echo "  http://$WORKER1_IP:30000/health"
echo "  http://$WORKER2_IP:30000/health"
echo " "