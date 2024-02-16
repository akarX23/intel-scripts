#!/bin/bash

SSB_DIR=$(pwd)/ssb-dbgen
SIZE_FACTOR=20
GEN_DATA=0
BUILD_SSB=0
FILL_SERVER=false
CLICKHOUSE_BINARY="$(which clickhouse)"
ckhost="localhost"
ckport="9000"

pprint () {
    echo "---->" $1
}

# Help function to display usage instructions
function display_help {
    echo "Usage: configure.sh [OPTIONS]"
    echo "Options:"
    echo "  -s, --ssb-dir PATH       Specify the SSB dbgen directory (default: $SSB_DIR)"
    echo "  -f, --size-factor VALUE  Specify the size factor (default: $SIZE_FACTOR)"
    echo "  -o, --gen-data           Pass this to only generate data"
    echo "  -b                       Pass this to build the dbgen binary"
    echo "  --fill-server            Fill a clickhouse server with ssb data"
    echo "  --clickhouse-bin         Set the path to the ClickHouse binary. Default: $CLICKHOUSE_BINARY"
    echo "  --ck-host                Clickhouse host (default: $ckhost)"
    echo "  --ck-port                Clickhouse port (default: $ckport)"
    echo "  -h, --help               Display this help message"
}

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
    key="$1"

    case $key in
        -s|--ssb-dir)
            SSB_DIR="$2"
            shift
            ;;
        -f|--size-factor)
            SIZE_FACTOR="$2"
            shift
            ;;
        -o|--gen-data)
            GEN_DATA=1
            ;;
        -b)
            BUILD_SSB=1
            ;;
        -h|--help)
            display_help
            exit 0
            ;;
        --fill-server)
            FILL_SERVER=true
            ;;
        --clickhouse-bin)
            CLICKHOUSE_BINARY="$2"
            shift
            ;;
        --ck-host)
            ckhost="$2"
            shift
            ;;
        --ck-port)
            ckport="$2"
            shift
            ;;
        *)
            echo "Unknown option: $key"
            display_help
            exit 1
            ;;
    esac
    shift
done

<<<<<<< HEAD

supplier_table="
   CREATE TABLE supplier
    (
            S_SUPPKEY       UInt32,
            S_NAME          String,
            S_ADDRESS       String,
            S_CITY          LowCardinality(String),
            S_NATION        LowCardinality(String),
            S_REGION        LowCardinality(String),
            S_PHONE         String
    )
    ENGINE = MergeTree ORDER BY S_SUPPKEY;
"
part_table="
    CREATE TABLE part
=======
create_table_query="
    CREATE TABLE customer
>>>>>>> be659bcffe693d2fe1b0e4922415921cb4234234
    (
            C_CUSTKEY       UInt32,
            C_NAME          String,
            C_ADDRESS       String,
            C_CITY          LowCardinality(String),
            C_NATION        LowCardinality(String),
            C_REGION        LowCardinality(String),
            C_PHONE         String,
            C_MKTSEGMENT    LowCardinality(String)
    )
    ENGINE = MergeTree ORDER BY (C_CUSTKEY);

    CREATE TABLE lineorder
    (
        LO_ORDERKEY             UInt32,
        LO_LINENUMBER           UInt8,
        LO_CUSTKEY              UInt32,
        LO_PARTKEY              UInt32,
        LO_SUPPKEY              UInt32,
        LO_ORDERDATE            Date,
        LO_ORDERPRIORITY        LowCardinality(String),
        LO_SHIPPRIORITY         UInt8,
        LO_QUANTITY             UInt8,
        LO_EXTENDEDPRICE        UInt32,
        LO_ORDTOTALPRICE        UInt32,
        LO_DISCOUNT             UInt8,
        LO_REVENUE              UInt32,
        LO_SUPPLYCOST           UInt32,
        LO_TAX                  UInt8,
        LO_COMMITDATE           Date,
        LO_SHIPMODE             LowCardinality(String)
    )
    ENGINE = MergeTree PARTITION BY toYear(LO_ORDERDATE) ORDER BY (LO_ORDERDATE, LO_ORDERKEY);

    CREATE TABLE part
    (
            P_PARTKEY       UInt32,
            P_NAME          String,
            P_MFGR          LowCardinality(String),
            P_CATEGORY      LowCardinality(String),
            P_BRAND         LowCardinality(String),
            P_COLOR         LowCardinality(String),
            P_TYPE          LowCardinality(String),
            P_SIZE          UInt8,
            P_CONTAINER     LowCardinality(String)
    )
    ENGINE = MergeTree ORDER BY P_PARTKEY;

    CREATE TABLE supplier
    (
            S_SUPPKEY       UInt32,
            S_NAME          String,
            S_ADDRESS       String,
            S_CITY          LowCardinality(String),
            S_NATION        LowCardinality(String),
            S_REGION        LowCardinality(String),
            S_PHONE         String
    )
    ENGINE = MergeTree ORDER BY S_SUPPKEY;
"

lineorder_flat_table="
    SET max_memory_usage = 20000000000;
    CREATE TABLE lineorder_flat
    ENGINE = MergeTree
    PARTITION BY toYear(LO_ORDERDATE)
    ORDER BY (LO_ORDERDATE, LO_ORDERKEY) AS
    SELECT
        l.LO_ORDERKEY AS LO_ORDERKEY,
        l.LO_LINENUMBER AS LO_LINENUMBER,
        l.LO_CUSTKEY AS LO_CUSTKEY,
        l.LO_PARTKEY AS LO_PARTKEY,
        l.LO_SUPPKEY AS LO_SUPPKEY,
        l.LO_ORDERDATE AS LO_ORDERDATE,
        l.LO_ORDERPRIORITY AS LO_ORDERPRIORITY,
        l.LO_SHIPPRIORITY AS LO_SHIPPRIORITY,
        l.LO_QUANTITY AS LO_QUANTITY,
        l.LO_EXTENDEDPRICE AS LO_EXTENDEDPRICE,
        l.LO_ORDTOTALPRICE AS LO_ORDTOTALPRICE,
        l.LO_DISCOUNT AS LO_DISCOUNT,
        l.LO_REVENUE AS LO_REVENUE,
        l.LO_SUPPLYCOST AS LO_SUPPLYCOST,
        l.LO_TAX AS LO_TAX,
        l.LO_COMMITDATE AS LO_COMMITDATE,
        l.LO_SHIPMODE AS LO_SHIPMODE,
        c.C_NAME AS C_NAME,
        c.C_ADDRESS AS C_ADDRESS,
        c.C_CITY AS C_CITY,
        c.C_NATION AS C_NATION,
        c.C_REGION AS C_REGION,
        c.C_PHONE AS C_PHONE,
        c.C_MKTSEGMENT AS C_MKTSEGMENT,
        s.S_NAME AS S_NAME,
        s.S_ADDRESS AS S_ADDRESS,
        s.S_CITY AS S_CITY,
        s.S_NATION AS S_NATION,
        s.S_REGION AS S_REGION,
        s.S_PHONE AS S_PHONE,
        p.P_NAME AS P_NAME,
        p.P_MFGR AS P_MFGR,
        p.P_CATEGORY AS P_CATEGORY,
        p.P_BRAND AS P_BRAND,
        p.P_COLOR AS P_COLOR,
        p.P_TYPE AS P_TYPE,
        p.P_SIZE AS P_SIZE,
        p.P_CONTAINER AS P_CONTAINER
    FROM lineorder AS l
    INNER JOIN customer AS c ON c.C_CUSTKEY = l.LO_CUSTKEY
    INNER JOIN supplier AS s ON s.S_SUPPKEY = l.LO_SUPPKEY
    INNER JOIN part AS p ON p.P_PARTKEY = l.LO_PARTKEY;
"

# Display configuration
echo "Configuring with the following settings:"
echo "SSB_DIR: $SSB_DIR"
echo "SIZE_FACTOR: $SIZE_FACTOR"
<<<<<<< HEAD
echo "ONLY_GEN_DATA: $ONLY_GEN_DATA"

if [ $BUILD_SSB -eq 1 ]; then
    pprint "Cloning ssb at: $SSB_DIR"
    git clone https://github.com/vadimtk/ssb-dbgen.git $SSB_DIR

    cd $SSB_DIR
    pprint "Building ssb with command: make"
    make
fi

=======

if [ $BUILD_SSB -eq 1 ]; then
    pprint "Cloning ssb at: $SSB_DIR"
    git clone https://github.com/vadimtk/ssb-dbgen.git $SSB_DIR

    cd $SSB_DIR
    pprint "Building ssb with command: make"
    make
fi

>>>>>>> be659bcffe693d2fe1b0e4922415921cb4234234
# Clone and build when ONLY_GEN_DATA is not set
if [ $GEN_DATA -eq 1 ]; then
    cd $SSB_DIR
    DB_GEN_COMMAND="${SSB_DIR}/dbgen -s $SIZE_FACTOR"
    pprint "Generating data with command: $DB_GEN_COMMAND"
    pprint "Generating customer data: $SSB_DIR/customer.tbl"
    eval $DB_GEN_COMMAND -T c
    pprint "Generating lineorder data: $SSB_DIR/lineorder.tbl"
    eval $DB_GEN_COMMAND -T l
    pprint "Generating part data: $SSB_DIR/part.tbl"
    eval $DB_GEN_COMMAND -T p
    pprint "Generating supplier data: $SSB_DIR/supplier.tbl"
    eval $DB_GEN_COMMAND -T s
    pprint "Generating date data: $SSB_DIR/date.tbl"
    eval $DB_GEN_COMMAND -T d
fi

if [[ $FILL_SERVER == true ]]; then
<<<<<<< HEAD
    eval $CLICKHOUSE_BINARY client --host $ckhost --port $ckport --multiquery --query $create_table_query
    eval $CLICKHOUSE_BINARY client --host $ckhost --port $ckport --query "INSERT INTO customer FORMAT CSV" < $SSB_DIR/customer.tbl
    eval $CLICKHOUSE_BINARY client --host $ckhost --port $ckport --query "INSERT INTO part FORMAT CSV" < $SSB_DIR/part.tbl
    eval $CLICKHOUSE_BINARY client --host $ckhost --port $ckport --query "INSERT INTO supplier FORMAT CSV" < $SSB_DIR/supplier.tbl
    eval $CLICKHOUSE_BINARY client --host $ckhost --port $ckport --query "INSERT INTO lineorder FORMAT CSV" < $SSB_DIR/customer.tbl
    eval $CLICKHOUSE_BINARY client --host $ckhost --port $ckport --multiquery --query $lineorder_flat_table
=======
    pprint "Creating Tables"
    ${CLICKHOUSE_BINARY} client --host $ckhost --port $ckport --multiquery -q "$create_table_query"
    pprint "Inserting customer table"
    ${CLICKHOUSE_BINARY} client --host $ckhost --port $ckport --query "INSERT INTO customer FORMAT CSV" < ${SSB_DIR}/customer.tbl
    pprint "Inserting part table"
    ${CLICKHOUSE_BINARY} client --host $ckhost --port $ckport --query "INSERT INTO part FORMAT CSV" < ${SSB_DIR}/part.tbl
    pprint "Inserting supplier table"
    ${CLICKHOUSE_BINARY} client --host $ckhost --port $ckport --query "INSERT INTO supplier FORMAT CSV" < ${SSB_DIR}/supplier.tbl
    pprint "Inserting lineorder table"
    ${CLICKHOUSE_BINARY} client --host $ckhost --port $ckport --query "INSERT INTO lineorder FORMAT CSV" < ${SSB_DIR}/lineorder.tbl
    pprint "Creating lineorder_flat table"
    ${CLICKHOUSE_BINARY} client --host $ckhost --port $ckport --multiquery -q "$lineorder_flat_table"
>>>>>>> be659bcffe693d2fe1b0e4922415921cb4234234
fi

