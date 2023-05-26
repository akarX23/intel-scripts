# Setup of QAT and Softwares
This guide will server as a single document for installation and setup of Intel QAT Drivers and their usage with libraries like **openssl, NGINX, and HA Proxy**. We will be only going through the steps for the **Hardware Installation** of QAT. Our system has an **Intel® Xeon® Scalable Processor family with Intel® QAT Gen4/Gen4m** which requires **Hardware v2.0** and the OS is **Ubuntu 22.04**.

## Requirements to smoothly run this guide
- Hardware - **Intel® Xeon® Scalable Processor family with Intel® QAT Gen4/Gen4m**
- OS - **Ubuntu 22.04**

## Assumptions
- BIOS is already configured for the QAT Chip
- **apt** has been configured with any **required proxies**
- Git installed

More info about pre-requisites and installation can be found [here](https://cdrdv2.intel.com/v1/dl/getContent/632506).
## Steps we will be performing in this guide
- Install Intel QAT Driver - This is the main service that will be used by other softwares
- Install Intel QAT Engine for OpenSSL
- Install QATzip for accelaration of compression and decompression
- Install the Intel version of NGINX which is compatible with QAT Accelaration for Encryption, Decryption and Compression, Decompression.
- Install HA Proxy with QAT Accelaration

### Install the QAT Driver
Before installing, we need to create a working directory where the QAT Driver files will be stored. For this guide we will use `/QAT-Driver`. Now download the latest QAT driver from Intel [here](https://www.intel.com/content/www/us/en/download/765501/intel-quickassist-technology-driver-for-linux-hw-version-2-0.html). Move the `.tar` file into the working directory.

Use the `qat-driver.sh` script to setup QAT accelaration for your system:
```
./qat-driver.sh --qat-driver-dir /QAT-Driver
```
Verify the acceleration software kernel objects are loaded and ready to use with this command:
```
lsmod | grep qat

# Ouput - can vary depending on your specific hardware
qat_4xxx 45056 0
intel_qat 331776 2 qat_4xxx,usdm_drv
uio 20480 1 intel_qat
mdev 20480 2 intel_qat,vfio_mdev
vfio 36864 3 intel_qat,vfio_mdev,vfio_iommu_type1
irqbypass 16384 2 intel_qat,kvm
```
Start the QAT Driver service:
```
service qat_service start
```
The configuration files are located at `/etc` directory. The name for the first configuration file for **Intel® QuickAssist Technology Hardware Version 2.0** devices is `4xxx_dev0.conf`. Depending on the number of devices you can have multiple files.

You can check how many devices you have:
```
service qat_service status

# Output
Apr 24 20:59:52 spr-251 systemd[1]: Starting LSB: modprobe the QAT modules, which loads dependant modules, before calling the user s
Apr 24 20:59:52 spr-251 qat_service[53589]: Restarting all devices.
Apr 24 20:59:52 spr-251 qat_service[53589]: Processing /etc/4xxx_dev0.conf
Apr 24 20:59:53 spr-251 qat_service[53589]: Processing /etc/4xxx_dev1.conf
Apr 24 20:59:54 spr-251 qat_service[53602]: Checking status of all devices.
Apr 24 20:59:54 spr-251 qat_service[53602]: There is 2 QAT acceleration device(s) in the system:
Apr 24 20:59:54 spr-251 qat_service[53602]:  qat_dev0 - type: 4xxx,  inst_id: 0,  node_id: 0,  bsf: 0000:6b:00.0,  #accel: 1 #engine
Apr 24 20:59:54 spr-251 qat_service[53602]:  qat_dev1 - type: 4xxx,  inst_id: 1,  node_id: 1,  bsf: 0000:e8:00.0,  #accel: 1 #engine
```
As you can see, I have 2 QAT accelaration devices
#### Uninstalling the driver
```
./qat-driver.sh --qat-driver-dir /QAT-Driver --uninstall
```
### Install QAT Engine for OpenSSL
More detailed steps and information can be found [here](https://github.com/intel/QAT_Engine).

#### Pre-requisites
- Intel QAT Driver to be installed using the above steps.
- Install **OpenSSL 3.0**. This can be installed using the `install-openssl.sh` script. You can use it in this way:
```
sudo ./install-openssl.sh --git-dir ./openssl-git --install-dir /Openssl
```
- `--git-dir` - Location where you want the GitHub source code to be.
- `--install-dir` - Location where the build files will be installed.

**Note**: QAT Engine requires you to have Openssl 3.0. The above script clones the Openssl source code and uses the Openssl 3.0 branch to install.

#### Installing the QAT Engine
Execute the script `qat-engine.sh` provided like this:
```
sudo ./qat-engine.sh --qat-driver-dir /QAT-Driver --openssl-dir /Openssl
```
- `--qat-driver-dir` - Directory where you installed the QAT Driver above.
- `--openssl-dir` - Directory where the Openssl build files are stored.
- 
The QAT Engine uses a different configuration for the QAT Driver. This is located at `/path/to/qat_engine/qat_hw_config`. You would need to do an extra step which is described [here](https://github.com/intel/QAT_Engine#copy-the-intel-quickassist-technology-driver-config-files-for-qat_hw).

If you already had a version of OpenSSL previously installed then before testing OpenSSL with QAT Engine you might need to execute 
`export LD_LIBRARY_PATH=$OPENSSL_INSTALL_DIR/lib64` to tell OpenSSL to use the new engines. 

#### Testing the QAT Engine
To verify if the engine works, execute this:
```
cd /path/to/openssl_install/bin
./openssl engine -t -c -v qatengine

#Output
(qatengine) Reference implementation of QAT crypto engine(qat_hw) <qatengine version>
 [RSA, DSA, DH, AES-128-CBC-HMAC-SHA1, AES-128-CBC-HMAC-SHA256,
 AES-256-CBC-HMAC-SHA1, AES-256-CBC-HMAC-SHA256, TLS1-PRF, HKDF, X25519, X448]
    [ available ]
    ENABLE_EXTERNAL_POLLING, POLL, SET_INSTANCE_FOR_THREAD,
    GET_NUM_OP_RETRIES, SET_MAX_RETRY_COUNT, SET_INTERNAL_POLL_INTERVAL,
    GET_EXTERNAL_POLLING_FD, ENABLE_EVENT_DRIVEN_POLLING_MODE,
    GET_NUM_CRYPTO_INSTANCES, DISABLE_EVENT_DRIVEN_POLLING_MODE,
    SET_EPOLL_TIMEOUT, SET_CRYPTO_SMALL_PACKET_OFFLOAD_THRESHOLD,
    ENABLE_INLINE_POLLING, ENABLE_HEURISTIC_POLLING,
    GET_NUM_REQUESTS_IN_FLIGHT, INIT_ENGINE, SET_CONFIGURATION_SECTION_NAME,
    ENABLE_SW_FALLBACK, HEARTBEAT_POLL, DISABLE_QAT_OFFLOAD
```
You can also test the speed utility:
```
./openssl speed -engine qatengine -elapsed -async_jobs 72 rsa2048
```
If you execute the same command without the `-engine qatengine`, you will see the vast difference in performance.

### Install QATzip for OpenSSL
To install QATzip just execute the script `qat-zip.sh` like this:
```
sudo ./qat-zip.sh --qat-driver-dir /QAT-Driver --git-dir /home/username/QAT-Scripts/QATzip
```
Substitute the paths according to your preference.

Read about the installation in detail [here](https://github.com/intel/QATzip#build-intel-quickassist-technology-driver).

#### Updating the QATzip configuration file for QAT Driver
In order to use the `qzip` utility with the QAT Engine, you would need some configuration in the `4xxx_dev.conf` file in `/etc`. 

To update the configuration file, copy the configure file(s) from directory of  `$QZ_ROOT/config_file/$YOUR_PLATFORM/$CONFIG_TYPE/*.conf`  to directory of  `/etc`

`$QZ_ROOT`: The directory which you passed as `--git-dir`

`YOUR_PLATFORM`: the QAT hardware platform, c6xx for Intel® C62X Series Chipset, dh895xcc for Intel® Communications Chipset 8925 to 8955 Series, 4xx for Intel® QAT Gen4/Gen4m

`CONFIG_TYPE`: tuned configure file(s) for different usage,  `multiple_process_opt`  for multiple process optimization,  `multiple_thread_opt`  for multiple thread optimization.

### Install NGINX with QAT support
NGINX with QAT is available as a separate [GitHub Repo](https://github.com/intel/asynch_mode_nginx) which needs to built and compiled for using QAT Engine with NGINX. 

One step command is to execute the script `nginx-qat.sh`. Make sure you have atleast **QAT Driver, QAT Engine and OpenSSL 3.0** installed. Then execute the script like this:
```
./nginx-qat.sh --qat-driver-dir /QAT-Driver --nginx-install-dir /Nginx --openssl-dir /Openssl --qzip-dir /home/username/QATzip --git-dir ./NGINX-QAT
```
- `--qzip-dir`: The directory where QATzip was extracted. This option is not required if you don't want to use accelarated compression and decompression. 
- `--qat-driver-dir`: Installation path of QAT Driver
- `--nginx-install-dir`: Path where you want the Nginx build files
- `--openssl-dir`: Path where the OpenSSL build files exist
- `--git-dir`: Path where you want to clone the Nginx QAT repository

To test if NGINX is working, execute `curl http://localhost` and you should get the NGINX welcome page as a response. 

#### Configuring NGINX to use QAT
Till now we have installed NGINX and setup the QAT Engine modules but we haven't actually used the QAT Engine. You NGINX configuration lives in the `--nginx-install-dir` which in our case is `/Nginx`.

The `nginx` binary lives in `/Nginx/sbin` directory. The default configuration file being used is `/Nginx/conf/nginx.conf`. We will change this file to use the QAT Engine. Delete this file and create a new `nginx.conf` with this content:

```
user  root;
worker_processes  auto;
load_module /Nginx/modules/ngx_ssl_engine_qat_module.so;

events {
    worker_connections  1024;
    accept_mutex off;
    use epoll;
}

ssl_engine {
    use_engine qatengine;
    default_algorithms RSA,EC,DH,DSA;
    qat_engine {
        qat_offload_mode async;
        qat_notify_mode poll;
        qat_poll_mode heuristic;
#        qat_sw_fallback on;
    }
}

http {
    include       mime.types;
    default_type  application/octet-stream;
    sendfile        on;
    keepalive_timeout  65;

    server {
        listen       80;
        server_name  localhost;
        location / {
            root   html;
            index  index.html index.htm;
        }

        error_page   500 502 503 504  /50x.html;
        location = /50x.html {
            root   html;
        }
    }

ssl_asynch  on;
    # HTTPS server with async mode.
    server {
        #If QAT Engine enabled,  `asynch` need to add to `listen` directive or just add `ssl_asynch  on;` to the context.
        listen       443 ssl;
        server_name  localhost;

        ssl_protocols       TLSv1.3;
        ssl_certificate      /Nginx/ssl/test.crt;
        ssl_certificate_key  /Nginx/ssl/test.key;

        location / {
            root   html;
            index  index.html index.htm;
        }
    }
}
```
As you can see we initialize the QAT Engine with NGINX so that all encryption and decryption is offloaded to the QAT. We have setup an https endpoint with the certificates in `/Nginx/ssl`. Before we reload nginx we need to create these certificates. 
```
mkdir /Nginx/ssl
openssl req -x509 -sha256 -nodes -days 365 -newkey rsa:2048 -keyout /Nginx/ssl/test.key -out /Nginx/ssl/test.crt
```
Now reload nginx:
```
/Nginx/sbin/nginx -s reload
```
Now test if our setup works:
```
# HTTP
curl localhost

# HTTPS
curl -k https://localhost:443

# Certificate info
openssl s_client -showcerts -connect localhost:443
```
To see if QAT is actually being used, do `cat /sys/kernel/debug/qat_4xxx_0000:6b:00.0/fw_counters`. This will display some number which will rise each time you use the QAT driver.

## Benchmarking NGINX
We use [wrk](https://github.com/wg/wrk/tree/master) to benchmark NGINX. There will be some configuration changes in the QAT Driver and NGINX. 

### QAT Configuration
For both the QAT devices in my system, the configuration files - `/etc/4xxx_dev0.conf` and `/etc/4xxx_dev1.conf` have the `SHIM` section setup like this:
```
[SHIM]
NumberCyInstances = 1
NumberDcInstances = 0
NumProcesses = 32
LimitDevAccess = 1
```
`NumProcesses` should be as high as possible. In my case I get error as soon as I increase it beyond 32. It's an issue I have yet to fix. Also the number of `worker_processes` in the NGINX configuration should be half of this number.

### NGINX Configuration
The number of worker processes are **16**. The `/Nginx/conf/nginx.conf` looks like this:
```
 #user  root;
worker_processes  16;

load_module modules/ngx_ssl_engine_qat_module.so;

events {
    use epoll;
    worker_connections 8192;
    accept_mutex off;
}

ssl_engine {
    use_engine qatengine;
    default_algorithms RSA,EC,DH,DSA;
    qat_engine {
        qat_offload_mode async;
        qat_notify_mode poll;
        qat_poll_mode heuristic;
#        qat_sw_fallback on;
    }
}

http {
    include       mime.types;
    default_type  application/octet-stream;

    #log_format  main  '$remote_addr - $remote_user [$time_local] "$request" '
    #                  '$status $body_bytes_sent "$http_referer" '
    #                  '"$http_user_agent" "$http_x_forwarded_for"';

    #access_log  logs/access.log  main;

    sendfile        on;
    #tcp_nopush     on;

    #keepalive_timeout  0;
    keepalive_timeout  65;

    gzip  on;
    gzip_min_length     128;
    gzip_comp_level     1;
    gzip_types  text/css text/javascript text/xml text/plain text/x-component application/javascript application/json application/xml application/rss+xml font/truetype font/opentype application/vnd.ms-fontobject image/svg+xml;
    gzip_vary            on;
    gzip_disable        "msie6";
    gzip_http_version   1.0;

    server {
        listen       80;
        server_name  localhost;

        #charset koi8-r;

        #access_log  logs/host.access.log  main;

        location / {
            root   html;
            index  index.html index.htm;
        }

        #error_page  404              /404.html;

        # redirect server error pages to the static page /50x.html
        #
        error_page   500 502 503 504  /50x.html;
        location = /50x.html {
            root   html;
        }
    }
    
    server {
        #If QAT Engine enabled,  `asynch` need to add to `listen` directive or just add `ssl_asynch  on;` to the context.
        listen       443 ssl asynch;
        server_name  localhost;

        ssl_protocols       TLSv1.3;
        ssl_certificate      /Nginx/ssl/test.crt;
        ssl_certificate_key  /Nginx/ssl/test.key;
        
        location / {
            root   html;
            index  index.html index.htm;
        }
    }
}
```
When I execute `curl -k https://localhost:443` I am able to get the NGINX welcome page. Also each time the endpoint is accessed the value in `/sys/kernel/debug/qat_4xxx_0000:6b:00.0/fw_counters` goes up which means that traffic is being offloaded to QAT.

### Benchmarking Process
We will use `wrk` and some lua scripts to generate the load for benchmarking. The scripts are located in the `QAT-SPR/wrk-scripts` folder. Install `wrk` with these commands:
```
git clone https://github.com/wg/wrk
cd wrk
make
cp ./wrk /usr/local/bin
```
Once you have NGINX up and running and working with QAT, execute these commands as root:
```
cd QAT-SPR/wrk-scripts
chmod +x ./run-wrk.sh
./run-wrk.sh --server localhost:443 --size 10KB --with-qat
./run-wrk.sh --server localhost:443 --size 100KB --with-qat
./run-wrk.sh --server localhost:443 --size 1MB --with-qat
```
Once these execute one by one, you will logs in the `logs` folder. You can check the wrk logs for useful information such as **requests per second** and **data transferred**. 

Now to compare these logs with an unaccelarated NGINX, we can remove the `qat_engine` configuration in the `nginx.conf` file. The new file looks like this:
```
 #user  root;
worker_processes  16;

load_module modules/ngx_ssl_engine_qat_module.so;

events {
    #use epoll;
    worker_connections 8192;
    #accept_mutex off;
}


http {
    include       mime.types;
    default_type  application/octet-stream;

    #log_format  main  '$remote_addr - $remote_user [$time_local] "$request" '
    #                  '$status $body_bytes_sent "$http_referer" '
    #                  '"$http_user_agent" "$http_x_forwarded_for"';

    #access_log  logs/access.log  main;

    sendfile        on;
    #tcp_nopush     on;

    #keepalive_timeout  0;
    keepalive_timeout  65;

    gzip  on;
    gzip_min_length     128;
    gzip_comp_level     1;
    gzip_types  text/css text/javascript text/xml text/plain text/x-component application/javascript application/json application/xml application/rss+xml font/truetype font/opentype application/vnd.ms-fontobject image/svg+xml;
    gzip_vary            on;
    gzip_disable        "msie6";
    gzip_http_version   1.0;

    server {
        listen       80;
        server_name  localhost;

        location / {
            root   html;
            index  index.html index.htm;
        }
        
        error_page   500 502 503 504  /50x.html;
        location = /50x.html {
            root   html;
        }
    }
    
    server {
        listen       443 ssl;
        server_name  localhost;

        ssl_protocols       TLSv1.3;
        ssl_certificate      /Nginx/ssl/test.crt;
        ssl_certificate_key  /Nginx/ssl/test.key;
        
        location / {
            root   html;
            index  index.html index.htm;
        }
    }
}
```
Now run `/Nginx/sbin/nginx -s reload`. Now run the above wrk commands but without the `--with-qat` option:
```
./run-wrk.sh --server localhost:443 --size 10KB
./run-wrk.sh --server localhost:443 --size 100KB
./run-wrk.sh --server localhost:443 --size 1MB
```
You will have similar new log files like before. 

You can compare these logs to measure how well the benchmark performed. You can also check `cat /sys/kernel/debug/qat_4xxx_0000:6b:00.0/fw_counters` to see how much QAT was used.

## Command Cheatsheet
- Check status of qat service: `service qat_service status`
- Restart qat service: `service qat_service restart`
- Check if qat modules are loaded: `lsmod | grep "qa"`
- Check how much QAT is being utilized: 
`cat /sys/kernel/debug/qat_4xxx_0000:6b:00.0/fw_counters`
- Start NGINX server: `<NGINX install dir>/sbin/nginx` 
- Reload NGINX with new configuration: `<NGINX install dir>/sbin/nginx -s reload` 

## Existing Issues
Issues I am facing are:
- I haven't been able to use QAT Engine and QATzip together. They both require some special configuration and they both provide one configuration file which is the `4xxx_dev0.conf` file. This file is responsible for configuring the QAT Driver. I haven't beel able to compile a file that can work for both. Currently I am only able to make one of these work at a time by using their configuration file.

## Doubts
- I am not sure whether the parameters to the `wrk` client are wrong or there is some problem with the configuration because the QAT offload is definitely happening but it's not enough for some reason.
- When I increase the value of `NumProcesses` in the `[SHIM]` seciton of the QAT configuration file, it fails to load QAT. I am not able to find clear information about this.
