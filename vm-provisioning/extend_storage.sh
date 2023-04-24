#!/bin/bash

VM_NAME=
NEW_DISK_SIZE=
TARGET=vda

while [ "$1" != "" ]; do
    case $1 in
        -n )
            VM_NAME="$2"
            shift 1
            ;;
        -d ) 
            NEW_DISK_SIZE="$2"
            shift 1
            ;;
        -t )
            TARGET="$2"
            shift 1
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
    echo "Error: -n argument cannot be empty or null."
    exit 1
fi

# Check if new disk size is given
if [[ -z "$NEW_DISK_SIZE" ]]; then
    echo "Error: -d argument cannot be empty or null."
    exit 1
fi

virsh blockresize $VM_NAME $(virsh domblklist --domain "$VM_NAME" | grep "$TARGET" | awk '{print $2}') $NEW_DISK_SIZE

if [  "$TARGET" = "vda" ]; then
    ssh ubuntu@$(virsh domifaddr --domain "$VM_NAME"  | grep "ipv4.*192" | head -n 1 | awk '{print $4}' | cut -d'/' -f1)  sudo apt -y install cloud-guest-utils gdisk
    ssh ubuntu@$(virsh domifaddr --domain "$VM_NAME"  | grep "ipv4.*192" | head -n 1 | awk '{print $4}' | cut -d'/' -f1) sudo growpart /dev/vda 1
    ssh ubuntu@$(virsh domifaddr --domain "$VM_NAME"  | grep "ipv4.*192" | head -n 1 | awk '{print $4}' | cut -d'/' -f1) sudo resize2fs /dev/vda1
fi

exit 0