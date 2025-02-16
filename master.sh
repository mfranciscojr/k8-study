#!/bin/bash
# Kubernetes Cluster Initialization and Calico Deployment Automation Script
#
# This script:
#   1. Pulls required Kubernetes images via "kubeadm config images pull".
#   2. Retrieves the Kubernetes client version using "kubectl version --client"
#      and uses that version for kubeadm initialization.
#   3. Initializes the cluster with a specified pod network CIDR and node name.
#   4. Sets the KUBECONFIG environment variable.
#   5. Deploys the Calico Tigera Operator manifest.
#   6. Downloads, updates, and applies the Calico custom-resources manifest
#      (adjusting the default CIDR to match the specified pod network CIDR).
#
# Requirements: kubectl and kubeadm must be installed and available in PATH.
# Run as root or with sudo.
#
# Usage:
#   sudo ./k8s_calico_cluster.sh
#
# Customize these variables if needed:
POD_NETWORK_CIDR="10.10.0.0/16"
NODE_NAME="${NODE_NAME:-$(hostname)}"

# Function to log info messages
log() {
    echo "[INFO] $1"
}

# Function to log errors and exit
error_exit() {
    echo "[ERROR] $1" >&2
    exit 1
}

#############################
# Step 1: Pull required images
#############################
log "Pulling required Kubernetes images..."
sudo kubeadm config images pull || error_exit "Failed to pull images."

#############################
# Step 2: Get Kubernetes version from kubectl
#############################
log "Determining Kubernetes version from kubectl..."
# Using --client and parsing output like: "Client Version: v1.32.2"
KUBEADM_VERSION=$(kubectl version --client 2>/dev/null | grep "Client Version:" | awk '{print $3}')
if [ -z "$KUBEADM_VERSION" ]; then
    error_exit "Unable to determine Kubernetes version from kubectl."
fi
log "Detected Kubernetes version: $KUBEADM_VERSION"

#############################
# Step 3: Initialize the cluster using kubeadm
#############################
log "Initializing Kubernetes cluster with pod-network-cidr $POD_NETWORK_CIDR, version $KUBEADM_VERSION, node-name $NODE_NAME..."
sudo kubeadm init --pod-network-cidr "$POD_NETWORK_CIDR" --kubernetes-version "$KUBEADM_VERSION" --node-name "$NODE_NAME" || error_exit "kubeadm init failed."

#############################
# Step 4: Set KUBECONFIG environment variable
#############################
log "Setting KUBECONFIG environment variable..."
export KUBECONFIG=/etc/kubernetes/admin.conf

#############################
# Step 5: Deploy Calico Tigera Operator
#############################
log "Deploying Calico Tigera Operator manifest..."
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.29.1/manifests/tigera-operator.yaml || error_exit "Failed to deploy Tigera Operator."

#############################
# Step 6: Download and update Calico custom-resources manifest
#############################
log "Downloading Calico custom-resources manifest..."
wget -q https://raw.githubusercontent.com/projectcalico/calico/v3.29.1/manifests/custom-resources.yaml -O custom-resources.yaml || error_exit "Failed to download custom-resources.yaml."

log "Updating custom-resources.yaml to set cidr to $POD_NETWORK_CIDR..."
# Replace the default cidr "192.168.0.0/16" with the specified POD_NETWORK_CIDR.
sed -i "s/cidr: 192\.168\.0\.0\/16/cidr: $POD_NETWORK_CIDR/" custom-resources.yaml || error_exit "sed command failed."

log "Displaying updated custom-resources.yaml:"
cat custom-resources.yaml

log "Applying updated Calico custom-resources manifest..."
kubectl apply -f custom-resources.yaml || error_exit "Failed to apply custom-resources.yaml."

log "Kubernetes cluster initialization and Calico deployment complete."
