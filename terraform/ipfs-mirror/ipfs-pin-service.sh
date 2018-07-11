#!/bin/sh

while true; do
  # Download m3u8 and pin IPFS content
  wget -q https://ipfs-server.__DOMAIN_NAME__/live.m3u8 -O /var/www/html/live.m3u8
  cat /var/www/html/live.m3u8 | grep http | tail -n 5 | awk -F '/' '{print $5}' | xargs -n 1 /root/ipfs-pin.sh

  # Use IPNS to resolve m3u8 (uncomment to enable)
  #ipfs resolve /ipns/__IPFS_SERVER_IPFS_ID__ | ipfs cat | grep http | tail -n 5 | awk -F '/' '{print $5}' | xargs -n 1 /root/ipfs-pin.sh

  sleep 1
done