#!/bin/bash

IPFS_REF=$1

# Check if it is not already pinning
if [[ -z "$(ps aux | grep $IPFS_REF | grep -v grep | grep -v ipfs-pin )" ]]; then
    # Pin IPFS content
    ipfs pin add /ipfs/$IPFS_REF &
fi
