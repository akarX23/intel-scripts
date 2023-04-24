#!/bin/bash

## Define variables
MEM_SIZE=2048       # Memory setting in MiB
VCPUS=2             # CPU Cores count
OS_VARIANT="ubuntu20.04" # List with osinfo-query  os
ISO_FILE="/mnt/nvme01/ubuntu-20.04-server-cloudimg-amd64-disk-kvm.img" # Path to ISO file

echo -en "Enter vm name: "
read VM_NAME
OS_TYPE="linux"
echo -en "Enter virtual disk size : "
read DISK_SIZE
echo -en "Enter RAM required : "
read MEM_SIZE
 
sudo virt-install \
     --name ${VM_NAME} \
     --memory=${MEM_SIZE} \
     --vcpus=${VCPUS} \
     --os-type ${OS_TYPE} \
     --location ${ISO_FILE} \
     --disk size=${DISK_SIZE}  \
     --network network=default \
     --graphics=none \
     --os-variant=${OS_VARIANT} \
     --console pty,target_type=serial \
     --initrd-inject ks.cfg --extra-args "inst.ks=file:/ks.cfg console=tty0 console=ttyS0,115200n8"
     #--extra-args="ks=http://192.168.122.1/ks.cfg console=tty0 console=ttyS0,115200n8"
