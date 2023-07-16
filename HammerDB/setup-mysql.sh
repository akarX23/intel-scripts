#!/bin/bash

sudo apt update 
sudo apt install mysql-server -y
sudo systemctl start mysql.service
sudo systemctl enable mysql.service