#!/bin/bash

while getopts ":f:m:w:" opt; do
    case $opt in
        f) file_name=$OPTARG
        ;;
        m) master_ips=($(echo $OPTARG | tr "," " "))
        ;;
        w) worker_ips=($(echo $OPTARG | tr "," " "))
        ;;
        \?) echo "Invalid option -$OPTARG" >&2
        ;;
    esac
done

if [ -e "$file_name.yaml" ]; then
  rm $file_name.yaml
fi

echo "all:" > $file_name.yaml
echo "  hosts:" >> $file_name.yaml

for i in "${!master_ips[@]}"; do
    echo "    master$((i+1)):" >> $file_name.yaml
    echo "      ansible_host: ${master_ips[i]}" >> $file_name.yaml
    echo "      ip: ${master_ips[i]}" >> $file_name.yaml
    echo "      access_ip: ${master_ips[i]}" >> $file_name.yaml
done

for i in "${!worker_ips[@]}"; do
    echo "    worker$((i+1)):" >> $file_name.yaml
    echo "      ansible_host: ${worker_ips[i]}" >> $file_name.yaml
    echo "      ip: ${worker_ips[i]}" >> $file_name.yaml
    echo "      access_ip: ${worker_ips[i]}" >> $file_name.yaml
done

echo "  children:" >> $file_name.yaml
echo "    kube_control_plane:" >> $file_name.yaml
echo "      hosts:" >> $file_name.yaml
for i in "${!master_ips[@]}"; do
    echo "        master$((i+1)):" >> $file_name.yaml
done

echo "    kube_node:" >> $file_name.yaml
echo "      hosts:" >> $file_name.yaml
for i in "${!worker_ips[@]}"; do
    echo "        worker$((i+1)):" >> $file_name.yaml
done

echo "    etcd:" >> $file_name.yaml
echo "      hosts:" >> $file_name.yaml
for i in "${!master_ips[@]}"; do
    echo "        master$((i+1)):" >> $file_name.yaml
done
for i in "${!worker_ips[@]}"; do
    echo "        worker$((i+1)):" >> $file_name.yaml
done

echo "    k8s_cluster:" >> $file_name.yaml
echo "      children:" >> $file_name.yaml
echo "        kube_control_plane:" >> $file_name.yaml
echo "        kube_node:" >> $file_name.yaml

echo "    calico_rr:" >> $file_name.yaml
echo "      hosts: {}" >> $file_name.yaml

