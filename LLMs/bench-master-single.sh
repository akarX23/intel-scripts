#!/bin/bash

show_help() {
    echo "Usage: $0 -c <numactl_cores> -s <context_sizes> -t <num_tokens> -th <threads_array> -m <models_directory>"
    echo "Options:"
    echo "  -c, --numactl-cores      Space-separated numactl cores (e.g., \"0-55,112-167\")"
    echo "  -s, --context-sizes      Space-separated context sizes (e.g., \"512 1024\")"
    echo "  -t, --num-tokens         Number of tokens"
    echo "  -th, --threads           Space-separated threads array"
    echo "  -b, --batch-size         Batch Size"
    echo "  -m, --models-directory   Path to models directory"
    echo "  -l, --log-dir            Log Directory"
    exit 1
}

# Default values
numactl_cores="0-55 112-167"
context_sizes="1000"
num_tokens="1024"
batch_size="1000"
threads_array="28 28"
models_directory=""
log_directory="$(pwd)/"

# Parse input arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        -c|--numactl-cores) numactl_cores="$2"; shift 2;;
        -s|--context-sizes) context_sizes="$2"; shift 2;;
        -t|--num-tokens) num_tokens="$2"; shift 2;;
        -th|--threads) threads_array="$2"; shift 2;;
        -m|--models-directory) models_directory="$2"; shift 2;;
        -b|--batch-size) batch_size="$2"; shift 2;;
        -l|--log-dir) log_directory="$2"; shift 2;;
        -h|--help) show_help;;
        *) echo "Unknown option: $1"; show_help;;
    esac
done

# Check if the number of cores is equal to the number of threads
if [ ${#numactl_cores_array} -ne ${#threads_array} ]; then
  echo "The number of threads must be equal to the number of cores."
  exit 1
fi

# Check for mandatory arguments
if [[ -z "$models_directory" ]]; then
    echo "Missing model directory."
    show_help
fi

models=$(ls ${models_directory})

# Convert space-separated strings to arrays
IFS=' ' read -ra cores_array <<< "$numactl_cores"
IFS=' ' read -ra sizes_array <<< "$context_sizes"
IFS=' ' read -ra threads_array <<< "$threads_array"

log_directory=$log_directory/$(date +%Y-%m-%d-%H:%M:%S)
mkdir -p $log_directory

# Loop through combinations
for model in ${models[@]}; do
    # Initialize a counter for threads index
    threads_counter=0
    for cores in "${cores_array[@]}"; do
        current_threads=${threads_array[$threads_counter]}
        for size in "${sizes_array[@]}"; do
            
            if [[ $model =~ "70b" || $model =~ "70B" ]]; then
            gqa_flag="-g"
            else
            gqa_flag=""
            fi

            echo "Running benchmark for model: $(basename "$models_directory/$model"), Cores: $cores, Context Size: $size, Threads: $current_threads"
            
            # Call the benchmark script
            ./llama-bench.sh -m "${models_directory}/${model}" -n "$cores" -t "$num_tokens" -ct "$size" -b "$batch_size" -th "$current_threads" -l "$log_directory" ${gqa_flag}
            
            echo "-------------------------"
        done
        ((threads_counter++))
    done
done

echo "All benchmarks completed."