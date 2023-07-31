#!/bin/bash

SSB_DIR=$(pwd)/ssb-dbgen
SIZE_FACTOR=20
ONLY_GEN_DATA=0

pprint () {
    echo "---->" $1
}

# Help function to display usage instructions
function display_help {
    echo "Usage: configure.sh [OPTIONS]"
    echo "Options:"
    echo "  -s, --ssb-dir PATH       Specify the SSB dbgen directory (default: $SSB_DIR)"
    echo "  -f, --size-factor VALUE  Specify the size factor (default: $SIZE_FACTOR)"
    echo "  -o, --only-gen-data      Pass this to only generate data without building the library"
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
        -o|--only-gen-data)
            ONLY_GEN_DATA=1
            ;;
        -h|--help)
            display_help
            exit 0
            ;;
        *)
            echo "Unknown option: $key"
            display_help
            exit 1
            ;;
    esac
    shift
done

# Display configuration
echo "Configuring with the following settings:"
echo "SSB_DIR: $SSB_DIR"
echo "SIZE_FACTOR: $SIZE_FACTOR"
echo "ONLY_GEN_DATA: $ONLY_GEN_DATA"

# Clone and build when ONLY_GEN_DATA is not set
if [ $ONLY_GEN_DATA -eq 0 ]; then
    pprint "Cloning ssb at: $SSB_DIR"
    git clone https://github.com/vadimtk/ssb-dbgen.git $SSB_DIR

    cd $SSB_DIR
    pprint "Building ssb with command: make"
    make
fi

cd $SSB_DIR
DB_GEN_COMMAND="$(SSB_DIR)/dbgen -s $SIZE_FACTOR"
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

