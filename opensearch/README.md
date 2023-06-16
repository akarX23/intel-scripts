# Opensearch Multi-Node  Deployment with performance enhancements
This guide is to get you up to speed on setting up an opensearch cluster with recommended performance improvements built-in. This is an automated deployment using ansible. This deployment currently supports setting up of **Cluster Manager** and **Worker** nodes only. Support for other types of nodes maybe added in the fututre. Also, this has only been tested on **Ubuntu 20.04** only. Also, security configuration is not supported in this deployment.
## Pre-requisites
-  Target servers should be able to communicate with each other on their IP Addresses
- Preferably all ports should be open and firewalls disabled to reduce any chance of network blockage
- Target servers to be able to connect to the internet and download data
- A user with the same username in all servers having passwordless sudo
- Keyless SSH access to all target servers
- For an HA cluster, at least 3 manager nodes will be required
- Minimum 2 GB Ram for each node
- Anible to be installed and accessible on the machine where the scripts are to be run.
## Setup Options

### There are two options available:
- **Docker** : One open search container will be run in every node on the host network itself. A volume on each node will also be created which will be mapped with the Opensearch data directory for storing and back up of data. 
- **Native Install** : This will install Opensearch natively on each node with the required configurations. The data directory, by default, will be set to the default directory of opensearch.

Both the options provide customizations of the openseach.yml configuration file. The Docker option also comes with an additional configuration of Opensearch dashboards.
## Steps to setup cluster
### Initial steps
- clone the repository
```
git clone https://github.com/akarX23/opensearch-multi-node-setup-ansible.git
cd opensearch-multi-node-automation
```
- Generate the hosts.yaml file. This will be inventory file for the Ansible deployment.
```
./gen-hosts-yaml.sh -f hosts -m <comma separated manager node IPs> -d <comma separated data node IPs>
```
- Now you should have a `hosts.yaml` file in your directory.
- Follow next steps depending on the deployment flavour.
### Docker Install
The Docker setup playbook generates the Opensearch docker-compose file which will be used to spin up the container. The confguration of opensearch is done through options passed in the docker file. Open the docker_setup/gen_os_compose.sh and edit the environment key. These values will be put in the `/etc/opensearch/opensearch.yml` of the container. By default, it looks like this:
```
environment:
- cluster.name=${CLUSTER_NAME}
- node.name=${NODE_NAME}
- node.roles=${NODE_ROLES}
- discovery.seed_hosts=${MANAGER_HOSTS},${DATA_HOSTS}
- cluster.initial_master_nodes=${MANAGER_HOSTS}
- bootstrap.memory_lock=true # Disable JVM heap memory swapping
- "OPENSEARCH_JAVA_OPTS=-Xms${av_ram} -Xmx${av_ram}" # Set min and max JVM heap sizes to at least 50% of system RAM
- "DISABLE_INSTALL_DEMO_CONFIG=true"
- "DISABLE_SECURITY_PLUGIN=true"
```
We can see that by default security is disabled. It is recommended to not change the `cluster.name, node.name, node.roles, discovery.seed_hosts` but if you know what you are doing, go ahead!

Also the playbook uses `docker_setup/configure_docker.sh` file to install docker. This will work fine on ubuntu systems but if you are using some other distribution, you would need to change this file to support the docker installation on that OS. If docker is already installed on the cluster nodes, you can comment this task entirely. Also there is space to configure any proxies that might be needed for docker in the `configure_docker.sh` file.

Once you have made your changes execute this command to initiate the playbook:
```
# Run from repository directory
ansible-playbook -i hosts.yaml docker_setup/playbook.yml -u username
```
Now wait for about 5 mins depending on your network speed. Your final result should look like this:
```
PLAY RECAP **************************************************************************************************************************
data1                      : ok=13   changed=5    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
data2                      : ok=13   changed=5    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
manager1                   : ok=13   changed=5    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
manager2                   : ok=13   changed=5    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
manager3                   : ok=13   changed=5    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
```
Once this is done, to check the cluster health, run:
```
curl http://<any node IP>:9200/_cat/nodes?v

ip              heap.percent ram.percent cpu load_1m load_5m load_15m node.role node.roles      cluster_manager name
192.168.122.114            6          73   0    0.01    0.02     0.00 di        data,ingest     -               os-data2
192.168.122.61             9          73   0    0.07    0.02     0.00 m         cluster_manager *               os-manager3
192.168.122.69             7          73   0    0.00    0.00     0.00 di        data,ingest     -               os-data1
192.168.122.118            5          73   0    0.00    0.00     0.00 m         cluster_manager -               os-manager2
192.168.122.205            5          73   0    0.00    0.00     0.00 m         cluster_manager -               os-manager1
```
Cluster is successfully setup!
### Native Install
In the manual installation the playbook generates the opensearch.yml file for the opensearch cluster to use. This configuration can be found in the `manual_setup/gen_os_config.sh`.  This is the default configuration:
```
cluster.name: ${CLUSTER_NAME}
node.name: ${NODE_NAME}
node.roles: ${NODE_ROLES}
discovery.seed_hosts: ${MANAGER_HOSTS},${DATA_HOSTS}
cluster.initial_master_nodes: ${MANAGER_HOSTS}
network.host: 0.0.0.0
plugins.security.disabled: true
bootstrap.memory_lock: true
```
You can add or remove options to this depending on your requirement. The playbook also configures all the performance optimizations from the `manual_setup/perf_config.sh` file. It is recommended to not change any settings in this.

The playbook installs  Opensearch using `manual_setup/install_opensearch_manual.sh` file. This downloads the `.deb` package  by default. If you are using another distribution, you can change the URL to point to that package. You can find the download links [here](https://opensearch.org/downloads.html).  There is space to configure proxies as well in this script.
 
 Once you have configured the `manual_setup/gen_os_config.sh` file, execute the following command to setup the cluster:
 ```
 # Execute from repository directory
 ansible-playbook -i hosts manual_setup/playbook.yml -u username
 ```
 You should get the following out put after this has finished executing:
 ```
PLAY RECAP **************************************************************************************************************************
data1                      : ok=13   changed=5    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
data2                      : ok=13   changed=5    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
manager1                   : ok=13   changed=5    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
manager2                   : ok=13   changed=5    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
manager3                   : ok=13   changed=5    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
```
Once this is done, to check the cluster health, run:
```
curl http://<any node IP>:9200/_cat/nodes?v

ip              heap.percent ram.percent cpu load_1m load_5m load_15m node.role node.roles      cluster_manager name
192.168.122.114            6          73   0    0.01    0.02     0.00 di        data,ingest     -               os-data2
192.168.122.61             9          73   0    0.07    0.02     0.00 m         cluster_manager *               os-manager3
192.168.122.69             7          73   0    0.00    0.00     0.00 di        data,ingest     -               os-data1
192.168.122.118            5          73   0    0.00    0.00     0.00 m         cluster_manager -               os-manager2
192.168.122.205            5          73   0    0.00    0.00     0.00 m         cluster_manager -               os-manager1
```
## Which Performance Optimizations are Included?
- JAVA Heap size set to 50% of total RAM on each node.
- Swap turned off
- Number of memory swaps available to opensearch set to 262144
- Memory Lock limit set to unlimited
- Open files limit set to max
- Opensearch cluster nodes have `bootstrap.mem_lock=true` by default.
## Extras - Dashboards and Benchmarks
### Opensearch Dashboard
The docker setup also includes the option to install Opensearch dashboards.The current setup installs one Opensearch Dashboard instance on each master node. These can be really helpful to visualize your data better. To install, follow these steps:
```
# Generate the hosts.yaml file 
./gen_hosts.sh -f hosts -m <comma separated IPs of the current master nodes> -d <comma separated IPs of the current data nodes>

# Run the Dashboard playbook
ansible-playbook -i hosts.yaml docker_setup/dashboard-playbook.yaml  -u username
```
Once the playbook finishes, open your browser and go to `http://<manager-nod-IP>:5601 `to see the dashboard. You can read more about dashboards [here](https://opensearch.org/docs/latest/dashboards/quickstart-dashboards/).
### Opensearch Benchmark
This is a tool which can test workloads against your Opensearch cluster and give you detailed metrics. It's very useful  if you want to measure performance of your cluster. I have provided the script `setup_benchmark.sh` in the repository. It requires `pip, zip, and unizp`  which are installed using `apt` in the script. You can change this with your distribution commands. Then run this to setup the tool on a separate server than your cluster:
```
./setup_benchmark.sh -u username
```
This will setup JAVA 14 by default. You can read about running the tool [here](https://github.com/opensearch-project/opensearch-benchmark).

## Helpful Links for Opensearch usage
### Ingestion
- Normal doc – https://github.com/opensearch-project/documentation-website/blob/2.4/assets/examples/ecommerce-field_mappings.json (defining mapping)
-	Parent child – https://opensearch.org/docs/2.4/opensearch/supported-field-types/join/ (It talks about how to define a parent-child relationship mapping)
### Search
-	Normal search – https://opensearch.org/docs/1.2/opensearch/rest-api/search/
-	SQL based search – https://opensearch.org/docs/2.0/search-plugins/sql/full-text/ 
### Custom workload for benchmark 
-	StackOverflow dataset
-	SQL for aggregation (custom benchmark) – https://betterprogramming.pub/tired-of-troubleshooting-idle-search-resources-use-opensearch-benchmark-for-performance-tuning-d4277c9f724 (how to run custom benchmark)
### Quick start guide to create an index and search
- Overview - https://opensearch.org/docs/2.4/quickstart/

That's all the configuration this repository supports right now! If you have any doubts, feel free to contact me. If you want to make any contributions, you are free to do so! Thank you!
