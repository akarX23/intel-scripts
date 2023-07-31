#!/bin/bash

PARENT_LOG_DIR=""
CODECS=("lz4" "deflate" "zstd")

# Function to print help message
print_help() {
    echo "Usage: $0 -d PARENT_LOG_DIR -c CODECS"
    echo "PARENT_LOG_DIR: The parent directory containing log files for each CODEC."
    echo "CODECS: Comma-separated list of CODECs."
}

# Parse named arguments
while getopts "hd:c:" opt; do
    case "$opt" in
        h)
            print_help
            exit 0
            ;;
        d)
            PARENT_LOG_DIR="$OPTARG"
            ;;
        c)
             IFS=',' read -r -a CODECS <<< "$2"
            ;;
        \?)
            echo "Invalid option: -$OPTARG" >&2
            print_help
            exit 1
            ;;
        :)
            echo "Option -$OPTARG requires an argument." >&2
            print_help
            exit 1
            ;;
    esac
done

# Check if required arguments are provided
if [[ -z "$PARENT_LOG_DIR" ]]; then
    echo "Error: Missing required arguments."
    print_help
    exit 1
fi

# Function to parse the log file and calculate metrics
parse_log_file() {
    local codec="$1"
    local log_file="$PARENT_LOG_DIR/$codec/log/${codec}.log"

    # Initialize variables to store metrics
    totalT_sum=0
    latencyAVG_sum=0
    P95_sum=0
    QPS_Final_sum=0
    num_entries=0

    # Parse the log file and calculate metrics
    while read -r line; do
        if [[ $line =~ totalT:\ ([0-9.]+)\ s,\ latencyAVG:\ ([0-9.]+)\ ms,\ P95:\ ([0-9.]+)\ ms,\ QPS_Final:\ ([0-9.]+)$ ]]; then
            totalT_sum=$(bc <<<"$totalT_sum + ${BASH_REMATCH[1]}")
            latencyAVG_sum=$(bc <<<"$latencyAVG_sum + ${BASH_REMATCH[2]}")
            P95_sum=$(bc <<<"$P95_sum + ${BASH_REMATCH[3]}")
            QPS_Final_sum=$(bc <<<"$QPS_Final_sum + ${BASH_REMATCH[4]}")
            num_entries=$((num_entries + 1))
        fi
    done <"$log_file"

    # Calculate average metrics
    totalT_avg=$(bc <<<"scale=2; $totalT_sum / $num_entries")
    latencyAVG_avg=$(bc <<<"scale=2; $latencyAVG_sum / $num_entries")
    P95_avg=$(bc <<<"scale=2; $P95_sum / $num_entries")
    QPS_Final_avg=$(bc <<<"scale=2; $QPS_Final_sum / $num_entries")

    # Output summary
    echo "Metrics summary for $codec:"
    echo "Total Time (s): $totalT_avg"
    echo "Latency Average (ms): $latencyAVG_avg"
    echo "P95 (ms): $P95_avg"
    echo "QPS Final: $QPS_Final_avg"
    echo
}

# Loop through each CODEC and parse its log file
for codec in "${CODECS[@]}"; do
    parse_log_file "$codec"
done