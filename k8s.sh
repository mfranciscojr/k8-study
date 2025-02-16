#!/bin/bash
# Improved Kubernetes & containerd installation & configuration automation script
# This script disables swap, configures kernel modules and sysctl parameters,
# installs containerd, runc, CNI plugins, and Kubernetes components (kubeadm, kubelet, kubectl).
# It requires jq, wget and curl to be installed.
#
# Usage: Run as root or with sudo privileges.
# Make sure your system has an internet connection.
#
# Author: Jhun Francisco
# Date: Feb 16, 2025

set -euo pipefail
IFS=$'\n\t'

# Log function for easier debugging
log() {
    echo "[INFO] $1"
}

error_exit() {
    echo "[ERROR] $1" >&2
    exit 1
}

#############################
# Pre-requisite checks
#############################
command -v curl >/dev/null 2>&1 || error_exit "curl is required but not installed."
command -v wget >/dev/null 2>&1 || error_exit "wget is required but not installed."
command -v jq >/dev/null 2>&1 || error_exit "jq is required but not installed."

#############################
# Functions
#############################

disable_swap() {
    log "Disabling swap..."
    sudo swapoff -a
    sudo sed -i 's|^/swap.img|#/swap.img|' /etc/fstab
}

install_prerequisites() {
    log "Updating package lists and installing prerequisites..."
    sudo apt-get update -y
    sudo apt-get install -y ca-certificates gnupg lsb-release apt-transport-https gpg
}

load_kernel_modules() {
    log "Configuring kernel modules for containerd..."
    sudo tee /etc/modules-load.d/containerd.conf > /dev/null <<EOF
overlay
br_netfilter
EOF
    sudo modprobe overlay
    sudo modprobe br_netfilter
}

update_sysctl() {
    log "Setting sysctl parameters for Kubernetes..."
    sudo tee /etc/sysctl.d/99-kubernetes-cri.conf > /dev/null <<EOF
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF
    sudo sysctl --system
}

install_containerd() {
    log "Installing containerd..."
    # Fetch latest containerd release in the 1.x.x series from GitHub using jq
    LATEST_VERSION=$(curl --silent "https://api.github.com/repos/containerd/containerd/releases" | \
      jq -r '.[] | select(.tag_name | test("^v1\\.[0-9]+\\.[0-9]+$")) | .tag_name' | sort -V | tail -n1)
    if [ -z "$LATEST_VERSION" ]; then
        error_exit "Could not determine the latest containerd release."
    fi
    log "Latest containerd version detected: $LATEST_VERSION"
    VERSION=${LATEST_VERSION#v}

    log "Downloading containerd-${VERSION}-linux-amd64.tar.gz..."
    wget -q "https://github.com/containerd/containerd/releases/download/${LATEST_VERSION}/containerd-${VERSION}-linux-amd64.tar.gz" -P /tmp/

    log "Extracting containerd..."
    sudo tar -C /usr/local -xzvf /tmp/containerd-${VERSION}-linux-amd64.tar.gz

    log "Downloading containerd systemd service file..."
    sudo wget -q "https://raw.githubusercontent.com/containerd/containerd/main/containerd.service" -P /etc/systemd/system/

    log "Reloading systemd and enabling containerd..."
    sudo systemctl daemon-reload
    sudo systemctl enable --now containerd

    log "Generating default containerd configuration..."
    sudo mkdir -p /etc/containerd
    sudo containerd config default | sudo tee /etc/containerd/config.toml > /dev/null

    log "Modifying containerd configuration to set SystemdCgroup = true..."
    sudo sed -i 's/^\(\s*SystemdCgroup\s*=\s*\).*/\1true/' /etc/containerd/config.toml

    log "Restarting containerd..."
    sudo systemctl restart containerd
    log "containerd installation complete."
}

install_runc() {
    log "Installing runc..."
    LATEST_RUNC=$(curl --silent "https://api.github.com/repos/opencontainers/runc/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
    if [ -z "$LATEST_RUNC" ]; then
      error_exit "Could not determine the latest runc release."
    fi
    log "Latest runc version: $LATEST_RUNC"
    wget -q "https://github.com/opencontainers/runc/releases/download/${LATEST_RUNC}/runc.amd64" -P /tmp/
    sudo install -m 755 /tmp/runc.amd64 /usr/local/sbin/runc
    log "runc installation complete."
}

install_cni_plugins() {
    log "Installing CNI plugins..."
    LATEST_CNI=$(curl --silent "https://api.github.com/repos/containernetworking/plugins/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
    if [ -z "$LATEST_CNI" ]; then
      error_exit "Could not determine the latest CNI plugins release."
    fi
    log "Latest CNI plugins version: $LATEST_CNI"
    wget -q "https://github.com/containernetworking/plugins/releases/download/${LATEST_CNI}/cni-plugins-linux-amd64-${LATEST_CNI}.tgz" -P /tmp/
    sudo mkdir -p /opt/cni/bin
    sudo tar -C /opt/cni/bin -xzvf /tmp/cni-plugins-linux-amd64-${LATEST_CNI}.tgz
    log "CNI plugins installation complete."
}

install_kubernetes() {
    log "Installing Kubernetes components (kubeadm, kubelet, kubectl)..."
    # Fetch latest Kubernetes release info for stable channel (using kubeadm repo)
    # Here we assume that you want to use the latest candidate versions available from the official repo.
    sudo mkdir -p -m 755 /etc/apt/keyrings
    log "Downloading Kubernetes GPG key..."
    curl -fsSL "https://pkgs.k8s.io/core:/stable:/v1.29/deb/Release.key" | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
    log "Configuring Kubernetes APT repository..."
    echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.29/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list > /dev/null
    log "Updating APT package lists..."
    sudo apt-get update -y
    log "Installing kubelet, kubeadm, and kubectl..."
    sudo apt-get install -y kubelet kubeadm kubectl
    sudo apt-mark hold kubelet kubeadm kubectl
    log "Kubernetes components installation complete."
}

#############################
# Main Execution Flow
#############################

main() {
    log "Starting automation script..."
    disable_swap
    install_prerequisites
    load_kernel_modules
    update_sysctl
    install_containerd
    install_runc
    install_cni_plugins
    install_kubernetes
    log "All components have been installed and configured successfully."
}

main
