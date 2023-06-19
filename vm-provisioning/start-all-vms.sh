#!/bin/bash
echo "=== starting all kvm vms that contain the word $1 ==="
for i in $(virsh list --all | awk '{print $2}'); do virsh start $i; done
virsh list --all
