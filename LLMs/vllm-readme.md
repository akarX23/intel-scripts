# vLLM Benchmarking Procedure - Xeons
The procedure is broadly divided into 4 steps:
- Getting Server Details
- Making sure the BIOS is correctly setup
- Configuring docker
- Building vLLM image for Xeons
- Run the benchmark script with **Tensor Parallelism**
- Run the benchmark setup with **Load Balancing**

## Server Details
To get the server hardware details, just run the command: **`lscpu`**
Here is a sample output:
```
Architecture:             x86_64
  CPU op-mode(s):         32-bit, 64-bit
  Address sizes:          52 bits physical, 57 bits virtual
  Byte Order:             Little Endian
CPU(s):                   288
  On-line CPU(s) list:    0-287
Vendor ID:                GenuineIntel
  Model name:             GENUINE INTEL(R) XEON(R)
    CPU family:           6
    Model:                173
    Thread(s) per core:   2
    Core(s) per socket:   72
    Socket(s):            2
    Stepping:             1
    CPU(s) scaling MHz:   21%
    CPU max MHz:          3900.0000
    CPU min MHz:          800.0000
    BogoMIPS:             5600.00
    Flags:                fpu vme de pse tsc msr pae mce cx8 apic sep mtrr pge mca cmov pat pse36 clflush amx_bf16 avx512_fp16 amx_t ile amx_int8 flush_l1d arch_capabilities
Virtualization features:
  Virtualization:         VT-x
Caches (sum of all):
  L1d:                    6.8 MiB (144 instances)
  L1i:                    9 MiB (144 instances)
  L2:                     288 MiB (144 instances)
  L3:                     864 MiB (2 instances)
NUMA:
  NUMA node(s):           6
  NUMA node0 CPU(s):      0-23,144-167
  NUMA node1 CPU(s):      24-47,168-191
  NUMA node2 CPU(s):      48-71,192-215
  NUMA node3 CPU(s):      72-95,216-239
  NUMA node4 CPU(s):      96-119,240-263
  NUMA node5 CPU(s):      120-143,264-287
Vulnerabilities:
  Gather data sampling:   Not affected
  Itlb multihit:          Not affected
  L1tf:                   Not affected
  Mds:                    Not affected
  Meltdown:               Not affected
  Mmio stale data:        Not affected
  Reg file data sampling: Not affected
  Retbleed:               Not affected
  Spec rstack overflow:   Not affected
  Spec store bypass:      Mitigation; Speculative Store Bypass disabled via prctl
  Spectre v1:             Mitigation; usercopy/swapgs barriers and __user pointer sanitization
  Spectre v2:             Mitigation; Enhanced / Automatic IBRS; IBPB conditional; RSB filling; PBRSB-eIBRS Not affected; BHI BHI_DIS_S
  Srbds:                  Not affected
  Tsx async abort:        Not affected
``` 
The important information here that should be noted for our procedure is the NUMA Node configuration:
```
NUMA:
  NUMA node(s):           6
  NUMA node0 CPU(s):      0-23,144-167
  NUMA node1 CPU(s):      24-47,168-191
  NUMA node2 CPU(s):      48-71,192-215
  NUMA node3 CPU(s):      72-95,216-239
  NUMA node4 CPU(s):      96-119,240-263
  NUMA node5 CPU(s):      120-143,264-287
```

To get the server software details, run `hostnamectl`
```
 Static hostname: elfleet048
       Icon name: computer-server
         Chassis: server 🖳
      Machine ID: 5ced64b850fc4653a767cf82cebca465
         Boot ID: a0f2cc1786aa4620ba3d96f64dc9c70c
Operating System: Ubuntu 24.04.2 LTS
          Kernel: Linux 6.8.0-55-generic
    Architecture: x86-64
 Hardware Vendor: Intel Corporation
  Hardware Model: AvenueCity
Firmware Version: BHSDCRB1.86B.3544.P02.2409040029
   Firmware Date: Wed 2024-09-04
    Firmware Age: 6month 3d
```
Here you can see the Operating System and the Kernel
## BIOS Settings
## Configuring Docker
The official instructions for Docker can be found on their website [here](https://docs.docker.com/engine/install/). You can select the Operating System that we found above and follow from there.
For Ubuntu, here are the instructions:
```
# Uninstall any docker libraries already present
for pkg in docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc; do sudo apt-get remove $pkg; done

```bash
# Add Docker's official GPG key:
sudo apt-get update
sudo apt-get install ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# Add the repository to Apt sources:
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update

# Install packages
sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Verify
sudo docker run hello-world

# Add your user to docker group
sudo usermod -aG docker $USER
```
Re-login to your server. You should be able to run `docker` without `sudo`
### Proxy Setup for Docker
If you are behind a corporate network, you would need to configure docker to use proxies. These steps are tested on Ubuntu, but should work on other OS as well:
```
# Create systemd dir
mkdir /etc/systemd/system/docker.service.d

# Add proxies
cat <<EOT >> /etc/systemd/system/docker.service.d/http-proxy.conf
[Service]
Environment="HTTP_PROXY=http://proxy.example:123/"
Environment="HTTPS_PROXY=http://proxy.example:123/"
Environment="NO_PROXY=localhost,127.0.0.0"
EOT

# Reload daemon
systemctl daemon-reload

# Restart docker
systemctl restart docker
```
## Building vLLM image 
Clone the vLLM repository
`git clone https://github.com/vllm-project/vllm`

If using a corporate proxy, export these variables:
```
export http_proxy=http://proxy.example:123/
export https_proxy=http://proxy.example:123/
export no_proxy=localhost,127.0.0.1,0.0.0.0
```

Build the image
```
cd vllm
docker build --build-arg https_proxy=$https_proxy --build-arg http_proxy=$http_proxy -f Dockerfile.cpu -t vllm-cpu-env .
```
## Run the benchmark script with Tensor Parallelism
To run this script, we need first to start the vLLM container and login to its shell:
- Run the vLLM container
```
# Run the container
docker run -d -v /home/$USER/.cache/huggingface/hub:/root/.cache/huggingface/hub -e http_proxy=$http_proxy -e HTTP_PROXY=$http_proxy -e https_proxy=$https_proxy -e HTTPS_PROXY=$https_proxy -e no_proxy=$no_proxy -e NO_PROXY=$no_proxy --name vllm --privileged --entrypoint sleep vllm-cpu-env infinity
```
- Login to its shell
```
docker exec -it vllm bash
```
Download the script
```
wget https://raw.githubusercontent.com/akarX23/intel-scripts/refs/heads/master/LLMs/vllm-master-bench.sh
chmod +x vllm-master-bench.sh
```
Print the configurable options
```
./vllm-master-bench.sh --help

# Output
Usage: ./vllm-master-bench.sh [options]

Options:
  --host <host>                 vLLM server host (default: 0.0.0.0)
  --port <port>                 vLLM server port (default: 8000)
  --kv_cache <GB>               KV cache size in GB (default: 40)
  --cpus_bind <cpus>            CPUs to bind (required)
  --hf_token <token>            Huggingface token (default: $HF_TOKEN)
  --model <model>               Model to host and benchmark (required)
  --tp <integer>                Tensor parallelism (default: 1)
  --vllm-server-args <args>     Extra arguments for vLLM server
  --vllm-root <path>            Root directory of vLLM (default: /home/akarx/intel-scripts/LLMs/vllm)
  --dataset-name <name>         Dataset for benchmarking (default: random)
  --num-prompts <num>           Number of prompts per request (default: 1000)
  --concurrencies <list>        List of concurrency values (required, comma-separated)
  --input-lengths <list>        List of input token lengths (required, comma-separated)
  --output-lengths <list>       List of output token lengths (required, comma-separated)
  --client-args <args>          Extra arguments for the benchmark client
  --log-dir <path>              Directory for logs (required)
  --help                        Display this help message
```
When we run vLLM with tensor parallelism on CPUs, we treat each NUMA Node as a GPU Card and split the model amongst them. For example, our NUMA Node configuration is:
```
NUMA:
  NUMA node(s):           6
  NUMA node0 CPU(s):      0-23,144-167
  NUMA node1 CPU(s):      24-47,168-191
  NUMA node2 CPU(s):      48-71,192-215
  NUMA node3 CPU(s):      72-95,216-239
  NUMA node4 CPU(s):      96-119,240-263
  NUMA node5 CPU(s):      120-143,264-287
```
Ideally, in our case, we should run vLLM with a maximum `--tp` value of 6. To do this, we use the `--cpus_bind` parameter. Here we define a list of core ranges separated by "|" that will be used to split the model processing. **Note that the model memory is still loaded in the RAM, only the processing is split across the CPUS.**

Since we have hyper-threading enabled, each NUMA Node has 2 sets of CPU Threads. vLLM runs best when only one set of threads per NUMA Node is being used. In our server, if we want to run vLLM with `--tp 6`, the cpus_bind will be like this:
`--cpus_bind "0-23|24-47|48-71|72-95|96-119|120-143"`

To automate a long-running benchmark, the script accepts these arguments for the benchmark client:
```
  --concurrencies <list>        List of concurrency values (required, comma-separated)
  --input-lengths <list>        List of input token lengths (required, comma-separated)
  --output-lengths <list>       List of output token lengths (required, comma-separated)
```
The script will run every iteration possible of the list of numbers provided in these parameters, one after the other, and compile the results. For example, `--concurrencies 1,2 --input-lengths 128,256 --output-lengths 512,1024` will run these combinations:
| Concurrency | Input Length | Output Length|
|--|--|--|
| 1 | 128 | 512 |
| 1 | 128 | 1024 |
| 1 | 256 | 512 |
| 1 | 256 | 512 |
| 2 | 128 | 512 |
| 2 | 128 | 1024 |
| 2 | 256 | 512 |
| 2 | 256 | 512 |

Lastly, the `--log-dir` parameter will accept a directory to save all logs to, which will be 3 files:
- vllm-server.out : Output of the vLLM Server command
- client.out : Output of the benchmark client
- results.csv : CSV formatted results for all the combinations specified

The other parameters are self-explanatory and can be used for experimentation to get different results.

A sample command you can run in the docker container for a long-running benchmark:
```
# If using a gated model
export HF_TOKEN=<your-hf-token>

# Benchmark meta-llama/Llama-3.1-8B-Instruct
./vllm-master-bench.sh --cpus_bind "0-23|24-47|48-71|72-95|96-119|120-143" --tp 6 --model meta-llama/Llama-3.1-8B-Instruct --concurrencies 1,2,4,8,16,32,64 --input-lengths 128,256,512,1024 --output-lengths 128,256,512,1024 --log-dir run1
```
The results can be found in the `run1` directory

## Run the benchmark setup with Load Balancing
Before following these steps, make sure there aren't any vLLM containers running to avoid any hindrance in performance.

In this procedure, we initiate multiple deployments of vLLM - 1 for each NUMA Node. The core ranges for each will be used as described in the previous section. We do this by using a `python` script to generate a `docker-compose.yml` file which has configurations for multiple containers and an HA Proxy container. It also generates a `haproxy.cfg` file which contains the load balancing configuration across our vLLM containers.

#### Step 1 - Generate the configuration files
Download the Python script
```
wget https://raw.githubusercontent.com/akarX23/intel-scripts/refs/heads/master/LLMs/vllm-cpu-lb-bench/gen-deploy-files.py
```
For a list of all options, run `python3 gen-deploy-files.py --help`

Generate the configuration:

Use the core-ranges for each NUMA Node, specify one core for ha_prpxy, and specify a value of kv_cache suitable for your RAM. The `--kv_cache` value is in GBs, and the product of this value and the number of core-ranges you have defined is the total space that will be occupied in your RAM.
```
python3 gen-deploy-files.py --core_ranges 0-39,40-79,80-119,120-159,160-199,200-224 --model meta-llama/Llama-3.1-8B-Instruct --docker_image vllm-cpu-env --ha_port 8000 --ha_proxy_core 225 --kv_cache 80 --hf_cache /home/$USER/.cache/huggingface/hub
```
This should generate the `docker-compose.yml` and the `haproxy.cfg` file. 

#### Step 2 - Run the benchmark
Download the benchmark script
```
wget https://raw.githubusercontent.com/akarX23/intel-scripts/refs/heads/master/LLMs/vllm-cpu-lb-bench/bench.sh

chmod +x bench.sh
```

This script is very similar to the one we used for Tensor Parallelism. The main difference is that it spawns multiple vLLM docker containers instead of a single vLLM command. You can check all options here:
```
./bench.sh --help

Usage: ./bench.sh [OPTIONS]

Options:
  --host                   Set the host (default: 0.0.0.0)
  --port                   Set the port (default: 8000)
  --deployment-files-root  Set the deployment files root (default: /home/akarx/intel-scripts/LLMs/vllm-cpu-lb-bench)
  --dataset-name           Set the dataset name (default: random)
  --num-prompts            Set the number of prompts (default: 1000)
  --client-args            Set additional client arguments
  --model                  (Required) Set the model name
  --concurrencies          (Required) Set comma-separated concurrency values
  --input-lengths          (Required) Set comma-separated input length values
  --output-lengths         (Required) Set comma-separated output length values
  --log-dir                (Required) Set the log directory
  --num-deployments        (Required) Set the number of deployments
  --cores-per-deployment   (Required) Set the number of cores per deployment
  --vllm-root              (Required) Set the VLLM root directory
  -h, --help               Show this help message and exit
```
For the recording of results, you need to specify `--num-deployments` and `--cores-per-deployment`. Also, `--vllm-root` is the path to the vLLM repository we had cloned earlier. The `--deployment-files-root` is the directory where your generated configuration files live.

A sample command to run a long-running benchmark:
```
# HF Token for gated models
export HF_TOKEN=<hf-token>

./bench.sh --host localhost --port 8000 --num-prompts 300 --model meta-llama/Llama-3.1-8B-Instruct --concurrencies 6,12,24 --input-lengths 128,256,512,1024 --output-lengths 1,128,256 --log-dir ./run1 --num-deployments 6 --cores-per-deployment 24 --vllm-root /home/cefls_user/vllm/
```
The results will be saved in the `run1` directory as specified in the `--log-dir` parameter.
