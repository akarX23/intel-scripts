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

http_proxy="http://proxy01.iind.intel.com:911/"
https_proxy="http://proxy01.iind.intel.com:912/"
ftp_proxy="ftp://proxy-us.intel.com:911/"
no_proxy="127.0.0.1,localhost"

cat <<EOT >> /etc/profile.d/proxy_setup.sh

export http_proxy="$http_proxy"
export https_proxy="$https_proxy"
export ftp_proxy="$ftp_proxy"
export no_proxy="$no_proxy"

# For curl
export HTTP_PROXY="$http_proxy"
export HTTPS_PROXY="$https_proxy"
export FTP_PROXY="$ftp_proxy"
export NO_PROXY="$no_proxy"

EOT

cat <<EOT >> /etc/apt/apt.conf.d/80proxy

Acquire::http::proxy "$http_proxy";
Acquire::https::proxy "$https_proxy";
Acquire::ftp::proxy "$ftp_proxy";

EOT

echo "source /etc/profile.d/proxy_setup.sh" >> /root/.bashrc
echo "${USER} ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers