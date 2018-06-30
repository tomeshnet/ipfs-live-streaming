#!/bin/bash

# Load settings
. ~/settings

function startFFmpeg() {
  while true; do
    mv /var/log/ffmpeg /var/log/ffmpeg.1
    ffmpeg -nostats -re -i "${RTMP_STREAM}" -f mpegts -vcodec copy -hls_time 15 -hls_list_size 0 -f hls $what.m3u8 > /var/log/ffmpeg 2>&1
    sleep 1
  done
}

# Create directory for HLS content
rm -rf ~/live
mkdir ~/live
cd ~/live

what="$(date +%Y%m%d%H%M)-LIVE"

# Start ffmpeg in background
startFFmpeg &

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
    ipfs add $nextfile >> ~/process-stream.log

    # Update the log with the future name (hash already there)
    sed -i "s#$nextfile#$nextfile $time.ts $timecode#" ~/process-stream.log

    # Remove next file
    rm -f $nextfile

    # Rewrite the m3u8 file with the new ipfs hashes from the log
    cp $what.m3u8 current.m3u8
    while read p; do
      h=$(echo "$p" | awk '{print $2}') # Hash
      f=$(echo "$p" | awk '{print $3}') # Filename
      sed -i "s#$f#${IPFS_GATEWAY}/ipfs/$h#" current.m3u8
    done < ~/process-stream.log

    # IPNS publish
    m3u8hash=$(ipfs add current.m3u8 | awk '{print $2}')
    ipfs name publish --timeout=5s $m3u8hash &
  else
    sleep 5
  fi
done