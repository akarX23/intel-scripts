#!/bin/bash

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        -v|--vms)
        vm_names="$2"
        shift 2
        ;;
        -s|--size)
        disk_size="$2"
        shift 2
        ;;
        -p|--pool)
        pool="$2"
        shift 2
        ;;
        -d|--disks)
        num_disks="$2"
        shift 2
        ;;
        *)
        echo "Unknown argument: $1"
        exit 1
        ;;
    esac
done

# Check that required arguments were provided
if [[ -z "$vm_names" || -z "$disk_size" ]]; then
    echo "Usage: $0 --vm <comma-separated list of VM names> --size <disk size (e.g. 10G)> [--pool <storage pool name>] [--disks <number of disks to attach>]"
    exit 1
fi

# Set default values for optional arguments
if [[ -z "$pool" ]]; then
    pool="uvtool"
fi
if [[ -z "$num_disks" ]]; then
    num_disks=1
fi

# Split the comma-separated list of VM names into an array
IFS=',' read -ra vm_array <<< "$vm_names"

echo "Shutting VMs down for attaching disks"
for vm_name in "${vm_array[@]}"; do
    virsh shutdown $vm_name
done

sleep 10

# Loop over each VM and attach the specified number of disks
for vm_name in "${vm_array[@]}"; do

    for (( i=1; i<=$num_disks; i++ )); do
        target=""

        # Determine the next available target
        existing_targets=$(virsh domblklist --domain $vm_name | awk '/v[a-z]*/{print $1}' | awk '{print $NF}')
        readarray -t target_arr <<< "$existing_targets"
        next_target=""

        j=0
        for j in "${!target_arr[@]}"; do
            target="${target_arr[$j]}"

            if [ $j -lt $((${#target_arr[@]}-1)) ]; then
                next_target_in_loop="${target_arr[$j+1]}"
            else
                next_target_in_loop=""
            fi

            next_suffix=$(echo "$target" | sed 's/.*\(.\)$/\1/' | tr 'a-y' 'b-z')
            next_target=$(echo "$target" | awk '{print substr($0, 1, length-1)}')$next_suffix

            if [ "$next_target" != "$next_target_in_loop" ]; then
                target=$next_target
                break
            fi
        done

        # Calculate the name of the disk image
        img_name="$vm_name-$target-$i.qcow2"

        echo "$target"

        # Create the disk image
        virsh vol-create-as --pool $pool --name $img_name $disk_size --format qcow2 --allocation 0

        # Set the appropriate ownership on the disk image
        sudo chown libvirt-qemu:kvm $(virsh vol-path --pool $pool --vol $img_name)

        # Attach the disk image to the VM
        virsh attach-disk $vm_name $(virsh vol-path --pool $pool --vol $img_name) $target --driver qemu --subdriver qcow2 --config

        sleep 3
    done
done

for vm_name in "${vm_array[@]}"; do
    virsh start $vm_name
done