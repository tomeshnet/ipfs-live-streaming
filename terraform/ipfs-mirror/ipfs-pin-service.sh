#!/bin/sh

while true; do
  # Re-establish swarm connection to main IPFS server
  #    IPFS takes a long time to find the hashes. 
  #    By manually setting a connection allows pinning to happen very quickly
  #    Since connections are dropped we re-connect every loop
  ipfs swarm connect /ip4/__IPFS_SERVER_IPV4_PRIVATE__/tcp/4001/ipfs/__IPFS_SERVER_IPFS_ID__

  # Download m3u8 and pin IPFS content
  wget -q https://ipfs-server.__DOMAIN_NAME__/live.m3u8 -O /var/www/html/live.m3u8
  cat /var/www/html/live.m3u8 | grep http | tail -n 5 | awk -F '/' '{print $5}' | xargs -n 1 /root/ipfs-pin.sh

  # Use IPNS to resolve m3u8 (uncomment to enable)
  #ipfs resolve /ipns/__IPFS_SERVER_IPFS_ID__ | ipfs cat | grep http | tail -n 5 | awk -F '/' '{print $5}' | xargs -n 1 /root/ipfs-pin.sh
  
  sleep 5
done
