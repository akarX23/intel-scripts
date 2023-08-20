# Instructions to Benchmark IAA RocksDB on spr195

- Login to the JumpServer
- Login to spr195 machine
- switch to _root_ user with `sudo su`
- change to the scripts directory: `cd /home/benchmark/rocksDB`
- Run benchmark (Read next sextion for more detailed usage):

```
./rocksdb-bench-master.sh -m 2750000 -t 12 -du 30 -ta fill,bench
```

## Benchmark Scripts usage

In the `/home/benchmark/rocksDB` you will find multiple scripts. The `rocksdb-bench-master.sh` is a wrapper for the rest of the scripts. You can view the options available in the script using `./rocksdb-bench-master.sh -h`

```
Usage: ./rocksdb-bench-master.sh [options]
Options:
  --num-iaa, -n              Set the number of IAA instances (default: 2)
  --data-dir, -d             Set the database directory (default: /tmp)
  --rocksdb-dir, -r          Set the RocksDB directory (default: /home/akarx/rocksdb)
  --max-ops, -m              Set the maximum number of operations (default: 275000000)
  --threads, -t              Set the number of threads (default: 1)
  --max-bg-jobs, -j          Set the maximum number of background jobs (default: 30)
  --bench-type. -b           Set the benchmark type (default: iaa,zstd)
  --duration, -du            Set the duration of the benchmark (default: 120)
  --rw-percent, -rw          Set the percentage of reads and writes (default: 80)
  --numa-args, -na           Set the numa arguments (default: --cpunodebind=0 --membind=0) - Pass in quotes.
  --tasks, -ta               Set the tasks to run (default: bench) - accepts 'fill', 'bench', 'fill,bench'
  --help, -h                 Display this help message
```

You can use the `-ta` option to specify if you just want to populate the data or run the benchmark or both. If both are given then the database will be populated first and then the benchmark will be executed.

The default value of the number of IAA devices is determined dynamically in the script. It's recommended **NOT** to specify this option.

This script will generate logs in the `logs` directory. To see the summarised table again for the previously generated logs execute `./summarise.sh`.

These benchmarks should normally be run for a longer time to get a better understanding of the metrics. You can see the logs for a long benchmark in `/home/benchmark/rocksDB/prod-logs`. To put these logs in tabular format, you can use `./summarise.sh --log-dir prod-logs`.

## Sample run

```
cd /home/benchmark/rockdsDB
./rocksdb-bench-master.sh -b zstd,iaa -du 120 -ta bench -m 275000000 -j 80 -t 8 -rw 80 -na "--cpunodebind=1 --membind=1"

# Output
Flushing System cache
---------------------------------------------
Benchmarking database for ZSTD
---------------------------------------------
80/20 READ/WRITE RocksDB WORKLOAD
Time left : 2 secondsss
readwrite throughput (ops/s):  18077
Compressed data size (GB):     11.12
CPU utilization (%):           .26
p99 get latency (us):          377.13

Flushing System cache
---------------------------------------------
Benchmarking database for IAA
---------------------------------------------
80/20 READ/WRITE RocksDB WORKLOAD
Time left : 2 secondsss
readwrite throughput (ops/s):  20838
Compressed data size (GB):     12.13
CPU utilization (%):           .15
p99 get latency (us):          372.94

---------------------------------------------
Summarizing Results
---------------------------------------------
Test: IAA
Read Write Throughput (ops/s): 20838
Compressed Data Size (GB): 12.13
CPU utilization (%): .15
p99 get latency (us): 372.94

Test: ZSTD
Read Write Throughput (ops/s): 18077
Compressed Data Size (GB): 11.12
CPU utilization (%): .26
p99 get latency (us): 377.13

+-----------------------------------------------------------------------+
|                         Metric |        IAA |       ZSTD |   % Change |
+-----------------------------------------------------------------------+
|  Read Write Throughput (ops/s) |      20838 |      18077 |     +15.00 |
|      Compressed Data Size (GB) |      12.13 |      11.12 |      +9.00 |
|            CPU utilization (%) |        .15 |        .26 |     -42.00 |
|           p99 get latency (us) |     372.94 |     377.13 |      -1.00 |
+-----------------------------------------------------------------------+
```
