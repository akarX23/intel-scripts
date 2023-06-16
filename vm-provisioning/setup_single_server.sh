#!/bin/bash

USER=ubuntu

while getopts ":u:" opt; do
    case $opt in
        u) USER=$OPTARG
        ;;
        \?) echo "Invalid option -$OPTARG" >&2
        ;;
    esac
done    

cat <<EOT >> /etc/profile.d/proxy_setup.sh

export http_proxy="http://proxy01.iind.intel.com:911/"
export https_proxy="http://proxy01.iind.intel.com:912/"
export ftp_proxy="ftp://proxy-us.intel.com:911/"
export no_proxy="127.0.0.1,localhost"

# For curl
export HTTP_PROXY="http://proxy01.iind.intel.com:911/"
export HTTPS_PROXY="http://proxy01.iind.intel.com:912/"
export FTP_PROXY="ftp://proxy-us.intel.com:911/"
export NO_PROXY=\$no_proxy

EOT

cat <<EOT >> /etc/apt/apt.conf.d/80proxy

Acquire::http::proxy "http://proxy01.iind.intel.com:911/";
Acquire::https::proxy "http://proxy01.iind.intel.com:912/";
Acquire::ftp::proxy "ftp://proxy-us.intel.com:911/";

EOT

echo "source /etc/profile.d/proxy_setup.sh" >> /root/.bashrc
echo "${USER} ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers