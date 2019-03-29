#!/bin/bash

# Load settings
. ~/settings

# Create directory for HLS content
rm -rf ~/hls/*
cd ~/hls

DISCONNET=1

# Start ffmpeg in background
what="TEST1"
M3U8_SIZE=5

while true; do
	nextfile=$(cat ${what}.m3u8  |tail -n1);

 	if [ -f "${nextfile}" ]; then
  		timecode=`grep -B1 ${nextfile} ${what}.m3u8 | head -n1 | awk -F : '{print $2}' | tr -d ,`
  		if ! [ -z "${nextfile}" ]; then
  			if ! [ -z "{$timecode}" ]; then


                            reset_stream_marker=''
                            if [[ "$(grep -B2 ${nextfile} ${what}.m3u8 | head -n1)" == "#EXT-X-DISCONTINUITY" ]]; then
                               reset_stream_marker=" #EXT-X-DISCONTINUITY"
                            if
                            if [[ "$(DISCONNET)" == "1" ]]; then
                               reset_stream_marker=" #EXT-X-DISCONTINUITY"
			       DISCONNECT=0
                            fi

			    # Current UTC date for the log
			    time=`date "+%F-%H-%M-%S"`

			    # Add ts file to IPFS

			    ret=`ipfs add ${nextfile} 2>/dev/null > ~/tmp.txt; echo $?`
			    attempts=5
			    until [[ ${ret} -eq 0 || ${attempts} -eq 0 ]]; do
			      # Wait and retry
			      sleep 1
			     echo ipfs add ${nextfile}
			      ret=`ipfs add ${nextfile} 2>/dev/null > ~/tmp.txt; echo $?`
			      attempts=$((attempts-1))
			    done
			    if [[ ${ret} -eq 0 ]]; then
			      # Update the log with the future name (hash already there)
			      echo $(cat ~/tmp.txt) ${time}.ts ${timecode}${reset_stream_marker} >> ~/process-stream.log

			      # Remove nextfile and tmp.txt
			      rm -f ${nextfile} ~/tmp.txt

			      # Write the m3u8 file with the new IPFS hashes from the log
			      totalLines="$(wc -l ~/process-stream.log | awk '{print $1}')"

			      sequence=0
			      if (( "${totalLines}" > ${M3U8_SIZE} )); then
			          sequence=`expr ${totalLines} - ${M3U8_SIZE}`
			      fi
			      echo "#EXTM3U" > current.m3u8
			      echo "#EXT-X-VERSION:3" >> current.m3u8
			      echo "#EXT-X-TARGETDURATION:${HLS_TIME}" >> current.m3u8
			      echo "#EXT-X-MEDIA-SEQUENCE:${sequence}" >> current.m3u8
			      tail -n ${M3U8_SIZE} ~/process-stream.log | awk '{print $6"#EXTINF:"$5",\n'${IPFS_GATEWAY}'/ipfs/"$2}' | sed 's/#EXT-X-DISCONTINUITY#/#EXT-X-DISCONTINUITY\n#/g' >> current.m3u8

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
    sleep 5
  fi
done
