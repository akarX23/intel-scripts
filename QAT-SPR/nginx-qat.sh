#!/bin/bash

ICP_ROOT=$ICP_ROOT
NGINX_INSTALL_DIR=
GIT_DIR=./NGINX-QAT
OPENSSL_LIB=
QZ_ROOT=

# Parse command line arguments
while [ "$1" != "" ]; do
    case $1 in
        --qat-driver-dir )
            ICP_ROOT="$2"
            shift 1
            ;;
        --nginx-install-dir )
            NGINX_INSTALL_DIR="$2"
            shift 1
            ;;
        --git-dir )
            GIT_DIR="$2"
            shift 1
            ;;
        --openssl-dir )
            OPENSSL_LIB="$2"
            shift 1
            ;;
        --qzip-dir )
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

if [[ -z "$NGINX_INSTALL_DIR" ]]; then
    echo "Error: --nginx-install-dir cannot be empty or null."
    exit 1
fi

if [[ -z "$OPENSSL_LIB" ]]; then
    echo "Error: --openssl-dir cannot be empty or null."
    exit 1
fi

sudo apt-get install libxslt-dev
sudo apt-get install libgd-dev
sudo apt-get install libgeoip-dev

wget --no-check-certificate https://github.com/PCRE2Project/pcre2/releases/download/pcre2-10.42/pcre2-10.42.tar.gz
tar -zxvf pcre2-10.42.tar.gz
cd pcre2-10.42
./configure
make -j 24
make install

git clone https://github.com/intel/asynch_mode_nginx $GIT_DIR
cd $GIT_DIR

./configure \
    --prefix=$NGINX_INSTALL_DIR \
    --with-http_ssl_module \
    --add-dynamic-module=modules/nginx_qatzip_module \
    --add-dynamic-module=modules/nginx_qat_module/ \
    --with-cc-opt="-DNGX_SECURE_MEM -I$OPENSSL_LIB/include -I$ICP_ROOT/quickassist/include -I$ICP_ROOT/quickassist/include/dc -I$QZ_ROOT/include -Wno-error=deprecated-declarations" \
    --with-ld-opt="-Wl,-rpath=$OPENSSL_LIB/lib64 -L$OPENSSL_LIB/lib64 -L$QZ_ROOT/src -lqatzip -lz"

make
make install