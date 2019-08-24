#!/usr/bin/env bash

set -e

IPFS_MIRROR_INSTANCE=$1
DOMAIN_NAME=$2
EMAIL_ADDRESS=$3
DRY_RUN=$4

#######################
# nginx + letsencrypt #
#######################

# Generate dhparam.pem
openssl dhparam -out /etc/ssl/certs/dhparam.pem 2048

# Get letsencrypt certificates with certbot
systemctl stop nginx.service
if [[ "${DRY_RUN}" == "true" ]]; then
  certbot certonly -n --dry-run --agree-tos --standalone --email "${EMAIL_ADDRESS}" -d "ipfs-mirror-${IPFS_MIRROR_INSTANCE}.${DOMAIN_NAME}" -d "ipfs-gateway-${IPFS_MIRROR_INSTANCE}.${DOMAIN_NAME}"
else
  certbot certonly -n --agree-tos --standalone --email "${EMAIL_ADDRESS}" -d "ipfs-mirror-${IPFS_MIRROR_INSTANCE}.${DOMAIN_NAME}" -d "ipfs-gateway-${IPFS_MIRROR_INSTANCE}.${DOMAIN_NAME}"
fi

# Configure nginx with HTTPS
cp -f /tmp/ipfs-mirror/nginx-default /etc/nginx/sites-available/default
sed -i "s#__DOMAIN_NAME__#${DOMAIN_NAME}#g" /etc/nginx/sites-available/default
sed -i "s#__IPFS_MIRROR_INSTANCE__#${IPFS_MIRROR_INSTANCE}#g" /etc/nginx/sites-available/default

cp -f /tmp/ipfs-mirror/nginx-gateway "/etc/nginx/sites-available/ipfs-gateway-${IPFS_MIRROR_INSTANCE}.${DOMAIN_NAME}"
sed -i "s#__DOMAIN_NAME__#${DOMAIN_NAME}#g" "/etc/nginx/sites-available/ipfs-gateway-${IPFS_MIRROR_INSTANCE}.${DOMAIN_NAME}"
sed -i "s#__IPFS_MIRROR_INSTANCE__#${IPFS_MIRROR_INSTANCE}#g" "/etc/nginx/sites-available/ipfs-gateway-${IPFS_MIRROR_INSTANCE}.${DOMAIN_NAME}"
ln -s "/etc/nginx/sites-available/ipfs-gateway-${IPFS_MIRROR_INSTANCE}.${DOMAIN_NAME}" "/etc/nginx/sites-enabled/ipfs-gateway-${IPFS_MIRROR_INSTANCE}.${DOMAIN_NAME}"

systemctl start nginx.service

# Configure auto-renewals
echo "30 2 * * 1 certbot renew >> /var/log/letsencrypt/letsencrypt.log" >> /etc/crontab
echo "35 2 * * 1 root systemctl reload nginx" >> /etc/crontab
