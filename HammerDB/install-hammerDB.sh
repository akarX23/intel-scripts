#!/bin/bash

wget https://github.com/TPC-Council/HammerDB/releases/download/v4.8/HammerDB-4.8-Linux.tar.gz
tar -zxvf HammerDB-4.8-Linux.tar.gz 
cd HammerDB-4.1
sudo apt-get update 
sudo apt-get install libmysqlclient21 -y