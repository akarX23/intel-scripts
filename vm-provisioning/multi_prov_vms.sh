#!/bin/bash

function countdown {
    local max_time=$1
    local pid=$2
    local flag=0
    local elapsed_time=0

    while [ $elapsed_time -le $max_time ]
    do
        if [ $flag -eq 1 ]; then
            break
        fi
        printf "\rElapsed Time : $elapsed_time seconds"
        sleep 1
        (( elapsed_time++ ))
        if ! ps -p $pid > /dev/null; then
            flag=1
        fi
    done

    printf "\n"
}


# Define default values
MEM_SIZE=2048
VCPUS=2
DISK_SIZE=10
RELEASE=focal
NETWORK=nat
DOCKER=
ZSH=
OPENSEARCH=

# Parse command line arguments
while [ "$1" != "" ]; do
    case $1 in
        --memory | -m )
            MEM_SIZE="$2"
            shift 1
            ;;
        --vcpu | -c )
            VCPUS="$2"
            shift 1
            ;;
        --dsize | -d )
            DISK_SIZE="$2"
            shift 1
            ;;
        --rel | -r )
            RELEASE="$2"
            shift 1
            ;;
        --name | -n )
            VM_NAME="$2"
            shift 1
            ;;
        --num )
            VM_COUNT="$2"
            shift 1
            ;;
        --ntype )
            NETWORK="$2"
            shift 1
            ;;
        --docker )
            DOCKER=true
            ;;
        --zsh )
            ZSH=true
            ;;
	--opensearch )
	    OPENSEARCH=true
	    ;;
        --yes | -y )
            AUTO_CONFIRM=true
            ;;
        * )
            echo "Unknown argument: $1"
            exit 1
            ;;
    esac
    shift
done

# Check if name is null
if [[ -z "$VM_NAME" ]]; then
    echo "Error: --name or -n argument cannot be empty or null."
    exit 1
fi

# Read password
echo -e "\nEnter password for default user ubuntu (hidden input):"
read -s PASSWD

# Display all values
echo -e "\nVM Name: $VM_NAME"
echo "Memory (MB): $MEM_SIZE"
echo "vCPUs: $VCPUS"
echo "Disk Size (GB): $DISK_SIZE"
echo "Ubuntu Release: $RELEASE"
echo -e "Network Type: $NETWORK \n"

# Confirm values
if [[ -z "$AUTO_CONFIRM" ]]; then
  read -p "Do you want to proceed with the above configuration? [y/N]: " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 1
  fi
else
  echo -e "\nSkipping confirmation prompt.\n"
fi

uvt_kvm_args=("release=$RELEASE" "arch=amd64"
    "--memory" "$MEM_SIZE" "--cpu" "$VCPUS" "--disk" "$DISK_SIZE"
    "--ssh-public-key-file" "/home/akarx/.ssh/id_rsa.pub" "--password" "$PASSWD"
     "--run-script-once" "/home/akarx/scripts/vm-provisioning/setup_single_server.sh"
   )

if [[ "$DOCKER" = true ]]; then
    uvt_kvm_args+=("--run-script-once" "/home/akarx/scripts/docker-setup/configure_docker.sh")
fi

if [[ "$ZSH" = true ]]; then
    uvt_kvm_args+=("--run-script-once" "/home/akarx/scripts/vm-provisioning/setup-zsh.sh")
fi

if [[ "$OPENSEARCH" = true ]]; then
    uvt_kvm_args+=("--run-script-once" "/home/akarx/scripts/opensearch/install_opensearch_manual.sh")
fi

echo -e "\nCreating vm $VM_NAME and running setup scripts"

# Create the VMs with the specified configuration in parallel
for i in $(seq 1 $VM_COUNT); do
    uvt-kvm create "$VM_NAME-$i" "${uvt_kvm_args[@]}" >/dev/null 2>&1
done

uvt-kvm wait $VM_NAME-1 &
pid=$!

countdown 300 $pid

# Get the current network of the virtual machine
current_network=$(virsh dumpxml $VM_NAME-1 | grep 'source network' | awk -F\' '{print $2}')
echo -e "\nCurrent network: $current_network"

IPs=()
for i in $(seq 1 $VM_COUNT); do

    echo -e "\n------------------------------------------------\n"
    virsh autostart $VM_NAME-$i

    IP=$(uvt-kvm ip "$VM_NAME-$i")
    IPs+=("$VM_NAME-$i: $IP") 

    echo -e "Removing the IP if it already exists in known_hosts"
    ssh-keygen -f "/home/akarx/.ssh/known_hosts" -R $IP 

    echo -e "\nAdding IP in known_hosts"
    ssh-keyscan  $IP >> ~/.ssh/known_hosts
done

echo -e "\n------------------------------------------------\n"
echo -e "\nGetting IP address of VMs"
for ip in "${IPs[@]}"; do
  echo $ip
done