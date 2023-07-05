
# ES Benchmarking plan
This guide assumes you have Kibana and esrally configured in separate VMs.


## Initial steps
- Setup an ES Cluster with the ansible scripts. Instructions [here](https://github.com/akarX23/intel-scripts/tree/master/elasticsearch).
- Make sure there is nothing else running on the machine hosting the ES Cluster.
- Define proper configuration for the VMs in the beginning since all the benchmark runs will use the same hardware configurations like RAM, vCPUs and storage.

## Understand the resources invloved

For each search or indexing operation the following resources are involved:

### **Storage**: Where data persists
-   SSDs are recommended whenever possible, in particular for nodes running search and index operations. Due to the higher cost of SSD storage, a  [hot-warm architecture](https://www.elastic.co/blog/implementing-hot-warm-cold-in-elasticsearch-with-index-lifecycle-management)  is recommended to reduce expenses.
-   When operating on bare metal, local disk is king!
-   Elasticsearch does not need redundant storage (RAID 1/5/10 is not necessary), logging and metrics use cases typically have at least one replica shard, which is the minimum to ensure fault tolerance while minimizing the number of writes.

### **Memory**: Where data is buffered

-   **JVM Heap:**Stores metadata about the cluster, indices, shards, segments, and fielddata. This is ideally set to 50% of available RAM.
-   **OS Cache:**Elasticsearch will use the remainder of available memory to cache data, improving performance dramatically by avoiding disk reads during full-text search, aggregations on doc values, and sorts.

### **Compute**: Where data is processed

Elasticsearch nodes have  **thread pools**  and **thread queues**  that use the available compute resources. The quantity and performance of CPU cores governs the average speed and peak throughput of data operations in Elasticsearch.

### **Network**: Where data is transferred

The network performance — both  _**bandwidth**_ _and_ _**latency**_  — can have an impact on the inter-node communication and inter-cluster features like  [cross-cluster search](https://www.elastic.co/guide/en/elasticsearch/reference/7.9/modules-cross-cluster-search.html)  and  [cross-cluster replication](https://www.elastic.co/guide/en/elasticsearch/reference/7.9/xpack-ccr.html).

## Data and Node Calculation
Depending on the size of deployment we will need to configure our cluster with enough nodes and resources to handle the estimated amount of data. Before that we need to answer a few questions:

-   How much raw data (GB) we will index per day?
-   How many days we will retain the data?
-   How many days in the hot zone?
-   How many days in the warm zone?
-   How many replica shards will you enforce?

In general we add 5% or 10% for margin of error and 15% to stay under the disk watermarks. We also recommend adding a node for hardware failure.
### Let’s do the math

-   **Total Data (GB)** = Raw data (GB) per day * Number of days retained * (Number of replicas + 1)
-   **Total Storage (GB)**  = Total data (GB) * (1 + 0.15 disk Watermark threshold + 0.1 Margin of error)
-   **Total Data Nodes**  = ROUNDUP(Total storage (GB) / Memory per data node / Memory:Data ratio)  
    
In case of large deployment it's safer to add a node for failover capacity. 

### Example: Sizing a large deployment

Let’s do the math with the following inputs:

-   You receive 100GB per day and we need to keep this data for 30 days in the hot zone and 12 months in the warm zone.
-   We have 64GB of memory per node with 30GB allocated for heap and the remaining for OS cache.
-   The typical memory:data ratio for the hot zone used is 1:30 and for the warm zone is 1:160.

If we receive 100GB per day and we have to keep this data for 30 days, this gives us:

-   **Total Data (GB)** in the  hot zone  = (100GB x 30 days * 2) =  **6000GB**
-   **Total Storage (GB)**  in the hot zone = 6000GB x (1+0.15+0.1) =  **7500GB**
-   **Total Data Nodes**  in the hot zone = ROUNDUP(7500 / 64 / 30) + 1 =  **5 nodes**
-   **Total Data (GB)**  in the  warm zone  = (100GB x 365 days * 2) =  **73000GB**
-   **Total Storage (GB)**  in the warm zone = 73000GB x (1+0.15+0.1) =  **91250GB**
-   **Total Data Nodes**  in the warm zone = ROUNDUP(91250 / 64 / 160) + 1 =  **10 nodes**
## Benchmarking
Now that we have our cluster(s) sized appropriately, we need to confirm that our math holds up in real world conditions. To be more confident before moving to production, we will want to do benchmark testing to confirm the expected performance

### Indexing benchmark

For the indexing benchmarks we are trying to answers the following questions:

-   What is the maximum indexing throughput for my clusters?
-   What is the data volume that I can index per day?
-   Is my cluster oversized or undersized ?

First we need to figure out the optimal bulk size and concurrent clients for bulk operations which can give maximum thoughput for our cluster. We start with 1 Rally Client and 200 as the bulk size and double it with each iteration. We will be using the [pmc](https://github.com/elastic/rally-tracks/tree/master/pmc) dataset for this and use the following command:
```
esrally race --track=pmc --target-hosts=es-1:9200,es-2:9200,es-3:9200,es-4:9200,es-5:9200,es-6:9200,es-7:9200 --pipeline=benchmark-only --kill-running-processes --report-file pmc.report --track-params number_of_replicas:2,bulk_size:200,bulk_indexing_clients:1 --telemetry shard-stats,data-stream-stats,ingest-pipeline-stats,disk-usage-stats --user-tags run01:1client-bulk200-10nodes
```
You can change the `--track-params` with each benchmark and measure the throughput until you receive an optimal mark,

Now use the same command and keep the `bulk_size` fixed and increase the `bulk-indexing_clients` by 3 for each iteration. This will give you the optimal number of concurrent clients. 

Once you find the `bulk_size` and the `bulk_indexing_clients` you will have the maximum throughput your cluster can handle at its current state. Any more throughput will require more nodes to be added.

