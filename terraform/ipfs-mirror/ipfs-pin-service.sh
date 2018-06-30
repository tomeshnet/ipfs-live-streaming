#!/bin/sh

while true; do
  ipfs resolve /ipns/__IPFS_SERVER_IPFS_ID__ | ipfs cat | grep http | tail -n 5 | awk -F '/' '{print $5}' | xargs -n 1 /root/ipfs-pin.sh
  sleep 1
done