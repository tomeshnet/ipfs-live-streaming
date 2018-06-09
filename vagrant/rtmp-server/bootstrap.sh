#!/usr/bin/env bash

NGINX_VERSION=1.15.0

# Install Digital Ocean new metrics
curl -sSL https://agent.digitalocean.com/install.sh | sh

# Prevent apt-daily from holding up /var/lib/dpkg/lock on boot
systemctl disable apt-daily.service
systemctl disable apt-daily.timer

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

# Start nginx
/usr/local/nginx/sbin/nginx
