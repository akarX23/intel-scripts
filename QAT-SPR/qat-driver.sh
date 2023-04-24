#!/bin/bash

ICP_ROOT=
UNINSTALL=

# Parse command line arguments
while [ "$1" != "" ]; do
    case $1 in
        --qat-driver-dir )
            ICP_ROOT="$2"
            shift 1
            ;;
        --uninstall )
            UNINSTALL=true
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

if [[ "$UNINSTALL" ]]; then
    cd $ICP_ROOT
    make uninstall 
    make clean
    service qat_service stop

    exit 0
fi

sudo apt-get update
sudo apt-get install -y libsystemd-dev
sudo apt-get install -y pciutils-dev
sudo apt-get install -y libudev-dev
sudo apt-get install -y libreadline6-dev
sudo apt-get install -y pkg-config
sudo apt-get install -y libxml2-dev
sudo apt-get install -y pciutils-dev
sudo apt-get install -y libboost-all-dev
sudo apt-get install -y libelf-dev
sudo apt-get install -y libnl-3-dev
sudo apt-get install -y kernel-devel-$(uname -r)
sudo apt-get install -y build-essential
sudo apt-get install -y yasm
sudo apt-get install -y zlib1g-dev
sudo apt-get install -y libssl-dev

cd $ICP_ROOT
tar -zxof QAT*.tar.gz
chmod -R o-rwx *

./configure
make -j install

service qat_service start
