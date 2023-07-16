#!/bin/bash

# Function to display the help message
display_help() {
    echo "Usage: ./rocksdb-bench-master.sh [options]"
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
    echo "  --numa-args, -na           Set the numa arguments (default: $NUMA_ARGS) - Pass in quotes."
    echo "  --tasks, -ta               Set the tasks to run (default: $TASKS) - accepts 'fill', 'bench', 'fill,bench'"
    echo "  --help, -h                 Display this help message"
}

conduct_test() {
    TEST=$1
    TASK=$2

    echo -e "\nFlushing System cache"
    sudo sh -c "sync;echo 3 > /proc/sys/vm/drop_caches"

    if [ "$TASK" == "fill" ]; then

        echo "---------------------------------------------"
        echo "Filling database for $(echo "$TEST" | tr '[:lower:]' '[:upper:]')"
        echo "---------------------------------------------"

        # Fill database
        ./benchmark_fill.sh -n $NUM_IAA -d $DATABASE_DIR -r $ROCKSDB_DIR -m "$MAX_OPS" -t $NUM_THREADS -j $MAX_BG_JOBS -b $TEST -na "$NUMA_ARGS" 2> /dev/null

    elif [ "$TASK" == "bench" ]; then

        echo -e "---------------------------------------------"
        echo "Benchmarking database for $(echo "$TEST" | tr '[:lower:]' '[:upper:]')"
        echo "---------------------------------------------"

        # Bench database
        ./benchmark_rw.sh -n $NUM_IAA -d $DATABASE_DIR -r $ROCKSDB_DIR -m $MAX_OPS -t $NUM_THREADS -j $MAX_BG_JOBS -b $TEST -du $DURATION -na "$NUMA_ARGS" -rw $RW_PERCENT
    
    fi
}

iax_dev_id="0cfe"
num_iax=$(lspci -d:${iax_dev_id} | wc -l)

NUM_IAA=$num_iax
DATABASE_DIR=/tmp
NUMA_ARGS="--cpunodebind=0 --membind=0"
ROCKSDB_DIR="/home/akarx/rocksdb"
MAX_OPS=275000000
NUM_THREADS=1
MAX_BG_JOBS=30
BENCH_TYPE="iaa,zstd"
RW_PERCENT=80
DURATION=120
TASKS="bench"

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
        --tasks | -ta )
            TASKS="$2"
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

# Check if TASKS contains "bench,fill"
if [[ $TASKS == "bench,fill" ]]; then
    # Swap the order of elements to "fill,bench"
    TASKS="fill,bench"
fi

IFS=',' read -ra tests <<< "$(echo "$BENCH_TYPE" | sed 's/ *, */,/g')"
IFS=',' read -ra tasks <<< "$(echo "$TASKS" | sed 's/ *, */,/g')"

# Loop over the array and use its values
for task in "${tasks[@]}"
do
    for test in "${tests[@]}"
    do
        conduct_test $test $task
    done
done

echo -e "\n---------------------------------------------"
echo "Summarizing Results"
echo "---------------------------------------------"

echo -e "\n$(hostnamectl | grep "Operating System")"
echo "Kernel Version: $(hostnamectl | grep "Kernel" | cut -d ":" -f 2 | sed -e 's/^[[:space:]]*//')"
echo "RocksDB Version: $($ROCKSDB_DIR/db_bench --version | cut -d " " -f 3)"
echo "ZSTD Version: $(zstd --version | grep -oP 'v\d+\.\d+\.\d+')"
echo "CPU: $(lscpu | grep "Model name" | cut -d ":" -f 2 | tr -s " " | head -n 1)"
echo "Number of IAA devices: $NUM_IAA"

./summarise.sh
