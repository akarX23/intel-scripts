#!/bin/bash

ulimit -n 655350

# Default values
server="localhost:443"
with_qat=
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
    --duration)
      duration="$2"
      shift # past argument
      shift # past value
      ;;
    --with-qat)
      with_qat=true
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

qat_arg=""
if [ "$with_qat" = true ]; then
  qat_arg="--with-qat"
fi

./run-wrk.sh --server $server --size 10KB --duration $duration $qat_arg  
./run-wrk.sh --server $server --size 100KB --duration $duration $qat_arg 
./run-wrk.sh --server $server --size 1MB --duration $duration $qat_arg 

./summarise.sh