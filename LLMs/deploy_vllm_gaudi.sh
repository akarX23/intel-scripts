#!/bin/bash

# Check if the user provided a valid integer argument
if [ -z "$1" ] || ! [[ "$1" =~ ^[0-9]+$ ]]; then
    echo "Usage: $0 <number_of_instances>"
    exit 1
fi

NUM_INSTANCES=$1
START_PORT=8001
MODEL="meta-llama/Llama-3.1-8B-Instruct"
DOWNLOAD_DIR="/mnt/models/hub"

# Kill existing vLLM processes
pkill -f "vllm.entrypoints.openai.api_server"

# Deploy vLLM instances
for ((i=0; i<NUM_INSTANCES; i++)); do
    PORT=$((START_PORT + i))
    echo "Starting vLLM instance on port $PORT..."

   # export PT_HPU_ENABLE_LAZY_COLLECTIVES=true
   # export EXPERIMENTAL_WEIGHT_SHARING=0
   # export VLLM_SKIP_WARMUP=false
   # export VLLM_GRAPH_RESERVED_MEM=0.05
   # export VLLM_GRAPH_PROMPT_RATIO=0.5
   # export VLLM_DECODE_BLOCK_BUCKET_STEP=256
   # export VLLM_PROMPT_SEQ_BUCKET_STEP=256
   # export VLLM_PROMPT_SEQ_BUCKET_MAX=2048
   # export VLLM_DECODE_BLOCK_BUCKET_MAX=1024

    nohup python3 -m vllm.entrypoints.openai.api_server \
        --host 0.0.0.0 --port $PORT \
        --model $MODEL \
        --block-size 128 \
        --dtype bfloat16 \
        --tensor-parallel-size 1 \
        --download_dir $DOWNLOAD_DIR \
        --max-model-len 2048 \
        --gpu-memory-util 0.9 \
        --use-padding-aware-scheduling \
        --max-num-seqs 256 \
        --max-num-prefill-seqs 16 \
        --num_scheduler_steps 16 > "vllm_$PORT.log" 2>&1 &
done

echo "All instances started successfully."

# Install HAProxy if not installed
if ! command -v haproxy &> /dev/null; then
    echo "Installing HAProxy..."
    sudo apt update && sudo apt install -y haproxy
fi

# Increase HAProxy performance limits
echo "Configuring HAProxy system settings..."
echo "ulimit -n 1048576" | sudo tee -a /etc/default/haproxy
echo "* soft nofile 1048576" | sudo tee -a /etc/security/limits.conf
echo "* hard nofile 1048576" | sudo tee -a /etc/security/limits.conf
sudo sysctl -w net.core.somaxconn=65535
sudo sysctl -w net.ipv4.tcp_max_syn_backlog=65535
sudo sysctl -w net.ipv4.tcp_fin_timeout=10
sudo sysctl -w net.ipv4.tcp_tw_reuse=1

# Generate HAProxy config
HAPROXY_CONFIG="/etc/haproxy/haproxy.cfg"

echo "Generating HAProxy configuration..."
sudo tee $HAPROXY_CONFIG > /dev/null <<EOL
global
    log stdout format raw local0
    maxconn 200000
    nbthread 8
    tune.ssl.default-dh-param 2048
    tune.bufsize 32768
    tune.maxrewrite 8192
    tune.ssl.cachesize 1000000
    tune.http.maxhdr 128
    tune.h2.max-concurrent-streams 256
    tune.h2.header-table-size 65536
    tune.h2.initial-window-size 1048576

defaults
    log global
    option redispatch
    timeout connect 5000ms
    timeout client 50000ms
    timeout server 50000ms

frontend vllm_frontend
    bind *:8000
    default_backend vllm_backend

backend vllm_backend
    balance roundrobin
EOL

for ((i=0; i<NUM_INSTANCES; i++)); do
    PORT=$((START_PORT + i))
    echo "    server vllm$((i+1)) 127.0.0.1:$PORT check" | sudo tee -a $HAPROXY_CONFIG
done

# Restart HAProxy
echo "Restarting HAProxy..."
/etc/init.d/haproxy restart

# Verify HAProxy status
/etc/init.d/haproxy status

echo "Deployment complete. vLLM instances running on ports 8001-$((START_PORT + NUM_INSTANCES - 1)) and load balanced via port 8000."
