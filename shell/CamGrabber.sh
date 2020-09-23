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
SCRIPTDIRNAME=`dirname "$0"`

#Variables globales de ce daemon
VARDIRNAME=CamGrabber
RUNDIR=/var/run/$VARDIRNAME
DAEMONPID=$$
DAEMON_NAME=xms_daemon_Grabber_Cam.sh
DAEMONPIDFILE=$RUNDIR/$DAEMON_NAME.pid

NASSHARE=/media/dlink-2a629f/Partages

LOGDIR=/var/log/$VARDIRNAME
LOGFILE=$LOGDIR/$(CurrentDateTime)_$SCRIPTNAME.log

CAMERA_CONF_FILE="$SCRIPTDIRNAME/$SCRIPTNAME.conf"
VLC_RECORD_PROCESSES="$SCRIPTDIRNAME/$SCRIPTNAME.vlc.pids"
VLC_RECORD_PROCESSES_OLD="$SCRIPTDIRNAME/$SCRIPTNAME.vlc.old.pids"


#----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------#
ReMount()
{
	NetBiosName=$1
	CifsShare=$2
	UserForMount=$3
		
	PwdForMount=`cat /home/pi/scripts/MountLoginPassword.cfg | grep "$NetBiosName " | grep "$UserForMount " | awk '{print $3}' | /home/pi/xmsEncodeDecode -d`

	if [ ! -d /media/$NetBiosName ]; then 
		mkdir /media/$NetBiosName
	fi

	LogFull "	Mounting //$NetBiosName/$CifsShare   user=$UserForMount "
	# cette commande utilise le module samba --> samba doit etre installé	
	nmbLookupOutputFile=$LOGDIR"/nmblookup_"$NetBiosName"_"$CifsShare".log"
	nmbLookupOutputFile=$(echo $nmbLookupOutputFile | sed -e "s/ /_/g")
	
	sudo nmblookup -B 192.168.1.255 $NetBiosName > "$nmbLookupOutputFile"
	test=$(cat $nmbLookupOutputFile | grep "name_query failed")
	
	if [ ! "$test"X = X ]; then # error
		LogFull "nmblookup : hôte $NetBiosName non trouvé" 
		LogFull $test
		return 1
	fi
	
	# montage
	sudo umount /media/$NetBiosName 2>/dev/null	
	cifsMountError="$LOGDIR/cifs_"$NetBiosName"_"$CifsShare"_errors".log
	cifsMountError=$(echo $cifsMountError | sed -e "s/ /_/g")
	LogFull $NetBiosName
	LogFull $CifsShare
	LogFull $UserForMount
	LogFull $PwdForMount
	LogFull $cifsMountError
	sudo mount -v -t cifs   //$NetBiosName/"$CifsShare" /media/$NetBiosName -o user=$UserForMount,pass=$PwdForMount,file_mode=0777,dir_mode=0777 1>$cifsMountError 2>&1
	ls /media/$NetBiosName >/dev/null 2>&1
	mountResult=$?
	if [ $mountResult -eq 0 ]; then 
		LogFull "OK ; IP="$pcIP
	else
		LogFull "Command mount has failed ; for details, just execute this command : #cat $cifsMountError"
	fi
	return $mountResult
}

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
	# for tests
	#echo -n 0
	#return

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
ProcessRecordingCheckIteration()
{
	LogFull "Start new vlc capture for each cam"
	
	while read row; do
		camRow=`echo $row | sed -e "s/ //g" | grep "^[^#;]"`
		if [ "X$camRow" != "X" ]; then
			camName=`echo $camRow | cut -d~ -f1`
			camUrl=`echo $camRow | cut -d~ -f2`  
			LogFull "Process cam : $camName, url : $camUrl"
			
			newVideoFile=$NASSHARE/Cam/$(CurrentDateTimeNano)_Grab-$camName.avi
			
			#cvlc -q --sout "#transcode{acodec=mp4a,ab=128,channels=2,samplerate=44100}:std{accesle,mux=mp4,dst=$newVideoFile}" "http://192.168.1.84/cgi-bin/hi3510/snap.cgi?&-getstream" 1>/dev/null 2>&1 &
			
			LogFull ".   cvlc -q --sout #transcode{acodec=mp4a,ab=128,channels=2,samplerate=44100}:std{accesle,mux=mp4,dst=$newVideoFile} $camUrl"
			cvlc --sout "#transcode{acodec=mp4a,ab=32,channels=2,samplerate=44100}:std{access=file,mux=mp4,dst=$newVideoFile}" $camUrl &>/$CAMERA_CONF_FILE"$camName"".log" &						
			
			vlcPid=$!
			RegisterNewRecordProcessPid $vlcPid
			sleep 1
		fi
	done < $CAMERA_CONF_FILE
}

#-----------------------------------------------------------------------------------------------------------------------#
RegisterNewRecordProcessPid()
{
	LogFull "  New process pid is : $1"
	echo $1 >> $VLC_RECORD_PROCESSES
}

#-----------------------------------------------------------------------------------------------------------------------#
# Kill all vlc processes ; their pid have been backed up in $VLC_RECORD_PROCESSES file
KillAllRegisteredProcessesPid()
{
	LogFull "Kill all vlc processes"
	
	while read row; do
		killCommand="sudo kill -INT $row"
		LogFull ".   $killCommand"
		$killCommand 2>/dev/null
	done < $VLC_RECORD_PROCESSES_OLD
	
	sudo rm -f $VLC_RECORD_PROCESSES_OLD
}


#-----------------------------------------------------------------------------------------------------------------------#
#-----------------------------------------------------------------------------------------------------------------------#
#                                                  START OF PROGRAM                                                     #
#-----------------------------------------------------------------------------------------------------------------------#
#-----------------------------------------------------------------------------------------------------------------------#
sudo mkdir $LOGDIR 1>/dev/null 2>&1
sudo chmod 777 $LOGDIR 1>/dev/null 2>&1

LogFull "Start of daemon"

sudo mkdir $RUNDIR 2>/dev/null
sudo chmod 777 $RUNDIR 2>/dev/null
sudo chmod 777 $DAEMONPIDFILE 2>/dev/null
sudo echo -n $DAEMONPID > $DAEMONPIDFILE

KillAllRegisteredProcessesPid

while [ $(MustRun) -eq 1 ]; do
	
	# Vérifier que le partage est acessible et remonter le partage
	shareIsAccessible=1
	ls $NASSHARE 1>/dev/null 2>&1
	if [ $? -ne 0 ]; then
		LogFull "Share is not accessible : $NASSHARE"
		shareIsAccessible=0
		ReMount "dlink-2a629f" 		"Volume_1"			"xavier"
		sleep 3
		ls $NASSHARE 1>/dev/null 2>&1		
		if [ $? -eq 0 ]; then
			shareIsAccessible=1
		fi
	fi
	
	if [ $shareIsAccessible -eq 1 ]; then
	
		# Find and remove file created for more than 7 days
		find $NASSHARE/Cam/ -name "*.avi" -mtime +7 | while read filepath; do { echo Remove $filepath; rm -f $filepath; } done
		find $LOGDIR 		-name "*.log" -mtime +7 | while read filepath; do { echo Remove $filepath; rm -f $filepath; } done
		
		LogFull "Process new file loop recording rotation iteration"	
		
		mv $VLC_RECORD_PROCESSES $VLC_RECORD_PROCESSES_OLD
		ProcessRecordingCheckIteration
		sleep 1
		KillAllRegisteredProcessesPid
		
		cpt=0
		while [ $cpt -le 3600 ]; do
			cpt=$(($cpt +1))
			sleep 1
			if [ $(MustRun) -eq 0 ]; then
				cpt=3700
			fi
		done
		
	fi
done

KillAllRegisteredProcessesPid

LogFull "End of daemon"