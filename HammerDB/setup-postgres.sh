#!/bin/bash

sudo apt update
sudo apt install postgresql postgresql-contrib -y

VERSION=$(psql --version | awk '{print $NF}' | awk -F. '{print $1}')
PG_HBA_FILE="/etc/postgresql/$POSTGRES_VERSION/main/pg_hba.conf"
sudo sed -i "s/peer/md5/" "$PG_HBA_FILE"

sudo systemctl start postgresql.service
sudo systemctl enable postgresql.service