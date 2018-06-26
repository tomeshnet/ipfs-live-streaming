#!/bin/sh

DOMAIN_NAME=$1
RTMP_SERVER_PRIVATE_IP=$2

RTMP_STREAM=rtmp://$RTMP_SERVER_PRIVATE_IP/live
IPFS_GATEWAY=http://$DOMAIN_NAME:8080

cd ~/live

what=`date +Y%m%d%H%M`
what="LIVE-$what"

if [ -z "$(screen -list | grep ffmpeg)" ]; then
    rm -rf LIVE-*.ts
    rm -rf LIVE-.m3u8
    screen -dmS ffmpeg ffmpeg -re -i "${RTMP_STREAM}" -f mpegts -vcodec copy -hls_time 15 -hls_list_size 0 -f hls $what.m3u8
fi

while true; do
  nextfile=$(ls $what*.ts 2>/dev/null | tail -n 1)

  if ! [ -z "$nextfile" ]; then
    # Wait for file to finish writing
    inotifywait -e close_write $nextfile

    # Grab the timecode from the m3u8 file so we can add it to the log
    timecode=`cat $what.m3u8 | grep -B1 $nextfile | grep "#" | awk -F : '{print $2}' | tr -d ,`

    # What we will call this file later
    time=`date "+%F-%H-%M-%S"`

    # Add the file to IPFS
    ipfs add $nextfile >> log

    # Update the log with the future name (hash already there)
    sed -i "s#$nextfile#$nextfile $time.ts $timecode#" log

    # remove next file
    rm -f $nextfile
    
    # Rewrite the m3u8 file with the new ipfs hashes from the log
    cp $what.m3u8 current.m3u8
    while read p; do
      h=$(echo "$p" | awk '{print $2}') # Hash
      f=$(echo "$p" | awk '{print $3}') # Filename
      sed -i "s#$f#${IPFS_GATEWAY}/ipfs/$h#" current.m3u8
    done < log

    # IPNS publish
    m3u8hash=$(ipfs add current.m3u8 | awk '{print $2}')
    ipfs name publish --timeout=5s $m3u8hash &
  fi
done
