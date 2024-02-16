#!/bin/bash

curl -X GET https://vault.habana.ai/artifactory/api/gpg/key/public | sudo apt-key add --
export OS=$(lsb_release -c | awk '{print $2}')

echo "deb https://vault.habana.ai/artifactory/debian $OS main" | sudo tee /etc/apt/sources.list.d/artifactory.list

sudo dpkg --configure -a
sudo apt-get update

sudo apt install -y habanalabs-firmware

sudo apt install -y habanalabs-dkms

sudo modprobe -r habanalabs
sudo modprobe -r habanalabs_cn
sudo modprobe -r habanalabs_en

sudo modprobe habanalabs_en
sudo modprobe habanalabs_cn
sudo modprobe habanalabs

sudo apt install -y habanalabs-container-runtime

sudo tee /etc/docker/daemon.json <<EOF
{
   "default-runtime": "habana",
   "runtimes": {
      "habana": {
            "path": "/usr/bin/habana-container-runtime",
            "runtimeArgs": []
      }
   }
}
EOF


sudo systemctl restart docker
