#!/bin/bash

# WORKS ON MY RBPI 3, with Linux raspberrypi 5.4.51-v7+ ( armv7l )   ,   WITH FFMPEG 4.1.6-1~deb10u1+rpt1      and      VLC media player 3.0.11 Vetinari (revision 3.0.11-0-gdc0c5ced72)

horodate=$(date +"%Y%m%d_%H%M%S")
curmonth=`date +%m`
curday=`date +%d`
curyear=`date +%Y`

scriptName=`basename "$0"`
scriptDirPath=`dirname "$0"`
scriptSessionsDirRoot=/home/pi/$scriptName
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

WAITDURATION=600
WAITDURATIONFORRECORD=$(( WAITDURATION + 63 ))

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
		#camRow=`echo $row | sed -e "s/ //g" | grep "^[^#;]"`
		camRow=`echo $row | grep "^[^#;]"`
		
		if [ "X$camRow" != "X" ]; then
			camName=`echo $camRow | cut -d~ -f1`
			camUrl=`echo $camRow | cut -d~ -f2`  
			camOptions=`echo $camRow | cut -d~ -f3`
			
			LogFull "Process : $camName, $camOptions : "
			
			recordingLogFile="/$sessionDir/"$camName".log"
			
			newVideoFile=$scriptSessionsDirRoot/$(CurrentDateTimeNano)_Grab-$camName.avi
			
			# just a little pb remains : ffmped does not generate logs : we may be have to use 
			#    FFREPORT="level=32:file=/home/pi/CamGrabber.sh/ffmpeg-c2.log"
			#    or some options such as -v verbose, or maybe nostdin
			if [ "$camOptions" = "method1"  ]; then
				camCommand="ffmpeg -t $WAITDURATIONFORRECORD -i $camUrl -vcodec copy $newVideoFile"
				LogFull ".   $camCommand"
				( ffmpeg -t $WAITDURATIONFORRECORD -i $camUrl -vcodec copy $newVideoFile ; sudo cp $newVideoFile $NASSHARE/Cam/ 2>&1 >$recordingLogFile ; sudo rm -f $newVideoFile ) &
			elif [ "$camOptions" = "method2"  ]; then
				camCommand="timeout $WAITDURATIONFORRECORD"s" ffmpeg -use_wallclock_as_timestamps 1 -i $camUrl -vcodec copy $newVideoFile"
				LogFull ".   $camCommand"
				( timeout $WAITDURATIONFORRECORD"s" ffmpeg -use_wallclock_as_timestamps 1 -i $camUrl -vcodec copy $newVideoFile 2>&1 >$recordingLogFile ; sudo cp $newVideoFile $NASSHARE/Cam/ ; sudo rm -f $newVideoFile ) &				
			elif [ "$camOptions" = "method3"  ]; then
				camCommand="timeout $WAITDURATIONFORRECORD"s" cvlc --sout \"#transcode{acodec=mp4a,ab=32,channels=2,samplerate=44100}:std{access=file,mux=mp4,dst=$newVideoFile}\" $camUrl"
				LogFull ".   $camCommand"
				( timeout $WAITDURATIONFORRECORD"s" cvlc --sout "#transcode{acodec=mp4a,ab=32,channels=2,samplerate=44100}:std{access=file,mux=mp4,dst=$newVideoFile}" $camUrl 2>&1 >/$sessionDir/vlc"$camName"".log" ; sudo cp $newVideoFile $NASSHARE/Cam/ ; sudo rm -f $newVideoFile ) &
			else 
				LogFull ".   camOptions is not supported : $camOptions"
			fi

			# to prevent all recording to start at the same time
			#sleep 1
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
				
		ProcessRecordingCheckIteration
		
		cpt=0
		while [ $cpt -le $WAITDURATION ]; do
			cpt=$(($cpt +1))
			sleep 1
			if [ $(MustRun) -eq 0 ]; then
				cpt=$WAITDURATIONFORRECORD
			fi
		done
	fi
done

sudo killall ffmpeg
sudo killall vlc

LogFull "End of : $scriptName $1"