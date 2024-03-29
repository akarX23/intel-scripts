# Instructions to Benchmark QAT workloads on spr197

## Initial steps

- Login to the JumpServer
- Login to spr197 machine
- switch to _root_ user with `sudo su`
- change to the scripts directory: `cd /home/benchmark/QAT-SPR`

## OpenSSL Benchmarking

Then scripts for OpenSSL run the speed test with 2 different configurations , one which uses the QAT Engine and one without QAT. The speed test is an official utility of the `openssl` CLI which can be used to generate a very high number of bits for different algorithms and different key sizes. In our case we use the RSA algorithm with the key size as 2048 bits. This performs multiple private and public key operations. The script prints the percentage improvement gained by using QAT vs Without QAT.

After performing the initial steps above, execute the script: `./openssl-speed.sh <duration in seconds>`

Sample run:

```
# Execute script
./openssl-speed.sh 10

# Output
---------------------------------------------
Running OpenSSL Speed with QAT
---------------------------------------------
Engine "qatengine" set.
You have chosen to measure elapsed time instead of user CPU time.
Doing 2048 bits private rsa's for 3s: 58180 2048 bits private RSA's in 3.00s
Doing 2048 bits public rsa's for 3s: 779954 2048 bits public RSA's in 3.00s

---------------------------------------------
Running OpenSSL Speed without QAT
---------------------------------------------
You have chosen to measure elapsed time instead of user CPU time.
Doing 2048 bits private rsa's for 3s: 7766 2048 bits private RSA's in 3.00s
Doing 2048 bits public rsa's for 3s: 158630 2048 bits public RSA's in 3.00s


Operating System: Ubuntu 22.04.2 LTS
Kernel Version: Linux 5.15.0-72-generic
OpenSSL Version: OpenSSL 3.0.9-dev
Number of QAT Devices: 2
CPU: Intel(R) Xeon(R) Platinum 8480+

+-----------------------------------------------------+
|            Test |        Verify/s |          Sign/s |
+-----------------------------------------------------+
|        With QAT |        259984.7 |         19393.3 |
|          No QAT |         52876.7 |          2588.7 |
|  Percent Change |       +391.681% |       +649.152% |
+-----------------------------------------------------+
```

## NGINX Benchmarking

NGINX is a web server software which is widely used to serve files and as a reverse proxy. It uses a configuration file which contains all the ports on which NGINX has to listen on. This file also defines what the ports will server and also whether the port servers SSL traffic.

QAT is used for speeding up the SSL traffic as it involves a lot of encryption and decryption in the background. In our benchmark configuration we have configured NGINX to listen on port _443_ where it serves SSL traffic using self-signed certificates. 5 different _location_ blocks have been defined which server files of 5 sizes - 100KB, 256KB, 750KB, 1MB, and 5MB. NGINX will serve these files at `https://localhost:443/100KB` and so on. Whenever request is made to these endpoints, all these files will be encrypted and sent. This encryption is what we aim to speed up using QAT.

QAT involves offloading operations from the CPU. This off-loading involves its own overhead. Due to this if data comes in small packets to the CPU, there will be a lot of off-loading required which will result in a negative improvement of performance. This is the reason we have files with different sizes being served by NGINX.

The benchmarking script uses **wrk** client to load test _localhost:443_ using one file size one after the other. We have 2 NGINX configuration files, one has QAT enabled while other does not. The rest of the configuration remains same for both the files. The benchmarking script changes the NGINX configuration file and does the benchmark for both configurations. In the end we get results for all the runs tabulated along with **percent change in performance based on the total data transferred**.

Perform the initial steps above and perform these steps:

```
# Change to script directory
cd /home/benchmark/QAT-SPR/wrk-scripts

# Run the script
./run-all.sh --duration 5 --workloads 100KB,256KB,750KB,1MB
```

You can change the `--duration` parameter according to requirement, the rest should be kept same.

This script will generate logs in the `logs` directory. To see the summarised table again for the previously generated logs execute `./summarise.sh`.

These benchmarks should normally be run for a longer time to get a better understanding of the metrics. You can see the logs for a long benchmark in `/home/akarx/intel-scripts/QAT-SPR/wrk-scripts/prod-logs`. To put these logs in tabular format, you can use `./summarise.sh --log-dir prod-logs`.

Sample run:

```
+-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| Workload |                      Type |    Threads |   Connections |   Duration |       Total Requests | Requests/s |  Total Data Transfer | Transfer/s |   99% Latency |  Max Req/s |    % Change in Throughput |
+-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
|      1MB |               QAT Enabled |         24 |           350 |         5m |              5474942 |   18245.94 |               5.22TB |    17.82GB |       10.13ms |      1.05k |                    +38.00 |
|      1MB |              QAT Disabled |         24 |           350 |         5m |              3949612 |   13161.01 |               3.77TB |    12.86GB |       13.04ms |      1.05k |                         - |
|    750KB |               QAT Enabled |         28 |           300 |         5m |              6358941 |   21189.44 |               4.44TB |    15.16GB |        7.86ms |      1.22k |                    +46.00 |
|    750KB |              QAT Disabled |         28 |           300 |         5m |              4336769 |   14451.09 |               3.03TB |    10.34GB |        9.39ms |      1.10k |                         - |
|    256KB |               QAT Enabled |         28 |           350 |         5m |             11692082 |   38965.17 |               2.79TB |     9.53GB |        4.88ms |      1.90k |                    +84.00 |
|    256KB |              QAT Disabled |         28 |           350 |         5m |              6321013 |   21062.98 |               1.51TB |     5.15GB |        5.21ms |      1.18k |                         - |
|    100KB |               QAT Enabled |         28 |           300 |         5m |             11695910 |   38974.46 |               1.09TB |     3.73GB |        2.68ms |      1.83k |                    +58.00 |
|    100KB |              QAT Disabled |         28 |           300 |         5m |              7353676 |   24504.44 |             703.70GB |     2.34GB |        2.86ms |      2.22k |                         - |
+-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
```
