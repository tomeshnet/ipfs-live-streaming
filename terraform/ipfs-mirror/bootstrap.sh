#!/usr/bin/env bash

set -e

IPFS_SERVER_PRIVATE_IP=$1
IPFSKEY=$2

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
apt install -y jq

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
cp -f /tmp/ipfs-mirror/ipfs.service /etc/systemd/system/ipfs.service
systemctl daemon-reload
systemctl enable ipfs
systemctl start ipfs

cp -f /tmp/ipfs-mirror/pin.sh /root/pin.sh
cp -f /tmp/ipfs-mirror/pin-service.sh /root/pin-service.sh
cp -f /tmp/ipfs-mirror/pin.service /etc/systemd/system/pin.service
chmod a+x /root/*.sh

sed -i "s#__IPFS_SERVER__#$IPFS_SERVER_PRIVATE_IP#" /root/pin.sh
sed -i "s#__IPNS_KEY__#$IPFSKEY#" /root/pin.sh
sed -i "s#__IPFS_SERVER__#$IPFS_SERVER_PRIVATE_IP#" /root/pin-service.sh

systemctl daemon-reload
systemctl enable pin
systemctl start pin

