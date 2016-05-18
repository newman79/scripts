#!/bin/bash

#-----------------------------------------------------------------------------------------------------------------------#
CurrentDateTime()
{
	res=$(date +"%Y%m%d_%H%M%S")
	echo $res
}

#-----------------------------------------------------------------------------------------------------------------------#
CurrentDateTimeNano()
{
	res=$(date +"%Y%m%d_%H%M%S_%N")
	echo $res
}

SCRIPTNAME=`basename "$0"`
SCRIPTDIRNAME=`SCRIPTDIRNAME "$0"`

#Variables globales de ce daemon
VARDIRNAME=CamGrabber
RUNDIR=/var/run/$VARDIRNAME
DAEMONPID=$$
DAEMON_NAME=xms_daemon_Grabber_Cam.sh
DAEMONPIDFILE=$RUNDIR/$DAEMON_NAME.pid

LOGDIR=/var/log/$VARDIRNAME
LOGFILE=$LOGDIR/$(CurrentDateTime)_$SCRIPTNAME.log

#-----------------------------------------------------------------------------------------------------------------------#
LogFull()
{
	arg1="$1"
	echo [$(CurrentDateTime)][$SCRIPTNAME] "$arg1"
	sudo echo [$(CurrentDateTime)][$SCRIPTNAME] "$arg1" >> $LOGFILE
}

#-----------------------------------------------------------------------------------------------------------------------#
MustRun()
{
	if [ ! -f $DAEMONPIDFILE ]; then
		echo -n 0
		return
	fi
	pidFilePid=$(cat $DAEMONPIDFILE)
	if [ "$pidFilePid" !=  "$$" ]; then
		echo -n 0
		return
	fi
	echo -n 1
}

#-----------------------------------------------------------------------------------------------------------------------#
sudo mkdir $LOGDIR 1>/dev/null 2>&1
sudo chmod 777 $LOGDIR 1>/dev/null 2>&1

LogFull "Start of daemon"

sudo mkdir $RUNDIR 2>/dev/null
sudo chmod 777 $RUNDIR 2>/dev/null
sudo echo -n $DAEMONPID > $DAEMONPIDFILE

minimumFN=20
snapRemoteFilePath=$RUNDIR/RemoteFilePath
ip_camera=192.168.1.84

while [ $(MustRun) -eq 1 ]; do
	
	# Recherche et supprime les fichier de plus de 1 jour
	find /media/dlink-00c3c7/Partages/Cam/ -name "*avi" -mtime 1 | while read filepath; do { echo Remove $filepath; rm -f $filepath; } done
	
	newVideoFile=/media/dlink-00c3c7/Partages/Cam/$(CurrentDateTimeNano)_Grab.avi
	LogFull "Process new grab : $newVideoFile"	
	cvlc -q --sout "#transcode{acodec=mp4a,ab=128,channels=2,samplerate=44100}:std{accesle,mux=mp4,dst=$newVideoFile}" "http://192.168.1.84/cgi-bin/hi3510/snap.cgi?&-getstream" 1>/dev/null 2>&1 &
	lastCommandPid=$!
	sleep 1
	sudo kill -INT $oldLastCommandPid 2>/dev/null
	
	cpt=0
	while [ $cpt -le 3600 ]; do
		cpt=$(($cpt +1))
		sleep 1
		if [ $(MustRun) -eq 0 ]; then
			cpt=3700
		fi
	done
	
	oldLastCommandPid=$lastCommandPid
done

sudo kill -INT $oldLastCommandPid 2>/dev/null

LogFull "End of daemon"