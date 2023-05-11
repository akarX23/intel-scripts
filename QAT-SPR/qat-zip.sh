#!/bin/bash

ICP_ROOT=$ICP_ROOT
QZ_ROOT=./QATzip

# Parse command line arguments
while [ "$1" != "" ]; do
    case $1 in
        --qat-driver-dir )
            ICP_ROOT="$2"
            shift 1
            ;;
        --git-dir )
            QZ_ROOT="$2"
            shift 1
            ;;
        * )
            echo "Unknown argument: $1"
            exit 1
            ;;
    esac
    shift
done

if [[ -z "$ICP_ROOT" ]]; then
    echo "Error: --qat-driver-dir cannot be empty or null."
    exit 1
fi

echo 1024 > /sys/kernel/mm/hugepages/hugepages-2048kB/nr_hugepages
rmmod usdm_drv
CORES=$(nproc --all)
insmod $ICP_ROOT/build/usdm_drv.ko max_huge_pages=1024 max_huge_pages_per_process=$CORES

sudo apt-get install liblz4-dev

git clone https://github.com/intel/QATzip $QZ_ROOT

cd $QZ_ROOT
./autogen.sh
./configure --with-ICP_ROOT=$ICP_ROOT
make clean
make
make install
