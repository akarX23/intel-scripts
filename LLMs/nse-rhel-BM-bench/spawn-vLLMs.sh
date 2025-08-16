#!/bin/bash

# Default values
HOST="0.0.0.0"
PORT=8000
SERVER_ARGS=""
KV_CACHE="100"
VLLM_USE_V1=1
MODEL=""
CORE_RANGES="0-31|43-74|86-117|128-159"
LOG_DIR=""
HF_TOKEN=""

# Print help message
print_help() {
  echo "Usage: $0 [OPTIONS]"
  echo ""
  echo "Options:"
  echo "  --host <host>              Host to bind to (default: 0.0.0.0)"
  echo "  --port <port>              Port to bind to (default: 8000)"
  echo "  --kv-cache <size>          KV Cache space (default: 100)"
  echo "  --vllm-use-v1 <0|1>        Use VLLM V1 (default: 1)"
  echo "  --server-args <args>       Additional args for vllm server"
  echo "  --model <model_path>       REQUIRED: Model to load"
  echo "  --core-ranges <ranges>     CPU core range (e.g., 0-40|43-83|86-125|128-168)"
  echo "  --log-dir <dir>            REQUIRED: Log directory to store output"
  echo "  --help                     Show this help message and exit"
  echo "  --hf-token <token>         Hugging Face token to export as HF_TOKEN (default: built-in token)"
  echo ""
  echo "Example:"
  echo "  $0 --model meta-llama/Llama-3.1-8B-Instruct --core-ranges 0-40 --log-dir ./logs"
  exit 0
}

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --host) HOST="$2"; shift 2 ;;
    --port) PORT="$2"; shift 2 ;;
    --kv-cache) KV_CACHE="$2"; shift 2 ;;
    --vllm-use-v1) VLLM_USE_V1="$2"; shift 2 ;;
    --server-args) SERVER_ARGS="$2"; shift 2 ;;
    --model) MODEL="$2"; shift 2 ;;
    --core-ranges) CORE_RANGES="$2"; shift 2 ;;
    --log-dir) LOG_DIR="$2"; shift 2 ;;
    --hf-token) HF_TOKEN="$2"; shift 2 ;;
    --help) print_help ;;
    *) echo "Unknown option: $1"; print_help ;;
  esac
done

# Check for required arguments
if [[ -z "$MODEL" || -z "$LOG_DIR" ]]; then
  echo "Error: --model, --core-ranges, and --log-dir are required."
  print_help
fi

wait_for_server() {
  local host="$1"
  local port="$2"
  local timeout=1500
  local elapsed=0

  echo "Waiting for vLLM server to be ready on $host:$port ..."

  while ! nc -z "$host" "$port" 2>/dev/null; do
    sleep 1
    elapsed=$((elapsed+1))

    # Check if process is still running
    if ! kill -0 "$VLLM_PID" 2>/dev/null; then
      echo "❌ vLLM process exited unexpectedly. Check logs at $LOG_FILE"
      exit 1
    fi

    if [[ $elapsed -ge $timeout ]]; then
      echo "❌ Timed out waiting for vLLM server to start after ${timeout}s"
      kill "$VLLM_PID" 2>/dev/null
      exit 1
    fi
  done

  echo "✅ vLLM server is up and running on $host:$port"
}


# Create log directory if it doesn't exist
mkdir -p "$LOG_DIR"

# Export environment variables
export VLLM_CPU_OMP_THREADS_BIND="$CORE_RANGES"
export VLLM_CPU_KVCACHE_SPACE="$KV_CACHE"
export VLLM_ENGINE_ITERATION_TIMEOUT_S=600
export VLLM_ALLOW_LONG_MAX_MODEL_LEN=1
export TORCHINDUCTOR_COMPILE_THREADS=1
export LD_PRELOAD="/usr/lib/x86_64-linux-gnu/libtcmalloc_minimal.so.4:$LD_PRELOAD"
export VLLM_CPU_NUM_OF_RESERVED_CPU=2
export HF_TOKEN="$HF_TOKEN"
export VLLM_USE_V1="$VLLM_USE_V1"

# Log file path
LOG_FILE="$LOG_DIR/vllm_server.log"

# Final command
CMD="vllm serve $MODEL \
  --dtype bfloat16 \
  -O3 \
  --max-num-seqs 4096 \
  --enable_chunked_prefill \
  --distributed-executor-backend mp \
  --max-num-batched-tokens 4096 \
  --host $HOST \
  --port $PORT \
  $SERVER_ARGS"

echo "Running: $CMD" | tee "$LOG_FILE"

# Run in background and capture PID
nohup bash -c "$CMD" >> "$LOG_FILE" 2>&1 &
VLLM_PID=$!
echo "vLLM server started with PID $VLLM_PID"

# Stream logs in background while checking readiness
tail -n 0 -f "$LOG_FILE" &
TAIL_PID=$!

# Wait for server to be ready or fail
wait_for_server "$HOST" "$PORT"

# Stop tailing logs once ready
kill "$TAIL_PID" 2>/dev/null

