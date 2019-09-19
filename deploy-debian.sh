#!/bin/bash
# This script must be run as root. IE `su`
# And under Debian 10

if [ -z "$var" ]
then
      echo "You need to specify the domain name as the first paramater"
      echo "IE:  ./deploy-debian.sh live.mesh.world"
      exit;
else
      DOMAIN=$1
fi

# Create file that is expected in DO env
mkdir -p /var/lib/cloud/instance
touch /var/lib/cloud/instance/boot-finished

# DPKG does not work on debian10 for some reason without this
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# Get some pacakges
cd ~
apt-get -y update 
apt-get -y install wget git python procps curl net-tools

# Clone repo
git clone https://github.com/tomeshnet/ipfs-live-streaming.git

# Put files in the right places that are similar to DO
cd ipfs-live-streaming
mv terraform/rtmp-server/ /tmp/rtmp-server
mv terraform/shared/video-player /tmp/video-player

# Mark executable
chmod +x /tmp/rtmp-server/bootstrap.sh
chmod +x /tmp/rtmp-server/bootstrap-post-dns.sh
chmod +x /tmp/rtmp-server/process-stream.sh

# Remove DO Agent installation
sed -i "/agent.digitalocean.com/d" /tmp/rtmp-server/bootstrap.sh

# Remove easy-rsa3 and replace it with easy-rsa2 from git
apt-get remove easy-rsa
git clone https://github.com/OpenVPN/easy-rsa.git
cd easy-rsa
git checkout release/2.x
mkdir /usr/share/easy-rsa
cp  -r easy-rsa/2.0/* /usr/share/easy-rsa

# Run bootstrap
/tmp/rtmp-server/bootstrap.sh $DOMAIN domainadmin@$DOMAIN 127.0.0.1 ""

# Fix missing paramaters
sed -i "s/remote  1194/remote $DOMAIN 1194/" /root/client-keys/client.conf 
sed -i "s/remote  1194/remote $DOMAIN 1194/" /root/client-keys/client.ovpn
sed -i "s/Peers: \[\"tcp:\/\/:12345\"\]/Peers: \[\"tcp:\/\/$DOMAIN:12345\"\]/" /root/client-keys/yggdrasil.conf  


echo Configure DNS then to point the following domains to your IP
echo At minimum
echo "   $DOMAIN"
echo "   ipfs-server.$DOMAIN"
echo "   ipfs-gateway.$DOMAIN"
echo Then run
echo /tmp/rtmp-server/bootstrap-post-dns.sh $DOMAIN domainadmin@$DOMAIN ""
