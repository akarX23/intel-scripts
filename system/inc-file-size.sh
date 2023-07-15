#!/bin/bash

filename="$2"  # Replace with your file name
target_size_mb=$1     # Replace with your desired target size in megabytes

touch "${filename}.large"
current_size_bytes=$(stat -c%s "${filename}.large")
target_size_bytes=$((target_size_mb * 1024 * 1024))
remaining_size_bytes=$((target_size_bytes - current_size_bytes))

while [ $remaining_size_bytes -gt 0 ]; do
    cat "$filename" >> "${filename}.large"
    current_size_bytes=$(stat -c%s "${filename}.large")
    remaining_size_bytes=$((target_size_bytes - current_size_bytes))
done
