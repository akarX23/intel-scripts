#!/bin/bash

# Default values
HOST="0.0.0.0"
PORT=8000
SERVER_ARGS=""
KV_CACHE="100"
VLLM_USE_V1=1
MODEL=""
CORE_RANGES=""
LOG_DIR=""
HF_TOKEN=""
DEPLOYMENTS=1
VLLM_CPU_SGL_KERNEL=1

# Print help message
print_help() {
  echo "Usage: $0 [OPTIONS]"
  echo ""
  echo "Options:"
  echo "  --host <host>              Host to bind to (default: 0.0.0.0)"
  echo "  --port <port>              Starting port to bind to (default: 8000)"
  echo "  --kv-cache <size>          KV Cache space (default: 100)"
  echo "  --vllm-use-v1 <0|1>        Use VLLM V1 (default: 1)"
  echo "  --use-sgl <0|1> Use VLLM CPU single kernel (default: 1)"
  echo "  --server-args <args>       Additional args for vllm server"
  echo "  --model <model_path>       REQUIRED: Model to load"
  echo "  --core-ranges <ranges>     Comma-separated CPU core ranges per deployment"
  echo "                             (e.g., \"0-31|43-74,86-117|128-159\")"
  echo "  --deployments <num>        Number of deployments (default: 1)"
  echo "  --log-dir <dir>            REQUIRED: Log directory to store output"
  echo "  --hf-token <token>         Hugging Face token (default: built-in token)"
  echo "  --help                     Show this help message and exit"
  echo ""
  echo "Example:"
  echo "  $0 --model meta-llama/Llama-3.1-8B-Instruct --deployments 2 \\"
  echo "     --core-ranges \"0-31|43-74,86-117|128-159\" --log-dir ./logs"
  exit 0
}

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --host) HOST="$2"; shift 2 ;;
    --port) PORT="$2"; shift 2 ;;
    --kv-cache) KV_CACHE="$2"; shift 2 ;;
    --vllm-use-v1) VLLM_USE_V1="$2"; shift 2 ;;
    --use-sgl) VLLM_CPU_SGL_KERNEL="$2"; shift 2 ;;
    --server-args) SERVER_ARGS="$2"; shift 2 ;;
    --model) MODEL="$2"; shift 2 ;;
    --core-ranges) CORE_RANGES="$2"; shift 2 ;;
    --log-dir) LOG_DIR="$2"; shift 2 ;;
    --hf-token) HF_TOKEN="$2"; shift 2 ;;
    --deployments) DEPLOYMENTS="$2"; shift 2 ;;
    --help) print_help ;;
    *) echo "Unknown option: $1"; print_help ;;
  esac
done

# Check for required arguments
if [[ -z "$MODEL" || -z "$LOG_DIR" || -z "$CORE_RANGES" ]]; then
  echo "Error: --model, --core-ranges, and --log-dir are required."
  print_help
fi

IFS=',' read -r -a CORE_RANGES_ARRAY <<< "$CORE_RANGES"

if [[ ${#CORE_RANGES_ARRAY[@]} -ne $DEPLOYMENTS ]]; then
  echo "Error: Number of core ranges provided (${#CORE_RANGES_ARRAY[@]}) does not match --deployments ($DEPLOYMENTS)"
  exit 1
fi

wait_for_server() {
  local host="$1"
  local port="$2"
  local pid="$3"
  local log_file="$4"
  local timeout=1500
  local elapsed=0

  echo "Waiting for vLLM server (PID=$pid) on $host:$port ..."

  while ! nc -z "$host" "$port" 2>/dev/null; do
    sleep 1
    elapsed=$((elapsed+1))

    if ! kill -0 "$pid" 2>/dev/null; then
      echo "❌ vLLM process $pid exited unexpectedly. Check logs at $log_file"
      exit 1
    fi

    if [[ $elapsed -ge $timeout ]]; then
      echo "❌ Timed out waiting for vLLM server on port $port after ${timeout}s"
      kill "$pid" 2>/dev/null
      exit 1
    fi
  done

  echo "✅ vLLM server on $host:$port is up (PID=$pid)"
}

# Create log directory
mkdir -p "$LOG_DIR"

# Array to track wait_for_server jobs
WAIT_PIDS=()

# Launch deployments in parallel
for i in $(seq 1 $DEPLOYMENTS); do
  DEPLOY_PORT=$((PORT + i - 1))
  DEPLOY_LOG="$LOG_DIR/vllm_server_$i.log"
  CORE_BIND="${CORE_RANGES_ARRAY[$((i-1))]}"

  # Per-deployment env vars
  ENV_VARS="VLLM_CPU_OMP_THREADS_BIND=\"$CORE_BIND\" \
VLLM_CPU_KVCACHE_SPACE=\"$KV_CACHE\" \
VLLM_ENGINE_ITERATION_TIMEOUT_S=600 \
VLLM_ALLOW_LONG_MAX_MODEL_LEN=1 \
TORCHINDUCTOR_COMPILE_THREADS=1 \
LD_PRELOAD=\"/usr/lib/x86_64-linux-gnu/libtcmalloc_minimal.so.4:$LD_PRELOAD\" \
VLLM_CPU_NUM_OF_RESERVED_CPU=2 \
HF_TOKEN=\"$HF_TOKEN\" \
VLLM_USE_V1=\"$VLLM_USE_V1\" \
VLLM_CPU_SGL_KERNEL=\"$VLLM_CPU_SGL_KERNEL\""

  CMD="vllm serve $MODEL \
    --dtype bfloat16 \
    --distributed-executor-backend mp \
    --host $HOST \
    --port $DEPLOY_PORT \
    $SERVER_ARGS"

    # --max-num-seqs 4096 \
    # --max-num-batched-tokens 4096 \

  # Combine env vars + command
  ENV_AND_CMD="$ENV_VARS $CMD"

  echo "Launching deployment $i on port $DEPLOY_PORT (cores: $CORE_BIND)"
  
  # Write env + cmd to the log header
  echo "==== Launching Deployment $i ====" > "$DEPLOY_LOG"
  echo "$ENV_AND_CMD" >> "$DEPLOY_LOG"
  echo "=================================" >> "$DEPLOY_LOG"

  # Run deployment
  nohup bash -c "$ENV_AND_CMD" >> "$DEPLOY_LOG" 2>&1 &
  VLLM_PID=$!
  echo "Deployment $i started with PID $VLLM_PID"

  # Readiness check (parallel)
  wait_for_server "$HOST" "$DEPLOY_PORT" "$VLLM_PID" "$DEPLOY_LOG" &
  WAIT_PIDS+=($!)
done

# Only wait for readiness checks, not the vLLM servers
for pid in "${WAIT_PIDS[@]}"; do
  wait "$pid"
done

echo "🎉 All $DEPLOYMENTS vLLM deployments are up and running!"
