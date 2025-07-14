import argparse
import yaml
import os
import sys
import shlex

HF_TOKEN=os.getenv("HF_TOKEN")
default_hf_cache = os.path.expanduser("~/.cache/huggingface/hub")

def parse_core_ranges(core_ranges):
    """Parses a comma-separated list of core ranges into a list of strings."""
    return [r.strip() for r in core_ranges.split(",")]

def generate_vllm_services(core_ranges, docker_image, model, kv_cache, extra_args, hf_cache):
    """Generates vLLM service definitions."""
    services = {}
    for i, core_range in enumerate(core_ranges, 1):
        service_name = f"vllm-{i}"
        container_name = f"vllm_container_{i}"
        services[service_name] = {
            "image": docker_image,
            "container_name": container_name,
            "privileged": True,
            "environment": [
                "VLLM_USE_V1=1",
                "VLLM_ALLOW_LONG_MAX_MODEL_LEN=1",
                "VLLM_ENGINE_ITERATION_TIMEOUT_S=600",
                f"VLLM_CPU_KVCACHE_SPACE={kv_cache}",
                f"VLLM_CPU_OMP_THREADS_BIND={core_range}",
                f"HF_TOKEN={HF_TOKEN}",
                f"http_proxy={os.environ.get('http_proxy', '')}",
                f"https_proxy={os.environ.get('https_proxy', '')}",
                f"no_proxy={os.environ.get('no_proxy', '')}"
            ],
            "command": ["--model", model, "-tp", "1", "--dtype", "bfloat16"] if extra_args == "" else ["--model", model, "-tp", "1", "--dtype", "bfloat16"] + list(map(str, shlex.split(extra_args))),
            "networks": ["vllm_net"],
            "volumes": [f"{hf_cache}:/root/.cache/huggingface/hub"],
            "healthcheck": {
                "test": ["CMD", "curl", "-f", "http://localhost:8000/v1/models"],
                "interval": "10s",
                "timeout": "5s",
                "retries": 50,
                "start_period": "30s"
            }
        }
    return services

def generate_haproxy_config(core_ranges):
    """Generates HAProxy configuration file content."""
    backends = "\n".join([f"    server vllm-{i} vllm-{i}:8000 check" for i in range(1, len(core_ranges) + 1)])

    return f"""
global
    log stdout format raw local0

defaults
    log global
    timeout connect 5s
    timeout client 50s
    timeout server 50s

frontend http_front
    bind *:{args.ha_port}
    default_backend vllm_backend

backend vllm_backend
    balance roundrobin
    option httpchk GET /health
{backends}
"""

def generate_haproxy_service(ha_proxy_core, ha_port):
    """Generates HAProxy service definition."""
    return {
        "haproxy": {
            "image": "haproxy:latest",
            "container_name": "haproxy_container",
            "volumes": [f"{sys.path[0]}/haproxy.cfg:/usr/local/etc/haproxy/haproxy.cfg:ro"],
            "ports": [f"{ha_port}:{ha_port}"],
            "cpuset": ha_proxy_core,
            "networks": ["vllm_net"],
            "restart": "always"
        }
    }
def generate_docker_compose(vllm_services, ha_service):
    """Generates the full docker-compose.yml structure."""
    compose_data = {
        "version": "3.8",
        "services": {**vllm_services, **ha_service},
        "networks": {
            "vllm_net": {
                "driver": "bridge"
            }
        }
    }
    return compose_data

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Generate docker-compose.yml and ha.conf for vLLM.")
    parser.add_argument("--core_ranges", required=True, help="Comma-separated CPU core ranges (e.g., 0-8,10-16)")
    parser.add_argument("--kv_cache", required=True, help="KV Cache size in GB")
    parser.add_argument("--docker_image", required=True, help="Docker image name for vLLM")
    parser.add_argument("--model", required=True, help="LLM model name")
    parser.add_argument("--ha_port", required=True, help="Port for HA Proxy")
    parser.add_argument("--ha_core", required=True, help="CPU core range for HA Proxy")
    parser.add_argument("--hf_cache", default=default_hf_cache, help="Path to Hugging Face hub cache")
    parser.add_argument("--vllm_extra_args", default="", help="Extra arguments for vLLM server")

    args = parser.parse_args()
    
    core_ranges = parse_core_ranges(args.core_ranges)

    # Generate the configurations
    vllm_services = generate_vllm_services(core_ranges, args.docker_image, args.model, args.kv_cache, args.vllm_extra_args, args.hf_cache)
    ha_service = generate_haproxy_service(args.ha_core, args.ha_port)
    docker_compose_data = generate_docker_compose(vllm_services, ha_service)
    ha_config = generate_haproxy_config(args.ha_port)

    # Write the docker-compose file
    with open("docker-compose.yml", "w") as f:
        yaml.dump(docker_compose_data, f, default_flow_style=False)

    # Write the ha config file
    with open("haproxy.cfg", "w") as f:
        f.write(ha_config)

    print("Generated docker-compose.yml and haproxy.cfg successfully!")
