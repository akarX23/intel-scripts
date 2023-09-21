#!/bin/bash

log_dir=logs
VERBOSE=false
ROCKSDB_DIR="/home/akarx/QAT-installs/RocksDB-git"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
    --log-dir)
      log_dir="$2"
      shift # past argument
      shift
      ;;
    --rocksdb-dir | -r )
        ROCKSDB_DIR="$2"
        shift 
        shift
        ;;
    --verbose | -v)
      VERBOSE=true
      shift # past argument
      ;;
    *) # unknown option
      shift # past argument
      ;;
  esac
done

# Count QAT devices
NUM_QAT=$(lspci | grep "rev 40" | wc -l)

echo -e "\n$(hostnamectl | grep "Operating System")"
echo "Kernel Version: $(hostnamectl | grep "Kernel" | cut -d ":" -f 2 | sed -e 's/^[[:space:]]*//')"
echo "RocksDB Version: $($ROCKSDB_DIR/db_bench --version | cut -d " " -f 3)"
echo "ZSTD Version: $(zstd --version | grep -oP 'v\d+\.\d+\.\d+')"
echo "CPU: $(lscpu | grep "Model name" | cut -d ":" -f 2 | tr -s " " | head -n 1)"
echo "Number of Enabled QAT devices: $NUM_QAT"

tests=("qat" "zstd")

# Declare an associative array to store the extracted values
declare -A extracted_values
metrics=("tpt_rw" "dbs_size" "cpu_tot" "avg_p99_get_latency")
metric_headers=("Read Write Throughput (ops/s)" "Compressed Data Size (GB)" "CPU utilization (%)" "p99 get latency (us)")

for test in "${tests[@]}"
do
    tpt_rw=$(cat $log_dir/output_${test}_* | grep readrandomwriterandom | tr -s " " | cut -d " " -f 5 | paste -s -d+ - | bc)
    cpu_usr=$(cat $log_dir/cpu_util_${test}.txt | grep Average | tr -s ' ' | cut -d ' ' -f 3)
    cpu_sys=$(cat $log_dir/cpu_util_${test}.txt | grep Average | tr -s ' ' | cut -d ' ' -f 5)
    cpu_tot=$(echo "$cpu_usr+$cpu_sys" | bc)
    sum_p99_get_latency=$(cat $log_dir/output_${test}_* | grep rocksdb.db.get.micros | cut -d ' ' -f 10 | paste -s -d+ - | bc)
    avg_p99_get_latency=$(echo "scale=2; $sum_p99_get_latency/$NUM_QAT" | bc)
    dbs_size=$(cat $log_dir/dbs_size_${test})

    if [[ "$VERBOSE" = true ]]; then
      echo "Test: $(echo "$test" | tr '[:lower:]' '[:upper:]')"
    fi
  
    for index in "${!metrics[@]}"
    do
        metric="${metrics[${index}]}"
        header="${metric_headers[${index}]}"

        extracted_values["${metric}_${test}"]=$(eval echo "\${${metric}}")

        if [[ "$VERBOSE" = true ]]; then
          echo "$header: ${extracted_values["${metric}_${test}"]}"
        fi
    done
    echo
done

# Print table
table_width=71

echo "+$(printf "%0.s-" $(seq 1 $table_width))+"
printf "| %30s | %10s | %10s | %10s |\n" "Metric" "qat" "ZSTD" "% Change"
echo "+$(printf "%0.s-" $(seq 1 $table_width))+"

for index in "${!metrics[@]}"
do
    metric="${metrics[${index}]}"
    header="${metric_headers[${index}]}"

    qat_val=${extracted_values["${metric}_qat"]}
    zstd_val=${extracted_values["${metric}_zstd"]}
    percent_change=$(echo "scale=2; (($qat_val-$zstd_val)/$zstd_val)*100" | bc)

    if (( $(echo "$percent_change >= 0" | bc -l) )); then
    percent_change="+$percent_change"
    fi

    printf "| %30s | %10s | %10s | %10s |\n" "$header" "$qat_val" "$zstd_val" "$percent_change"
done

echo "+$(printf "%0.s-" $(seq 1 $table_width))+"