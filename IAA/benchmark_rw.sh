#!/bin/bash

# Function to display the help message
display_help() {
    echo "Usage: ./benchmark_rw.sh [options]"
    echo "Options:"
    echo "  --num-iaa, -n              Set the number of IAA instances (default: $NUM_IAA)"
    echo "  --data-dir, -d             Set the database directory (default: $DATABASE_DIR)"
    echo "  --rocksdb-dir, -r          Set the RocksDB directory (default: $ROCKSDB_DIR)"
    echo "  --max-ops, -m              Set the maximum number of operations (default: $MAX_OPS)"
    echo "  --threads, -t              Set the number of threads (default: $NUM_THREADS)"
    echo "  --max-bg-jobs, -j          Set the maximum number of background jobs (default: $MAX_BG_JOBS)"
    echo "  --bench-type. -b           Set the benchmark type (default: $BENCH_TYPE)"
    echo "  --duration, -du            Set the duration of the benchmark (default: $DURATION)"
    echo "  --rw-percent, -rw          Set the percentage of reads and writes (default: $RW_PERCENT)"
    echo "  --numa-args, -na           Set the numa arguments (default: $NUMA_ARGS)"
    echo "  --help, -h                 Display this help message"
}

function countdown {
    local max_time=$1
    local pid=$2
    local flag=0
    local elapsed_time=0

    while [ $elapsed_time -le $max_time ]
    do
        if [ $flag -eq 1 ]; then
            break
        fi
        printf "\rTime left : $(($max_time - $elapsed_time)) seconds"
        sleep 1
        (( elapsed_time++ ))
        if ! ps -p $pid > /dev/null; then
            flag=1
        fi
    done

    printf "\n"
}

# count iax instances
iax_dev_id="0cfe"
num_iax=$(lspci -d:${iax_dev_id} | wc -l)

NUM_IAA=$num_iax
DATABASE_DIR=/tmp
NUMA_ARGS="--cpunodebind=0 --membind=0"
ROCKSDB_DIR="/home/akarx/rocksdb"
MAX_OPS=275000000
NUM_THREADS=1
MAX_BG_JOBS=10
DURATION=120
RW_PERCENT=80
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
        --duration | -du )
            DURATION="$2"
            shift 1;
            ;;
        --rw-percent | -rw )
            RW_PERCENT="$2"
            shift 1;
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

dbs_size=0
for (( i = 0; i < $NUM_IAA; i++ ))
do
  if [ ! -e "$DATABASE_DIR/rocksdb_${BENCH_TYPE}_${i}" ]; then
    echo "ERROR: db files missing from "$DATABASE_DIR/rocksdb_${BENCH_TYPE}_${i}", please run _fill.sh script to populate data files"
    exit 1
  fi
  db_size=$(du -s "$DATABASE_DIR/rocksdb_${BENCH_TYPE}_${i}" | cut -f 1)
  dbs_size=$(($dbs_size+$db_size))
done
dbs_size=$(echo "scale=2;$dbs_size/1024/1024" | bc)

mkdir -p logs > /dev/null 2>&1
touch logs/dbs_size_${BENCH_TYPE}
echo "$dbs_size" > logs/dbs_size_${BENCH_TYPE}

# Readrandomwriterandom
echo "$RW_PERCENT/$(expr 100 - $RW_PERCENT) READ/WRITE RocksDB WORKLOAD"

# for (( i = 0; i < $NUM_IAA; i++ ))
# do
    # if [ "$i" -eq 0 ]; then
    # NUMA_ARGS="-C 0-55"
    # else
    # NUMA_ARGS="-C 56-111"
    # fi

    numactl $NUMA_ARGS "$ROCKSDB_DIR/db_bench" --benchmarks="readrandomwriterandom,stats" --statistics --db="$DATABASE_DIR/rocksdb_${BENCH_TYPE}_${i}" --use_existing_db \
    --key_size=16 --value_size=32 --block_size=16384 --num="$MAX_OPS" --bloom_bits=10 --duration="$DURATION" --threads="$NUM_THREADS" --disable_wal \
    --compression_type="$COMPRESSION_TYPE" --compressor_options="$COMPRESSION_OPTIONS" \
    --cache_size=-1 --cache_index_and_filter_blocks=false --compressed_cache_size=-1 --row_cache_size=0 \
    --use_direct_reads=false --use_direct_io_for_flush_and_compaction=false \
    --max_background_jobs="$MAX_BG_JOBS" --subcompactions=5 --readwritepercent="$RW_PERCENT" \
    --max_write_buffer_number=20 --min_write_buffer_number_to_merge=1 \
    --level0_file_num_compaction_trigger=10 --level0_slowdown_writes_trigger=60 --level0_stop_writes_trigger=120 --max_bytes_for_level_base=671088640 > logs/output_${BENCH_TYPE}_${i}.txt 2>&1 &
    pids[${i}]=$!
# done

sar $DURATION 1 > logs/cpu_util_${BENCH_TYPE}.txt &

countdown $DURATION ${pids[0]}
for pid in ${pids[*]}; do
    wait $pid
done

tpt_rw=$(cat logs/output_${BENCH_TYPE}_* | grep readrandomwriterandom | tr -s " " | cut -d " " -f 5 | paste -s -d+ - | bc)

cpu_usr=$(cat logs/cpu_util_${BENCH_TYPE}.txt | grep Average | tr -s ' ' | cut -d ' ' -f 3)
cpu_sys=$(cat logs/cpu_util_${BENCH_TYPE}.txt | grep Average | tr -s ' ' | cut -d ' ' -f 5)
cpu_tot=$(echo "$cpu_usr+$cpu_sys" | bc)

sum_p99_get_latency=$(cat logs/output_${BENCH_TYPE}_* | grep rocksdb.db.get.micros | cut -d ' ' -f 10 | paste -s -d+ - | bc)
avg_p99_get_latency=$(echo "scale=2; $sum_p99_get_latency/$NUM_IAA" | bc)

echo "Read Write throughput (ops/s): " $tpt_rw
echo "Compressed data size (GB):     " $dbs_size
echo "CPU utilization (%):           " $cpu_tot
echo "p99 get latency (us):          " $avg_p99_get_latency