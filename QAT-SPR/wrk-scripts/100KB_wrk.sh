#!/bin/bash

http_proxy= https_proxy= wrk \
 -t 56 \
 -c 6200 \
 -d 120s \
 -s /home/cdn/wrk/scripts/100KB_query.lua \
 -H "Connection: keep-alive" \
 --timeout 10s \
 -L \
 https://localhost:443
