#!/bin/bash

# Set to "true" to hide host update messages; set to "false" to show them.
QUIET=true

# Define an associative array with hostnames as keys and IP addresses as values
declare -A HOSTS=(
  ["k8-master-node-1"]="192.168.100.51"
  ["k8-master-node-2"]="192.168.100.52"
  ["k8-master-node-3"]="192.168.100.53"
  ["k8-worker-node-1"]="192.168.100.61"
  ["k8-worker-node-2"]="192.168.100.62"
  ["k8-worker-node-3"]="192.168.100.63"
)

# Function to update /etc/hosts quietly based on QUIET flag
update_hosts_file() {
  local ip="$1"
  local hostname="$2"

  # Check if the hostname already exists in /etc/hosts
  if grep -q "$hostname" /etc/hosts; then
    [ "$QUIET" != true ] && echo "$hostname exists in /etc/hosts. Updating entry..."
    # Remove existing entry
    sudo sed -i.bak "/\s$hostname$/d" /etc/hosts
  fi

  [ "$QUIET" != true ] && echo "Adding $hostname to /etc/hosts..."
  echo "$ip    $hostname" | sudo tee -a /etc/hosts > /dev/null
}

# Update /etc/hosts with all entries from the HOSTS array
for host in "${!HOSTS[@]}"; do
  update_hosts_file "${HOSTS[$host]}" "$host"
done

# Create an array of hostnames sorted in ascending order
sorted_hostnames=($(for host in "${!HOSTS[@]}"; do
  echo "$host"
done | sort))

# Display options to the user
echo "Select the hostname to configure:"
select selection in "${sorted_hostnames[@]}"; do
  if [[ -n "$selection" ]]; then
    HOSTNAME="$selection"
    IP="${HOSTS[$HOSTNAME]}"
    break
  else
    echo "Invalid selection. Please try again."
  fi
done

# Update the system hostname
echo "Setting hostname to $HOSTNAME..."
sudo hostnamectl set-hostname "$HOSTNAME"

# Identify the network interface name
INTERFACE=$(ip -o link show | awk -F': ' '{print $2}' | grep -E '^(en|eth)' | head -n 1)

# Check for existing Netplan configuration files
NETPLAN_DIR="/etc/netplan"
NETPLAN_CONFIG=$(ls $NETPLAN_DIR/*.yaml 2>/dev/null | head -n 1)

# If no Netplan configuration file exists, create a new one
if [[ -z "$NETPLAN_CONFIG" ]]; then
  NETPLAN_CONFIG="$NETPLAN_DIR/99-custom-config.yaml"
fi

# Backup existing Netplan configuration
if [[ -f "$NETPLAN_CONFIG" ]]; then
  echo "Backing up existing Netplan configuration..."
  sudo cp "$NETPLAN_CONFIG" "${NETPLAN_CONFIG}.bak"
fi

# Update or create Netplan configuration for the selected IP address using default routes
echo "Updating Netplan configuration at $NETPLAN_CONFIG..."
sudo tee "$NETPLAN_CONFIG" > /dev/null <<EOL
network:
  version: 2
  renderer: networkd
  ethernets:
    $INTERFACE:
      dhcp4: no
      addresses:
        - $IP/24
      routes:
        - to: default
          via: 192.168.100.1
      nameservers:
        addresses: [8.8.8.8, 4.2.2.2]
EOL

# Set correct permissions for the Netplan configuration file
echo "Setting permissions for $NETPLAN_CONFIG..."
sudo chmod 600 "$NETPLAN_CONFIG"

# Apply Netplan configuration
echo "Applying Netplan configuration..."
sudo netplan apply

echo "Configuration complete. Hostname set to $HOSTNAME with IP address $IP."

echo "logging user out to apply changes"
exit
logout
