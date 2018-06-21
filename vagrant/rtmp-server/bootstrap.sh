#!/usr/bin/env bash

set -e

YGGDRASIL_GO_VERSION=0.2
NGINX_VERSION=1.15.0

# Prevent apt-daily from holding up /var/lib/dpkg/lock on boot
systemctl disable apt-daily.service
systemctl disable apt-daily.timer

# Install Digital Ocean new metrics
curl -sSL https://agent.digitalocean.com/install.sh | sh

# Install standard tools
apt install -y \
  build-essential \
  git \
  libpcre3 \
  libpcre3-dev \
  libssl-dev \
  zlibc \
  zlib1g \
  zlib1g-dev

# Install golang
mkdir /tmp/golang
wget --progress=bar:force https://dl.google.com/go/go1.9.2.linux-amd64.tar.gz -P /tmp/golang
tar -C /usr/local -xzf /tmp/golang/go1.9.2.linux-amd64.tar.gz
{
  echo ''
  echo '# Add golang path'
  echo 'export PATH=$PATH:/usr/local/go/bin'
} >> /etc/profile
. /etc/profile

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
cat <<"EOF"> ~/client.conf
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
echo "remote $myip 1194"  >> ~/client.conf
echo "<ca>" >> ~/client.conf
cat keys/ca.crt >> ~/client.conf
echo "</ca>" >> ~/client.conf

echo "<cert>" >> ~/client.conf
cat keys/remote.crt >> ~/client.conf
echo "</cert>" >> ~/client.conf

echo "<key>" >> ~/client.conf
cat keys/remote.key >> ~/client.conf
echo "</key>" >> ~/client.conf

#############
# Yggdrasil #
#############

# Install yggdrasil
git clone https://github.com/yggdrasil-network/yggdrasil-go.git
cd yggdrasil-go
git checkout "v${YGGDRASIL_GO_VERSION}"
cp /vagrant/rtmp-server/generate_keys.go .
./build -tags debug
cp yggdrasil /usr/bin/
cp yggdrasilctl /usr/bin/

# Configure yggdrasil
yggdrasil --genconf > /etc/yggdrasil.conf
sed -i 's/Listen: "\[::\]:[0-9]*"/Listen: "\[::\]:12345"/' /etc/yggdrasil.conf

# Generate publisher yggdrasil configurations
./generate_keys > ~/publisher.key
yggdrasil --genconf > ~/publisher.conf
sed -i "s/EncryptionPublicKey: .*/`cat ~/publisher.key | grep EncryptionPublicKey`/" ~/publisher.conf
sed -i "s/EncryptionPrivateKey: .*/`cat ~/publisher.key | grep EncryptionPrivateKey`/" ~/publisher.conf
sed -i "s|Peers: \[\]|Peers: \[\"tcp://`ifconfig eth0 | grep inet | grep -v inet6 | awk '{print $2'}`:12345\"\]|" ~/publisher.conf

# Start yggdrasil service
cp contrib/systemd/* /etc/systemd/system/
systemctl daemon-reload
systemctl enable yggdrasil
systemctl start yggdrasil
cd ~

#######################
# nginx + RTMP module #
#######################

# Download nginx and nginx-rtmp
wget "http://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz"
tar xzf "nginx-${NGINX_VERSION}.tar.gz"
git clone https://github.com/arut/nginx-rtmp-module.git

# Build nginx with nginx-rtmp
cd "nginx-${NGINX_VERSION}"
./configure --with-http_ssl_module --add-module=../nginx-rtmp-module
make
make install

# Configure nginx RTMP server
mkdir /root/hls
cp -f /vagrant/rtmp-server/nginx.conf /usr/local/nginx/conf/nginx.conf
sed -i "s/__PUBLISHER_IP_ADDRESS__/`cat ~/publisher.key | grep Address | awk '{print $2}'`/" /usr/local/nginx/conf/nginx.conf

# Start nginx
/usr/local/nginx/sbin/nginx
