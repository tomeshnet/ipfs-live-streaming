#!/bin/sh
wget http://__IPFS_SERVER__:8080/ipfs/$1 -o /tmp/file
ipfs add /tmp/file
rm -rf /tmp/file
