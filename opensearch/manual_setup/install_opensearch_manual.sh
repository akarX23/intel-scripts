#!/bin/bash

export http_proxy=""
export https_proxy=""
export ftp_proxy=""
export no_proxy="127.0.0.1,localhost"

# For curl
export HTTP_PROXY="$http_proxy"
export HTTPS_PROXY="$https_proxy"
export FTP_PROXY="$ftp_proxy"
export NO_PROXY="$no_proxy"

DEB_FILE="opensearch-2.8.0-linux-x64.deb"

if [ ! -f "$DEB_FILE" ]; then
  wget https://artifacts.opensearch.org/releases/bundle/opensearch/2.8.0/opensearch-2.8.0-linux-x64.deb
fi

sudo dpkg -i opensearch-2.8.0-linux-x64.deb
