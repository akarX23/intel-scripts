#!/bin/bash

export http_proxy="http://proxy01.iind.intel.com:911/"
export https_proxy="http://proxy01.iind.intel.com:912/"
export ftp_proxy="ftp://proxy-us.intel.com:911/"
export no_proxy="127.0.0.1,localhost"

# For curl
export HTTP_PROXY="http://proxy01.iind.intel.com:911/"
export HTTPS_PROXY="http://proxy01.iind.intel.com:912/"
export FTP_PROXY="ftp://proxy-us.intel.com:911/"
export NO_PROXY="127.0.0.1,localhost"

DEB_FILE="opensearch-2.6.0-linux-x64.deb"

if [ ! -f "$DEB_FILE" ]; then
  wget https://artifacts.elastic.co/downloads/elasticsearch/opensearch-2.6.0-linux-x64.deb
  sudo dpkg -i opensearch-2.6.0-linux-x64.deb
fi

#sudo systemctl enable opensearch
#sudo systemctl start opensearch

