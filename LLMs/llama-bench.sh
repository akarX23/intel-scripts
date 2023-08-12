#!/bin/bash

show_help() {
    echo "Usage: $0 -m <model_path> -n <numactl_cores> -t <num_tokens> -ct <context_size> -b <batch_size> -th <threads> -l <log_dir> [-g]"
    echo "Options:"
    echo "  -m, --model-path         Model path"
    echo "  -n, --numactl-cores      numactl cores"
    echo "  -t, --num-tokens         Number of tokens"
    echo "  -ct, --context-size      Context size"
    echo "  -b, --batch-size         Batch size"
    echo "  -th, --threads           Number of threads"
    echo "  -l, --log-dir            Log directory"
    echo "  -g, --use-gqa            Use GQA flag (optional)"
    echo "  -llp, --llama-path       Llama CPP main path"
    exit 1
}

# Default values
model_path=""
numactl_cores="0-55"
num_tokens="1024"
context_size="1000"
batch_size="1024"
threads="28"
log_dir="$(pwd)/logs"
use_gqa=false
llama_cpp_path="/home/akarx/llama.cpp/main"

# Parse input arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        -m|--model-path) model_path="$2"; shift 2;;
        -n|--numactl-cores) numactl_cores="$2"; shift 2;;
        -t|--num-tokens) num_tokens="$2"; shift 2;;
        -ct|--context-size) context_size="$2"; shift 2;;
        -b|--batch-size) batch_size="$2"; shift 2;;
        -th|--threads) threads="$2"; shift 2;;
        -l|--log-dir) log_dir="$2"; shift 2;;
        -g|--use-gqa) use_gqa=true; shift;;
        -llp|--llama-path) llama_cpp_path="$2"; shift 2;;
        -h|--help) show_help;;
        *) echo "Unknown option: $1"; show_help;;
    esac
done

# Set default values if not provided
if [[ -z "$model_path" ]]; then
    echo "Missing arguments."
    show_help
fi

# Set GQA flag if required
gqa_flag=""
if $use_gqa; then
    gqa_flag="-gqa 8"
fi

# Execute the benchmark script
command="numactl -C ${numactl_cores} ${llama_cpp_path} -m ${model_path} -n ${num_tokens} -t ${threads} ${gqa_flag} --ctx-size ${context_size} --batch-size ${batch_size}"
echo "Executing: ${command}"
result=$(eval ${command})

echo "Result: " $result
size=$(echo $result | grep "model size" | awk '{print $5}')
ctx_size=$(echo $result | grep "n_ctx" | head -n 1 | awk '{print $4}')
prompt_time=$(echo $result | grep "prompt eval time" | awk '{print $6}')
prompt_tokens=$(echo $result | grep "prompt eval time" | awk '{print $9}')
load_time=$(echo $result | grep "load time" | awk '{print $5}')
tps=$(echo "scale=2;$prompt_tokens / ($prompt_time / 1000)" | bc)
quant=$(echo $result | grep "ftype" | grep  -o '[0-9]*' | tail -1)

mkdir -p $log_dir
# Store the timings in a log file
log_file="$log_dir/${size}-$(date +%Y-%m-%d-%H:%M:%S).log"
echo "load_time: ${load_time} ms" >> ${log_file}
echo "numa_cores: ${numactl_cores}" >> ${log_file}
echo "Context size: ${ctx_size}" >> ${log_file}
echo "Prompt Time: ${prompt_time}" >> ${log_file}
echo "Prompt Tokens: ${prompt_tokens}" >> ${log_file}
echo "Tokens per second: ${tps}" >> ${log_file}
echo "Quantization: ${quant}" >> ${log_file}