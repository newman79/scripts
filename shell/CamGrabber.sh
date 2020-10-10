#!/bin/bash

horodate=$(date +"%Y%m%d_%H%M%S")
curmonth=`date +%m`
curday=`date +%d`
curyear=`date +%Y`

scriptName=`basename "$0"`
scriptDirPath=`dirname "$0"`
scriptSessionsDirRoot=/home/pi/$scriptName
#sessionDir=$scriptSessionsDirRoot/$horodate
sessionDir=$scriptSessionsDirRoot
logfile="$sessionDir/$scriptName_$horodate.log"
pidfile=$scriptSessionsDirRoot/$scriptName.pid
lastlogfile="$scriptSessionsDirRoot/lastlog.log"

NetBiosName="dlink-2a629f"
CifsShare="Volume_1"
UserForMount="xavier"
NASSHARE=/media/$NetBiosName/Partages
CAMERA_CONF_FILE="$scriptDirPath/$scriptName.conf"
VLC_RECORD_PROCESSES="$sessionDir/$scriptName.vlc.pids"
VLC_RECORD_PROCESSES_OLD="$sessionDir/$scriptName.vlc.old.pids"

#########################################################################################################################
#                                                Logs Functions definition
#########################################################################################################################
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

#-----------------------------------------------------------------------------------------------------------------------#
LogFull()
{
	arg1="$1"
	echo [$(CurrentDateTime)][$scriptName] "$arg1"
	sudo echo [$(CurrentDateTime)][$scriptName] "$arg1" >> $logfile
}

#########################################################################################################################
#                                              Functions definition 																	
#########################################################################################################################
ReMountNas()
{
	sudo umount /media/$NetBiosName 2>/dev/null	

	PwdForMount=`cat /home/pi/scripts/MountLoginPassword.cfg | grep "$NetBiosName " | grep "$UserForMount " | awk '{print $3}' | /home/pi/xmsEncodeDecode -d`
	LogFull "sudo mount -v -t cifs   //$NetBiosName/$CifsShare /media/$NetBiosName -o user=$UserForMount,pass=$PwdForMount,file_mode=0777,dir_mode=0777 2>&1"	
	sudo mount -v -t cifs   //$NetBiosName/"$CifsShare" /media/$NetBiosName -o user=$UserForMount,pass=$PwdForMount,file_mode=0777,dir_mode=0777 2>&1
	
	ls /media/$NetBiosName >/dev/null 2>&1
	mountResult=$(sudo mount | grep $NetBiosName | wc -l)
	CheckValueIs $mountResult 1 "nas mount has failed"
	return $mountResult
}

#----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------#
MustRun()
{
	res=$(ls $pidfile 2>/dev/null | wc -l)
	if [ $res -eq 1 ]; then
		psId=$(cat $pidfile)
		if [ "x" == "x"$psId ]; then
			psId=1
		fi
		res=$(ps -p $psId -f | grep $scriptName | wc -l)
	fi
	echo -n $res
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
			cvlc --sout "#transcode{acodec=mp4a,ab=32,channels=2,samplerate=44100}:std{access=file,mux=mp4,dst=$newVideoFile}" $camUrl &>/$sessionDir/"$camName"".log" &						
			
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
KillAllOldRegisteredProcesses()
{
	LogFull "Try to kill all old vlc processes"	
	KillVlcProcessesWithPidInFile $VLC_RECORD_PROCESSES_OLD
}

#-----------------------------------------------------------------------------------------------------------------------#
KillAllCurrentRegisteredProcesses()
{
	LogFull "Try to kill all current vlc processes"	
	KillVlcProcessesWithPidInFile $VLC_RECORD_PROCESSES
}


#-----------------------------------------------------------------------------------------------------------------------#
# Kill all vlc processes from pid of specified file
KillVlcProcessesWithPidInFile()
{
	res=$(ls $1 | grep $1 | wc -l)

	if [ $res -eq 1 ]; then

		while read row; do
			isAVlcProcess=$(ps -p $row -f | grep vlc | wc -l)
			if [ $isAVlcProcess -eq 1 ]; then
				killCommand="sudo kill -INT $row"
				LogFull ".   $killCommand"
				$killCommand 2>/dev/null
			else
				LogFull ".   Process with id $row does not exist or is not a vlc process"
			fi
		done < $1			

	else
		LogFull ".   $1 does not exist"
	fi
}

#---------------------------------------------------------------------------------------#
#--------------------------------------- PROGRAM START ---------------------------------#
#---------------------------------------------------------------------------------------#

#---------------------- create new session dir and root folders ------------------------#
mkdir -p $sessionDir 2>/dev/null

sudo rm -f $lastlogfile
sudo ln -s $logfile $lastlogfile

LogFull "-------------------------------------------------------"
LogFull "Start of : script $scriptName $1"

KillAllOldRegisteredProcesses
KillAllCurrentRegisteredProcesses

res=$(ls $pidfile 2>/dev/null | wc -l)
if [ $res -eq 0 ]; then
	sudo echo $$ > $pidfile	
fi

while [ $(MustRun) -eq 1 ]; do
	
	# Vérifier que le partage est acessible et remonter le partage
	shareIsAccessible=1
	ls $NASSHARE 1>/dev/null 2>&1
	if [ $? -ne 0 ]; then
		LogFull "Share is not accessible : $NASSHARE"
		shareIsAccessible=0
		ReMountNas
		sleep 3
		ls $NASSHARE 1>/dev/null 2>&1		
		if [ $? -eq 0 ]; then
			shareIsAccessible=1
		fi
	fi
	
	if [ $shareIsAccessible -eq 1 ]; then
	
		# Find and remove file created for more than 7 days
		find $NASSHARE/Cam/ -name "*.avi" -mtime +7 | while read filepath; do { echo Remove $filepath; rm -f $filepath; } done
		find $sessionDir	-name "*.log" -mtime +7 | while read filepath; do { echo Remove $filepath; rm -f $filepath; } done
				
		LogFull "Process new file loop recording rotation iteration"	
		# to make sure the file exists
		touch $VLC_RECORD_PROCESSES

		sudo mv $VLC_RECORD_PROCESSES $VLC_RECORD_PROCESSES_OLD

		ProcessRecordingCheckIteration
		sleep 1
		KillAllOldRegisteredProcesses
		
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

KillAllOldRegisteredProcesses
KillAllCurrentRegisteredProcesses

LogFull "End of : $scriptName $1"

