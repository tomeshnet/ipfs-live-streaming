#!/bin/bash
cd terraform

echo "--------Domain Name--------"
read -p "What is your domain name (e.g. tomesh.net): " -r
echo -n $REPLY > .keys/domain_name

echo "Make sure the nameserver of your domain points to:"
echo "ns1.digitalocean.com"
echo "ns2.digitalocean.com"
echo "ns3.digitalocean.com"

echo "--------DigitalOcean API Token--------"
read -p "What is your DigitalOcean API Token: "  -r
echo -n $REPLY > .keys/do_token

echo "--------DigitalOcean SSH Keys--------"
echo "Creating RSA keys for SSH access..."
ssh-keygen -q -t rsa -f .keys/id_rsa
fingerprint=$(ssh-keygen -l -E md5 -f .keys/id_rsa.pub | awk '{print $2}' | sed 's/MD5://')
echo -n $fingerprint > .keys/ssh_fingerprint

echo "Add the newly created SSH public key to your DigitalOcean account under 'Settings > Security' and verify the fingerprint '$fingerprint':"
cat .keys/id_rsa.pub

echo "--------Let's Encrypt SSL/TLS Certificates--------"
read -p "What is the e-mail you would like to use for Let's Encrypt: " -r
echo -n $REPLY > .keys/email_address
