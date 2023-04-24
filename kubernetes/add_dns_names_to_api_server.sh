#!/bin/bash

set -e

if [ $# -ne 2 ]; then
    echo "Usage: $0 <comma-separated list of master nodes> <comma-separated list of DNS names>"
    exit 1
fi

masters=$1
dns_names=$2

for master in $(echo $masters | tr ',' ' '); do
    for dns_name in $(echo $dns_names | tr ',' ' '); do
        ssh ubuntu@$master "sudo kubectl -n kube-system get configmap kubeadm-config -o jsonpath='{.data.ClusterConfiguration}' > kubeadm.yaml"
	ssh ubuntu@$master "wget -qO ~/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64"
	ssh ubuntu@$master "sudo mv /home/ubuntu/yq /usr/local/bin"
	ssh ubuntu@$master "sudo chmod a+x /usr/local/bin/yq"
    done
done
