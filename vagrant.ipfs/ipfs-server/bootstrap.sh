#!/usr/bin/env bash

set -e


# Prevent apt-daily from holding up /var/lib/dpkg/lock on boot
systemctl disable apt-daily.service
systemctl disable apt-daily.timer

# Install Digital Ocean new metrics
curl -sSL https://agent.digitalocean.com/install.sh | sh


apt install -y inotify-tools ffmpeg

cd /tmp
wget https://dist.ipfs.io/go-ipfs/v0.4.15/go-ipfs_v0.4.15_linux-amd64.tar.gz
tar xvfz go-ipfs_v0.4.15_linux-amd64.tar.gz
cp go-ipfs/ipfs /usr/local/bin
ipfs init
sed -i 's#"Gateway": "/ip4/127.0.0.1/tcp/8080#"Gateway": "/ip4/0.0.0.0/tcp/8080#'  ~/.ipfs/config  

cp -f /vagrant/ipfs-server/ipfs.service /etc/systemd/system/ipfs.service
systemctl daemon-reload
systemctl enable ipfs.service
systemctl start ipfs.service

cp -f /vagrant/ipfs-server/process.sh ~/process.sh
cd ~
mkdir live
cd live
screen -dmS IPFSProcess ../process.sh



