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

DEB_FILE="elasticsearch-7.17.10-amd64.deb"
RPM_FILE="elasticsearch-7.17.10-x86_64.rpm"

if [ ! -f "$DEB_FILE" ] && [ ! -f "$RPM_FILE" ]; then
  if [[ "$(grep -Ei 'debian|buntu|mint' /etc/*release)" ]]; then
    wget https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-7.17.10-amd64.deb
    sudo dpkg -i elasticsearch-7.17.10-amd64.deb
  elif [[ "$(grep -Ei 'centos|redhat' /etc/*release)" ]]; then
    wget https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-7.17.10-x86_64.rpm
    sudo rpm --install elasticsearch-7.17.10-x86_64.rpm
  else
    echo "Unsupported operating system"
    exit 1
  fi
fi

#sudo systemctl enable opensearch
#sudo systemctl start opensearch

