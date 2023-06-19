#!/bin/bash

while getopts ":f:m:d:" opt; do
    case $opt in
        f) file_name=$OPTARG
        ;;
        m) manager_ips=($(echo $OPTARG | tr "," " "))
        ;;
        d) data_ips=($(echo $OPTARG | tr "," " "))
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

for i in "${!manager_ips[@]}"; do
    echo "    manager$((i+1)):" >> $file_name.yaml
    echo "      ansible_host: ${manager_ips[i]}" >> $file_name.yaml
    echo "      ip: ${manager_ips[i]}" >> $file_name.yaml
    echo "      access_ip: ${manager_ips[i]}" >> $file_name.yaml
done

for i in "${!data_ips[@]}"; do
    echo "    data$((i+1)):" >> $file_name.yaml
    echo "      ansible_host: ${data_ips[i]}" >> $file_name.yaml
    echo "      ip: ${data_ips[i]}" >> $file_name.yaml
    echo "      access_ip: ${data_ips[i]}" >> $file_name.yaml
done

echo "  children:" >> $file_name.yaml
echo "    cluster_manager:" >> $file_name.yaml
echo "      hosts:" >> $file_name.yaml
for i in "${!manager_ips[@]}"; do
    echo "        manager$((i+1)):" >> $file_name.yaml
done

echo "    cluster_data:" >> $file_name.yaml
echo "      hosts:" >> $file_name.yaml
for i in "${!data_ips[@]}"; do
    echo "        data$((i+1)):" >> $file_name.yaml
done

