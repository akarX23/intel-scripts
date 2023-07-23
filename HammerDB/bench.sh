#!/bin/bash

# Default values for variables
HDB_DIR="/home/ubuntu/HammerDB-4.8"
DB_USER="root"
DB_PASSWORD="root"
DATA_WAREHOUSES=2
TASKS="fill,bench"
VIRTUAL_USERS=2
DATABASE="mysql"
RAMPUP_DUR="1"
PG_SUPERUSER_PASSWORD=postgres
PG_SUPERUSER=postgres
ITERATIONS=10000000
DB_HOST=localhost
DB_PORT=3306
NUMA_ARGS="--cpunodebind=0 --membind=0"
DB_CORES="0-$(nproc)"
BENCH_DURATION=1
OUTPUT_DIR=$(pwd)

# Help function to display script usage
print_help() {
    echo "Usage: $0 [OPTIONS]"
    echo "Options:"
    echo "  -d, --hdb-dir DIR         Set the HammerDB directory (default: $HDB_DIR)"
    echo "  -u, --db-user USER     Set the DB username (default: $DB_USER)"
    echo "  -p, --db-password PASS Set the DB password (default: $DB_PASSWORD)"
    echo "  -host, --db-host HOST        Set the database host (default: $DB_HOST)"
    echo "  -port, --db-port PORT        Set the database port (default: $DB_PORT)"
    echo "  -w, --data-warehouses NUM Set the number of data warehouses (default: $DATA_WAREHOUSES)"
    echo "  -t, --tasks TASKS         Set the tasks to perform (default: $TASKS)"
    echo "  -v, --virtual-users NUM   Set the number of virtual users (default: $VIRTUAL_USERS)"
    echo "  -db, --database DB        Set the database type (default: $DATABASE)"
    echo "  -dbc, --db-cores CORES    Set the database cores in taskset format (default: $DB_CORES)"
    echo "  -o, --output-dir DIR      Set the output directory for scripts and logs (default: $OUTPUT_DIR)"
    echo "  -r, --rampup-dur NUM      Set the rampup duration in minutes (default: $RAMPUP_DUR)"
    echo "  -b, --bench-duration NUM  Set the benchmark duration in minutes (default: $BENCH_DURATION)"
    echo "  -pgsp, --pg-superuser-password PASS Set the PostgreSQL superuser password (default: $PG_SUPERUSER_PASSWORD)"
    echo "  -pgsu, --pg-superuser USER Set the PostgreSQL superuser (default: $PG_SUPERUSER)"
    echo "  -i, --iterations NUM      Set the number of iterations (default: $ITERATIONS)"
    echo "  -n, --numa-args ARGS      Set the NUMA arguments for HammerDB Client (default: $NUMA_ARGS)"
    echo "  --verbose                 Print all HammerDB output to console"
    echo "  -h, --help                 Display this help message"
    echo "Note: If an option is not provided, the default value will be used."
}

is_valid_database() {
    # We'll convert the provided database name to lowercase for comparison
    local db_lowercase
    db_lowercase=$(echo "$1" | tr '[:upper:]' '[:lower:]')

    # List of valid databases (MySQL and PostgreSQL)
    case "$db_lowercase" in
        "mysql"|"pg")
            return 0  # Valid database
            ;;
        *)
            return 1  # Invalid database
            ;;
    esac
}

validate_tasks() {
    local tasks="$1"
    local valid_tasks=("fill" "bench")

    IFS=',' read -ra task_list <<< "$tasks"
    for task in "${task_list[@]}"; do
        if [[ ! " ${valid_tasks[*]} " =~ " ${task} " ]]; then
            echo "Invalid task: $task"
            echo "Supported tasks are: fill, bench"
            exit 1
        fi
    done
}

create_script_file() {
    local benchmark_file="$1"
    local task="$2"

    # Start with a common header
    cat <<EOF > "$benchmark_file"
dbset db ${DATABASE}
dbset bm tpc-c
diset tpcc ${DATABASE}_pass ${DB_PASSWORD}   
diset tpcc ${DATABASE}_user ${DB_USER}
diset connection ${DATABASE}_host ${DB_HOST}
diset connection ${DATABASE}_port ${DB_PORT}
EOF
   
    if [[ "$DATABASE" == "pg" ]]; then
        cat <<EOF >> "$benchmark_file"
diset tpcc pg_superuserpass ${PG_SUPERUSER_PASSWORD}
diset tpcc pg_superuser ${PG_SUPERUSER}
EOF
    fi 
        # Add the task-specific content
        case "$task" in
            "fill")
                cat <<EOF >> "$benchmark_file"
diset tpcc ${DATABASE}_count_ware ${DATA_WAREHOUSES}
diset tpcc ${DATABASE}_num_vu ${VIRTUAL_USERS}
diset tpcc ${DATABASE}_total_iterations ${ITERATIONS}
buildschema
EOF
                ;;
            "bench")
                cat <<EOF >> "$benchmark_file"
vudestroy
diset tpcc ${DATABASE}_driver timed
diset tpcc ${DATABASE}_timeprofile true
diset tpcc ${DATABASE}_rampup ${RAMPUP_DUR}
diset tpcc ${DATABASE}_duration ${BENCH_DURATION}
loadscript
vuset vu ${VIRTUAL_USERS}
vuset logtotemp 1
vucreate
vurun
vudestroy
EOF
                ;;
        esac
}


# Parse command-line arguments using a loop
while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            print_help
            exit 0
            ;;
        -d|--hdb-dir)
            HDB_DIR="$2"
            shift 2
            ;;
        -u|--db-user)
            DB_USER="$2"
            shift 2
            ;;
        -p|--db-password)
            DB_PASSWORD="$2"
            shift 2
            ;;
        -w|--data-warehouses)
            DATA_WAREHOUSES="$2"
            shift 2
            ;;
        -t|--tasks)
            TASKS="$2"
            shift 2
            ;;
        -v|--virtual-users)
            VIRTUAL_USERS="$2"
            shift 2
            ;;
        -db|--database)
            DATABASE="$2"
            shift 2
            ;;
        -r | --rampup-dur)
            RAMPUP_DUR="$2"
            shift 2
            ;;
        -b | --bench-duration)
            BENCH_DURATION="$2"
            shift 2
            ;;
        -pgsp | --pg-superuser-password)
            PG_SUPERUSER_PASSWORD="$2"
            shift 2
            ;;
        -pgsu | --pg-superuser)
            PG_SUPERUSER="$2"
            shift 2
            ;;
        -i | --iterations)
            ITERATIONS="$2"
            shift 2
            ;;
        -n | --numa-args)
            NUMA_ARGS="$2"
            shift 2
            ;;
        -host | --db-host)
            DB_HOST="$2"
            shift 2
            ;;
        -port | --db-port)
            DB_PORT="$2"
            shift 2
            ;;
        -dbc | --db-cores) 
            DB_CORES="$2"
            shift 2
            ;;
        -o | --output-dir)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        --verbose)
            VERBOSE=true
            shift 1
            ;;
        *)
            echo "Invalid option: $1"
            print_help
            exit 1
            ;;
    esac
done

# Check if the provided database is valid before proceeding
if ! is_valid_database "$DATABASE"; then
    echo "Invalid database: $DATABASE"
    echo "Supported databases are: mysql, pg"
    exit 1
fi

validate_tasks "$TASKS"

OUTPUT_DIR="$OUTPUT_DIR/HammerDB-Run-$(date +%Y-%m-%d_%H:%M:%S)"
SCRIPTS_DIR="$OUTPUT_DIR/scripts"
LOG_DIR="$OUTPUT_DIR/logs"

cd $HDB_DIR
mkdir -p $SCRIPTS_DIR
mkdir -p $LOG_DIR

if [[ "$DATABASE" == "mysql" ]]; then
    DATABASE_VERSION=$(mysql --version | awk '{print $3}' | cut -d '-' -f 1)
    DB_TEXT="MySQL"
    ln -s /run/mysqld/mysqld.sock /tmp/mysql.sock 2> /dev/null
    sudo taskset -apc $DB_CORES $(pgrep mysql | head -n 1)
elif [[ "$DATABASE" == "pg" ]]; then
    DATABASE_VERSION=$(psql --version | awk '{print $3}')
    DB_TEXT="PostgreSQL"
    sudo taskset -apc $DB_CORES $(pgrep postgres | head -n 1)
fi

# Loop over the tasks
IFS=',' read -ra task_list <<< "$TASKS"
for task in "${task_list[@]}"; do
    case "$task" in
        "fill")
            echo -e "\n+++++++++++++++++++++++++++++++++++++++++++++"
            echo "Filling Database with $DATA_WAREHOUSES warehouses"
            echo -e "+++++++++++++++++++++++++++++++++++++++++++++\n"
            create_script_file "$SCRIPTS_DIR/${DATABASE}_fill.tcl" "fill"
            echo "Created HammerDB fill scripts at $SCRIPTS_DIR/${DATABASE}_fill.tcl"
            if [ "$VERBOSE" = "true" ]; then
                # If --verbose option is provided, use tee for both stdout and log file
                numactl $NUMA_ARGS ./hammerdbcli auto $SCRIPTS_DIR/${DATABASE}_fill.tcl | tee "$LOG_DIR/${DATABASE}_fill.log"
            else
                # If --verbose option is not provided, redirect stdout to log file only
                numactl $NUMA_ARGS ./hammerdbcli auto $SCRIPTS_DIR/${DATABASE}_fill.tcl > "$LOG_DIR/${DATABASE}_fill.log"
            fi            
            ;;
        "bench")
            echo -e "\n+++++++++++++++++++++++++++++++++++++++++++++"
            echo "Running Benchmark with $VIRTUAL_USERS virtual users"
            echo -e "+++++++++++++++++++++++++++++++++++++++++++++\n"
            create_script_file "$SCRIPTS_DIR/${DATABASE}_bench.tcl" "bench"
            echo "Created HammerDB bench scripts at $SCRIPTS_DIR/${DATABASE}_bench.tcl"
            if [ "$VERBOSE" = "true" ]; then
                # If --verbose option is provided, use tee for both stdout and log file
                numactl $NUMA_ARGS ./hammerdbcli auto $SCRIPTS_DIR/${DATABASE}_bench.tcl | tee "$LOG_DIR/${DATABASE}_bench.log"
            else
                # If --verbose option is not provided, redirect stdout to log file only
                numactl $NUMA_ARGS ./hammerdbcli auto $SCRIPTS_DIR/${DATABASE}_bench.tcl > "$LOG_DIR/${DATABASE}_bench.log"
            fi            
            ;;
        *)
            # This should never happen due to the task validation earlier.
            # However, adding it for completeness.
            echo "Unknown task: $task"
            ;;
    esac
done

NOPM=$(cat $LOG_DIR/${DATABASE}_bench.log | grep "TEST RESULT" | awk '{print $7}')
TPM=$(cat $LOG_DIR/${DATABASE}_bench.log | grep "TEST RESULT" | awk '{print $10}')

echo -e "\n+++++++++++++++++++++++++++++++++++++++++++++"
echo "Summarizing results"
echo -e "+++++++++++++++++++++++++++++++++++++++++++++\n"

if [[ $NUMA_ARGS == *"-C "* ]]; then
    # If NUMA_ARGS contains the "-C" option, extract the core-range
    CORE_AFFINITY=$(echo "$NUMA_ARGS" | grep -oP "(?<=-C ).*")
    HammerDB_CORE_OR_NODE="HammerDB Core Affinity: $CORE_AFFINITY"
elif [[ $NUMA_ARGS == *"--cpunodebind="* && $NUMA_ARGS == *"--membind="* ]]; then
    # If NUMA_ARGS contains both "--cpunodebind" and "--membind" options, extract the node-index
    CPU_NODE_BIND=$(echo "$NUMA_ARGS" | grep -oP "(?<=--cpunodebind=)\d+")
    MEM_BIND=$(echo "$NUMA_ARGS" | grep -oP "(?<=--membind=)\d+")
    HammerDB_CORE_OR_NODE="HammerDB - CPU Node Bind: $CPU_NODE_BIND, Memory Node Bind: $MEM_BIND"
else
    # NUMA_ARGS has an unsupported format
    HammerDB_CORE_OR_NODE="Unsupported NUMA_ARGS format: $NUMA_ARGS"
fi

cat <<EOF > "$OUTPUT_DIR/summary"

--------------------------
DATABASE
--------------------------
Database: ${DATABASE}
DB Host: ${DB_HOST}
DB Port: ${DB_PORT}
DB User: ${DB_USER}
DB Password: ${DB_PASSWORD}
Database Core Affinity: ${DB_CORES}

--------------------------
HAMMER DB
--------------------------
HammerDB Path: ${HDB_DIR}
${HammerDB_CORE_OR_NODE}
Data Warehouses: ${DATA_WAREHOUSES}
Virtual Users: ${VIRTUAL_USERS}
Rampup Duration: ${RAMPUP_DUR}
Benchmark Duration: ${BENCH_DURATION}
Iterations: ${ITERATIONS}

--------------------------
SYSTEM
--------------------------
$(hostnamectl | grep "Operating System" | tr -s " ")
Kernel Version: $(hostnamectl | grep "Kernel" | cut -d ":" -f 2 | sed -e 's/^[[:space:]]*//')
CPU: $(lscpu | grep "Model name" | cut -d ":" -f 2 | sed -e 's/^[[:space:]]*//')
${DB_TEXT} Version: ${DATABASE_VERSION}

--------------------------
GENERATED FILES
--------------------------
Summary file: ${OUTPUT_DIR}/summary
Scripts Directory: ${SCRIPTS_DIR}
Logs Directory: ${LOG_DIR}

--------------------------
RESULTS
--------------------------
NOPM: ${NOPM}
TPM: ${TPM}
EOF

echo -e "Scripts can be found at: $SCRIPTS_DIR"
echo -e "Logs can be found at: $LOG_DIR"
echo -e "Summary can be found at: $OUTPUT_DIR/summary"
echo -e "--------------------------
RESULTS
--------------------------
NOPM: ${NOPM}
TPM: ${TPM}"

if [ "$VERBOSE" = "true" ]; then
    cat "$OUTPUT_DIR/summary"
fi