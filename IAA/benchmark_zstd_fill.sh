#!/bin/bash
num_instances=8
db_base_dir=/tmp/rocksdb_db_zstd

sudo sh -c "sync;echo 3 > /proc/sys/vm/drop_caches"

# Fillseq
echo "PREPARE DATA"
for (( i = 0; i < $num_instances; i++ ))
do
  rm -rf ${db_base_dir}_${i}
  mkdir -p ${db_base_dir}_${i}
  numactl --cpunodebind=0 --membind=0 rocksdb/db_bench --benchmarks="fillseq" --db=${db_base_dir}_${i} \
  --key_size=16 --value_size=32 --block_size=16384 --num=275000000 --bloom_bits=10 --threads=1 --disable_wal \
  --value_src_data_type=file_direct --value_src_data_file=standard_calgary_corpus \
  --compression_type=zstd \
  --cache_size=-1 --cache_index_and_filter_blocks=false --compressed_cache_size=-1 --row_cache_size=0 \
  --use_direct_reads=false --use_direct_io_for_flush_and_compaction=false \
  --max_background_jobs=30 --subcompactions=5 > /dev/null 2>&1 &
  pids[${i}]=$!
done

for pid in ${pids[*]}; do
  wait $pid
done
