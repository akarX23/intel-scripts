#!/bin/bash

# Default values for variables
HDB_DIR="/home/ubuntu/HammerDB-4.8"
MYSQL_USER="root"
MYSQL_PASSWORD="root"
DATA_WAREHOUSES=2
TASKS="fill,bench"
VIRTUAL_USERS=2
DATABASE="mysql"
SCRIPTS_DIR="$(pwd)/scripts"
RAMPUP_DUR="1"
RUN_TIMER="100"

# Help function to display script usage
print_help() {
    echo "Usage: $0 [OPTIONS]"
    echo "Options:"
    echo "  -h, --help                 Display this help message"
    echo "  -d, --hdb-dir DIR         Set the HammerDB directory (default: /home/ubuntu/HammerDB-4.8)"
    echo "  -u, --db-user USER     Set the DB username (default: root)"
    echo "  -p, --db-password PASS Set the DB password (default: root)"
    echo "  -w, --data-warehouses NUM Set the number of data warehouses (default: 2)"
    echo "  -t, --tasks TASKS         Set the tasks to perform (default: fill,bench)"
    echo "  -v, --virtual-users NUM   Set the number of virtual users (default: 2)"
    echo "  -db, --database DB        Set the database type (default: mysql)"
    echo "  -s, --scripts-dir DIR     Set the scripts directory (default: scripts)"
    echo "  -r, --rampup-dur NUM      Set the rampup duration in minutes (default: 1)"
    echo "  -rt, --run-timer NUM      Set the run timer in seconds (default: 100)"
    echo "Note: If an option is not provided, the default value will be used."
}

is_valid_database() {
    # We'll convert the provided database name to lowercase for comparison
    local db_lowercase
    db_lowercase=$(echo "$1" | tr '[:upper:]' '[:lower:]')

    # List of valid databases (MySQL and PostgreSQL)
    case "$db_lowercase" in
        "mysql"|"postgres")
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
diset tpcc mysql_pass ${MYSQL_PASSWORD}   
diset tpcc mysql_user ${MYSQL_USER}
EOF
    
        # Add the task-specific content
        case "$task" in
            "fill")
                cat <<EOF >> "$benchmark_file"
diset tpcc mysql_count_ware ${DATA_WAREHOUSES}
diset tpcc mysql_num_vu ${VIRTUAL_USERS}
buildschema
EOF
                ;;
            "bench")
                cat <<EOF >> "$benchmark_file"
vudestroy
diset tpcc mysql_driver timed
diset tpcc mysql_timeprofile true
diset tpcc mysql_rampup ${RAMPUP_DUR}
diset tpcc mysql_duration 5
loadscript
vuset vu ${VIRTUAL_USERS}
vucreate
vurun
runtimer ${RUN_TIMER}
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
            MYSQL_USER="$2"
            shift 2
            ;;
        -p|--db-password)
            MYSQL_PASSWORD="$2"
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
        -rt | --run-timer)
            RUN_TIMER="$2"
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
    echo "Supported databases are: mysql, postgres"
    exit 1
fi

validate_tasks "$TASKS"

cd $HDB_DIR
mkdir -p $SCRIPTS_DIR
sudo ln -s /run/mysqld/mysqld.sock /tmp/mysql.sock 2> /dev/null

# Loop over the tasks
IFS=',' read -ra task_list <<< "$TASKS"
for task in "${task_list[@]}"; do
    case "$task" in
        "fill")
            echo "Performing 'fill' task..."
            create_benchmark_file "$SCRIPTS_DIR/${DATABASE}_fill.tcl" "fill"
            eval ./hammerdbcli auto $SCRIPTS_DIR/${DATABASE}_fill.tcl
            ;;
        "bench")
            echo "Performing 'bench' task..."
            create_benchmark_file "$SCRIPTS_DIR/${DATABASE}_bench.tcl" "bench"
            eval ./hammerdbcli auto $SCRIPTS_DIR/${DATABASE}_bench.tcl
            ;;
        *)
            # This should never happen due to the task validation earlier.
            # However, adding it for completeness.
            echo "Unknown task: $task"
            ;;
    esac
done

