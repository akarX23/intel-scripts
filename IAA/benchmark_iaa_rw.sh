#!/bin/bash
num_instances=8
db_base_dir=/tmp/rocksdb_db_iaa

#./enable_iax_user_4 > /dev/null 2>&1
export LD_LIBRARY_PATH=/usr/lib:$LD_LIBRARY_PATH  # For QPL to load libaccel-config

dbs_size=0
for (( i = 0; i < $num_instances; i++ ))
do
  if [ ! -e ${db_base_dir}_${i} ]; then
    echo "ERROR: db files missing from ${db_base_dir}_${i}, please run _fill.sh script to populate data files"
    exit 1
  fi
  db_size=$(du -s ${db_base_dir}_${i} | cut -f 1)
  dbs_size=$(($dbs_size+$db_size))
done
dbs_size=$(echo "scale=2;$dbs_size/1024/1024" | bc)


# Readrandomwriterandom
echo "80/20 READ/WRITE RocksDB WORKLOAD"
for (( i = 0; i < $num_instances; i++ ))
do
  numactl --cpunodebind=0 --membind=0 rocksdb/db_bench --benchmarks="readrandomwriterandom,stats" --statistics --db=${db_base_dir}_${i} --use_existing_db \
  --key_size=16 --value_size=32 --block_size=16384 --num=275000000 --bloom_bits=10 --duration=120 --threads=10 --disable_wal \
  --compression_type=com.intel.iaa_compressor_rocksdb --compressor_options="execution_path=hw;compression_mode=dynamic;level=0" \
  --cache_size=-1 --cache_index_and_filter_blocks=false --compressed_cache_size=-1 --row_cache_size=0 \
  --use_direct_reads=false --use_direct_io_for_flush_and_compaction=false \
  --max_background_jobs=10 --subcompactions=5 --readwritepercent=80 \
  --max_write_buffer_number=20 --min_write_buffer_number_to_merge=1 \
  --level0_file_num_compaction_trigger=10 --level0_slowdown_writes_trigger=60 --level0_stop_writes_trigger=120 --max_bytes_for_level_base=671088640 > output_${i}.txt 2>&1 &
  pids[${i}]=$!
done

sar 60 1 > cpu_util.txt 

for pid in ${pids[*]}; do
  wait $pid
done

tpt_rw=$(cat output_* | grep readrandomwriterandom | tr -s " " | cut -d " " -f 5 | paste -s -d+ - | bc)

cpu_usr=$(cat cpu_util.txt | grep Average | tr -s ' ' | cut -d ' ' -f 3)
cpu_sys=$(cat cpu_util.txt | grep Average | tr -s ' ' | cut -d ' ' -f 5)
cpu_tot=$(echo "$cpu_usr+$cpu_sys" | bc)

sum_p99_get_latency=$(cat output_* | grep rocksdb.db.get.micros | cut -d ' ' -f 10 | paste -s -d+ - | bc)
avg_p99_get_latency=$(echo "scale=2; $sum_p99_get_latency/$num_instances" | bc)

#rm -rf output_*.txt

echo "IAA"
echo "readwrite throughput (ops/s): " $tpt_rw
echo "Compressed data size (GB):    " $dbs_size
echo "CPU utilization (%):          " $cpu_tot
echo "p99 get latency (us):         " $avg_p99_get_latency


# Since re-running the benchmarks decreases the performance we want to prevent this from being possible
for (( i = 0; i < $num_instances; i++ ))
do
  rm -rf ${db_base_dir}_${i}
done
