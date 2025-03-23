import argparse
import yaml
import os
import sys

HF_TOKEN=os.getenv("HF_TOKEN")

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
                "VLLM_USE_V1=0",
                "VLLM_ALLOW_LONG_MAX_MODEL_LEN=1",
                "VLLM_ENGINE_ITERATION_TIMEOUT_S=600",
                f"VLLM_CPU_KVCACHE_SPACE={kv_cache}",
                f"VLLM_CPU_OMP_THREADS_BIND={core_range}",
                f"HF_TOKEN={HF_TOKEN}",
                f"http_proxy={os.environ.get('http_proxy', '')}",
                f"https_proxy={os.environ.get('https_proxy', '')}",
                f"no_proxy={os.environ.get('no_proxy', '')}"
            ],
            "cpuset": core_range,
            "command": ["--model", model, "-tp", "1", "--dtype", "bfloat16"] if extra_args == "" else ["--model", model, "-tp", "1", "--dtype", "bfloat16", extra_args],
            "networks": ["vllm_net"],
            "volumes": [f"{hf_cache}:/root/.cache/huggingface/hub"],
            "healthcheck": {
                "test": ["CMD", "curl", "-f", "http://localhost:8000/v1/models"],
                "interval": "10s",
                "timeout": "5s",
                "retries": 5,
                "start_period": "30s"
            }
        }
    return services

def generate_nginx_config(port):
    """Generates Nginx configuration file content."""
    backends = "\n".join([f"    server vllm-{i}:8000 max_fails=10 fail_timeout=10000s;" for i in range(1, len(core_ranges) + 1)])
    
    return f"""
upstream vllm_backend {{
    random two least_conn; 
{backends}
}}

server {{
    listen {port};
    location / {{
        proxy_pass http://vllm_backend;
        proxy_connect_timeout 120s; # Time to establish connection to upstream
        proxy_read_timeout 120s; # Time to wait for upstream to send data
        proxy_send_timeout 120s; # Time to wait for upstream to accept data
    }} 
}}
"""

def generate_nginx_service(nginx_core, nginx_port):
    """Generates Nginx service definition."""
    return {
        "nginx": {
            "image": "nginx:latest",
            "container_name": "nginx_container",
            "volumes": [f"{sys.path[0]}/nginx.conf:/etc/nginx/conf.d/default.conf:ro"],
            "ports": [f"{nginx_port}:{nginx_port}"],
            "cpuset": nginx_core,
            "networks": ["vllm_net"],
            "restart": "always"
        }
    }

def generate_docker_compose(vllm_services, nginx_service):
    """Generates the full docker-compose.yml structure."""
    compose_data = {
        "version": "3.8",
        "services": {**vllm_services, **nginx_service},
        "networks": {
            "vllm_net": {
                "driver": "bridge"
            }
        }
    }
    return compose_data

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Generate docker-compose.yml and nginx.conf for vLLM.")
    parser.add_argument("--core_ranges", required=True, help="Comma-separated CPU core ranges (e.g., 0-8,10-16)")
    parser.add_argument("--kv_cache", required=True, help="KV Cache size in GB")
    parser.add_argument("--docker_image", required=True, help="Docker image name for vLLM")
    parser.add_argument("--model", required=True, help="LLM model name")
    parser.add_argument("--nginx_port", required=True, help="Port for HAProxy")
    parser.add_argument("--nginx_core", required=True, help="CPU core range for HAProxy")
    parser.add_argument("--hf_cache", required=True, help="Path to huggingface hub cache")
    parser.add_argument("--vllm_extra_args", default="", help="Extra arguments for vLLM server")

    args = parser.parse_args()
    
    core_ranges = parse_core_ranges(args.core_ranges)

    # Generate the configurations
    vllm_services = generate_vllm_services(core_ranges, args.docker_image, args.model, args.kv_cache, args.vllm_extra_args, args.hf_cache)
    nginx_service = generate_nginx_service(args.nginx_core, args.nginx_port)
    docker_compose_data = generate_docker_compose(vllm_services, nginx_service)
    nginx_config = generate_nginx_config(args.nginx_port)

    # Write the docker-compose file
    with open("docker-compose.yml", "w") as f:
        yaml.dump(docker_compose_data, f, default_flow_style=False)

    # Write the nginx config file
    with open("nginx.conf", "w") as f:
        f.write(nginx_config)

    print("Generated docker-compose.yml and haproxy.cfg successfully!")
