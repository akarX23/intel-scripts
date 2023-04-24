#!/bin/bash

GIT_DIR=
INSTALL_DIR=
LIBRPATH=

# Parse command line arguments
while [ "$1" != "" ]; do
    case $1 in
        --git-dir )
            GIT_DIR="$2"
            shift 1
            ;;
        --install-dir )
            INSTALL_DIR="$2"
            shift 1
            ;;
        * )
            echo "Unknown argument: $1"
            exit 1
            ;;
    esac
    shift
done

if [[ -z "$GIT_DIR" ]]; then
    echo "Error: --git-dir cannot be empty or null."
    exit 1
fi

if [[ -z "$INSTALL_DIR" ]]; then
    echo "Error: --install-dir cannot be empty or null."
    exit 1
fi

git clone https://github.com/openssl/openssl.git $GIT_DIR
cd $GIT_DIR
git checkout openssl-3.0

./config --prefix=$INSTALL_DIR 

make depend
make
make install

echo "export OPENSSL_ENGINES=$INSTALL_DIR/lib64/engines-3" >> ~/.bashrc
echo "export OPENSSL_ENGINES=$INSTALL_DIR/lib64/engines-3" >> ~/.zshrc