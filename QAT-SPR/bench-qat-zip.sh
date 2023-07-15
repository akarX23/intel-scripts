#!/bin/bash

ulimit -n 655350

TARGET_FILE=/home/benchmark/1GB.bin

mkdir -p zip-logs

while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
    --file | -f)
      TARGET_FILE="$2"
      shift # past argument
      shift # past value
      ;;
    *) # unknown option
      shift # past argument
      exit
      ;;
  esac
done

echo "Enabling QAT..."
cp /home/akarx/QAT-installs/Zip/config_file/4xxx/multiple_process_opt/4xxx_dev0.conf /etc
cp /home/akarx/QAT-installs/Zip/config_file/4xxx/multiple_process_opt/4xxx_dev1.conf /etc
service qat_service restart

echo "+++++++++++++++++++++++++++++++++++++++++++++"
echo "Running with QAT Enabled"
echo -e "+++++++++++++++++++++++++++++++++++++++++++++\n"

echo "Compressing a 1GB file..."
compress_qat=$(qzip -O 7z $TARGET_FILE -o result 2> /dev/null)

echo "Decompressing a 1GB file..."
decompress_qat=$(qzip -d result.7z 2> /dev/null)

echo "Disabling QAT..."
service qat_service stop

echo "+++++++++++++++++++++++++++++++++++++++++++++"
echo "Running with QAT Disabled"
echo -e "+++++++++++++++++++++++++++++++++++++++++++++\n"

echo "Compressing a 1GB file..."
compress=$(qzip -O 7z $TARGET_FILE -o result 2> /dev/null)

echo "Decompressing a 1GB file..."
decompress=$(qzip -d result.7z 2> /dev/null)

echo "+++++++++++++++++++++++++++++++++++++++++++++"
echo "Comparing results"
echo -e "+++++++++++++++++++++++++++++++++++++++++++++\n"

table_width=204
