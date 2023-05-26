#!/bin/bash

# Function to summarize log file
summarize_log_file() {
  local log_file="$1"
  local server=$(grep -m 1 "Running " "$log_file" | awk '{print $2}')
  local requests=$(grep "Requests/sec" "$log_file" | awk '{print $2}')
  local latency=$(grep "Latency" "$log_file" | awk '{print $2}')
  local threads=$(grep -m 1 "Thread Stats" "$log_file" | awk '{print $3}')
  local connections=$(grep -m 1 "Thread Stats" "$log_file" | awk '{print $6}')
  
  echo "| $server | $requests | $latency | $threads | $connections |"
}

# Get list of log files
log_files=$(find logs -name "*.log")

# Check if log files exist
if [ -z "$log_files" ]; then
  echo "No wrk log files found in the logs directory."
  exit 1
fi

# Print table header
echo "+-------------+-------------+-------------+-------------+-------------+"
echo "| Server      | Requests/s  | Latency(ms) | Threads     | Connections |"
echo "+-------------+-------------+-------------+-------------+-------------+"

# Process each log file
for log_file in $log_files; do
  summarize_log_file "$log_file"
done

# Print table footer
echo "+-------------+-------------+-------------+-------------+-------------+"
