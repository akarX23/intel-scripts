# NGINX Benchmarking setup
## NGINX
NGINX is a popular open-source web server and reverse proxy server known for its high performance, scalability, and versatility. Originally created to address the C10k problem, NGINX efficiently handles concurrent connections and delivers static content swiftly. Its event-driven architecture and asynchronous processing enable it to handle thousands of simultaneous requests efficiently. NGINX is widely used as a load balancer, caching server, and SSL/TLS terminator, enhancing the performance and security of web applications. It supports various protocols like HTTP, HTTPS, TCP, and UDP, making it suitable for diverse use cases. NGINX's modular design, rich feature set, and extensive documentation contribute to its widespread adoption by developers and system administrators worldwide. Read More [here](https://www.freecodecamp.org/news/an-introduction-to-nginx-for-developers-62179b6a458f/).
## Benchmarking  Setup
The benchmarking setup is very simple. We have 5 files with sizes 100KB, 256KB, 750KB, 1MB, and 5 MB. We have these stored on the same system as NGINX. They are being served at different endpoints on NGINX, *eg: http://localhost/100KB*. We then use a tool called **wrk** which is a linux based utility. 
> wrk is a powerful benchmarking tool used to measure the performance and throughput of web servers. It supports high concurrency, making it suitable for stress testing and load balancing analysis. With its simple command-line interface and Lua scripting capabilities, wrk allows developers to simulate realistic workloads and analyze server responses, aiding in performance optimization.

To install wrk just follow these instructions for Ubuntu 20.04:
```
# Install unzip
sudo apt install unzip

# Install wrk
sudo apt-get install build-essential libssl-dev git -y
git clone https://github.com/wg/wrk.git wrk 
cd wrk 
sudo make
sudo cp wrk /usr/local/bin 
```
### Install NGINX
First clone the repository:
```
git clone https://github.com/akarX23/intel-scripts
cd intel-scripts/nginx
```

We have a script that will install nginx on your system and configure it to serve the different workloads. Before executing the script edit the `nginx.conf` file and edit the path for each endpoint to be the same as the workloads directory in your system. The workloads are downloaded when you clone this repo, available at `nginx/workloads`.

Now install nginx:
```
sudo chmod 400 setup.sh run-all.sh run-wrk.sh
./setup --install-nginx --update-nginx
```

Test with `wget http://localhost/100KB`
#### Run the benchmark
```
./run-all.sh --duration 30 --server http://localhost
```
