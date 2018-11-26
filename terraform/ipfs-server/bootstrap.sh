#!/usr/bin/env bash

set -e

DOMAIN_NAME=$1
EMAIL_ADDRESS=$2
RTMP_SERVER_PRIVATE_IP=$3
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
  bc \
  certbot \
  ffmpeg \
  inotify-tools \
  jq \
  lsof \
  nginx

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

# Wait for IPFS daemon to start
sleep 10
until [[ `ipfs id >/dev/null 2>&1; echo $?` -eq 0 ]]; do
  sleep 1
done
sleep 10

# Write IPFS identity to client file
IPFS_ID=`ipfs id | jq .ID | sed 's/"//g'`
echo -n "$IPFS_ID" > ~/client-keys/ipfs_id

# Publish message to IPNS
echo "Serving m3u8 over IPNS is currently disabled" | ipfs add | awk '{print $2}' | ipfs name publish --timeout=30s || true &

########################
# Process video stream #
########################

# Install video stream processing script
cp -f /tmp/ipfs-server/process-stream.sh ~/process-stream.sh

# Save settings to a file
echo "#!/bin/sh" > ~/settings
echo "export DOMAIN_NAME=\"${DOMAIN_NAME}\"" >> ~/settings
echo "export RTMP_SERVER_PRIVATE_IP=\"${RTMP_SERVER_PRIVATE_IP}\"" >> ~/settings
echo "export RTMP_STREAM=\"rtmp://${RTMP_SERVER_PRIVATE_IP}/live\"" >> ~/settings
echo "export IPFS_GATEWAY=\"https://ipfs-gateway.${DOMAIN_NAME}\"" >> ~/settings
chmod +x ~/settings

# Install and start process-stream service
cp -f /tmp/ipfs-server/process-stream.service /etc/systemd/system/process-stream.service
systemctl daemon-reload
systemctl enable process-stream
systemctl start process-stream

################
# Video player #
################

# Install web video player
rm -rf /var/www/html/*
cp -r /tmp/video-player/* /var/www/html/

# Configure video player
sed -i "s#__IPFS_GATEWAY_SELF__#https://ipfs-gateway.${DOMAIN_NAME}#g" /var/www/html/js/common.js
sed -i "s#__IPFS_GATEWAY_ORIGIN__#https://ipfs-gateway.${DOMAIN_NAME}#g" /var/www/html/js/common.js
sed -i "s#__IPFS_ID_ORIGIN__#${IPFS_ID}#g" /var/www/html/js/common.js
sed -i "s#__M3U8_HTTP_URLS__#${M3U8_HTTP_URLS}#g" /var/www/html/js/common.js
