#!/usr/bin/env bash

set -e

DOMAIN_NAME=$1
RTMP_SERVER_PRIVATE_IP=$2

IPFS_VERSION=0.4.15

# Wait for cloud-init to complete
until [[ -f /var/lib/cloud/instance/boot-finished ]]; do
  sleep 1
done

# Prevent apt-daily from holding up /var/lib/dpkg/lock on boot
systemctl disable apt-daily.service
systemctl disable apt-daily.timer

# Install Digital Ocean new metrics
curl -sSL https://agent.digitalocean.com/install.sh | sh

# Install programs
apt update
apt install -y \
  ffmpeg \
  inotify-tools \
  jq

# Create directory for generating client keys
mkdir /root/client-keys

########
# IPFS #
########

# Install IPFS
cd /tmp
wget "https://dist.ipfs.io/go-ipfs/v${IPFS_VERSION}/go-ipfs_v${IPFS_VERSION}_linux-amd64.tar.gz"
tar xvfz "go-ipfs_v${IPFS_VERSION}_linux-amd64.tar.gz"
cp go-ipfs/ipfs /usr/local/bin
cd ~

# Configure IPFS
ipfs init
sed -i 's#"Gateway": "/ip4/127.0.0.1/tcp/8080#"Gateway": "/ip4/0.0.0.0/tcp/8080#' ~/.ipfs/config
cp -f /tmp/ipfs-server/ipfs.service /etc/systemd/system/ipfs.service
systemctl daemon-reload
systemctl enable ipfs
systemctl start ipfs

# Write IPFS identity to client file
until [[ `ipfs id >/dev/null 2>&1; echo $?` -eq 0 ]]; do
  sleep 1
done
echo -n `ipfs id | jq .ID | sed 's/"//g'` > ~/client-keys/ipfs_id

########################
# Process video stream #
########################

# Install video stream processing script
cp -f /tmp/ipfs-server/process-stream.sh ~/process-stream.sh
mkdir ~/live

# Start video stream processing in background
screen -dmS process-stream ./process-stream.sh $DOMAIN_NAME $RTMP_SERVER_PRIVATE_IP