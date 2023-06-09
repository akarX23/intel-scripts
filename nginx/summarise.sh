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

  # Return file size and content type as an array
  arr=("$file_size")
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

  echo "$file_size,$threads,$connections,$duration,$total_requests,$requests_sec,$total_data,$data_sec,$ninety_ninth_p,$max_requests" >> wrk.csv
  printf "| %8s | %10s | %13s | %10s | %20s | %10s | %20s | %10s | %13s | %10s |\n" $file_size $threads   $connections   $duration  $total_requests   $requests_sec  $total_data  $data_sec  $ninety_ninth_p  $max_requests
}

append_files() {
    local files=()
    local directory=${@: -1}  # Last argument is the directory
    local sizes=("${@:1:$#-1}")  # All arguments except the last one are sizes

    for size in "${sizes[@]}"; do
        files+=($(ls "$directory" | grep "$size"_v))
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
table_width=194

rm wrk.csv
touch wrk.csv
echo "size,threads,connections,duration,total_requests,requests_sec,total_data,data_sec,ninety_ninth_p,max_requests" >> wrk.csv

# Print table header
echo "+$(printf "%0.s-" $(seq 1 $table_width))+"
printf "| %8s | %10s | %13s | %10s | %20s | %10s | %20s | %10s | %13s | %10s |\n" "Workload" "Threads" "Connections" "Duration" "Total Requests" "Requests/s" "Total Data Transfer" "Transfer/s" "99% Latency" "Max Req/s"
echo "+$(printf "%0.s-" $(seq 1 $table_width))+"

# Process each log file
for log_file in $log_files; do
  summarize_log_file "$log_dir/$log_file"
done

# Print table footer
echo "+$(printf "%0.s-" $(seq 1 $table_width))+"
