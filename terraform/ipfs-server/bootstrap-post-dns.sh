#!/usr/bin/env bash

set -e

DOMAIN_NAME=$1
EMAIL_ADDRESS=$2

#######################
# nginx + letsencrypt #
#######################

# Generate dhparam.pem
openssl dhparam –out /etc/ssl/certs/dhparam.pem 2048

# Get letsencrypt certificates with certbot
systemctl stop nginx.service
certbot certonly -n --agree-tos --standalone --email "${EMAIL_ADDRESS}" -d "${DOMAIN_NAME}" -d "ipfs-server.${DOMAIN_NAME}" -d "ipfs-gateway.${DOMAIN_NAME}"

# Configure nginx with HTTPS
cp -f /tmp/ipfs-server/nginx-default /etc/nginx/sites-available/default
sed -i "s#__DOMAIN_NAME__#${DOMAIN_NAME}#g" /etc/nginx/sites-available/default

cp -f /tmp/ipfs-server/nginx-gateway "/etc/nginx/sites-available/ipfs-gateway.${DOMAIN_NAME}"
sed -i "s#__DOMAIN_NAME__#${DOMAIN_NAME}#g" "/etc/nginx/sites-available/ipfs-gateway.${DOMAIN_NAME}"
ln -s "/etc/nginx/sites-available/ipfs-gateway.${DOMAIN_NAME}" "/etc/nginx/sites-enabled/ipfs-gateway.${DOMAIN_NAME}"

systemctl start nginx.service

# Configure auto-renewals
echo "30 2 * * 1 certbot renew >> /var/log/letsencrypt/letsencrypt.log" >> /etc/crontab
echo "35 2 * * 1 systemctl reload nginx" >> /etc/crontab