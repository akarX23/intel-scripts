#!/bin/bash

if [ -n "$1" ]; then
    WDIR="$1"
else
    WDIR="./"
fi

mkdir -p $WDIR
CUR_DIR=$(pwd)
cd $WDIR

# Update packages
sudo apt-get update -y

# accel-config dependencies
sudo apt install build-essential -y
sudo apt install autoconf automake autotools-dev libtool pkgconf asciidoc xmlto -y
sudo apt install uuid-dev libjson-c-dev libkeyutils-dev -y
sudo apt install debhelper devscripts debmake quilt fakeroot lintian asciidoctor -y
sudo apt install file gnupg patch patchutils -y

# QPL dependencies
sudo apt install nasm cmake -y

# RocksDB dependencies
sudo apt install numactl -y
sudo apt install libgflags-dev -y
sudo apt-get install gcc-8 -y
sudo apt-get install g++-8 -y
sudo update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-8 700 --slave /usr/bin/g++ g++ /usr/bin/g++-8
sudo apt-get install zstd -y

# Data collection
sudo apt install sysstat -y

# accel-config
git clone --branch accel-config-v3.4.6.4 https://github.com/intel/idxd-config.git
cd idxd-config
./autogen.sh
./configure CFLAGS='-g -O2' --prefix=/usr --sysconfdir=/etc --libdir=/usr/lib
make
make check
sudo make install
cd ..

# QPL
git clone --recursive --branch v1.1.0 https://github.com/intel/qpl.git qpl_source
cd qpl_source
mkdir build
cd build
cmake -DCMAKE_INSTALL_PREFIX=../../qpl -DCMAKE_BUILD_TYPE=Release -DEFFICIENT_WAIT=ON ..
cmake --build . --target install -- -j
cd ../..

# RocksDB with IAA plugin
git clone --branch pluggable_compression_rc_filedata_v0.13.0 https://github.com/lucagiac81/rocksdb.git rocksdb
cd rocksdb
git clone --branch v0.3.0 "https://github.com/intel/iaa-plugin-rocksdb.git" plugin/iaa_compressor
EXTRA_CXXFLAGS="-I./../qpl/include" EXTRA_LDFLAGS="-L./../qpl/lib" ROCKSDB_PLUGINS="iaa_compressor" make -j release
cd ..

# Setting up IAA users
cd $CUR_DIR
chmod +x configure_iaa_user.sh
sudo ./configure_iaa_user.sh