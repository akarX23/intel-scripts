#!/bin/bash

# Parse arguments
while [[ $# -gt 0 ]]
do
key="$1"

case $key in
    --cluster)
    CLUSTER_NAME="$2"
    shift # past argument
    shift # past value
    ;;
    --node)
    NODE_NAME="$2"
    shift # past argument
    shift # past value
    ;;
    --roles)
    NODE_ROLES="$2"
    shift # past argument
    shift # past value
    ;;
    --managers)
    MANAGER_HOSTS="$2"
    shift # past argument
    shift # past value
    ;;
    --data)
    DATA_HOSTS="$2"
    shift # past argument
    shift # past value
    ;;
    *)    # unknown option
    echo "Unknown option: $1"
    exit 1
    ;;
esac
done

rm /etc/elasticsearch/elasticsearch.yml

cat > /etc/elasticsearch/elasticsearch.yml <<EOF

cluster.name: ${CLUSTER_NAME}
node.name: ${NODE_NAME}
node.roles: ${NODE_ROLES}
discovery.seed_hosts: ${MANAGER_HOSTS},${DATA_HOSTS}
cluster.initial_master_nodes: ${MANAGER_HOSTS}
network.host: 0.0.0.0
bootstrap.memory_lock: true
path.data: /var/lib/elasticsearch
path.logs: /var/log/elasticsearch
action.auto_create_index: true
transport.port: 9300
http.port: 9200

xpack.security.transport.ssl.enabled: false
xpack.security.enabled: false
xpack.security.http.ssl.enabled: false

EOF

chown elasticsearch:elasticsearch /etc/elasticsearch/elasticsearch.yml