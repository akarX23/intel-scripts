#!/bin/bash

# Function to display the help message
display_help() {
    echo "Usage: ./benchmark_fill.sh [options]"
    echo "Options:"
    echo "  --num-iaa, -n              Set the number of IAA instances (default: $NUM_IAA)"
    echo "  --data-dir, -d             Set the database directory (default: $DATABASE_DIR)"
    echo "  --rocksdb-dir, -r          Set the RocksDB directory (default: $ROCKSDB_DIR)"
    echo "  --max-ops, -m              Set the maximum number of operations (default: $MAX_OPS)"
    echo "  --threads, -t              Set the number of threads (default: $NUM_THREADS)"
    echo "  --max-bg-jobs, -j          Set the maximum number of background jobs (default: $MAX_BG_JOBS)"
    echo "  --bench-type. -b           Set the benchmark type (default: $BENCH_TYPE)"
    echo "  --numa-args, -na           Set the numa arguments (default: $NUMA_ARGS)"
    echo "  --help, -h                 Display this help message"
}

# Count IAA devices
iax_dev_id="0cfe"
num_iax=$(lspci -d:${iax_dev_id} | wc -l)

NUM_IAA=$num_iax
DATABASE_DIR=/tmp
NUMA_ARGS="--cpunodebind=0 --membind=0"
ROCKSDB_DIR="/home/akarx/rocksdb"
MAX_OPS=275000000
NUM_THREADS=1
MAX_BG_JOBS=30
BENCH_TYPE="iaa"

while [ "$1" != "" ]; do
    case $1 in
        --num-iaa | -n )
            NUM_IAA="$2"
            shift 1
            ;;
        --numa-args | -na )
            NUMA_ARGS="$2"
            shift 1
            ;;
        --data-dir | -d )
            DATABASE_DIR="$2"
            shift 1
            ;;
        --rocksdb-dir | -r )
            ROCKSDB_DIR="$2"
            shift 1
            ;;
        --max-ops | -m )
            MAX_OPS="$2"
            shift 1
            ;;
        --threads | -t )
            NUM_THREADS="$2"
            shift 1
            ;;
        --max-bg-jobs | -j )
            MAX_BG_JOBS="$2"
            shift 1
            ;;
        --bench-type | -b )
            BENCH_TYPE="$2"
            shift 1
            ;;
        --help | -h )
            display_help
            exit 0
            ;;
        * )
            echo "Unknown argument: $1"
            exit 1
            ;;
    esac
    shift
done

if [ "$BENCH_TYPE" == "iaa" ]; then
  COMPRESSION_TYPE="com.intel.iaa_compressor_rocksdb"
  COMPRESSION_OPTIONS="execution_path=hw;compression_mode=dynamic;level=0"
elif [ "$BENCH_TYPE" == "zstd" ]; then
  COMPRESSION_TYPE="zstd"
  COMPRESSION_OPTIONS=""
else
  echo "Invalid benchmark type"
  exit 1
fi

sudo sh -c "sync;echo 3 > /proc/sys/vm/drop_caches"

export LD_LIBRARY_PATH=/usr/lib:$LD_LIBRARY_PATH  # For QPL to load libaccel-config

i = 0
# Fillseq
echo "PREPARE DATA"
# for (( i = 0; i < $NUM_IAA; i++ ))
# do
  rm -rf "$DATABASE_DIR/rocksdb_${BENCH_TYPE}_${i}"
  mkdir -p "$DATABASE_DIR/rocksdb_${BENCH_TYPE}_${i}"
  numactl $NUMA_ARGS "$ROCKSDB_DIR/db_bench" --benchmarks="fillseq" --db="$DATABASE_DIR/rocksdb_${BENCH_TYPE}_${i}" \
  --key_size=16 --value_size=32 --block_size=16384 --num="$MAX_OPS" --bloom_bits=10 --threads="$NUM_THREADS" --disable_wal \
  --value_src_data_type=file_direct --value_src_data_file=standard_calgary_corpus \
  --compression_type="$COMPRESSION_TYPE" --compressor_options="$COMPRESSION_OPTIONS" \
  --cache_size=-1 --cache_index_and_filter_blocks=false --compressed_cache_size=-1 --row_cache_size=0 \
  --use_direct_reads=false --use_direct_io_for_flush_and_compaction=false \
  --max_background_jobs="$MAX_BG_JOBS" --subcompactions=5 &
  pids[${i}]=$!
# done

for pid in ${pids[*]}; do
  wait $pid
done
