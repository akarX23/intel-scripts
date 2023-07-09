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

  # Call the get_content_type function
  result=($(get_content_type "$1"))

  # Access the file size and content type from the array
  file_size="${result[0]}"
  content_type="${result[@]:1}"

  # Calculate the percentage change in total data transfer if "_qat" is present in the file name
  if [[ "$1" == *_qat_* ]]; then
    # Get the corresponding log file without QAT
    log_file_without_qat="${1/qat_/}"

    if [[ -e "$log_file_without_qat" ]]; then
      # Get the total data transfer without QAT
      total_requests_without_qat=$(cat "$log_file_without_qat" | awk '/ requests in / {print $1}')

      percent_change=$(echo "scale=2; (($total_requests - $total_requests_without_qat) / $total_requests_without_qat) * 100" | bc)

      if (( $(echo "$percent_change >= 0" | bc -l) )); then
        percent_change="+$percent_change"
      fi
    else
      percent_change="-"
    fi
  else
    percent_change="-"
  fi
  printf "| %8s | %25s | %10s | %13s | %10s | %20s | %10s | %20s | %10s | %13s | %10s | %10s |\n" $file_size "$content_type" $threads   $connections   $duration  $total_requests   $requests_sec  $total_data  $data_sec  $ninety_ninth_p  $max_requests  $percent_change
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

# Calculate the width of the table
table_width=206

# Print table header
echo "+$(printf "%0.s-" $(seq 1 $table_width))+"
printf "| %8s | %25s | %10s | %13s | %10s | %20s | %10s | %20s | %10s | %13s | %10s | %10s |\n" "Workload" "Type" "Threads" "Connections" "Duration" "Total Requests" "Requests/s" "Total Data Transfer" "Transfer/s" "99% Latency" "Max Req/s" "% Change in Transfer"
echo "+$(printf "%0.s-" $(seq 1 $table_width))+"

# Process each log file
for log_file in $log_files; do
  summarize_log_file "$log_dir/$log_file"
done

# Print table footer
echo "+$(printf "%0.s-" $(seq 1 $table_width))+"
