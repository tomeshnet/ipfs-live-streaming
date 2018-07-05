#!/usr/bin/env bash

set -e

IPFS_MIRROR_INSTANCE=$1
DOMAIN_NAME=$2
IPFS_SERVER_IPFS_ID=$3
M3U8_HTTP_URLS=$4

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
  nginx

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
cp -f /tmp/ipfs-mirror/ipfs.service /etc/systemd/system/ipfs.service
systemctl daemon-reload
systemctl enable ipfs
systemctl start ipfs

############
# IPFS pin #
############

# Copy IPFS pin scripts
cp -f /tmp/ipfs-mirror/ipfs-pin.sh /root/ipfs-pin.sh
cp -f /tmp/ipfs-mirror/ipfs-pin-service.sh /root/ipfs-pin-service.sh
sed -i "s#__DOMAIN_NAME__#${DOMAIN_NAME}#" /root/ipfs-pin-service.sh
sed -i "s#__IPFS_SERVER_IPFS_ID__#${IPFS_SERVER_IPFS_ID}#" /root/ipfs-pin-service.sh

# Install and start IPFS pin service
cp -f /tmp/ipfs-mirror/ipfs-pin.service /etc/systemd/system/ipfs-pin.service
systemctl daemon-reload
systemctl enable ipfs-pin
systemctl start ipfs-pin

################
# Video player #
################

# Install web video player
rm -rf /var/www/html/*
cp -r /tmp/video-player/* /var/www/html/

# Configure video player
sed -i "s#__IPFS_GATEWAY_SELF__#http://ipfs-mirror-${IPFS_MIRROR_INSTANCE}.${DOMAIN_NAME}:8080#g" /var/www/html/js/common.js
sed -i "s#__IPFS_GATEWAY_ORIGIN__#http://ipfs-server.${DOMAIN_NAME}:8080#g" /var/www/html/js/common.js
sed -i "s#__IPFS_ID_ORIGIN__#${IPFS_SERVER_IPFS_ID}#g" /var/www/html/js/common.js
sed -i "s#__M3U8_HTTP_URLS__#${M3U8_HTTP_URLS}#g" /var/www/html/js/common.js