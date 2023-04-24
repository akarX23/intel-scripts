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

# Calculate 50% ram of system
total_mem=$(free -m | awk '/^Mem:/{print $2}')
av_ram=$(($total_mem / 2))"m"

# Generate docker-compose file
cat > docker-compose.yml <<EOF
version: '3'
services:
  os:
    image: opensearchproject/opensearch:latest
    container_name: os-node
    environment:
      - cluster.name=${CLUSTER_NAME}
      - node.name=${NODE_NAME}
      - node.roles=${NODE_ROLES}
      - discovery.seed_hosts=${MANAGER_HOSTS},${DATA_HOSTS}
      - cluster.initial_master_nodes=${MANAGER_HOSTS}
      - bootstrap.memory_lock=true # Disable JVM heap memory swapping
      - "OPENSEARCH_JAVA_OPTS=-Xms${av_ram} -Xmx${av_ram}" # Set min and max JVM heap sizes to at least 50% of system RAM
      - "DISABLE_INSTALL_DEMO_CONFIG=true"
      - "DISABLE_SECURITY_PLUGIN=true"
    ulimits:
      memlock:
        soft: -1 # Set memlock to unlimited (no soft or hard limit)
        hard: -1
      nofile:
        soft: 65536 # Maximum number of open files for the opensearch user - set to at least 65536
        hard: 65536
    volumes:
      - $HOME/data:/usr/share/opensearch/data # Creates volume called opensearch-data1 and mounts it to the container
    ports:
      - 9200:9200 # REST API
      - 9600:9600 # Performance Analyzer
    network_mode: "host"

EOF
