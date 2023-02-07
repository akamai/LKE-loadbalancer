#!/bin/bash
apt update && sudo apt upgrade -y
do-release-upgrade
apt install unattended-upgrades apt-listchanges bsd-mailx -y
dpkg-reconfigure -plow unattended-upgrades
apt-get install haproxy socat keepalived python3-pip jq -y
sudo apt-get update && sudo apt-get install -y ca-certificates curl && sudo curl -fsSLo /usr/share/keyrings/kubernetes-archive-keyring.gpg https://packages.cloud.google.com/apt/doc/apt-key.gpg
echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo apt-get update && sudo apt-get install -y kubectl
pip3 install linode-cli --upgrade
version=v0.0.6
curl -LO https://github.com/linode/lelastic/releases/download/$version/lelastic.gz
gunzip lelastic.gz
chmod 755 lelastic
sudo mv lelastic /usr/local/bin
