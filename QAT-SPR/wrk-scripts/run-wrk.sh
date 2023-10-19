#!/bin/bash

ulimit -n 655350

# Default values
server="localhost:443"
size=""
with_qat=""
duration=120
threads=28
connections=2000
log_pre="logs"
sv_cores=""

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
    --server)
      server="$2"
      shift # past argument
      shift # past value
      ;;
    --size)
      size="$2"
      shift # past argument
      shift # past value
      ;;
    --sv-cores)
      sv_cores="$2"
      shift
      shift
      ;;
    --duration)
      duration="$2"
      shift # past argument
      shift # past value
      ;;
    --with-qat)
      with_qat="_qat"
      shift # past argument
      ;;
    --threads)
      threads="$2"
      shift # past argument
      shift # past value
      ;;
    --connections)
      connections="$2"
      shift # past argument
      shift # past value
      ;;
    --log-prefix)
      log_pre="$2"
      shift
      shift
      ;;
    *) # unknown option
      shift # past argument
      ;;
  esac
done

# Check if required arguments are provided
if [ -z "$server" ] || [ -z "$size" ] || [ -z "$sv_cores" ]; then
  echo "Usage: $0 --server <IP address:PORT(443)> --size <1MB|10KB|100KB> --duration <duration in seconds> [--with-qat] --log-prefix <Prefix for log directory> --sv-cores <Server pinned cores for monitoring>"
  exit 1
fi

# Set threads and connections based on size
case $size in
  1MB)
    connections=350
    ;;
  256KB)
    connections=350
    ;;
  100KB)
    connections=300
    ;;
  750KB)
    connections=300
    ;;
  *)
    echo "Invalid size. Please choose either 1MB, 256KB, or 100KB."
    exit 1
    ;;
esac

echo -e "Executing test for a $size workload with the following parameters:\n"
echo -e "Server URL: https://$server"
echo -e "Size: $size"
echo -e "Duration: ${duration}s"
echo -e "Threads: $threads"
echo -e "Connections: $connections"

# Display timer function
function countdown {
    local max_time=$1
    local pid=$2
    local flag=0
    local elapsed_time=0

    while [ $elapsed_time -le $max_time ]
    do
        if [ $flag -eq 1 ]; then
            break
        fi
        printf "\rElapsed Time : $elapsed_time seconds"
        sleep 1
        (( elapsed_time++ ))
        if ! ps -p $pid > /dev/null; then
            flag=1
        fi
    done

    printf "\n"
}


mkdir $log_pre 2>1 

# Run wrk and save output to log file

echo -e "\nExecuting WRK test"
log_file="${size}${with_qat}_query.log"
cpu_util_file="${size}${with_qat}_cpu.log"

sar -P $sv_cores 1 $duration > "$log_pre/$cpu_util_file" &
wrk -t $threads -c $connections -d ${duration}s  -L --timeout 4s \
 -H "Connection: keep-alive"  -H "Accept-Encoding: gzip" "https://$server/$size" > "$log_pre/$log_file" 2>&1 &
pid=$!

countdown $duration $pid

echo -e "\n--------------------------------\n" >> "$log_pre/$log_file"
cat "$log_pre/$cpu_util_file" >> "$log_pre/$log_file"
rm "$log_pre/$cpu_util_file"

echo -e "\nWrk script executed for $size. Logs saved under $log_pre/ directory."
