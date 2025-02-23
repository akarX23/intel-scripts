#!/bin/bash

# clone vllm-fork if vllm is not available
# checkout to the v1.20.0
# install dependencies
# downlaod the zipped images
# unzip images to a folder
# run the vLLM server in background
# Continuously check the /health endpoint for status
# Once vLLM is ready, launch the python benchmark script for 1 concurrent requests

# Parse command-line arguments
while [[ "$#" -gt 0 ]]; do
  case $1 in
    --wd)
      WORKDIR="$2"
      shift 2
      ;;
    --model)
      MODEL="$2"
      shift 2
      ;;
    *)
      echo "Unknown parameter: $1"
      exit 1
      ;;
  esac
done

WORKDIR=${WORKDIR:-$HOME}
MODEL=${MODEL:-meta-llama/Llama-3.2-11B-Vision-Instruct}

HF_TOKEN=$HF_TOKEN
cd $WORKDIR

# Setup vLLM
if command -v vllm &> /dev/null; then
    echo "vLLM is available"
else
    echo "vLLM is NOT available, cloning repository."
    git clone https://github.com/HabanaAI/vllm-fork
    cd vllm-fork
    git checkout v1.20.0
    pip install -r requirements-hpu.txt
    python3 setup.py develop
fi

# Install gdown if not available
if command -v gdown &> /dev/null; then
    echo "gdown already present"
else
    echo "Installing gdown"
    pip install gdown
fi

# Download images
echo "Downloading images"
cd $WORKDIR
gdown 16-PyrfqkFwRTU3pz3jctQlpGs9x18Nda

# Extract images
echo "Extracting images"
sudo apt install -y unzip
unzip -o converted_pngs.zip -d images
NUM_IMAGES=$(ls images | wc -l)

# Spawn the vLLM server
VLLM_SKIP_WARMUP=true vllm serve $MODEL --enforce-eager --max-model-len 8192 --max_num_seqs 16 & 
VLLM_PID=$!
echo "vLLM server started with PID $VLLM_PID"

# Wait for vLLM to be ready
echo "Waiting for vLLM to be ready..."
while true; do
    STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8000/health)
    if [ "$STATUS" == "200" ]; then
        echo "vLLM is ready!"
        break
    fi
    sleep 5
done

# Download benchmark script
wget https://raw.githubusercontent.com/akarX23/intel-scripts/refs/heads/master/LLMs/open-ai-client-benchmark-vlm.py -O bench.py

