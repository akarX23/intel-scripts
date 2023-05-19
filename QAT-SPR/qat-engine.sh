#!/bin/bash

ICP_ROOT=$ICP_ROOT
GIT_DIR=./QAT_Engine
OPENSSL_INSTALL_DIR=

# Parse command line arguments
while [ "$1" != "" ]; do
    case $1 in
        --qat-driver-dir )
            ICP_ROOT="$2"
            shift 1
            ;;
        --git-dir )
            GIT_DIR="$2"
            shift 1
            ;;
        --openssl-dir )
            OPENSSL_INSTALL_DIR="$2"
            shift 1
            ;;
        --qat-driver-dir )
            ICP_ROOT="$2"
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

if [[ -z "$OPENSSL_INSTALL_DIR" ]]; then
    echo "Error: --openssl-dir cannot be empty or null."
    exit 1
fi

git clone https://github.com/intel/QAT_Engine.git $GIT_DIR

cd $GIT_DIR
./autogen.sh

./configure \
--with-qat_hw_dir=$ICP_ROOT \
--with-openssl_install_dir=$OPENSSL_INSTALL_DIR

make
make install

echo "export LD_LIBRARY_PATH=$OPENSSL_INSTALL_DIR/lib64" >> ~/.zshrc
echo "export LD_LIBRARY_PATH=$OPENSSL_INSTALL_DIR/lib64" >> ~/.bashrc
