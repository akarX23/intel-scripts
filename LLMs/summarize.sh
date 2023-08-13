#!/bin/bash

log_dir="$1"

if [ -z "$log_dir" ]; then
    echo "Usage: $0 <log_directory>"
    exit 1
fi

echo "Model | Load Time | Context Size | Prompt Time | Prompt Tokens | Tokens/s | Quantization | Model Size"
echo "------+-----------+--------------+-------------+---------------+----------+--------------+------------"

for log_file in "$log_dir"/*.log; do
    if [ -f "$log_file" ]; then
        model=$(basename "$log_file" | cut -d '-' -f 2)
        load_time=$(grep "load_time" "$log_file" | awk '{print $2}')
        ctx_size=$(grep "Context size" "$log_file" | awk '{print $3}')
        prompt_time=$(grep "Prompt Time" "$log_file" | awk '{print $3}')
        prompt_tokens=$(grep "Prompt Tokens" "$log_file" | awk '{print $3}')
        tps=$(grep "Tokens per second" "$log_file" | awk '{print $4}')
        quantization=$(grep "Quantization" "$log_file" | awk '{print $2}')
        model_size=$(grep "Model Size" "$log_file" | awk '{print $3}')

        printf "%-6s| %-10s| %-13s| %-11s| %-13s| %-8s| %-12s| %-10s\n" "$model" "$load_time ms" "$ctx_size" "$prompt_time ms" "$prompt_tokens" "$tps" "$quantization bit" "$model_size"
    fi
done