#!/bin/bash

apt install python3-pip zip unzip -y

curl -s "https://get.sdkman.io" | bash
cp -r ~/.sdkman /home/ubuntu
chown ubuntu:ubutn /home/ubuntu
source ~/.sdkman/bin/sdkman-init.sh

sdk install java 14.0.2-open
sdk use java 14.0.2-open

echo "n" | sdk install java 11.0.17-amzn
echo "n" | sdk install java 8.0.362-amzn

echo "export JAVA_HOME=/home/ubuntu/.sdkman/candidates/java/current" >> /home/ubuntu/.zshrc
echo "export JAVA14_HOME=/home/ubuntu/.sdkman/candidates/java/14.0.2-open" >> /home/ubuntu/.zshrc
echo "export JAVA11_HOME=/home/ubuntu/.sdkman/candidates/java/11.0.17-amzn" >> /home/ubuntu/.zshrc
echo "export JAVA8_HOME=/home/ubuntu/.sdkman/candidates/java/8.0.362-amzn" >> /home/ubuntu/.zshrc
echo "export PATH=/home/ubuntu/.local/bin:$PATH" >> /home/ubuntu/.zshrc

sudo -u ubuntu pip3 install opensearch-benchmark