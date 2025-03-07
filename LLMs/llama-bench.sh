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
    echo "  -v, --verbose            Pass this flag to show llama.cpp output"
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
verbose=false

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
        -v|--verbose) verbose=true; shift;;
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

mkdir -p $log_dir

pprint() {
    echo -e "\n----->" $1
}

pprint "Flushing system cache"
sudo sh -c 'sync; echo 3 > /proc/sys/vm/drop_caches'

pprint "Sleeping for 5 seconds..."
sleep 5

# Execute the benchmark script
command="numactl -C ${numactl_cores} ${llama_cpp_path} -m ${model_path} -n ${num_tokens} -t ${threads} ${gqa_flag} --ctx-size ${context_size} --batch-size ${batch_size}"
pprint "Executing: ${command}"

if $verbose; then
    eval "${command}" 2>&1 | tee "$log_dir/cur.run"
else
    eval "${command}" &> "$log_dir/cur.run"
fi

size=$(cat $log_dir/cur.run | grep "model size" | awk '{print $5}')
ctx_size=$(cat $log_dir/cur.run | grep "n_ctx" | head -n 1 | awk '{print $4}')
prompt_time=$(cat $log_dir/cur.run | grep "prompt eval time" | awk '{print $6}')
prompt_tokens=$(cat $log_dir/cur.run | grep "prompt eval time" | awk '{print $9}')
load_time=$(cat $log_dir/cur.run | grep "load time" | awk '{print $5}')
quant=$(cat $log_dir/cur.run | grep "ftype" | grep  -o '[0-9]*' | tail -1)
tps=$(cat $log_dir/cur.run | grep "prompt eval time" | awk '{print $16}')

rm $log_dir/cur.run

# Store the timings in a log file
log_file="$log_dir/${size}-$(date +%Y-%m-%d-%H:%M:%S).log"
echo "load_time: ${load_time} ms" >> ${log_file}
echo "numa_cores: ${numactl_cores}" >> ${log_file}
echo "Context size: ${ctx_size}" >> ${log_file}
echo "Prompt Time: ${prompt_time} ms" >> ${log_file}
echo "Prompt Tokens: ${prompt_tokens}" >> ${log_file}
echo "Tokens per second: ${tps}" >> ${log_file}
echo "Quantization: ${quant}" >> ${log_file}
echo "Model Size: ${size}" >> ${log_file}
echo "Threads: ${threads}" >> ${log_file}
echo "Tokens Generated: ${num_tokens}" >> ${log_file}

pprint "Metrics saved in $log_file"