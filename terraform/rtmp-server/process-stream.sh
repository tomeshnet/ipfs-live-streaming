#!/bin/bash

# Load settings
. ~/settings

# Create directory for HLS content
rm -rf ~/hls/*
cd ~/hls

what="stream1"
RESTARTED="1"

while true; do
  nextfile=$(cat ${what}.m3u8 | tail -n1)

  if [ -f "${nextfile}" ]; then
    timecode=$(grep -B1 ${nextfile} ${what}.m3u8 | head -n1 | awk -F : '{print $2}' | tr -d ,)
    if ! [ -z "${nextfile}" ]; then
      if ! [ -z "{$timecode}" ]; then

        reset_stream_marker=''
        if [[ "$(grep -B2 ${nextfile} ${what}.m3u8 | head -n1)" == "#EXT-X-DISCONTINUITY" || "${RESTARTED}" == "1" ]]; then
          reset_stream_marker=" #EXT-X-DISCONTINUITY"
	  RESTARTED="0"
        fi

        # Current UTC date for the log
        time=$(date "+%F-%H-%M-%S")

        # Add ts file to IPFS
        hash=`ipfs add -Q ${nextfile}`
	
	if [[ -z "${hash}" ]]; then
	   echo ${nextfile} Add Failed, skipping for retry
	else
          # Update the log with the future name (hash already there)
          echo added ${hash} ${nextfile} ${time}.ts ${timecode}${reset_stream_marker} >>~/process-stream.log

          # Remove nextfile and tmp.txt
          rm -f ${nextfile} ~/tmp.txt

          echo "#EXTM3U" >current.m3u8
          echo "#EXT-X-VERSION:3" >>current.m3u8
          echo "#EXT-X-TARGETDURATION:20" >>current.m3u8
          echo "#EXT-X-MEDIA-SEQUENCE:0" >>current.m3u8
          echo "#EXT-X-PLAYLIST-TYPE:EVENT" >>current.m3u8

          cat ~/process-stream.log | awk '{print $6"#EXTINF:"$5",\n'${IPFS_GATEWAY}'/ipfs/"$2}' | sed 's/#EXT-X-DISCONTINUITY#/#EXT-X-DISCONTINUITY\n#/g' >>current.m3u8

          # Add m3u8 file to IPFS and IPNS publish (uncomment to enable)
          #m3u8hash=$(ipfs add current.m3u8 | awk '{print $2}')
          #ipfs name publish --timeout=5s $m3u8hash &

          # Copy files to web server
          cp current.m3u8 /var/www/html/live.m3u8
          cp ~/process-stream.log /var/www/html/live.log
        fi
      fi
    fi
  else
    sleep 1
  fi
done
