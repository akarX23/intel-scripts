import os
import time
import base64
import argparse
import datetime
import requests
from concurrent.futures import ThreadPoolExecutor

MODEL=""
HOST=""

# Function to send a request (updated version)
def send_request(image_path):
    # Open the image and encode it in Base64
    with open(image_path, "rb") as f:
        image = base64.b64encode(f.read()).decode("utf-8")
    image_data = f"data:image/png;base64,{image}"

    prompt = "Does this image contain sexually suggestive or provocative content? Just say yes or no."

    # Prepare the request data
    data = {
        "model": MODEL,
        "messages": [
            {
                "role": "user",
                "content": [
                    {"type": "text", "text": prompt},
                    {"type": "image_url", "image_url": {"url": image_data}}
                ]
            }
        ],
        "max_tokens": 1
    }

    headers = {
        "Content-Type": "application/json"
    }

    start_time = time.time()  # Record the start time

    # Send the request to the server
    response = requests.post(f"http://{HOST}:8000/v1/chat/completions", json=data, headers=headers)

    # Check the response
    result = response.json().get("choices", [{}])[0].get("message", {}).get("content", "No response")
    end_time = time.time()  # Record the end time
    time_taken = end_time - start_time

    # Return the image name as well for better tracking
    image_name = os.path.basename(image_path)
    return {"image_name": image_name, "result": result, "time_taken": time_taken}

# Main script
if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Run parallel inference requests on a folder of images.")
    parser.add_argument("--cores", type=int, required=True, help="Number of CPU cores")
    parser.add_argument("--num_concurrent", type=int, required=True, help="Number of concurrent requests")
    parser.add_argument("--total_requests", type=int, required=True, help="Total number of input requests")
    parser.add_argument("--image_folder", type=str, required=True, help="Path to the folder containing images")
    parser.add_argument("--deployments", type=int, default=1, help="Total deployments")
    parser.add_argument("--model", type=str, default="meta-llama/Llama-3.2-11B-Vision-Instruct", help="Model to benchmark")
    parser.add_argument("--host", type=str, default="localhost", help="Server host")

    args = parser.parse_args()
    
    MODEL=args.model
    HOST=args.host

 # Get all image files in the folder
    image_files = [
        os.path.join(args.image_folder, f)
        for f in os.listdir(args.image_folder)
        if f.lower().endswith((".png", ".jpg", ".jpeg"))
    ]

    if not image_files:
        print("No images found in the specified folder.")
        exit()

    # Ensure we have enough images
    if len(image_files) < args.total_requests:
        print(f"Warning: Only {len(image_files)} images found, but {args.total_requests} requests were specified.")

    # Generate the timestamp
    timestamp = datetime.datetime.now().strftime("%Y-%m-%d--%H-%M-%S")

    # Generate the log file name
    log_file_name = f"{args.cores}C-{args.num_concurrent}R-{args.total_requests}I-{args.deployments}D-{timestamp}.txt"

    # Prepare image data for requests
    image_data_list = image_files[:args.total_requests]

    start_time = time.time()

    # Use ThreadPoolExecutor to send requests in parallel
    with ThreadPoolExecutor(max_workers=args.num_concurrent) as executor:
        futures = executor.map(send_request, image_data_list)

    # Collect and print results
    with open(log_file_name, "w") as log_file:
        for result in futures:
            image_name = result["image_name"]
            output = f"Result for image {image_name}:\n{result['result']}\nTime taken: {result['time_taken']} seconds\n"
            print(output)
            log_file.write(output + "\n")

    total_time = time.time() - start_time
    print("Total time =", total_time)

    # Save the total time to the log file
    with open(log_file_name, "a") as log_file:
        log_file.write(f"\nTotal time taken: {total_time} seconds\n")

    print(f"Total time logged in {log_file_name}")
