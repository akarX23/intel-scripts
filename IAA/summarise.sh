#!/bin/bash

log_dir=logs

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
    --log-dir)
      log_dir="$2"
      shift # past argument
      shift
      ;;
    *) # unknown option
      shift # past argument
      ;;
  esac
done

# count iax instances
iax_dev_id="0cfe"
num_iax=$(lspci -d:${iax_dev_id} | wc -l)

NUM_IAA=$num_iax

tests=("iaa" "zstd")

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
    avg_p99_get_latency=$(echo "scale=2; $sum_p99_get_latency/$NUM_IAA" | bc)
    dbs_size=$(cat $log_dir/dbs_size_${test})

    echo "Test: $(echo "$test" | tr '[:lower:]' '[:upper:]')"
    for index in "${!metrics[@]}"
    do
        metric="${metrics[${index}]}"
        header="${metric_headers[${index}]}"

        extracted_values["${metric}_${test}"]=$(eval echo "\${${metric}}")
        echo "$header: ${extracted_values["${metric}_${test}"]}"
    done
    
    echo
done

# Print table
table_width=71

echo "+$(printf "%0.s-" $(seq 1 $table_width))+"
printf "| %30s | %10s | %10s | %10s |\n" "Metric" "IAA" "ZSTD" "% Change"
echo "+$(printf "%0.s-" $(seq 1 $table_width))+"

for index in "${!metrics[@]}"
do
    metric="${metrics[${index}]}"
    header="${metric_headers[${index}]}"

    iaa_val=${extracted_values["${metric}_iaa"]}
    zstd_val=${extracted_values["${metric}_zstd"]}
    percent_change=$(echo "scale=2; (($iaa_val-$zstd_val)/$zstd_val)*100" | bc)

    if (( $(echo "$percent_change >= 0" | bc -l) )); then
    percent_change="+$percent_change"
    fi

    printf "| %30s | %10s | %10s | %10s |\n" "$header" "$iaa_val" "$zstd_val" "$percent_change"
done

echo "+$(printf "%0.s-" $(seq 1 $table_width))+"