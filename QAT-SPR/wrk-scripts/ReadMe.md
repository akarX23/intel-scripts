# Major Project Commands
All the following commands are in memory. After you access the jump server, perform these commands:
```
# Access the SPR Server
ssh akarx@192.168.50.197

# Switch user
sudo su
zsh

# QAT devices status
service qat_service status

# location of conf files and how to display:
ls /etc | grep 4xx

# Status of QAT with openssl
openssl engine -t -c -v qatengine

# Speed test without QAT
openssl speed -seconds 5 -elapsed -async_jobs 72 rsa2048

# Speed test with QAT
openssl speed -engine qatengine -seconds 5 -elapsed -async_jobs 72 rsa2048

# Change to NGINX directory
cd /home/akarx/QAT-installs/NGINX/install

# Start NGINX
./sbin/nginx

# Status of all CPUs in separate terminal
htop
(Press f4 then type nginx to show the NGINX processes)

# Show that NGINX is serving HTTPS on port 443
openssl s_client -connect localhost:443 -servername localhost

# Print the NGINX with QAT configuration file
cat conf/nginx.conf.qat

# Change to the WRK scripts directory
cd /home/akarx/intel-scripts/QAT-SPR/wrk-scripts

# Print contents of a file (run-wrk.sh):
cat run-wrk.sh

# Run the NGINX benchmark
./run-all.sh --server localhost:443 --duration 5 --nginx-bin-path /home/akarx/QAT-installs/NGINX/install/sbin/nginx --nginx-wqat-conf-path /home/akarx/QAT-installs/NGINX/install/conf/nginx.conf.bak --nginx-qat-conf-path /home/akarx/QAT-installs/NGINX/install/conf/nginx.conf.qat

# Run one workload
./run-wrk.sh --server localhost:443 --size 100KB --duration 5 --with-qat

# Print results for test run
./summarise.sh

# Print results for 15 mins benchmark
./summarise.sh prod-logs/
```
