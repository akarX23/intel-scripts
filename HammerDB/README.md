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
  -dbc, --db-cores CORES    Set the database cores in taskset format (default: 0-12)
  -o, --output-dir DIR      Set the output directory for scripts and logs (default: /home/ubuntu/intel-scripts/HammerDB)
  -r, --rampup-dur NUM      Set the rampup duration in minutes (default: 1)
  -b, --bench-duration NUM  Set the benchmark duration in minutes (default: 1)
  -pgsp, --pg-superuser-password PASS Set the PostgreSQL superuser password (default: postgres)
  -pgsu, --pg-superuser USER Set the PostgreSQL superuser (default: postgres)
  -i, --iterations NUM      Set the number of iterations (default: 10000000)
  -n, --numa-args ARGS      Set the NUMA arguments for HammerDB Client (default: --cpunodebind=0 --membind=0)
  --verbose                 Print all HammerDB output to console
  -h, --help                 Display this help message
Note: If an option is not provided, the default value will be used.
```

Please go through all the options to see which configuration fits your use case. The script will autogenerate the script files for fill and benchmark which will be passed to the HammerDB Client.

Sample run:

```
./bench.sh -d /home/ubuntu/HammerDB-4.8 -u postgres -p postgres -w 1 -t fill,bench -v 1 -db pg -r 1 -port 5432 -b 1 -n "-C 6-11" -dbc "0-5" -o /home/ubuntu/HammerRuns --verbose

# Output
pid 20949's current affinity list: 0-5
pid 20949's new affinity list: 0-5

+++++++++++++++++++++++++++++++++++++++++++++
Filling Database with 1 warehouses
+++++++++++++++++++++++++++++++++++++++++++++

Created HammerDB fill scripts at /home/ubuntu/HammerRuns/HammerDB-Run-2023-07-23_12:23:26/scripts/pg_fill.tcl
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

Created HammerDB bench scripts at /home/ubuntu/HammerRuns/HammerDB-Run-2023-07-23_12:23:26/scripts/pg_bench.tcl
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

Scripts can be found at: /home/ubuntu/HammerRuns/HammerDB-Run-2023-07-23_12:23:26/scripts
Logs can be found at: /home/ubuntu/HammerRuns/HammerDB-Run-2023-07-23_12:23:26/logs
Summary can be found at: /home/ubuntu/HammerRuns/HammerDB-Run-2023-07-23_12:23:26/summary
--------------------------
RESULTS
--------------------------
NOPM: 15900
TPM: 36709

--------------------------
DATABASE
--------------------------
Database: pg
DB Host: localhost
DB Port: 5432
DB User: postgres
DB Password: postgres
Database Core Affinity: 0-5

--------------------------
HAMMER DB
--------------------------
HammerDB Path: /home/ubuntu/HammerDB-4.8
HammerDB Core Affinity: 6-11
Data Warehouses: 1
Virtual Users: 1
Rampup Duration: 1
Benchmark Duration: 1
Iterations: 10000000

--------------------------
SYSTEM
--------------------------
Operating System: Ubuntu 20.04.5 LTS
Kernel Version: Linux 5.4.0-137-generic
CPU: Intel Xeon Processor (Cascadelake)
PostgreSQL Version: 12.15

--------------------------
GENERATED FILES
--------------------------
Summary file: /home/ubuntu/HammerRuns/HammerDB-Run-2023-07-23_12:23:26/summary
Scripts Directory: /home/ubuntu/HammerRuns/HammerDB-Run-2023-07-23_12:23:26/scripts
Logs Directory: /home/ubuntu/HammerRuns/HammerDB-Run-2023-07-23_12:23:26/logs
```
