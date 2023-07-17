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
      exit
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
  numactl -C 56-111 ./run-wrk.sh --server $server --size 100KB --duration $duration --threads $threads --connections $connections $1
  echo

  echo "---------------------------------------------"
  echo "Running wrk with 256KB size"
  echo "---------------------------------------------"
  numactl -C 56-111 ./run-wrk.sh --server $server --size 256KB --duration $duration --threads $threads --connections $connections $1
  echo

  echo "---------------------------------------------"
  echo "Running wrk with 750KB size"
  echo "---------------------------------------------"
  numactl -C 56-111 ./run-wrk.sh --server $server --size 750KB --duration $duration --threads $threads --connections $connections $1
  echo


  echo "---------------------------------------------"
  echo "Running wrk with 1MB size"
  echo "---------------------------------------------"
  numactl -C 16-55 ./run-wrk.sh --server $server --size 1MB --duration $duration --threads 24 --connections $connections $1
  echo
}

flush_cache() {
  echo "Flushing System cache"
  sync; echo 3 > /proc/sys/vm/drop_caches
  sleep 5
}

# cat /sys/kernel/debug/qat_4xxx_0000:6b:00.0/fw_counters

echo "Enabling QAT..."
eval $nginx_bin_path -s stop 2> /dev/null
cp /home/akarx/QAT-installs/Engine/qat_hw_config/4xxx/multi_process/4xxx_dev0.conf /etc/4xxx_dev1.conf
cp /home/akarx/QAT-installs/Engine/qat_hw_config/4xxx/multi_process/4xxx_dev0.conf /etc/4xxx_dev0.conf
sleep 2
service qat_service restart

echo "+++++++++++++++++++++++++++++++++++++++++++++"
echo "Running with QAT Enabled"
echo -e "+++++++++++++++++++++++++++++++++++++++++++++\n"

eval $nginx_bin_path -c $nginx_qat_conf_path

mkdir -p logs
# sar  -n DEV $(($(( $duration )) * 4)) 1 > logs/qat_sar.log &

run_workloads --with-qat
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

# sar  -n DEV $(($(( $duration )) * 4)) 1 > logs/sar.log &

run_workloads

wait

echo "+++++++++++++++++++++++++++++++++++++++++++++"
echo "Summarizing results"
echo -e "+++++++++++++++++++++++++++++++++++++++++++++\n"

echo -e "\n$(hostnamectl | grep "Operating System")"
echo "Kernel Version: $(hostnamectl | grep "Kernel" | cut -d ":" -f 2 | sed -e 's/^[[:space:]]*//')"
echo "NGINX Version: $($nginx_bin_path -v 2>&1 | grep -oP 'nginx/\K[\d.]+')"
echo "Number of QAT Devices: $(lspci | grep Eth | wc -l)"
echo -e "CPU: $(lscpu | grep "Model name" | cut -d ":" -f 2 | sed -e 's/^[[:space:]]*//')\n"

./summarise.sh
