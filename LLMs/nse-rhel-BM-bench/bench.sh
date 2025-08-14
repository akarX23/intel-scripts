#!/bin/bash

# Default values
HOST="0.0.0.0"
PORT=8000
DATASET_NAME="sonnet"
NUM_PROMPTS=1000
CLIENT_ARGS=""

# Required arguments (initially empty)
MODEL=""
CONCURRENCIES=()
LENGTHS=()
LOG_DIR=""
NUM_DEPLOYMENTS=""
CORES_PER_DEPLOYMENT=""
VLLM_ROOT=""
CONDA_ENV=""

# Help function
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --host                   Set the host (default: $HOST)"
    echo "  --port                   Set the port (default: $PORT)"
    echo "  --dataset-name           Set the dataset name (default: $DATASET_NAME)"
    echo "  --num-prompts            Set the number of prompts (default: $NUM_PROMPTS)"
    echo "  --client-args            Set additional client arguments"
    echo "  --model                  (Required) Set the model name"
    echo "  --concurrencies          (Required) Set comma-separated concurrency values"
    echo "  --lengths                (Required) Set comma-separated token length values"
    echo "  --log-dir                (Required) Set the log directory"
    echo "  --num-deployments        (Required) Set the number of deployments"
    echo "  --cores-per-deployment   (Required) Set the number of cores per deployment"
    echo "  --vllm-root              (Required) Set the VLLM root directory"
    echo "  --conda-env <env_name>     REQUIRED: Conda environment to activate"
    echo "  -h, --help               Show this help message and exit"
    exit 1
}

# Parse arguments
while [[ "$#" -gt 0 ]]; do
    case "$1" in
        --host) HOST="$2"; shift 2;;
        --port) PORT="$2"; shift 2;;
        --dataset-name) DATASET_NAME="$2"; shift 2;;
        --num-prompts) NUM_PROMPTS="$2"; shift 2;;
        --client-args) CLIENT_ARGS="$2"; shift 2;;
        --model) MODEL="$2"; shift 2;;
        --concurrencies) IFS=',' read -r -a CONCURRENCIES <<< "$2"; shift 2;;
        --lengths) IFS=',' read -r -a LENGTHS <<< "$2"; shift 2;;
        --log-dir) LOG_DIR="$2"; shift 2;;
        --num-deployments) NUM_DEPLOYMENTS="$2"; shift 2;;
        --cores-per-deployment) CORES_PER_DEPLOYMENT="$2"; shift 2;;
        --vllm-root) VLLM_ROOT="$2"; shift 2;;
        --conda-env) CONDA_ENV="$2"; shift 2 ;;
        -h|--help) usage;;
        *) echo "Unknown option: $1"; usage;;
    esac
done

# Validate required arguments and track missing ones
MISSING_ARGS=()

[[ -z "$MODEL" ]] && MISSING_ARGS+=("--model")
[[ -z "$LOG_DIR" ]] && MISSING_ARGS+=("--log-dir")
[[ -z "$NUM_DEPLOYMENTS" ]] && MISSING_ARGS+=("--num-deployments")
[[ -z "$CORES_PER_DEPLOYMENT" ]] && MISSING_ARGS+=("--cores-per-deployment")
[[ -z "$VLLM_ROOT" ]] && MISSING_ARGS+=("--vllm-root")
[[ ${#CONCURRENCIES[@]} -eq 0 ]] && MISSING_ARGS+=("--concurrencies")
[[ ${#LENGTHS[@]} -eq 0 ]] && MISSING_ARGS+=("--lengths")

if [[ ${#MISSING_ARGS[@]} -gt 0 ]]; then
    echo "Error: The following required arguments are missing:"
    for arg in "${MISSING_ARGS[@]}"; do
        echo "  $arg"
    done
    echo ""
    usage
fi

# Configuration Summary
echo "Configuration Summary:"
echo "------------------------------------"
echo "HOST:                 $HOST"
echo "PORT:                 $PORT"
echo "DATASET NAME:         $DATASET_NAME"
echo "NUM PROMPTS:          $NUM_PROMPTS"
echo "CLIENT ARGS:          $CLIENT_ARGS"
echo "MODEL:                $MODEL"
echo "CONCURRENCIES:        ${CONCURRENCIES[*]}"
echo "LENGTHS:              ${LENGTHS[*]}"
echo "LOG DIR:              $LOG_DIR"
echo "NUM DEPLOYMENTS:      $NUM_DEPLOYMENTS"
echo "CORES PER DEPLOYMENT: $CORES_PER_DEPLOYMENT"
echo "VLLM ROOT:            $VLLM_ROOT"
echo "------------------------------------"

mkdir -p "$LOG_DIR"
# Activate conda environment
source "$(conda info --base)/etc/profile.d/conda.sh"
conda info --env
conda activate "$CONDA_ENV"

echo -e "\n\n"

# Launch docker compose deployment
echo "vLLM server is not active on $HOST:$PORT (HTTP status: $HEALTH_STATUS)."
echo "Waiting for vLLM to be ready on $HOST:$PORT..."

MAX_WAIT=150
WAIT_INTERVAL=5
elapsed=0

while true; do
    HEALTH_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "http://$HOST:$PORT/health")

    if [ "$HEALTH_STATUS" == "200" ]; then
        echo "✅ vLLM is ready!"
        break
    fi

    if (( elapsed >= MAX_WAIT )); then
        echo "❌ vLLM server is not active on $HOST:$PORT after $MAX_WAIT seconds (Last HTTP status: $HEALTH_STATUS). Exiting..."
        exit 1
    fi

    sleep $WAIT_INTERVAL
    elapsed=$((elapsed + WAIT_INTERVAL))
done

sleep 10

CLIENT_LOG="$LOG_DIR/client.out"
RESULTS_CSV="$LOG_DIR/results.csv"
rm -f "$CLIENT_LOG" "$RESULTS_CSV"

echo "Runtime,Optimizations,Model,Number of Deployments,Cores per Deployment,Input Sequence Length,Output Sequence Length,Concurrency,Mean TTFT,P90 TTFT,Mean TPOT,P90 TPOT,E2E Latency,P90 E2E Latency,Output Token Throughput,Interactivity,Request Throughput,RAM Utilization" > "$RESULTS_CSV"

# Run benchmarks: nested loops for concurrency, input lengths, and output lengths
echo -e "Starting benchmarks... \n"
for concurrency in "${CONCURRENCIES[@]}"; do
    for length in "${LENGTHS[@]}"; do
           
            # Calculate NUM_PROMPTS based on concurrency
            NUM_PROMPTS=$((concurrency * 2))
            
            echo -e "Running benchmark with concurrency: $concurrency, input length: $length, output length: $length, num prompts: $NUM_PROMPTS\n" | tee -a "$CLIENT_LOG"

            # Add extra args if dataset is sonnet
            SONNET_ARGS=""
            if [[ "$DATASET_NAME" == "sonnet" ]]; then
                # Customize as per your sonnet handling requirement
                SONNET_ARGS="--dataset-path $VLLM_ROOT/benchmarks/sonnet.txt --sonnet-input-len $length --sonnet-output-len $length --sonnet-prefix-len 100"
            fi

            if [[ "$DATASET_NAME" == "random" ]]; then
                # Customize as per your sonnet handling requirement
                RANDOM_ARGS="--random-input-len $length --random-output-len $length"
            fi

            if [[ "$DATASET_NAME" == "vision" ]]; then
                # Customize as per your sonnet handling requirement
                DATASET_NAME="hf"
                VISION_ARGS="--backend openai-chat --endpoint /v1/chat/completions --dataset-path lmarena-ai/VisionArena-Chat --hf-split train --ignore-eos --hf-output-len $length"
            fi

            # Construct the benchmark command
            CMD="python3 $VLLM_ROOT/benchmarks/benchmark_serving.py \
                --backend vllm \
                --host $HOST \
                --port $PORT \
                --model $MODEL \
                --request-rate inf \
                --dataset-name $DATASET_NAME \
                --num-prompts $NUM_PROMPTS \
                --ignore-eos \
                --max-concurrency $concurrency \
                --metric_percentiles 90 \
                --percentile_metrics='ttft,tpot,itl,e2el' \
                $RANDOM_ARGS \
                $SONNET_ARGS \
                $VISION_ARGS \
                $CLIENT_ARGS "
            # Append the command to the client.out file
            echo -e "Running command: $CMD \n" >> $CLIENT_LOG
            
            # Execute the command and capture its output in a variable
            bench_output=$(eval "$CMD" 2>&1)
            echo "$bench_output" >> "$CLIENT_LOG"

            # Extract metrics from the benchmark output using grep and awk
            mean_ttft=$(echo "$bench_output" | grep "Mean TTFT" | awk -F: '{print $2}' | xargs)
            p90_ttft=$(echo "$bench_output" | grep "P90 TTFT" | awk -F: '{print $2}' | xargs)

            mean_tpot=$(echo "$bench_output" | grep "Mean TPOT" | awk -F: '{print $2}' | xargs)
            p90_tpot=$(echo "$bench_output" | grep "P90 TPOT" | awk -F: '{print $2}' | xargs)

            mean_e2e=$(echo "$bench_output" | grep "Mean E2EL" | awk -F: '{print $2}' | xargs)
            p90_e2e=$(echo "$bench_output" | grep "P90 E2EL" | awk -F: '{print $2}' | xargs)

            req_throughput=$(echo "$bench_output" | grep "Request throughput" | awk -F: '{print $2}' | xargs)

            output_token_throughput=$(echo "$bench_output" | grep "Output token throughput" | awk -F: '{print $2}' | xargs)
            tokens_per_sec_per_user=$(awk "BEGIN {printf \"%.2f\", $output_token_throughput / $concurrency}")

            # Append a separator for clarity between runs
            echo -e "\n\n\n\n" >> $CLIENT_LOG

            # Append the extracted metrics as a CSV line to the results file
            echo "vLLM,AMX,$MODEL,$NUM_DEPLOYMENTS,$CORES_PER_DEPLOYMENT,$length,$length,$concurrency,$mean_ttft,$p90_ttft,$mean_tpot,$p90_tpot,$mean_e2e,$p90_e2e,$output_token_throughput,$tokens_per_sec_per_user,$req_throughput,$RAM_USAGE_GB" >> "$RESULTS_CSV"

            # 5 second break
            sleep 10    
    done
done

echo -e "\n\nBenchmarks completed. Results saved to $RESULTS_CSV"
