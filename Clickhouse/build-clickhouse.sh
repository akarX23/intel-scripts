#!/bin/bash

CURRENT_DIR=$(pwd)
CK_GIT_DIR=$CURRENT_DIR/Clickhouse
QPL_INSTALL_PATH=/home/akarx/qpl

pprint() {
    echo "--->" $1
}

# Help function to display usage instructions
function display_help {
    echo "Usage: configure.sh [OPTIONS]"
    echo "Options:"
    echo "  -c, --clickhouse-dir PATH   Specify the Clickhouse git directory (default: $CK_GIT_DIR)"
    echo "  -q, --qpl-install-path PATH Specify the QPL install path (default: $QPL_INSTALL_PATH)"
    echo "  -h, --help                  Display this help message"
}

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
    key="$1"

    case $key in
        -c|--clickhouse-dir)
            CK_GIT_DIR="$2"
            shift
            ;;
        -q|--qpl-install-path)
            QPL_INSTALL_PATH="$2"
            shift
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

pprint "Installing Pre-requisites"

sudo apt-get update -y
sudo apt-get install git cmake ccache python3 ninja-build nasm yasm gawk lsb-release wget software-properties-common gnupg
sudo apt install clang-16

export PATH=/usr/lib/ccache:$PATH

pprint "Cloning clickhouse source at $CK_GIT_DIR"
git clone --recursive --shallow-submodules https://github.com/ClickHouse/ClickHouse.git $CK_GIT_DIR
cd $CK_GIT_DIR
mkdir build

pprint "Building Clickhouse with command: cmake -S . -B build -DENABLE_QPL=1 -DCMAKE_PREFIX_PATH=$QPL_INSTALL_PATH -DCMAKE_CXX_COMPILER=/usr/bin/clang++-16 -DCMAKE_C_COMPILER=/usr/bin/clang-16"
cmake -S . -B build -DENABLE_QPL=1 -DCMAKE_PREFIX_PATH=/home/akarx/qpl -DCMAKE_CXX_COMPILER=/usr/bin/clang++-16 -DCMAKE_C_COMPILER=/usr/bin/clang-16

pprint "Generating Clickhouse binary with command: cmake --build build --target clickhouse"
cmake --build build --target clickhouse

pprint "Copying clickhouse binary at $CK_GIT_DIR/build/programs/clickhouse to /usr/bin"
sudo cp $CK_GIT_DIR/build/programs/clickhouse /usr/bin

