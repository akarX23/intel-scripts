#!/bin/bash

# Get the PIDs of all nginx worker processes and store them in an array
PIDS=($(ps aux | grep "nginx: worker process" | awk '{print $2}'))

# Loop over the PIDs and execute the taskset command accordingly
i=0
for pid in "${PIDS[@]}"; do
  if [ "$i" -le 7 ]; then
    taskset -pc "$i" "$pid"
  else
    core_number=$((i + 104))
    taskset -pc "$core_number" "$pid"
  fi
  ((i++))
done