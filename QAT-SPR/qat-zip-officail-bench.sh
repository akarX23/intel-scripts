#!/bin/bash

QZ_ROOT=/home/akarx/QAT-installs/Zip/
ICP_ROOT=/home/akarx/QAT-installs/Driver/
THREADS=28
NUMA_ARGS="--cpunodebind=0 --membind=0"
PROCESSES=1

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
    --qz-root | -qz)
      QZ_ROOT="$2"
      shift # past argument
      shift
      ;;
    --icp-root | -icp)
      ICP_ROOT="$2"
      shift # past argument
      shift
      ;;
    *) # unknown option
      shift # past argument
      exit 1
      ;;
  esac
done

#check whether test exists
if [ ! -f "$QZ_ROOT/test/test" ]; then
    echo "$QZ_ROOT/test/test: No such file. Compile first!"
    exit 1
fi

mkdir logs 2>1

echo "Enabling QAT..."
cp /home/akarx/QAT-installs/Zip/config_file/4xxx/multiple_process_opt/4xxx*.conf /etc
service qat_service restart
echo 1024 > /sys/kernel/mm/hugepages/hugepages-2048kB/nr_hugepages
rmmod usdm_drv
insmod $ICP_ROOT/build/usdm_drv.ko max_huge_pages=1024 max_huge_pages_per_process=24
sleep 5

echo "+++++++++++++++++++++++++++++++++++++++++++++"
echo "Running with QAT Enabled"
echo -e "+++++++++++++++++++++++++++++++++++++++++++++\n"

echo "---------------------------------------------"
echo "Compression test on 1GB file"
echo "---------------------------------------------"
numactl -C 56-111 $QZ_ROOT/test/test -m 4 -i /home/benchmark/1GB.bin -t $THREADS -D comp -l 10 > logs/1GB_comp.log 2>&1

compthroughput=`awk '{sum+=$8} END{print sum}' logs/1GB_comp.log`
echo "compthroughput=$compthroughput Gbps"

echo "---------------------------------------------"
echo "Decompression test on 1GB file"
echo "---------------------------------------------"
numactl -C 56-111 $QZ_ROOT/test/test -m 4 -i /home/benchmark/1GB.bin -t $THREADS -D comp -l 10 > logs/1GB_decomp.log 2>&1

compthroughput=`awk '{sum+=$8} END{print sum}' logs/1GB_decomp.log`
echo "compthroughput=$compthroughput Gbps"

echo