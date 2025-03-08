#!/bin/bash

# Default values
HOST="0.0.0.0"
PORT=8000
DEPLOYMENT_FILES_ROOT="$(pwd)"
DATASET_NAME="random"
NUM_PROMPTS=1000
CLIENT_ARGS=""

# Required arguments (initially empty)
MODEL=""
CONCURRENCIES=()
INPUT_LENGTHS=()
OUTPUT_LENGTHS=()
LOG_DIR=""
NUM_DEPLOYMENTS=""
CORES_PER_DEPLOYMENT=""
VLLM_ROOT=""

# Help function
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --host                   Set the host (default: $HOST)"
    echo "  --port                   Set the port (default: $PORT)"
    echo "  --deployment-files-root  Set the deployment files root (default: $DEPLOYMENT_FILES_ROOT)"
    echo "  --dataset-name           Set the dataset name (default: $DATASET_NAME)"
    echo "  --num-prompts            Set the number of prompts (default: $NUM_PROMPTS)"
    echo "  --client-args            Set additional client arguments"
    echo "  --model                  (Required) Set the model name"
    echo "  --concurrencies          (Required) Set comma-separated concurrency values"
    echo "  --input-lengths          (Required) Set comma-separated input length values"
    echo "  --output-lengths         (Required) Set comma-separated output length values"
    echo "  --log-dir                (Required) Set the log directory"
    echo "  --num-deployments        (Required) Set the number of deployments"
    echo "  --cores-per-deployment   (Required) Set the number of cores per deployment"
    echo "  --vllm-root              (Required) Set the VLLM root directory"
    echo "  -h, --help               Show this help message and exit"
    exit 1
}

# Parse arguments
while [[ "$#" -gt 0 ]]; do
    case "$1" in
        --host) HOST="$2"; shift 2;;
        --port) PORT="$2"; shift 2;;
        --deployment-files-root) DEPLOYMENT_FILES_ROOT="$2"; shift 2;;
        --dataset-name) DATASET_NAME="$2"; shift 2;;
        --num-prompts) NUM_PROMPTS="$2"; shift 2;;
        --client-args) CLIENT_ARGS="$2"; shift 2;;
        --model) MODEL="$2"; shift 2;;
        --concurrencies) IFS=',' read -r -a CONCURRENCIES <<< "$2"; shift 2;;
        --input-lengths) IFS=',' read -r -a INPUT_LENGTHS <<< "$2"; shift 2;;
        --output-lengths) IFS=',' read -r -a OUTPUT_LENGTHS <<< "$2"; shift 2;;
        --log-dir) LOG_DIR="$2"; shift 2;;
        --num-deployments) NUM_DEPLOYMENTS="$2"; shift 2;;
        --cores-per-deployment) CORES_PER_DEPLOYMENT="$2"; shift 2;;
        --vllm-root) VLLM_ROOT="$2"; shift 2;;
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
[[ ${#INPUT_LENGTHS[@]} -eq 0 ]] && MISSING_ARGS+=("--input-lengths")
[[ ${#OUTPUT_LENGTHS[@]} -eq 0 ]] && MISSING_ARGS+=("--output-lengths")

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
echo "DEPLOYMENT FILES ROOT: $DEPLOYMENT_FILES_ROOT"
echo "DATASET NAME:         $DATASET_NAME"
echo "NUM PROMPTS:          $NUM_PROMPTS"
echo "CLIENT ARGS:          $CLIENT_ARGS"
echo "MODEL:                $MODEL"
echo "CONCURRENCIES:        ${CONCURRENCIES[*]}"
echo "INPUT LENGTHS:        ${INPUT_LENGTHS[*]}"
echo "OUTPUT LENGTHS:       ${OUTPUT_LENGTHS[*]}"
echo "LOG DIR:              $LOG_DIR"
echo "NUM DEPLOYMENTS:      $NUM_DEPLOYMENTS"
echo "CORES PER DEPLOYMENT: $CORES_PER_DEPLOYMENT"
echo "VLLM ROOT:            $VLLM_ROOT"
echo "------------------------------------"

mkdir -p "$LOG_DIR"
echo -e "\n\n"

cd $DEPLOYMENT_FILES_ROOT

# Launch docker compose deployment
echo "vLLM server is not active on $HOST:$PORT (HTTP status: $HEALTH_STATUS). Launching server..."
RAM_BEFORE=$(free -m | awk '/^Mem:/{print $3}')
docker compose -f docker-compose.yml up > "$LOG_DIR/vllm-server.out" 2>&1 &

# Wait for all deployments to come up
echo "Waiting for vLLM to be ready..."
while true; do
    STATUS=$(curl -s -o /dev/null -w "%{http_code}" "http://$HOST:$PORT/health")
    if [ "$STATUS" == "200" ]; then
        echo "vLLM is ready!"
        break
    fi
    sleep 5
done
sleep 60

RAM_AFTER=$(free -m | awk '/^Mem:/{print $3}')
RAM_USAGE_GB=$(echo "scale=2; ($RAM_AFTER - $RAM_BEFORE)/1024" | bc)

CLIENT_LOG="$LOG_DIR/client.out"
RESULTS_CSV="$LOG_DIR/results.csv"

echo "Runtime,Optimizations,Model,Number of Deployments,Cores per Deployment,Input Sequence Length,Output Sequence Length,Concurrency,Mean TTFT,Mean TPOT,Output Token Throughput,Request Throughput,RAM Utilization" > "$RESULTS_CSV"

# Run benchmarks: nested loops for concurrency, input lengths, and output lengths
echo -e "Starting benchmarks... \n"
for concurrency in "${CONCURRENCIES[@]}"; do
    for input_len in "${INPUT_LENGTHS[@]}"; do
        for output_len in "${OUTPUT_LENGTHS[@]}"; do
           
            echo -e "Running benchmark with concurrency: $concurrency, input length: $input_len, output length: $output_len \n" | tee -a "$CLIENT_LOG"
           
            # Construct the benchmark command
            CMD="python3 $VLLM_ROOT/benchmarks/benchmark_serving.py --backend vllm --host $HOST --port $PORT --model $MODEL --request-rate inf --dataset-name $DATASET_NAME --num-prompts $NUM_PROMPTS --ignore-eos --max-concurrency $concurrency --random-input-len $input_len --random-output-len $output_len $CLIENT_ARGS"
            
            # Append the command to the client.out file
            echo -e "Running command: $CMD \n" >> $CLIENT_LOG
            
            # Execute the command and capture its output in a variable
            bench_output=$(eval "$CMD" 2>&1)
            echo "$bench_output" >> "$CLIENT_LOG"

            # Extract metrics from the benchmark output using grep and awk
            mean_ttft=$(echo "$bench_output" | grep "Mean TTFT" | awk -F: '{print $2}' | xargs)
            mean_tpot=$(echo "$bench_output" | grep "Mean TPOT" | awk -F: '{print $2}' | xargs)
            req_throughput=$(echo "$bench_output" | grep "Request throughput" | awk -F: '{print $2}' | xargs)
            output_token_throughput=$(echo "$bench_output" | grep "Output token throughput" | awk -F: '{print $2}' | xargs)
            
            # Append a separator for clarity between runs
            echo -e "\n\n\n\n" >> $CLIENT_LOG

            # Append the extracted metrics as a CSV line to the results file
            echo "vLLM,AMX,$MODEL,$NUM_DEPLOYMENTS,$CORES_PER_DEPLOYMENT,$input_len,$output_len,$concurrency,$mean_ttft,$mean_tpot,$output_token_throughput,$req_throughput,$RAM_USAGE_GB" >> "$RESULTS_CSV"

            # 5 second break
            sleep 30
        done
    done
done

# Stop deployments
docker compose down
