# for APT
#!/bin/bash

cat <<EOT >> /etc/apt/apt.conf.d/80proxy

Acquire::http::proxy "http://proxy01.iind.intel.com:911/";
Acquire::https::proxy "http://proxy01.iind.intel.com:912/";
Acquire::ftp::proxy "ftp://proxy-us.intel.com:911/";

EOT