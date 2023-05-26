#!/bin/bash

ulimit -n 655350

http_proxy= https_proxy= wrk \
 -t 56 \
 -c 30700 \
 -d 120s \
 -s ./1MB_query.lua \
 -H "Connection: keep-alive" \
 --timeout 4s \
 -L \
 https://localhost:443

