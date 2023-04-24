#!/bin/bash

# Parse arguments
while [[ $# -gt 0 ]]
do
key="$1"

case $key in
    --managers)
    HOSTS="$2"
    shift # past argument
    shift # past value
    ;;
    *)    # unknown option
    echo "Unknown option: $1"
    exit 1
    ;;
esac
done

IFS=',' read -ra ADDR <<< "$HOSTS"
for i in "${ADDR[@]}"; do
  formatted_hosts="$formatted_hosts,\"http://$i:9200\""
done
formatted_hosts="${formatted_hosts:1}" # Remove the leading comma

# Generate docker-compose file
cat > docker-compose.yml <<EOF
version: '3'
services:
  os:
    image: opensearchproject/opensearch-dashboards:latest
    container_name: os-dashboard
    environment:
      - 'OPENSEARCH_HOSTS=[${formatted_hosts}]'
      - "DISABLE_SECURITY_DASHBOARDS_PLUGIN=true"
    ports:
      - 5601:5601 # Map host port 5601 to container port 5601
    expose:
      - "5601" # Expose port 5601 for web access to OpenSearch Dashboards
    network_mode: "host"

EOF
