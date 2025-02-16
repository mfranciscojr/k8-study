#!/bin/bash
# This script updates the package list, installs HAProxy (if not already installed),
# enables and starts the HAProxy service (if not already enabled/running), backs up
# the current configuration, deploys a new configuration from the current directory,
# and restarts HAProxy.

set -e  # Exit immediately if any command exits with a non-zero status

echo "Updating package list..."
sudo apt update

# Check if HAProxy is installed
if dpkg -s haproxy >/dev/null 2>&1; then
    echo "HAProxy is already installed. Skipping installation."
else
    echo "Installing HAProxy..."
    sudo apt install haproxy -y
fi
echo "Stopping haproxy..."
sudo systemctl stop haproxy

echo "Backing up current HAProxy configuration file..."
if [ -f /etc/haproxy/haproxy.cfg ]; then
    sudo cp /etc/haproxy/haproxy.cfg /etc/haproxy/haproxy.cfg.bak
    echo "Backup created at /etc/haproxy/haproxy.cfg.bak"
else
    echo "No existing HAProxy configuration found at /etc/haproxy/haproxy.cfg"
fi

echo "Deploying new HAProxy configuration file..."
if [ -f ./haproxy.cfg ]; then
    sudo cp ./haproxy.cfg /etc/haproxy/haproxy.cfg
else
    echo "New haproxy.cfg not found in the current directory!"
    exit 1
fi

# Check if HAProxy service is enabled
if systemctl is-enabled haproxy >/dev/null 2>&1; then
    echo "HAProxy service is already enabled."
else
    echo "Enabling HAProxy service..."
    sudo systemctl enable haproxy
fi

# Check if HAProxy service is running
if systemctl is-active haproxy >/dev/null 2>&1; then
    echo "HAProxy service is already running."
else
    echo "Starting HAProxy service..."
    sudo systemctl start haproxy
fi

echo "Restarting HAProxy service..."
sudo systemctl restart haproxy

echo "HAProxy setup complete."
