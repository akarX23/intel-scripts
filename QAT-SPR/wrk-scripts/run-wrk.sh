#!/bin/bash

ulimit -n 655350

# Default values
server="localhost:443"
size=""
with_qat=""
duration=120
threads=28
connections=2000

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
    *) # unknown option
      shift # past argument
      ;;
  esac
done

# Check if required arguments are provided
if [ -z "$server" ] || [ -z "$size" ]; then
  echo "Usage: $0 --server <IP address:PORT(443)> --size <1MB|10KB|100KB> --duration <duration in seconds> [--with-qat]"
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

echo -e "Executing test for a $size workload with the following parameters:\n\n"
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

mkdir logs 2>1

# Run wrk and save output to log file

echo -e "\nExecuting WRK test"
log_file="${size}${with_qat}_query.log"
wrk -t $threads -c $connections -d ${duration}s  -L --timeout 4s \
 -H "Connection: keep-alive" "https://$server/$size" > "logs/$log_file" 2>&1 &
pid=$!
countdown $duration $pid

echo -e "\nWrk script executed for $size. Logs saved under logs/ directory."
