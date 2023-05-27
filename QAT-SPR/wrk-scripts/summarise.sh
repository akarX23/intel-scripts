#!/bin/bash

#!/bin/bash

custom_sort() {
    local prefix
    local suffix
    
    prefix=$(echo "$1" | sed -E 's/(^[[:digit:]]+[[:alpha:]]+[[:digit:]]+).*/\1/')
    suffix=$(echo "$1" | sed -E 's/^[[:digit:]]+[[:alpha:]]+[[:digit:]]+(.*)$/\1/')
    
    if [[ $prefix == "10KB" ]]; then
        echo "1 $suffix"
    elif [[ $prefix == "100KB" ]]; then
        echo "2 $suffix"
    elif [[ $prefix == "1MB" ]]; then
        echo "3 $suffix"
    else
        echo "4 $1"
    fi
}

sort_files() {
    local files=()
    local sorted_files=()

    # Read input from stdin (piped from ls command)
    while IFS= read -r file; do
        files+=("$file")
    done

    for file in "${files[@]}"; do
        sorted_files+=("$(custom_sort "$file")")
    done

    sorted_files=($(echo "${sorted_files[@]}" | tr ' ' '\n' | sort | cut -d ' ' -f2-))

    for file in "${sorted_files[@]}"; do
        echo "$file"
    done
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
  if [[ $filename == *qat_video* ]]; then
    content_type="Video query with QAT"
  elif [[ $filename == *qat_query* ]]; then
    content_type="Normal query with QAT"
  elif [[ $filename == *video* ]]; then
    content_type="Video query w/o QAT"
  elif [[ $filename == *query* ]]; then
    content_type="Normal query w/o QAT"
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
  max_latency=$(echo "$output" | awk '/ Latency/ {print $4}')
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

  printf "| %8s | %25s | %10s | %13s | %10s | %20s | %10s | %20s | %10s | %13s | %10s |\n" $file_size "$content_type" $threads   $connections   $duration  $total_requests   $requests_sec  $total_data  $data_sec  $max_latency  $max_requests
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
log_files=$(append_files "1MB" "100KB" "10KB" "logs")

# Check if log files exist
if [ -z "$log_files" ]; then
  echo "No wrk log files found in the logs directory."
  exit 1
fi

# Calculate the width of the table
table_width=181

# Print table header
echo "+$(printf "%0.s-" $(seq 1 $table_width))+"
printf "| %8s | %25s | %10s | %13s | %10s | %20s | %10s | %20s | %10s | %13s | %10s |\n" "Workload" "Type" "Threads" "Connections" "Duration" "Total Requests" "Requests/s" "Total Data Transfer" "Transfer/s" "Max Latency" "Max Req/s"
echo "+$(printf "%0.s-" $(seq 1 $table_width))+"

# Process each log file
for log_file in $log_files; do
  summarize_log_file "logs/$log_file"
done

# Print table footer
echo "+$(printf "%0.s-" $(seq 1 $table_width))+"
