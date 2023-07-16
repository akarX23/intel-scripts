# HammerDB Scripts
## Pre-requisites
- Database already setup. You can use the scripts provided for PostgresSQL and MySQL setups for ubuntu.
- Admin privileges setup in the database.

## Steps to run the benchmark
- Download the script
```
wget https://raw.githubusercontent.com/akarX23/intel-scripts/master/HammerDB/bench.sh
```
- Run help with `./bench.sh -h`
```
# Help
Usage: ./bench.sh [OPTIONS]
Options:
  -d, --hdb-dir DIR         Set the HammerDB directory (default: /home/ubuntu/HammerDB-4.8)
  -u, --db-user USER     Set the DB username (default: root)
  -p, --db-password PASS Set the DB password (default: root)
  -host, --db-host HOST        Set the database host (default: localhost)
  -port, --db-port PORT        Set the database port (default: 3306)
  -w, --data-warehouses NUM Set the number of data warehouses (default: 2)
  -t, --tasks TASKS         Set the tasks to perform (default: fill,bench)
  -v, --virtual-users NUM   Set the number of virtual users (default: 2)
  -db, --database DB        Set the database type (default: mysql)
  -s, --scripts-dir DIR     Set the scripts directory (default: /home/ubuntu/intel-scripts/HammerDB/scripts)
  -r, --rampup-dur NUM      Set the rampup duration in minutes (default: 1)
  -b, --bench-duration NUM  Set the benchmark duration in minutes (default: 1)
  -pgsp, --pg-superuser-password PASS Set the PostgreSQL superuser password (default: postgres)
  -pgsu, --pg-superuser USER Set the PostgreSQL superuser (default: postgres)
  -i, --iterations NUM      Set the number of iterations (default: 10000000)
  -n, --numa-args ARGS      Set the NUMA arguments (default: --cpunodebind=0 --membind=0)
  -h, --help                 Display this help message
Note: If an option is not provided, the default value will be used.
```
Please go through all the options to see which configuration fits your use case.  The script will autogenerate the script files for fill and benchmark which will be passed to the HammerDB Client. 

Sample run:
```
./bench.sh -d /home/ubuntu/HammerDB-4.8 -u postgres -p postgres -w 1 -t fill,bench -v 1 -db pg -r 1 -port 5432 -b 1 -n "-C 6-9"

# Output
+++++++++++++++++++++++++++++++++++++++++++++
Filling Database with 1 warehouses
+++++++++++++++++++++++++++++++++++++++++++++

HammerDB CLI v4.8
Copyright (C) 2003-2023 Steve Shaw
Type "help" for a list of commands
Initialized Jobs on-disk database /tmp/hammer.DB using existing tables (253,952 KB)
Database set to PostgreSQL
Benchmark set to TPC-C for PostgreSQL
...
Vuser 1:CREATING TPCC INDEXES
Vuser 1:CREATING TPCC FUNCTIONS
Vuser 1:GATHERING SCHEMA STATISTICS
Vuser 1:POSTGRES SCHEMA COMPLETE
Vuser 1:FINISHED SUCCESS
ALL VIRTUAL USERS COMPLETE

+++++++++++++++++++++++++++++++++++++++++++++
Running Benchmark with 1 virtual users
+++++++++++++++++++++++++++++++++++++++++++++

HammerDB CLI v4.8
Copyright (C) 2003-2023 Steve Shaw
Type "help" for a list of commands
Initialized Jobs on-disk database /tmp/hammer.DB using existing tables (266,240 KB)
Database set to PostgreSQL
Benchmark set to TPC-C for PostgreSQL
...
Vuser 1:TEST RESULT : System achieved 17099 NOPM from 39188 PostgreSQL TPM
Vuser 1:Gathering timing data from Active Virtual Users...
Vuser 2:FINISHED SUCCESS
Vuser 1:Calculating timings...
Vuser 1:Writing timing data to /tmp/hdbxtprofile.log
Vuser 1:FINISHED SUCCESS
ALL VIRTUAL USERS COMPLETE
vudestroy success

+++++++++++++++++++++++++++++++++++++++++++++
Summarizing results
+++++++++++++++++++++++++++++++++++++++++++++

 Operating System: Ubuntu 20.04.5 LTS
Kernel Version: Linux 5.4.0-137-generic
CPU: Intel Xeon Processor (Cascadelake)
PostgreSQL Version: 12.15

NOPM: 17099
TPM: 39188
```
