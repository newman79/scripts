#!/bin/bash

if [ "x"$1 = "x" ]; then
	echo "no cam specified"
	exit 1
fi

for elem in "salon~8084~rtsp://admin:admin@192.168.1.84:554/11" "chambre1~8085~rtsp://admin:admin@192.168.1.40:554/11"; do
	
	c=`echo $elem | cut -d '~' -f1`
	p=`echo $elem | cut -d '~' -f2`
	cu=`echo $elem | cut -d '~' -f3`
	
	if [ $c = $1 ]; then
		cs=`ps ax | grep vlc | grep "stream-cam" | grep $c | wc -l`
		if [ $cs -eq 0 ]; then
			echo "Must relaunch " $c
			cvlc -v --sout "#transcode{acodec=mp4a,ab=128,channels=2,samplerate=44100}:std{access=http,mux=ts,dst=localhost:$p/stream-cam-$c}" $cu &			
		fi
		echo "cam is available at following url : http://<target>/cams/$c"
		echo "to access it, you will have to enter login and password"
		echo "stream will close in 6000s"
		exit 0
	fi
done

echo "given cam does not exist : $1"
exit 2
