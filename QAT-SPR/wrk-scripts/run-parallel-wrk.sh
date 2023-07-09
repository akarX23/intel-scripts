#!/bin/bash

sync; echo 3 > /proc/sys/vm/drop_caches

sleep 3

SIZE="$1"
shift;
DURATION="$1"
shift;

# Function to run wrk benchmark on a specific core range
run_benchmark() {
  local core_range=$1
  local output_file=$2

  numactl -C $core_range wrk -t56 -c1000 -d $DURATION https://localhost:443/$SIZE > >(tee $output_file) 2>&1
}

# Run benchmarks in parallel
run_benchmark "0-55" "benchmark_1.txt" &
run_benchmark "56-111" "benchmark_2.txt" &
run_benchmark "112-167" "benchmark_3.txt" &
run_benchmark "168-223" "benchmark_4.txt" &

# Wait for all benchmarks to finish
wait

# Combine and process the results
total_requests=0
total_latency=0

for benchmark_file in benchmark_*.txt; do
  requests=$(grep "Requests/sec" $benchmark_file | awk '{print $2}')
  latency=$(grep "Latency" $benchmark_file | awk '{print $2}')

  total_requests=$(echo "$total_requests + $requests" | bc)
  total_latency=$(echo "$total_latency + $latency" | bc)

	echo "Requests: $requests, latency: $latency, total_r: $total_requests, total_l: $total_latency"
done

echo "Total Requests/sec: $total_requests"
echo "Total Latency: $total_latency"
 
