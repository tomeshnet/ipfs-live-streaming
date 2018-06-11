#!/usr/bin/env bash

set -e

YGGDRASIL_GO_COMMIT=b0acc19
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

# Install yggdrasil
git clone https://github.com/yggdrasil-network/yggdrasil-go.git
cd yggdrasil-go
git checkout "${YGGDRASIL_GO_COMMIT}"
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
sed -i "s|Peers: \[\]|Peers: \[\"tcp://`ifconfig eth0 | grep 'inet ' | awk '{print $2'}`:12345\"\]|" ~/publisher.conf

# Start yggdrasil service
cp contrib/systemd/* /etc/systemd/system/
systemctl enable yggdrasil
systemctl start yggdrasil
cd ~

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
