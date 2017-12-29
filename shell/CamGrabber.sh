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

NASSHARE=/media/dlink-2a629f/Partages

LOGDIR=/var/log/$VARDIRNAME
LOGFILE=$LOGDIR/$(CurrentDateTime)_$SCRIPTNAME.log


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
		return 1
	fi
	
	# hote trouvé
	#IFS= 
	ipAndName=$(cat $nmbLookupOutputFile | grep $NetBiosName | grep -v querying | sed -n 1p)
	# fonctionne en bash mais ne fonctionne pas en sh
	# ipAndNameArray="( $ipAndName )"
	# pcIP="${ipAndNameArray[0]}"	 
	# on contourne par exemple comme ceci

	ipAndNameFile=$LOGDIR/"ipAndNameFile"	
	echo $ipAndName > $ipAndNameFile
	ipAndNameWithoutInfSup=$LOGDIR/"ipAndNameWithoutInfSup"
	cat $ipAndNameFile | sed -e s/\</L/g | sed -e s/\>/R/g > $ipAndNameWithoutInfSup
	IFS=' ' read pcIP ccc < $ipAndNameWithoutInfSup
	pcIP=$pcIP
	# je lit le 4e élement dans $pcIP	
	#	tokens=( $string )
	#	pcIP=${tokens[4]}

	echo "$pcIP" | grep '[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*' 1>/dev/null
	if [ $? -ne 0 ]; then 
		LogFull "hôte $NetBiosName non trouvé avec utilitaire nmblookup : $pcIP"
		return 2
	else
		echo -n "ip="$pcIP" "
	fi
		
	# montage
	sudo umount /media/$NetBiosName 2>/dev/null	
	cifsMountError="$LOGDIR/cifs_"$NetBiosName"_"$CifsShare"_errors".log
	cifsMountError=$(echo $cifsMountError | sed -e "s/ /_/g")
	sudo mount -v -t cifs   //$pcIP/"$CifsShare" /media/$NetBiosName -o user=$UserForMount,pass=$PwdForMount,file_mode=0777,dir_mode=0777 1>$cifsMountError 2>&1
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
	
	# Vérifier que le partage est acessible et remonter le partage
	accessible=1
	ls $NASSHARE 1>/dev/null 2>&1
	if [ $? -ne 0 ]; then
		LogFull "Partage inaccessible : $NASSHARE"
		accessible=0
		ReMount "dlink-00c3c7" 		"Volume_1"			"xavier"
		sleep 3
		ls $NASSHARE 1>/dev/null 2>&1		
		if [ $? -eq 0 ]; then
			accessible=1
		fi
	fi
	
	if [ $accessible -eq 1 ]; then
	
		# Recherche et supprime les fichier de plus de 1 jour
		find $NASSHARE/Cam/ -name "*.avi" -mtime +7 | while read filepath; do { echo Remove $filepath; rm -f $filepath; } done
		find $LOGDIR 		-name "*.log" -mtime +7 | while read filepath; do { echo Remove $filepath; rm -f $filepath; } done
		
		newVideoFile=$NASSHARE/Cam/$(CurrentDateTimeNano)_Grab.avi
		LogFull "Process new grab : $newVideoFile"	
		cvlc -q --sout "#transcode{acodec=mp4a,ab=128,channels=2,samplerate=44100}:std{accesle,mux=mp4,dst=$newVideoFile}" "http://192.168.1.84/cgi-bin/hi3510/snap.cgi?&-getstream" 1>/dev/null 2>&1 &
		lastCommandPid=$!
		sleep 1
		sudo kill -INT $oldLastCommandPid 2>/dev/null # Tue le dernier process fils de capture lancé par ce programme
		
		cpt=0
		while [ $cpt -le 3600 ]; do
			cpt=$(($cpt +1))
			sleep 1
			if [ $(MustRun) -eq 0 ]; then
				cpt=3700
			fi
		done
		
		oldLastCommandPid=$lastCommandPid
	fi
done

sudo kill -INT $oldLastCommandPid 2>/dev/null

LogFull "End of daemon"
