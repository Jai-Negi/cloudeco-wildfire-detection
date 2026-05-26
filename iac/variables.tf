variable "project_id" {
  description = "GCP project ID"
  type        = string
  default     = "cloudeco-494715"
}

variable "region" {
  description = "GCP region"
  type        = string
  default     = "australia-southeast1"
}

variable "zone" {
  description = "GCP zone"
  type        = string
  default     = "australia-southeast1-a"
}

variable "machine_type" {
  description = "VM machine type — 4 vCPU, 8GB RAM as per assignment spec"
  type        = string
  default     = "custom-4-8192"
}

variable "os_image" {
  description = "Boot disk OS image"
  type        = string
  default     = "ubuntu-os-cloud/ubuntu-2204-lts"
}

variable "disk_size_gb" {
  description = "Boot disk size in GB"
  type        = number
  default     = 50
}

variable "ssh_user" {
  description = "SSH username"
  type        = string
  default     = "jainegi"
}

variable "ssh_public_key" {
  description = "SSH public key for VM access"
  type        = string
  default     = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIH8kFVqV5G4x3UoggWBWPvlBJ7PbJuj/tcgmdFMAbhvo jainegi@Jais-MacBook-Air.local"
}

variable "ssh_private_key_path" {
  description = "Path to SSH private key for cluster setup"
  type        = string
  default     = "~/.ssh/cloudeco_key"
}

variable "network_name" {
  description = "VPC network name"
  type        = string
  default     = "default"
}

variable "docker_image" {
  description = "Docker image to deploy"
  type        = string
  default     = "jainegi02/cloudeco:latest"
}

variable "k8s_namespace" {
  description = "Kubernetes namespace"
  type        = string
  default     = "cloudeco"
}