terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}


# Startup script for installing Docker, cri-dockerd and Kubernetes
# Runs on ALL nodes (master and workers)


locals {
  k8s_install_script = <<-EOF
    #!/bin/bash
    set -e

    # Update and install dependencies
    apt-get update
    apt-get install -y apt-transport-https ca-certificates curl gpg

    # Install Docker
    mkdir -m 0755 -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    apt-get update
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    # Install cri-dockerd
    wget https://github.com/Mirantis/cri-dockerd/releases/download/v0.3.16/cri-dockerd_0.3.16.3-0.ubuntu-jammy_amd64.deb
    dpkg -i cri-dockerd_0.3.16.3-0.ubuntu-jammy_amd64.deb

    # Install Kubernetes
    curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.32/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
    echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.32/deb/ /' | tee /etc/apt/sources.list.d/kubernetes.list
    apt-get update
    apt-get install -y kubelet kubeadm kubectl
    apt-mark hold kubelet kubeadm kubectl

    # Disable swap
    swapoff -a

    # Signal that installation is complete
    touch /tmp/k8s_ready
    EOF
}


# Firewall Rules


resource "google_compute_firewall" "k8s_external" {
  name    = "k8s-allow-api"
  network = var.network_name

  description = "Allow external SSH and NodePort access"

  allow {
    protocol = "tcp"
    ports    = ["22", "30000"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["k8s-node"]
}

resource "google_compute_firewall" "k8s_internal" {
  name    = "k8s-internal"
  network = var.network_name

  description = "Allow internal Kubernetes cluster communication"

  allow {
    protocol = "tcp"
    ports    = ["6443", "2379-2380", "10250-10259", "6783"]
  }

  allow {
    protocol = "udp"
    ports    = ["6783", "6784"]
  }

  source_ranges = ["10.128.0.0/9"]
  target_tags   = ["k8s-node"]
}


# VM Instances


resource "google_compute_instance" "k8s_master" {
  name         = "k8s-master"
  machine_type = var.machine_type
  zone         = var.zone
  tags         = ["k8s-node"]

  boot_disk {
    initialize_params {
      image = var.os_image
      size  = var.disk_size_gb
      type  = "pd-balanced"
    }
  }

  network_interface {
    network = var.network_name
    access_config {}
  }

  metadata = {
    ssh-keys       = "${var.ssh_user}:${var.ssh_public_key}"
    startup-script = local.k8s_install_script
  }

  labels = {
    role = "master"
    app  = "cloudeco"
  }
}

resource "google_compute_instance" "k8s_worker1" {
  name         = "k8s-worker1"
  machine_type = var.machine_type
  zone         = var.zone
  tags         = ["k8s-node"]

  boot_disk {
    initialize_params {
      image = var.os_image
      size  = var.disk_size_gb
      type  = "pd-balanced"
    }
  }

  network_interface {
    network = var.network_name
    access_config {}
  }

  metadata = {
    ssh-keys       = "${var.ssh_user}:${var.ssh_public_key}"
    startup-script = local.k8s_install_script
  }

  labels = {
    role = "worker"
    app  = "cloudeco"
  }
}

resource "google_compute_instance" "k8s_worker2" {
  name         = "k8s-worker2"
  machine_type = var.machine_type
  zone         = var.zone
  tags         = ["k8s-node"]

  boot_disk {
    initialize_params {
      image = var.os_image
      size  = var.disk_size_gb
      type  = "pd-balanced"
    }
  }

  network_interface {
    network = var.network_name
    access_config {}
  }

  metadata = {
    ssh-keys       = "${var.ssh_user}:${var.ssh_public_key}"
    startup-script = local.k8s_install_script
  }

  labels = {
    role = "worker"
    app  = "cloudeco"
  }
}


# Outputs


output "master_external_ip" {
  description = "External IP of k8s-master"
  value       = google_compute_instance.k8s_master.network_interface[0].access_config[0].nat_ip
}

output "worker1_external_ip" {
  description = "External IP of k8s-worker1"
  value       = google_compute_instance.k8s_worker1.network_interface[0].access_config[0].nat_ip
}

output "worker2_external_ip" {
  description = "External IP of k8s-worker2"
  value       = google_compute_instance.k8s_worker2.network_interface[0].access_config[0].nat_ip
}

output "setup_command" {
  description = "Run this after terraform apply to bootstrap the cluster"
  value       = "bash iac/setup_cluster.sh ${google_compute_instance.k8s_master.network_interface[0].access_config[0].nat_ip} ${google_compute_instance.k8s_worker1.network_interface[0].access_config[0].nat_ip} ${google_compute_instance.k8s_worker2.network_interface[0].access_config[0].nat_ip}"
}