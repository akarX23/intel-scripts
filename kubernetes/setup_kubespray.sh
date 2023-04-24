#!/bin/bash

# Defaults
ANS_USER=$USER
KUBESPRAY_PATH=kubespray
NODE_PREFIX=node

# Extract arguments
while getopts ":m:w:u:p:k:h" opt; do
    case $opt in
        m)
            masters=$OPTARG
            master_ips=($(echo $OPTARG | tr "," " "))
            ;;
        w)
            workers=$OPTARG
            worker_ips=($(echo $OPTARG | tr "," " "))
            ;;
        u)
            ANS_USER=$OPTARG
            ;;
        p)
            NODE_PREFIX=$OPTARG
            ;;
        k) 
            KUBESPRAY_PATH=$OPTARG
            ;;
        h)
            echo "Usage: script.sh [OPTIONS]"
            echo "Options:"
            echo "  -m <string>   comma separated list of master node IPs"
            echo "  -w <string>   comma separated list of worker node IPs"
            echo "  -u <string>   remote user to use for ssh connection (default: $USER)"
            echo "  -p <string>   prefix to use for node names (default: node)"
            echo "  -k <string>   absolute path to kubespray directory (default: kubespray)"
            echo "  -h            display this help message and exit"
            exit 0
            ;;
        \?)
            echo "Invalid option: -$OPTARG" >&2
            echo "Use -h option to display the help message." >&2
            exit 1
            ;;
    esac
done

all_ips=("${master_ips[@]}" "${worker_ips[@]}")

###### START SETTING UP OF K8 CLUSTER #######

cd $KUBESPRAY_PATH
pip3 install -r requirements.txt
cp -rfp inventory/sample inventory/mycluster

# Add to known_hosts
for ip in "${all_ips[@]}"; do
    ssh-keyscan -H $ip >> $HOME/.ssh/known_hosts
done

# Generate hosts.yaml file with our script
declare -a IPS=("${all_ips[@]}")
CONFIG_FILE=inventory/mycluster/hosts.yaml KUBE_CONTROL_HOSTS=${#master_ips[@]} NODE_PREFIX=$NODE_PREFIX python3 contrib/inventory_builder/inventory.py ${IPS[@]}

# Generate ansible config
if ! grep -q "\[defaults\]" $HOME/.ansible.cfg; then
    echo -e '\n[defaults]\nhost_key_checking = False' >> $HOME/.ansible.cfg
fi

# Changing kube_read_only_port
sed -i 's/# kube_read_only_port: 10255/kube_read_only_port: 10255/g'  inventory/mycluster/group_vars/all/all.yml

# Execute ansible playbook
ansible-playbook -i  inventory/mycluster/hosts.yaml -u $ANS_USER -b cluster.yml  
 
# Copy admin.conf from root directory in a master node to user directory in the same master node so we can get access to that file
ssh ${ANS_USER}@${master_ips[0]} "sudo cp /etc/kubernetes/admin.conf ~/admin.conf"

# Give ubuntu user in master node permission to access admin.conf
ssh ${ANS_USER}@${master_ips[0]} "sudo chown $ANS_USER:$ANS_USER ~/admin.conf"

# Copy admin.conf from master node to bastion host
mkdir $HOME/.kubernetes
scp ${ANS_USER}@${master_ips[0]}:~/admin.conf $HOME/.kubernetes

# Give user in bastion host access to the admin.conf
sudo chown $USER:$USER $HOME/.kubernetes/admin.conf

# Change the address in admin.conf to use the private ip of the master node or else bastion won't be able to connect to k8 cluster
sed -i "s/127.0.0.1/${master_ips[0]}/g" $HOME/.kubernetes/admin.conf

###### END SETTING UP OF K8 CLUSTER #######

