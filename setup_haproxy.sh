#!/bin/bash
# This script updates the package list, installs HAProxy,
# enables and starts the HAProxy service, backs up the current configuration,
# deploys a new configuration from the local directory, and restarts HAProxy.

set -e  # Exit immediately if a command exits with a non-zero status

echo "Updating package list..."
sudo apt update

echo "Installing HAProxy..."
sudo apt install haproxy -y

echo "Enabling HAProxy service..."
sudo systemctl enable haproxy

echo "Starting HAProxy service..."
sudo systemctl start haproxy

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

echo "Restarting HAProxy service..."
sudo systemctl restart haproxy

echo "HAProxy setup complete."
