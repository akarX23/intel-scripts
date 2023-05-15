#!/bin/bash

while [[ $# -gt 0 ]]
do
key="$1"

case $key in
    --vms)
    IFS=',' read -r -a VMS <<< "$2"
    shift
    ;;
    --vcpus)
    VCPUS="$2"
    shift
    ;;
    --ram)
    RAM="$2"
    shift
    ;;
    *)
    # unknown option
    ;;
esac
shift
done

for VM in "${VMS[@]}"
do
    (
        echo "Updating VM: $VM"
        virsh shutdown $VM

        echo "Wating for $VM to shutdown"
        while [ "$(virsh domstate $VM)" != "shut off" ]; do
            echo "$VM - $(virsh domstate $VM)"
            sleep 1
        done

        echo "Setting Max Memory for $VM"
        virsh setmaxmem --domain $VM $(($RAM*1024*1024))

        echo "Setting vCPU for $VM"
        sed -i "s/<vcpu placement='static'>[^<]*<\/vcpu>/<vcpu placement='static'>$VCPUS<\/vcpu>/" /etc/libvirt/qemu/$VM.xml
        virsh create /etc/libvirt/qemu/$VM.xml

        echo "Waiting for $VM to come up"
        uvt-kvm wait $VM --without-ssh

        echo "Setting current memory fro $VM"
        virsh setmem --domain $VM $(($RAM*1024*1024))
    ) &
done

wait