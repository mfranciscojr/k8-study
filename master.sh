#!/bin/bash
# Kubernetes Cluster Initialization and Calico Deployment Automation Script (Bash-only update)
#
# This script:
#   1. Pulls required images via "kubeadm config images pull".
#   2. Retrieves the Kubernetes client version using "kubectl version --client"
#      and uses that version for kubeadm initialization.
#   3. Initializes the cluster with a specified pod network CIDR and node name.
#   4. Sets the KUBECONFIG environment variable.
#   5. Deploys the Calico Tigera Operator manifest.
#   6. Downloads the Calico custom-resources manifest.
#   7. Uses sed (with pipe delimiters) to update the "cidr:" line in the manifest by removing the default value and replacing it with POD_NETWORK_CIDR.
#   8. Applies the updated manifest.
#
# Requirements: kubectl, kubeadm, wget, and sed must be installed.
# Run this script as root or via sudo.
#
# Usage:
#   sudo ./k8s_calico_cluster.sh
#
# Customize these variables if needed:
POD_NETWORK_CIDR="10.10.0.0/16"
NODE_NAME="${NODE_NAME:-$(hostname)}"

# Function to log messages
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
# Example output: "Client Version: v1.32.2"
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
sleep 30
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
# Step 6: Download Calico custom-resources manifest
#############################
log "Downloading Calico custom-resources manifest..."
wget -q https://raw.githubusercontent.com/projectcalico/calico/v3.29.1/manifests/custom-resources.yaml -O custom-resources.yaml || error_exit "Failed to download custom-resources.yaml."

#############################
# Step 7: Update custom-resources.yaml using sed
#############################
log "Updating custom-resources.yaml to set cidr to $POD_NETWORK_CIDR..."
# Replace the entire value after 'cidr:' with POD_NETWORK_CIDR,
# regardless of what whitespace or content is present.
sed -i -E "s|^([[:space:]]*cidr:[[:space:]]*).*|\1${POD_NETWORK_CIDR}|" custom-resources.yaml || error_exit "sed command failed."

log "Displaying updated custom-resources.yaml:"
cat custom-resources.yaml

#############################
# Step 8: Apply the updated Calico manifest
#############################
log "Applying updated Calico custom-resources manifest..."
kubectl apply -f custom-resources.yaml || error_exit "Failed to apply custom-resources.yaml."
export KUBECONFIG=/etc/kubernetes/admin.conf
log "Kubernetes cluster initialization and Calico deployment complete."
