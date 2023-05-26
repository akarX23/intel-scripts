#!/bin/bash

ulimit -n 655350

# Default values
server=""
size=""
with_qat=""
duration=120

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
    threads=$(nproc)
    connections=30700
    ;;
  10KB)
    threads=$(nproc)
    connections=3100
    ;;
  100KB)
    threads=$(nproc)
    connections=6200
    ;;
  *)
    echo "Invalid size. Please choose either 1MB, 10KB, or 100KB."
    exit 1
    ;;
esac

# Construct wrk command
wrk_cmd="wrk -t $threads -c $connections -d ${duration}s -s ./${size}_query.lua -H \"Connection: keep-alive\" --timeout 4s -L"

if [ "$with_qat" = true ]; then
  wrk_cmd+=" --with-qat"
fi

wrk_cmd+=" https://$server"

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

mkdir logs

# Run wrk and save output to log file

echo "Executing normal query script"
log_file="${size}${with_qat}_query.log"
$wrk_cmd & > "logs/$log_file" 2>&1
pid=$!
countdown $size $pid

wrk_cmd="wrk -t $threads -c $connections -d ${duration}s -s ./${size}_video_query.lua -H \"Connection: keep-alive\" --timeout 4s -L"
log_file="${size}${with_qat}_video_query.log"
$wrk_cmd & > "logs/$log_file" 2>&1
pid=$!
countdown $size $pid

echo "Wrk script executed. Logs saved under logs/ directory."