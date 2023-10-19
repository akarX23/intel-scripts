#!/bin/bash

log_dir=logs

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
    --log-dir)
      log_dir="$2"
      shift # past argument
      shift
      ;;
    *) # unknown option
      shift # past argument
      ;;
  esac
done

# Convert sizes to bytes
convert_size_to_bytes() {
  local size=$1
  local unit=${size: -2}  # Extract the last two characters (unit)
  local value=${size%${unit}}  # Extract the value (all characters except the unit)

  case "$unit" in
    "KB") echo $(bc <<< "$value * 1024") ;;
    "MB") echo $(bc <<< "$value * 1024 * 1024") ;;
    "GB") echo $(bc <<< "$value * 1024 * 1024 * 1024") ;;
    "TB") echo $(bc <<< "$value * 1024 * 1024 * 1024 * 1024") ;;
    *) echo "Invalid size unit. Please provide a valid size (e.g., 1KB, 2MB, 700.68GB)." ;;
  esac
}

# Function to get content type based on log file name
get_content_type() {
  filename=$(basename "$1")
  content_type=""

  # Extract file size
  if [[ $filename =~ [0-9]+KB ]]; then
    file_size="${BASH_REMATCH[0]}"
  elif [[ $filename =~ [0-9]+MB ]]; then
    file_size="${BASH_REMATCH[0]}"
  fi

  # Extract content type
  # if [[ $filename == *qat_video* ]]; then
  #   content_type="Video query with QAT"
  if [[ $filename == *qat_query* ]]; then
    content_type="QAT Enabled"
  # elif [[ $filename == *video* ]]; then
  #   content_type="Video query w/o QAT"
  elif [[ $filename == *query* ]]; then
    content_type="QAT Disabled"
  fi

  # Return file size and content type as an array
  arr=("$file_size" "$content_type")
  echo "${arr[@]}"
}

# Function to summarize log file
summarize_log_file() {
  output=$(cat "$1")
  # echo $output
  # Extract duration
  duration=$(echo "$output" | awk '/ test @ / {print $2}')

  # Extract threads and connections
  threads=$(echo "$output" | awk '/ threads and / {print $1}')
  connections=$(echo "$output" | awk '/ threads and / {print $4}')

  # Extract max latency and max requests/sec
  ninety_ninth_p=$(echo "$output" | awk '/ 99%/ {print $2}')
  max_requests=$(echo "$output" | awk '/ Req\/Sec/ {print $4}')

  # Extract total requests and total data transfer
  total_requests=$(echo "$output" | awk '/ requests in / {print $1}')
  total_data=$(echo "$output" | awk '/ requests in / {print $5}')

  # Extract requests/sec and data transfer/sec
  requests_sec=$(echo "$output" | awk '/Requests\/sec/ {print $2}')
  data_sec=$(echo "$output" | awk '/Transfer\/sec/ {print $2}')

  # Extract CPU Utilization
  cpu_util_usr=$(echo "$output" | grep Average | tail -n +2 | tr -s ' ' | cut -d ' ' -f 3 | paste -s -d+ - | bc)
  cpu_util_sys=$(echo "$output"  | grep Average | tail -n +2 | tr -s ' ' | cut -d ' ' -f 5 | paste -s -d+ - | bc)
  cpu_tot=$(echo "$cpu_util_usr+$cpu_util_sys" | bc)

  # Call the get_content_type function
  result=($(get_content_type "$1"))

  # Access the file size and content type from the array
  file_size="${result[0]}"
  content_type="${result[@]:1}"

  percent_change="-"
  percent_change_cpu="-"
  # Calculate the percentage change in total data transfer if "_qat" is present in the file name
  if [[ "$1" == *_qat_* ]]; then
    # Get the corresponding log file without QAT
    log_file_without_qat="${1/qat_/}"

    if [[ -e "$log_file_without_qat" ]]; then
      # Get the total data transfer without QAT
        total_data_without_qat=$(cat "$log_file_without_qat" | awk '/ requests in / {print $5}')

        total_data_bytes=$(convert_size_to_bytes $total_data)
        total_data_wqat_bytes=$(convert_size_to_bytes $total_data_without_qat)

        total_cpu_usr_wqat=$(cat "$log_file_without_qat" | grep Average | tail -n +2 | tr -s ' ' | cut -d ' ' -f 3 | paste -s -d+ - | bc)
        total_cpu_sys_wqat=$(cat "$log_file_without_qat" | grep Average | tail -n +2 | tr -s ' ' | cut -d ' ' -f 5 | paste -s -d+ - | bc)
        total_cpu_wqat=$(echo "$total_cpu_usr_wqat+$total_cpu_sys_wqat" | bc)

        percent_change=$(echo "scale=2; (($total_data_bytes - $total_data_wqat_bytes) / $total_data_wqat_bytes) * 100" | bc)
        percent_change_cpu=$(echo "scale=2; (($cpu_tot - $total_cpu_wqat) / $total_cpu_wqat) * 100" | bc)

      if (( $(echo "$percent_change >= 0" | bc -l) )); then
        percent_change="+$percent_change"
      fi
      if (( $(echo "$percent_change_cpu >= 0" | bc -l) )); then
        percent_change_cpu="+$percent_change_cpu"
      fi
    fi
  fi
  printf "| %8s | %25s | %10s | %13s | %10s | %20s | %10s | %20s | %10s | %10s | %13s | %10s | %25s | %25s |\n" $file_size "$content_type" $threads   $connections   $duration  $total_requests   $requests_sec  $total_data $cpu_tot  $data_sec  $ninety_ninth_p  $max_requests  $percent_change $percent_change_cpu
}

append_files() {
    local files=()
    local directory=${@: -1}  # Last argument is the directory
    local sizes=("${@:1:$#-1}")  # All arguments except the last one are sizes

    for size in "${sizes[@]}"; do
        files+=($(ls "$directory" | grep "$size"_qat_v))
        files+=($(ls "$directory" | grep "$size"_v))
        files+=($(ls "$directory" | grep "$size"_qat_q))
        files+=($(ls "$directory" | grep "$size"_qu))
    done

    printf '%s\n' "${files[@]}"
}


# Get list of log files
log_files=$(append_files "1MB" "750KB" "256KB" "100KB" "$log_dir")

# Check if log files exist
if [ -z "$log_files" ]; then
  echo "No wrk log files found in the $log_dir directory."
  exit 1
fi

echo -e "\n$(hostnamectl | grep "Operating System")"
echo "Kernel Version: $(hostnamectl | grep "Kernel" | cut -d ":" -f 2 | sed -e 's/^[[:space:]]*//')"
echo "NGINX Version: $($nginx_bin_path -v 2>&1 | grep -oP 'nginx/\K[\d.]+')"
echo "Number of QAT Devices: $(lspci | grep Eth | wc -l)"
echo -e "CPU: $(lscpu | grep "Model name" | cut -d ":" -f 2 | sed -e 's/^[[:space:]]*//')\n"

# Calculate the width of the table
table_width=248

# Print table header
echo "+$(printf "%0.s-" $(seq 1 $table_width))+"
printf "| %8s | %25s | %10s | %13s | %10s | %20s | %10s | %20s | %10s | %10s | %13s | %10s | %25s | %25s |\n" "Workload" "Type" "Threads" "Connections" "Duration" "Total Requests" "Requests/s" "Total Data Transfer" "% CPU" "Transfer/s" "99% Latency" "Max Req/s" "% Change in Throughput" "% Change in CPU"
echo "+$(printf "%0.s-" $(seq 1 $table_width))+"

# Process each log file
for log_file in $log_files; do
  summarize_log_file "$log_dir/$log_file"
done

# Print table footer
echo "+$(printf "%0.s-" $(seq 1 $table_width))+"