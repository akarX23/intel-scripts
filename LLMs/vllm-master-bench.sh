#!/bin/bash

# Default values
HOST="0.0.0.0"
PORT=8000
KV_CACHE=40
HF_TOKEN=${HF_TOKEN:-""}
TP=1
VLLM_SERVER_ARGS=""
VLLM_ROOT="$(pwd)/vllm"
DATASET_NAME="random"
NUM_PROMPTS=1000
CLIENT_ARGS=""

# Required arguments
CPUS_BIND=""
MODEL=""
CONCURRENCIES=()
INPUT_LENGTHS=()
OUTPUT_LENGTHS=()
LOG_DIR=""

# install bc in bg
apt -y install bc > /dev/null 2>&1 

# Function to display help
usage() {
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  --host <host>                 vLLM server host (default: $HOST)"
    echo "  --port <port>                 vLLM server port (default: $PORT)"
    echo "  --kv_cache <GB>               KV cache size in GB (default: $KV_CACHE)"
    echo "  --cpus_bind <cpus>            CPUs to bind (required)"
    echo "  --hf_token <token>            Huggingface token (default: \$HF_TOKEN)"
    echo "  --model <model>               Model to host and benchmark (required)"
    echo "  --tp <integer>                Tensor parallelism (default: $TP)"
    echo "  --vllm-server-args <args>     Extra arguments for vLLM server"
    echo "  --vllm-root <path>            Root directory of vLLM (default: $VLLM_ROOT)"
    echo "  --dataset-name <name>         Dataset for benchmarking (default: $DATASET_NAME)"
    echo "  --num-prompts <num>           Number of prompts per request (default: $NUM_PROMPTS)"
    echo "  --concurrencies <list>        List of concurrency values (required, comma-separated)"
    echo "  --input-lengths <list>        List of input token lengths (required, comma-separated)"
    echo "  --output-lengths <list>       List of output token lengths (required, comma-separated)"
    echo "  --client-args <args>          Extra arguments for the benchmark client"
    echo "  --log-dir <path>              Directory for logs (required)"
    echo "  --help                        Display this help message"
    exit 1
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --host) HOST="$2"; shift 2;;
        --port) PORT="$2"; shift 2;;
        --kv_cache) KV_CACHE="$2"; shift 2;;
        --cpus_bind) CPUS_BIND="$2"; shift 2;;
        --hf_token) HF_TOKEN="$2"; shift 2;;
        --model) MODEL="$2"; shift 2;;
        --tp) TP="$2"; shift 2;;
        --vllm-server-args) VLLM_SERVER_ARGS="$2"; shift 2;;
        --vllm-root) VLLM_ROOT="$2"; shift 2;;
        --dataset-name) DATASET_NAME="$2"; shift 2;;
        --num-prompts) NUM_PROMPTS="$2"; shift 2;;
        --concurrencies) IFS=',' read -ra CONCURRENCIES <<< "$2"; shift 2;;
        --input-lengths) IFS=',' read -ra INPUT_LENGTHS <<< "$2"; shift 2;;
        --output-lengths) IFS=',' read -ra OUTPUT_LENGTHS <<< "$2"; shift 2;;
        --client-args) CLIENT_ARGS="$2"; shift 2;;
        --log-dir) LOG_DIR="$2"; shift 2;;
        --help) usage;;
        *) echo "Unknown option: $1"; usage;;
    esac
done

# Validate required arguments
MISSING_ARGS=()
[ -z "$CPUS_BIND" ] && MISSING_ARGS+=("--cpus_bind")
[ -z "$MODEL" ] && MISSING_ARGS+=("--model")
[ ${#CONCURRENCIES[@]} -eq 0 ] && MISSING_ARGS+=("--concurrencies")
[ ${#INPUT_LENGTHS[@]} -eq 0 ] && MISSING_ARGS+=("--input-lengths")
[ ${#OUTPUT_LENGTHS[@]} -eq 0 ] && MISSING_ARGS+=("--output-lengths")
[ -z "$LOG_DIR" ] && MISSING_ARGS+=("--log-dir")

if [ ${#MISSING_ARGS[@]} -ne 0 ]; then
    echo "Error: Missing required arguments: ${MISSING_ARGS[*]}"
    usage
fi


# Print summary
cat <<EOF

Configuration:
--------------
Host: $HOST
Port: $PORT
KV Cache: $KV_CACHE GB
CPUs Bind: $CPUS_BIND
Huggingface Token: ${HF_TOKEN:0:4}****** (masked)
Model: $MODEL
Tensor Parallelism: $TP
vLLM Server Args: $VLLM_SERVER_ARGS
vLLM Root: $VLLM_ROOT
Dataset Name: $DATASET_NAME
Number of Prompts: $NUM_PROMPTS
Concurrencies: ${CONCURRENCIES[*]}
Input Lengths: ${INPUT_LENGTHS[*]}
Output Lengths: ${OUTPUT_LENGTHS[*]}
Client Args: $CLIENT_ARGS
Log Directory: $LOG_DIR
--------------
EOF

mkdir -p "$LOG_DIR"
echo -e "\n\n"

# Check if vLLM server is active by querying the /health endpoint
HEALTH_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "http://$HOST:$PORT/health")
if [ "$HEALTH_STATUS" -eq 200 ]; then
    echo "vLLM server is active on $HOST:$PORT."

    SERVER_PID=$(pgrep -f "vllm.entrypoints.openai.api_server" | head -n 1)
    # # Get RAM usage (in KB) then convert to MB
    # RAM_USAGE_KB=$(ps -p "$SERVER_PID" -o rss= | xargs)
    # RAM_USAGE_MB=$(echo "scale=2; $RAM_USAGE_KB/1024" | bc)
    RAM_USAGE_GB="NA"
else
    echo "vLLM server is not active on $HOST:$PORT (HTTP status: $HEALTH_STATUS). Launching server..."

    RAM_BEFORE=$(free -m | awk '/^Mem:/{print $3}')

    # Launch the vLLM server in the background with output redirected to the log file
    VLLM_USE_V1=0 \
    VLLM_ALLOW_LONG_MAX_MODEL_LEN=1 \
    VLLM_ENGINE_ITERATION_TIMEOUT_S=600 \
    VLLM_CPU_KVCACHE_SPACE="$KV_CACHE" \
    VLLM_CPU_OMP_THREADS_BIND="$CPUS_BIND" \
    python3 -m vllm.entrypoints.openai.api_server --model "$MODEL" -tp $TP $VLLM_SERVER_ARGS \
        > "$LOG_DIR/vllm-server.out" 2>&1 &

    SERVER_PID=$!
    echo "vLLM server launched with PID: $SERVER_PID"

    # Wait for vLLM to be ready
    echo "Waiting for vLLM to be ready..."
    while true; do
        STATUS=$(curl -s -o /dev/null -w "%{http_code}" "http://$HOST:$PORT/health")
        if [ "$STATUS" == "200" ]; then
            echo "vLLM is ready!"
            break
        fi
        sleep 5
    done

    RAM_AFTER=$(free -m | awk '/^Mem:/{print $3}')
    RAM_USAGE_GB=$(echo "scale=2; ($RAM_AFTER - $RAM_BEFORE)/1024" | bc)
fi

CLIENT_LOG="$LOG_DIR/client.out"
RESULTS_CSV="$LOG_DIR/results.csv"

echo "Runtime,Optimizations,TP,Model,Input Sequence Length,Output Sequence Length,Concurrency,Mean TTFT,Mean TPOT,Output Token Throughput,Request Throughput,RAM Utilization" > "$RESULTS_CSV"

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
            echo "vLLM,AMX,$TP,$MODEL,$input_len,$output_len,$concurrency,$mean_ttft,$mean_tpot,$output_token_throughput,$req_throughput,$RAM_USAGE_GB" >> "$RESULTS_CSV"

            # 5 second break
            sleep 5
        done
    done
done

# Kill vLLM Server
echo -e "\n\nKilling vLLM Server"
kill -9 $SERVER_PID