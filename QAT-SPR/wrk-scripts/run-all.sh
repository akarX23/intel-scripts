#!/bin/bash

ulimit -n 655350

# Default values
server="localhost:443"
duration=10
nginx_bin_path="/home/akarx/QAT-installs/NGINX/sbin/nginx"
nginx_qat_conf_path="/home/akarx/QAT-installs/NGINX/conf/qat.conf"
nginx_wqat_cong_path="/home/akarx/QAT-installs/NGINX/conf/wqat.conf"
threads=28
connections=2000
workloads="100KB,256KB,750KB,1MB"
cl_cores="56-111"
log_pre="logs"
sv_cores="0-7,112-119"

function display_usage() {
  echo "Usage: $0 [options]"
  echo "Options:"
  echo "  --server <address>        Set the server address (default: $server)"
  echo "  --duration <time>        Set the duration in seconds (default: $duration)"
  echo "  --nginx-bin-path <path>  Set the NGINX binary path (default: $nginx_bin_path)"
  echo "  --nginx-qat-conf-path <path> Set the NGINX QAT configuration path (default: $nginx_qat_conf_path)"
  echo "  --nginx-wqat-conf-path <path> Set the NGINX WQAT configuration path (default: $nginx_wqat_conf_path)"
  echo "  --threads <num>          Set the number of threads (default: $threads)"
  echo "  --connections <num>      Set the number of connections (default: $connections)"
  echo "  --workloads <comma separated list> Set the workloads to run (default: $workloads)"
  echo "  --cl-cores   <Comma separated range of wrk cores pinning> (default: $cl_cores)"
  echo "  --sv-cores   <Comma separated range of nginx cores pinning> (default: $sv_cores)"
  echo "  --log-prefix  Prefix for log directory"
  echo "  -h, --help               Display this help message"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
    --workloads)
      workloads="$2"
      shift # past argument
      shift # past value
      ;;
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
    --cl-cores)
      cl_cores="$2"
      shift
      shift
      ;;
    --sv-cores)
      sv_cores="$2"
      shift
      shift
      ;;
    --log-prefix)
      log_pre="$2"
      shift
      shift
      ;;
    -h|--help) # Display help message
      display_usage
      exit 0
      ;;
    *) # unknown option
      echo "Unknown Option: $1"
      display_usage
      exit 1
      ;;
  esac
done

# Check if required arguments are provided
if [ -z "$server" ]; then
  echo "Usage: $0 --server <IP address:PORT(443)> --duration <duration in seconds> [--with-qat]"
  exit 1
fi

run_workloads () {
  local sizes="$1"
  IFS=',' read -ra size_array <<< "$sizes"
  
  for size in "${size_array[@]}"; do
    echo "---------------------------------------------"
    echo "Running wrk with $size size"
    echo "---------------------------------------------"
    numactl -C $cl_cores ./run-wrk.sh --server $server --size $size --duration $duration --threads $threads --connections $connections $2 --log-prefix $log_pre
    echo
  done
}

flush_cache() {
  echo "Flushing System cache"
  sync; echo 3 > /proc/sys/vm/drop_caches
  sleep 5
}

# cat /sys/kernel/debug/qat_4xxx_0000:6b:00.0/fw_counters

echo "Enabling QAT..."
eval $nginx_bin_path -s stop 2> /dev/null
#cp /home/akarx/QAT-installs/Engine/qat_hw_config/4xxx/multi_process/4xxx_dev0.conf /etc/4xxx_dev1.conf
#cp /home/akarx/QAT-installs/Engine/qat_hw_config/4xxx/multi_process/4xxx_dev0.conf /etc/4xxx_dev0.conf
sleep 2
service qat_service restart

echo "+++++++++++++++++++++++++++++++++++++++++++++"
echo "Running with QAT Enabled"
echo -e "+++++++++++++++++++++++++++++++++++++++++++++\n"

eval $nginx_bin_path -c $nginx_qat_conf_path
sleep 3
./alloc_nginx.sh $sv_cores &> /dev/null 

mkdir -p logs
# sar  -n DEV $(($(( $duration )) * 4)) 1 > logs/qat_sar.log &

run_workloads "$workloads" --with-qat
# cat /sys/kernel/debug/qat_4xxx_0000:6b:00.0/fw_counters

wait

echo "Disabling QAT..."
eval $nginx_bin_path -s stop 2> /dev/null
sleep 5

echo "+++++++++++++++++++++++++++++++++++++++++++++"
echo "Running without QAT Enabled"
echo -e "+++++++++++++++++++++++++++++++++++++++++++++\n"

flush_cache
eval $nginx_bin_path -c $nginx_wqat_cong_path
sleep 3
./alloc_nginx.sh $sv_cores &> /dev/null

# sar  -n DEV $(($(( $duration )) * 4)) 1 > logs/sar.log &

run_workloads "$workloads"

wait

echo "+++++++++++++++++++++++++++++++++++++++++++++"
echo "Summarizing results"
echo -e "+++++++++++++++++++++++++++++++++++++++++++++\n"

./summarise.sh --log-dir $log_pre
