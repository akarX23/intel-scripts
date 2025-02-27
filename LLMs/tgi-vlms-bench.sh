#!/bin/bash

# Parse command-line arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --hf-volume)
            HF_VOLUME="$2"
            shift 2
            ;;
        --images-dir)
            IMAGES_DIR="$2"
            shift 2
            ;;
        --conc)
            CONC="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

if [ -z "$HF_VOLUME" ] || [ -z "$IMAGES_DIR" ]; then
    echo "Usage: $0 --hf-volume <path> --images-dir <path> --conc <concurrency>"
    exit 1
fi

# Delete images greater than 1MB
find "$IMAGES_DIR" -type f -size +1M -delete

# Filter images less than or equal to 1MB and count them
NUM_IMAGES=$(find "$IMAGES_DIR" -type f -size 1M | wc -l)

docker rm -f tgi-H1

docker run -d -p 8000:80 \
    -v "$HF_VOLUME":/data \
    --runtime=habana \
    -e HABANA_VISIBLE_DEVICES=1 \
    -e OMPI_MCA_btl_vader_single_copy_mechanism=none \
    -e HF_TOKEN="$HF_TOKEN" \
    -e ENABLE_HPU_GRAPH=true \
    -e LIMIT_HPU_GRAPH=true \
    -e USE_FLASH_ATTENTION=true \
    -e http_proxy="$http_proxy" \
    -e HTTP_PROXY="$HTTP_PROXY" \
    -e https_proxy="$https_proxy" \
    -e HTTPS_PROXY="$HTTPS_PROXY" \
    -e no_proxy="$no_proxy" \
    -e NO_PROXY="$NO_PROXY" \
    --name tgi-H1 \
    -e FLASH_ATTENTION_RECOMPUTE=true \
    --cap-add=sys_nice --ipc=host \
    ghcr.io/huggingface/tgi-gaudi:2.3.1 \
    --model-id llava-hf/llava-v1.6-mistral-7b-hf \
    --max-input-length 4096  \
    --max-total-tokens 8192 --max-batch-total-tokens 16384

# Wait for TGI to be ready
echo "Waiting for TGI to be ready..."
while true; do
    STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8000/health)
    if [ "$STATUS" == "200" ]; then
        echo "TGI is ready!"
        break
    fi
    sleep 5
done

wget https://raw.githubusercontent.com/akarX23/intel-scripts/refs/heads/master/LLMs/open-ai-client-benchmark-vlm.py -O bench.py

python3 bench.py --cores 4 --deployments 1 --total_requests "$NUM_IMAGES" --image_folder "$IMAGES_DIR" --num_concurrent "$CONC" --model "$MODEL" --host localhost
