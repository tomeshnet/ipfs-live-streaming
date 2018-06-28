#!/bin/sh
while true: do
    curl http://__IPFS_SERVER__:8080/ipns/__IPNS_KEY__ | grep http | tail -n 5 | awk -F '/' '{print $5}' | xargs -n 1 /root/pin.sh
done
