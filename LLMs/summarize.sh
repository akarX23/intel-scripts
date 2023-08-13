#!/bin/bash

repeat(){
	local start=1
	local end=${1:-80}
	local str="${2:-=}"
	local range=$(seq $start $end)
	for i in $range ; do echo -n "${str}"; done
}

log_dir="$1"

if [ -z "$log_dir" ]; then
    echo "Usage: $0 <log_directory>"
    exit 1
fi

echo -e "\n$(hostnamectl | grep "Operating System")"
echo "Kernel Version: $(hostnamectl | grep "Kernel" | cut -d ":" -f 2 | sed -e 's/^[[:space:]]*//')"
echo -e "CPU: $(lscpu | grep "Model name" | cut -d ":" -f 2 | sed -e 's/^[[:space:]]*//')\n"

# Calculate the width of the table
table_width=163

# Print table header
repeat $table_width "-"; echo
printf "| %10s | %15s | %15s | %10s | %20s | %15s | %20s | %20s | %10s |\n" "Model Size" "Quantization" "Cores Used" "Threads" "Load Time" "Context Size" "Prompt Time" "Prompt Tokens" "TPS"
repeat $table_width "-"; echo

for log_file in "$log_dir"/*.log; do
    if [ -f "$log_file" ]; then
        model_size=$(grep "Model Size" "$log_file" | awk '{print $3}')
        quantization=$(grep "Quantization" "$log_file" | awk '{print $2}')
        cores=$(grep "numa_cores" "$log_file" | awk '{print $2}')
        threads=$(grep "Threads" "$log_file" | awk '{print $2}')
        load_time=$(grep "load_time" "$log_file" | awk '{print $2}')
        ctx_size=$(grep "Context size" "$log_file" | awk '{print $3}')
        prompt_time=$(grep "Prompt Time" "$log_file" | awk '{print $3}')
        prompt_tokens=$(grep "Prompt Tokens" "$log_file" | awk '{print $3}')
        tps=$(grep "Tokens per second" "$log_file" | awk '{print $4}')

        printf "| %10s | %15s | %15s | %10s | %20s | %15s | %20s | %20s | %10s |\n" "$model_size" "$quantization" "$cores" "$threads" "$load_time ms" "$ctx_size" "$prompt_time ms" "$prompt_tokens" "$tps"
    fi
done

repeat $table_width "-"; echo