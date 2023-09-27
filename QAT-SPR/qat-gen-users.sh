#!/bin/bash

# Function to display help
function show_help() {
  echo "Usage: $0 -t [cy|dc] -s [start_index] -n [num_users] -o [output_file]"
  echo "Options:"
  echo "  -t [cy|dc]: Type of users to generate (cy for Cy users, dc for Dc users)."
  echo "  -s [start_index]: Start index for user names."
  echo "  -n [num_users]: Number of users to generate."
  echo "  -o [output_file]: Path to the output file for configurations."
  exit 1
}

# Initialize variables with default values
user_type=""
start_index=""
num_users=""
output_file=""

# Parse command-line arguments
while getopts "t:s:n:o:" opt; do
  case $opt in
    t)
      user_type="$OPTARG"
      ;;
    s)
      start_index="$OPTARG"
      ;;
    n)
      num_users="$OPTARG"
      ;;
    o)
      output_file="$OPTARG"
      ;;
    *)
      show_help
      ;;
  esac
done

# Check if required arguments are provided
if [ -z "$user_type" ] || [ -z "$start_index" ] || [ -z "$num_users" ] || [ -z "$output_file" ]; then
  show_help
fi

# Check if the output file exists
if [ ! -f "$output_file" ]; then
  echo "Error: Output file '$output_file' not found."
  exit 1
fi

# Generate and append user configurations
for ((i = start_index; i < start_index + num_users; i++)); do
  if [ "$user_type" == "cy" ]; then
    echo "# Crypto - User instance #$i" >> "$output_file"
    echo "Cy${i}Name = UserCY${i}" >> "$output_file"
    echo "Cy${i}IsPolled = 1" >> "$output_file"
    echo "Cy${i}CoreAffinity = $i" >> "$output_file"
  elif [ "$user_type" == "dc" ]; then
    echo "# Crypto - User instance #$i" >> "$output_file"
    echo "Dc${i}Name = Dc${i}" >> "$output_file"
    echo "Dc${i}IsPolled = 1" >> "$output_file"
    echo "Dc${i}CoreAffinity = $i" >> "$output_file"
  else
    show_help
  fi
done

echo "User configurations generated and appended to '$output_file'."