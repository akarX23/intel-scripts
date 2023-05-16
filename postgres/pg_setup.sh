#!/bin/bash

# Default values
default_username="admin"
default_password="admin"
username="$default_username"
password="$default_password"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        --admin-name)
            username="$2"
            shift
            shift
            ;;
        --admin-password)
            password="$2"
            shift
            shift
            ;;
        *)
            echo "Invalid argument: $1"
            exit 1
            ;;
    esac
done

# Check if username and password are default
if [[ $username == $default_username ]] && [[ $password == $default_password ]]; then
    echo "No admin name and password provided. Default username and password will be used."
fi

# Update system packages
sudo apt update -y
sudo apt upgrade -y

# Install PostgreSQL
sudo apt install postgresql postgresql-contrib -y

# Start and enable PostgreSQL
sudo service postgresql start
sudo service postgresql enable

# Determine PostgreSQL version
version=$(pg_lsclusters -h | awk '{print $1}')

# Modify pg_hba.conf to use md5 authentication for postgres user
sudo sed -i "s/local[[:space:]]\+all[[:space:]]\+postgres[[:space:]]\+peer/local all postgres md5/" /etc/postgresql/$version/main/pg_hba.conf

# Restart PostgreSQL
sudo systemctl restart postgresql

# Connect to PostgreSQL and create user and database
sudo -u postgres psql -c "CREATE USER $username WITH PASSWORD '$password';"
sudo -u postgres psql -c "CREATE DATABASE $username;"
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE $username TO $username;"

# Exit the PostgreSQL prompt
sudo -u postgres psql -c "\q"

echo "PostgreSQL installation and setup completed!"