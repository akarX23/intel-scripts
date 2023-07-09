#!/bin/bash

echo "---------------------------------------------"
echo "Running OpenSSL Speed with QAT"
echo "---------------------------------------------"

# Run the first openssl speed command
result1=$(openssl speed -engine qatengine -seconds 5 -elapsed -async_jobs 72 rsa2048)

echo -e "\n---------------------------------------------"
echo "Running OpenSSL Speed without QAT"
echo -e "---------------------------------------------"

# Run the second openssl speed command
result2=$(openssl speed -seconds 5 -elapsed -async_jobs 72 rsa2048)

echo -e "\n"

# Extract the verify/s and sign/s values from the first result
verify1=$(echo "$result1" | grep "rsa 2048" | awk '{print $7}')
sign1=$(echo "$result1" | grep "rsa 2048" | awk '{print $6}')

# Extract the verify/s and sign/s values from the second result
verify2=$(echo "$result2" | grep "rsa 2048" | awk '{print $7}')
sign2=$(echo "$result2" | grep "rsa 2048" | awk '{print $6}')

# Calculate the percent change in verify/s and sign/s
verify_percent_change=$(awk "BEGIN {print (($verify1 - $verify2) / $verify2) * 100}")
sign_percent_change=$(awk "BEGIN {print (($sign1 - $sign2) / $sign2) * 100}")

# Calculate the width of the table
table_width=53

# Print table header
echo "+$(printf "%0.s-" $(seq 1 $table_width))+"
printf "| %15s | %15s | %15s |\n" "Test" "Verify/s" "Sign/s"
echo "+$(printf "%0.s-" $(seq 1 $table_width))+"

printf "| %15s | %15s | %15s |\n" "With QAT" "$verify1" "$sign1"
printf "| %15s | %15s | %15s |\n" "No QAT" "$verify2" "$sign2"
printf "| %15s | %15s | %15s |\n" "Percent Change" "+$verify_percent_change%" "+$sign_percent_change%"

echo "+$(printf "%0.s-" $(seq 1 $table_width))+"