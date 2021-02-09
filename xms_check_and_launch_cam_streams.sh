#!/bin/bash

for elem in "salon~8084~rtsp://admin:admin@192.168.1.84:554/11" "chambre1~8085~rtsp://admin:admin@192.168.1.40:554/11"; do
	
	c=`echo $elem | cut -d '~' -f1`
	p=`echo $elem | cut -d '~' -f2`
	cu=`echo $elem | cut -d '~' -f3`
	
	cs=`ps ax | grep vlc | grep "stream-cam" | grep $c | wc -l`
	echo status of $c : $cs
	if [ $cs -eq 0 ]; then
		echo "Must relaunch " $c
		timeout 600s cvlc -v --sout "#transcode{acodec=mp4a,ab=128,channels=2,samplerate=44100}:std{access=http,mux=ts,dst=localhost:$p/stream-cam-$c}" $cu &
	fi	
done