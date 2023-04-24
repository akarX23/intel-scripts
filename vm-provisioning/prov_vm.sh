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
OS_BENCHMARK=

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
        --osb )
            OS_BENCHMARK=true
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

# Check if the virtual machine exists
VM_EXISTS=$(virsh list --all | awk '{print $2}' | grep -x $VM_NAME)
if [ "$VM_EXISTS" ]; then
  echo "Error: virtual machine '$VM_NAME' already present."
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

uvt_kvm_args=(create "$VM_NAME" "release=$RELEASE" "arch=amd64"
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

if [[ "$OS_BENCHMARK" = true ]]; then
    uvt_kvm_args+=("--run-script-once" "/home/akarx/scripts/opensearch/setup_benchmark.sh")
fi

uvt-kvm "${uvt_kvm_args[@]}" 

echo -e "\nCreating vm $VM_NAME and running setup scripts"

uvt-kvm wait $VM_NAME &
pid=$!

countdown 300 $pid

# Create a unique macvtap interface name
if [ "$NETWORK" == "macvtap" ]; then
  MACVTAP_INTERFACE="macvtap$VM_NAME"
  echo -e "\nUsing macvtap interface: $MACVTAP_INTERFACE"
fi

# Check if the virtual machine exists
VM_EXISTS=$(virsh list --all | awk '{print $2}' | grep -w $VM_NAME)
if [ -z "$VM_EXISTS" ]; then
  echo "\nError: virtual machine '$VM_NAME' not found."
  exit 1
fi

# Get the current network of the virtual machine
current_network=$(virsh dumpxml $VM_NAME | grep 'source network' | awk -F\' '{print $2}')
echo -e "\nCurrent network: $current_network"

# echo -e "Deleting existing interfaces"
# interfaces=$(virsh dumpxml $VM_NAME | awk -F\' '/mac address/{print $2}')
# for interface in $interfaces; do
#   virsh detach-interface $VM_NAME network --mac $interface --config
#   ip link delete $(ip -o link show | awk -F': ' '/$interface/ {print $2}')
# done

# Create the network interface
# if [ "$NETWORK" == "nat" ]; then
#   echo -e "\nAttaching virtual machine to nat network 'default'"
#   virsh attach-interface $VM_NAME --type network --model virtio --source $current_network --config

virsh autostart $VM_NAME

if [ "$NETWORK" == "macvtap" ]; then
  sleep 5
  echo -e "\nShutting down $VM_NAME to attach network interfaces"
  virsh destroy $VM_NAME > /dev/null

  echo -e "\nAttaching virtual machine to macvtap network '$MACVTAP_INTERFACE'"
  # ip link add link eno1 name $MACVTAP_INTERFACE type macvtap mode bridge
  # ip link set $MACVTAP_INTERFACE up
  # ip addr add 10.227.88.140/24 dev $MACVTAP_INTERFACE 
  # ip addr add 192.168.122.2/24 dev $MACVTAP_INTERFACE
  # virsh attach-interface $VM_NAME --type direct --source eno1 --mode bridge --model virtio --target $MACVTAP_INTERFACE --config

cat > interface-{$VM_NAME}.xml << EOF
  <interface type='direct'>
    <source dev="eno1" mode="bridge"/>
    <model type='virtio'/>
    <target dev="$MACVTAP_INTERFACE"/>
  </interface>
EOF

  virsh attach-device $VM_NAME interface-{$VM_NAME}.xml --persistent --config
  rm interface-{$VM_NAME}.xml

  echo -e "Starting VM"
  virsh start $VM_NAME > /dev/null
  uvt-kvm wait $VM_NAME & pid=$!
  countdown 300 $pid
  echo -e "\n"
fi

echo -e "Removing the IP if it already exists in known_hosts"
ssh-keygen -f "/home/akarx/.ssh/known_hosts" -R $(uvt-kvm ip $VM_NAME) 

echo -e "\nAdding IP in known_hosts"
ssh-keyscan  $(uvt-kvm ip $VM_NAME) >> ~/.ssh/known_hosts 

echo -e "\nGetting IP address of vm $VM_NAME"
uvt-kvm ip $VM_NAME

