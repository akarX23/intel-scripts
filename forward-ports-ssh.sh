#!/bin/bash

# Check if the correct number of arguments are provided
if [ "$#" -lt 4 ]; then
    echo "Usage: $0 <ports> <target_ip> <main_server_ip> <username>"
    exit 1
fi

# Extract arguments
ports=$1
target_ip=$2
main_server_ip=$3
username=$4

# Construct the port forwarding command
port_forwarding_cmd="ssh -fN $username@$main_server_ip"
IFS=',' read -ra port_array <<< "$ports"
for port in "${port_array[@]}"; do
    port_forwarding_cmd+=" -L $port:$target_ip:$port"
done

# Execute the port forwarding command
echo "Executing command: $port_forwarding_cmd"
eval "$port_forwarding_cmd"
