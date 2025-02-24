#!/bin/bash

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
    --conc)
      CONC="$2"
      shift 2
      ;;
    --warm-iter)
      WARMUP_ITERATIONS="$2"
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
CONC=${CONC:-1}

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
cd $WORKDIR
if [ ! -f "converted_pngs.zip" ]; then
    echo "Downloading images"
    gdown 16-PyrfqkFwRTU3pz3jctQlpGs9x18Nda
else
    echo "Images archive already exists, skipping download."
fi

# Extract images
echo "Extracting images"
sudo apt install -y unzip
unzip -u converted_pngs.zip -d images
NUM_IMAGES=$(ls images/converted_pngs | wc -l)

# Determine vLLM command based on model
if [ "$MODEL" == "meta-llama/Llama-3.2-11B-Vision-Instruct" ]; then
    VLLM_COMMAND="VLLM_SKIP_WARMUP=true vllm serve $MODEL --enforce-eager --max-model-len 8192 --max_num_seqs 16 &"
else
    VLLM_COMMAND="VLLM_SKIP_WARMUP=true vllm serve $MODEL --max-model-len 8192 --max_num_seqs 16 &"
fi

# Start vLLM server in background
eval $VLLM_COMMAND
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

# Run warmup benchmark
echo "Running warmup benchmark for $WARMUP_ITERATIONS iterations"
for ((i=1; i<=WARMUP_ITERATIONS; i++)); do
    echo "Warmup iteration $i of $WARMUP_ITERATIONS"
    python3 bench.py --cores 4 --deployments 1 --total_requests $NUM_IMAGES --image_folder $WORKDIR/images/converted_pngs --num_concurrent $CONC --model $MODEL --host localhost
done

echo "Warmup complete. Running actual benchmark."

# Run actual benchmark script
python3 bench.py --cores 4 --deployments 1 --total_requests $NUM_IMAGES --image_folder $WORKDIR/images/converted_pngs --num_concurrent $CONC --model $MODEL --host localhost

# Clean up
echo "Stopping vLLM server"
kill $VLLM_PID