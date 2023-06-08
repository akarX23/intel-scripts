#!/bin/bash

ulimit -n 655350

# Default values
server="localhost:443"
duration=120
nginx_bin_path="/usr/local/nginx"
nginx_qat_conf_path="/etc/nginx/qat"
nginx_wqat_cong_path="/etc/nginx/nginx.conf"

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
    --nginx-bin-path)
      nginx_bin_path="$2"
      shift # past argument
      shift # past value
      ;;
    --nginx-wqat-conf-path)
      nginx_wqat_cong_path="$2"
      shift # past argument
      shift # past value
      ;;
    --nginx-qat-conf-path)
      nginx_qat_conf_path="$2"
      shift # past argument
      shift # past value
      ;;
    *) # unknown option
      shift # past argument
      ;;
  esac
done

# Check if required arguments are provided
if [ -z "$server" ]; then
  echo "Usage: $0 --server <IP address:PORT(443)> --duration <duration in seconds> [--with-qat]"
  exit 1
fi

run_workloads () {
echo "---------------------------------------------"
echo "Running wrk with 100KB size"
echo "---------------------------------------------"
./run-wrk.sh --server $server --size 100KB --duration $duration $1  
echo

echo "---------------------------------------------"
echo "Running wrk with 256KB size"
echo "---------------------------------------------"
./run-wrk.sh --server $server --size 256KB --duration $duration $1 
echo

echo "---------------------------------------------"
echo "Running wrk with 750KB size"
echo "---------------------------------------------"
./run-wrk.sh --server $server --size 750KB --duration $duration $1 
echo

echo "---------------------------------------------"
echo "Running wrk with 1MB size"
echo "---------------------------------------------"
./run-wrk.sh --server $server --size 1MB --duration $duration $1 
echo
}

echo "+++++++++++++++++++++++++++++++++++++++++++++"
echo "Running with QAT Enabled"
echo "+++++++++++++++++++++++++++++++++++++++++++++"

eval $nginx_bin_path -s stop
sleep 1
eval $nginx_bin_path -c $nginx_qat_conf_path

run_workloads --with-qat

echo "+++++++++++++++++++++++++++++++++++++++++++++"
echo "Running without QAT Enabled"
echo "+++++++++++++++++++++++++++++++++++++++++++++"

eval $nginx_bin_path -s stop
sleep 1
eval $nginx_bin_path -c $nginx_wqat_cong_path

run_workloads

echo "============================================="
echo "---------------------------------------------"
echo "Summarizing results"
echo "---------------------------------------------"
./summarise.sh
