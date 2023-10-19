#!/bin/bash

# Get the PIDs of all nginx worker processes and store them in an array
PIDS=($(ps aux | grep "nginx: worker process" | awk '{print $2}'))
IFS=',' read -r -a CORE_RANGES <<< "$1" 

if [ -z $CORE_RANGES ]; then
  echo "No Core range found. Usage: ./alloc_nginx.sh <core_ranges>"
  exit 1;
fi

# Loop over the PIDs and execute the taskset command accordingly
pid_counter=0

for range in "${CORE_RANGES[@]}";
do
  IFS='-' read -r -a curr_range <<< "$range"

  START=${curr_range[0]}
  END=${curr_range[1]}
  for ((core_num=${curr_range[0]}; core_num <= ${curr_range[1]}; core_num++ ))
  do
    taskset -pc $core_num ${PIDS[$pid_counter]}
    renice -20 ${PIDS[$pid_counter]}
    ((pid_counter++))
  done
done
