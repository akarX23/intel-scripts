#!/bin/bash

# Default values for variables
HDB_DIR="/home/ubuntu/HammerDB-4.8"
DB_USER="root"
DB_PASSWORD="root"
DATA_WAREHOUSES=2
TASKS="fill,bench"
VIRTUAL_USERS=2
DATABASE="mysql"
SCRIPTS_DIR="$(pwd)/scripts"
RAMPUP_DUR="1"
PG_SUPERUSER_PASSWORD=postgres
PG_SUPERUSER=postgres
ITERATIONS=10000000
DB_HOST=localhost
DB_PORT=3306
NUMA_ARGS="--cpunodebind=0 --membind=0"
BENCH_DURATION=1

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
    echo "  -s, --scripts-dir DIR     Set the scripts directory (default: $SCRIPTS_DIR)"
    echo "  -r, --rampup-dur NUM      Set the rampup duration in minutes (default: $RAMPUP_DUR)"
    echo "  -b, --bench-duration NUM  Set the benchmark duration in minutes (default: $BENCH_DURATION)"
    echo "  -pgsp, --pg-superuser-password PASS Set the PostgreSQL superuser password (default: $PG_SUPERUSER_PASSWORD)"
    echo "  -pgsu, --pg-superuser USER Set the PostgreSQL superuser (default: $PG_SUPERUSER)"
    echo "  -i, --iterations NUM      Set the number of iterations (default: $ITERATIONS)"
    echo "  -n, --numa-args ARGS      Set the NUMA arguments (default: $NUMA_ARGS)"
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

create_benchmark_file() {
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
        -s | --scripts-dir)
            SCRIPTS_DIR="$2"
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

cd $HDB_DIR
mkdir -p $SCRIPTS_DIR
ln -s /run/mysqld/mysqld.sock /tmp/mysql.sock 2> /dev/null

# Loop over the tasks
IFS=',' read -ra task_list <<< "$TASKS"
for task in "${task_list[@]}"; do
    case "$task" in
        "fill")
            echo "Performing 'fill' task..."
            create_benchmark_file "$SCRIPTS_DIR/${DATABASE}_fill.tcl" "fill"
            numactl $NUMA_ARGS ./hammerdbcli auto $SCRIPTS_DIR/${DATABASE}_fill.tcl
            ;;
        "bench")
            echo "Performing 'bench' task..."
            create_benchmark_file "$SCRIPTS_DIR/${DATABASE}_bench.tcl" "bench"
            numactl $NUMA_ARGS ./hammerdbcli auto $SCRIPTS_DIR/${DATABASE}_bench.tcl
            ;;
        *)
            # This should never happen due to the task validation earlier.
            # However, adding it for completeness.
            echo "Unknown task: $task"
            ;;
    esac
done

