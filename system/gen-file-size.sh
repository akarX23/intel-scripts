#!/bin/bash

output_file="$2"
filesize_kb=$1

# Calculate the number of lines needed to fill the file with zeroes
lines=$((filesize_kb * 1024 / 2)) # Divide by 2 because each line consists of 2 characters: '0\n'

# Generate the content with zeroes and write to the file
for (( i=1; i<=$lines; i++ ))
do
  echo -ne "0" >> "$output_file"
done