#!/usr/bin/env bash

set -e

DOMAIN_NAME=$1
EMAIL_ADDRESS=$2
RTMP_SERVER_PRIVATE_IP=$3
M3U8_HTTP_URLS=$4

NGINX_VERSION=1.15.0
IPFS_VERSION=0.4.22

# Wait for cloud-init to complete
until [[ -f /var/lib/cloud/instance/boot-finished ]]; do
  sleep 1
done

# Prevent apt-daily from holding up /var/lib/dpkg/lock on boot
systemctl disable apt-daily.service
systemctl disable apt-daily.timer

# Install Digital Ocean new metrics
curl -sSL https://agent.digitalocean.com/install.sh | sh

# Install standard tools
apt update
apt install -y \
  bc \
  build-essential \
  certbot \
  git \
  jq \
  libpcre3 \
  libpcre3-dev \
  libssl-dev \
  zlibc \
  zlib1g \
  zlib1g-dev

# Create directory for generating client keys
mkdir /root/client-keys

###########
# OpenVPN #
###########

# Install openvpn and generate keys and config file
apt install -y openvpn

# Build certificates
cd /usr/share/easy-rsa/
cp openssl-1.0.0.cnf openssl.cnf 
. ./vars
./clean-all
./build-dh

# Run the rest manually to avoid interactivity
export EASY_RSA="${EASY_RSA:-.}"
"$EASY_RSA/pkitool" --initca #ca
"$EASY_RSA/pkitool" --server server #server
"$EASY_RSA/pkitool" remote #client

# Create server file
cat <<"EOF"> /etc/openvpn/openvpn.conf
port 1194
local ::
proto udp
dev tun
daemon

ca "/usr/share/easy-rsa/keys/ca.crt"
cert "/usr/share/easy-rsa/keys/server.crt"
key "/usr/share/easy-rsa/keys/server.key"
dh "/usr/share/easy-rsa/keys/dh2048.pem"
server 10.10.10.0 255.255.255.0
duplicate-cn
keepalive 10 120
persist-key
persist-tun
max-clients 5
verb 3
mssfix 1200
tun-mtu 1500
tun-mtu-extra 32
EOF

# Enable autostart of all configs
echo AUTOSTART="all" >> /etc/default/openvpn

# Start daemon
systemctl daemon-reload
service openvpn restart

# Grab my IP address
myip=$(ifconfig eth0 | grep inet | grep -v inet6 | awk '{print $2}')

# Create client config
cat <<"EOF"> ~/client-keys/client.conf
client
dev tun
proto udp
resolv-retry infinite
nobind
persist-key
persist-tun
ns-cert-type server
verb 3

EOF

# Dynamic part of the config
echo "remote $myip 1194"  >> ~/client-keys/client.conf
echo "<ca>" >> ~/client-keys/client.conf
cat keys/ca.crt >> ~/client-keys/client.conf
echo "</ca>" >> ~/client-keys/client.conf

echo "<cert>" >> ~/client-keys/client.conf
cat keys/remote.crt >> ~/client-keys/client.conf
echo "</cert>" >> ~/client-keys/client.conf

echo "<key>" >> ~/client-keys/client.conf
cat keys/remote.key >> ~/client-keys/client.conf
echo "</key>" >> ~/client-keys/client.conf

# Copy config for Windows
cp ~/client-keys/client.conf ~/client-keys/client.ovpn

#############
# Yggdrasil #
#############

# Flag yggdrasil ipv6 addresses as non-internet addresses
echo "label 200::/7 6" | tee --append /etc/gai.conf
echo "label 300::/7 6" | tee --append /etc/gai.conf
  
# Download and install Yggdarsail deb from official repo
wget https://1390-115685026-gh.circle-artifacts.com/0/yggdrasil-0.3.6-amd64.deb
dpkg -i yggdrasil-0.3.6-amd64.deb
addgroup --system --quiet yggdrasil

# Generate publisher yggdrasil configurations
yggdrasil --genconf > ~/client-keys/yggdrasil.conf
sed -i "s/IfName: auto/IfName: ygg0/" ~/client-keys/yggdrasil.conf
sed -i 's/Listen: "\[::\]:[0-9]*"/Listen: "\[::\]:12345"/' ~/client-keys/yggdrasil.conf

# Start yggdrasil with the publisher configuration to get the client's yggdrasil IPv6 address
yggdrasil --useconffile ~/client-keys/yggdrasil.conf &
YGG_PID=$!

# Wait for yggdrasil with publisher configuration to start
echo -n Waiting on ygg0
until [[ `ifconfig ygg0 >/dev/null 2>&1; echo $?` -eq 0 ]]; do
  echo -n "."
  sleep 1
done

# Read publisher yggdrasil IPv6 address and kill process then stop the process
CLIENT_ADDRESS=`ifconfig ygg0 | grep -E 'inet6 2[0-9a-fA-F]{2}:' | awk '{print $2}'`
kill -9 $YGG_PID

# Add server ip to peering information for publisher configuration
sed -i "s|Peers: \[\]|Peers: \[\"tcp://`ifconfig eth0 | grep inet | grep -v inet6 | awk '{print $2}'`:12345\"\]|" ~/client-keys/yggdrasil.conf

# Generate server yggdrasil configurations
yggdrasil --genconf > /etc/yggdrasil.conf
chgrp yggdrasil /etc/yggdrasil.conf
sed -i 's/Listen: "\[::\]:[0-9]*"/Listen: "\[::\]:12345"/' /etc/yggdrasil.conf
sed -i "s/IfName: auto/IfName: ygg0/" /etc/yggdrasil.conf

# Start yggdrasil service
systemctl daemon-reload
systemctl enable yggdrasil
systemctl start yggdrasil
cd ~

# Write server yggdrasil IP address to client file
until [[ `ifconfig ygg0 >/dev/null 2>&1; echo $?` -eq 0 ]]; do
  sleep 1
done
echo -n `ifconfig ygg0 | grep -E 'inet6 2[0-9a-fA-F]{2}:' | awk '{print $2}'` > ~/client-keys/rtmp_yggdrasil

#######################
# nginx + RTMP module #
#######################

# Download nginx and nginx-rtmp
wget "http://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz"
tar xzf "nginx-${NGINX_VERSION}.tar.gz"
git clone https://github.com/arut/nginx-rtmp-module.git

# Build nginx with nginx-rtmp
cd "nginx-${NGINX_VERSION}"
./configure --with-http_ssl_module --with-http_v2_module --add-module=../nginx-rtmp-module --with-cc-opt=-Wno-error
make
make install

# Configure nginx RTMP server
mkdir /root/hls
cp -f /tmp/rtmp-server/nginx.conf /usr/local/nginx/conf/nginx.conf
sed -i "s/__PUBLISHER_IP_ADDRESS__/$CLIENT_ADDRESS/" /usr/local/nginx/conf/nginx.conf

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
cp -f /tmp/rtmp-server/ipfs.service /etc/systemd/system/ipfs.service
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
# Commented out because IPNS is not predictable and could stall the script
# echo "Serving m3u8 over IPNS is currently disabled" | ipfs add | awk '{print $2}' | ipfs name publish

########################
# Process video stream #
########################

# Install video stream processing script
cp -f /tmp/rtmp-server/process-stream.sh ~/process-stream.sh

# Save settings to a file
echo "#!/bin/sh" > ~/settings
echo "export DOMAIN_NAME=\"${DOMAIN_NAME}\"" >> ~/settings
echo "export RTMP_SERVER_PRIVATE_IP=\"${RTMP_SERVER_PRIVATE_IP}\"" >> ~/settings
echo "export RTMP_STREAM=\"/root/hls\"" >> ~/settings
echo "export IPFS_GATEWAY=\"https://ipfs-gateway.${DOMAIN_NAME}\"" >> ~/settings
chmod +x ~/settings

# Install and start process-stream service
cp -f /tmp/rtmp-server/process-stream.service /etc/systemd/system/process-stream.service
systemctl daemon-reload
systemctl enable process-stream
systemctl start process-stream

################
# Video player #
################

# Install web video player
rm -rf /var/www/html/* || true
mkdir -p /var/www/html/ || true
cp -r /tmp/video-player/* /var/www/html/

# Configure video player
sed -i "s#__IPFS_GATEWAY__#https://ipfs-gateway.${DOMAIN_NAME}#g" /var/www/html/js/common.js
sed -i "s#__IPFS_ID_ORIGIN__#${IPFS_ID}#g" /var/www/html/js/common.js
sed -i "s#__M3U8_HTTP_URLS__#${M3U8_HTTP_URLS}#g" /var/www/html/js/common.js

mkdir /usr/local/nginx/conf/conf.d

# Start nginx
cp /tmp/rtmp-server/nginx.service /etc/systemd/system/nginx.service
systemctl daemon-reload
systemctl enable nginx.service
systemctl start nginx.service

############
# Add Swap #
############

# Make 3 GB file, format it as swap and activate it
dd if=/dev/zero of=/swap.img bs=1M count=3072
mkswap /swap.img
chmod 600 /swap.img
swapon /swap.img
echo /swap.img none swap sw 0 0 >> /etc/fstab

exit 0
