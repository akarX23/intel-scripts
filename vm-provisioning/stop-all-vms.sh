#!/bin/bash
echo "=== stopping all kvm vms ==="
for i in $(virsh list --all |  awk '{print $2}'); do virsh shutdown $i; done
virsh list --all
