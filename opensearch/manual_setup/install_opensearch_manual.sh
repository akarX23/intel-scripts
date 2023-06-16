#!/bin/bash

export http_proxy=""
export https_proxy=""
export ftp_proxy=""
export no_proxy="127.0.0.1,localhost"

# For curl
export HTTP_PROXY=""
export HTTPS_PROXY=""
export FTP_PROXY=""
export NO_PROXY="127.0.0.1,localhost"

DEB_FILE="opensearch-2.6.0-linux-x64.deb"

if [ ! -f "$DEB_FILE" ]; then
  wget https://artifacts.opensearch.org/releases/bundle/opensearch/2.8.0/opensearch-2.8.0-linux-x64.deb
fi

sudo dpkg -i opensearch-2.6.0-linux-x64.deb
