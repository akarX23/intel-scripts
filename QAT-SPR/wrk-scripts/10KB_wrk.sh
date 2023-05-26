#!/bin/bash
ulimit -n 655350

http_proxy= https_proxy= wrk \
 -t 56 \
 -c 3100 \
 -d 120s \
 -s /home/cdn/wrk/scripts/10KB_query.lua \
 -H "Connection: keep-alive" \
 --timeout 10s \
 -L \
 https://localhost:443
