#!/bin/sh
cd ~/live

what='LIVE'
rm -rf $what*.ts
rm -rf $what.m3u8

screen -dmS ffmpeg ffmpeg -re -i rtmp://pit.stream.aseriesoftubez.com/demo/demo -f mpegts -vcodec copy -hls_time 30 -hls_list_size 0 -f hls $what.m3u8

while true; do

    nextfile=$(ls $what*.ts  2>/dev/null | tail -n 1 )

    if ! [ -z "$nextfile" ]; then

        #Wait for file to finish writing
        inotifywait -e close_write $nextfile

        #grab the timecode from teh m3u8 file so we can add it to the log
        timecode=`cat $what.m3u8  | grep -B1 $nextfile | grep "#" | awk -F : '{print $2}' | tr -d ,`

        #What we will call this file later
        time=`date "+%F-%H-%M-%S"`;

        #Add the file to ipfs
        ipfs add $nextfile >> log

        #Update the log with the future name (hash already there)
        sed -i  "s#$nextfile#$nextfile $time.ts $timecode#" log


        mv $nextfile $time.ts

        # Re-write the M3U8 file with the new ipfs hashes from the LOG
        cp $what.m3u8 current.m3u8
        while read p; do
          h=$(echo "$p" | awk '{print $2}') #Hash
          f=$(echo "$p" | awk '{print $3}') #File Name
        sed -i  "s#$f#https://ipfs.io/ipfs/$h#" current.m3u8
        done <log

        #make it an event
        sed -i "s/EXTM3U/EXTM3U\n#EXT-X-PLAYLIST-TYPE:EVENT/" current.m3u8

        # IPNS Push
        ipnsPush=$(ipfs add current.m3u8 | awk '{print $2}')
        ipfs name publish --timeout=1s $ipnsPush &


    fi
done

