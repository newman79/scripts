#!/bin/bash

horodate=$(date +"%Y%m%d_%H%M%S")
curmonth=`date +%m`
curday=`date +%d`
curyear=`date +%Y`

scriptName=`basename "$0"`
scriptSessionsDirRoot=/home/pi/$scriptName
sessionDir=$scriptSessionsDirRoot/$horodate
logfile="$sessionDir/$scriptName_$horodate.log"
pidfile=$scriptSessionsDirRoot/$scriptName.pid
lastlogfile="$scriptSessionsDirRoot/lastlog.log"

NetBiosName=dlink-2a629f
CifsShare=Volume_1
UserForMount=xavier

#########################################################################################################################
#                                                Logs Functions definition
#########################################################################################################################
CurrentDateTime()
{
	res=$(date +"%Y%m%d_%H%M%S")
	echo $res
}
#-----------------------------------------------------------------------------------------------------------------------#
Log()
{
	arg1="$1"
	arg2="$2"
	if [ ! X$arg2 = X ]; then
		if [ "$arg2" = "1" ]; then
				echo "${red}$arg1${reset}"
		else
			if [ "$arg2" = "0" ]; then
				echo "${green}$arg1${reset}"
			else
				echo "$arg1"
			fi
		fi
	else
		echo "$arg1"
	fi

	echo "$arg1" >> $logfile
}
#-----------------------------------------------------------------------------------------------------------------------#
LogFull()
{
	arg1="$1"
	echo [$(CurrentDateTime) $scriptName] "$arg1"
	echo [$(CurrentDateTime) $scriptName] "$arg1" >> $logfile
}

#-----------------------------------------------------------------------------------------------------------------------#
CheckValueIs()
{
	Value=$1
	GoodValue=$2
	LibelleIfNotOK=$3
	LibelleIfOK=$4

	if [ $Value -ne $GoodValue ]; then
		Log "$LibelleIfNotOK" 1
	else
		if [ ! "X$LibelleIfOK"  = "X" ]; then
			Log "$LibelleIfOK" 0
		else
			Log " : OK" 0
		fi
	fi
}

#########################################################################################################################
#                                              Functions definition 																	
#########################################################################################################################
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

#----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------#
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
CheckNasIsMounted()
{
	mountResult=$(sudo mount | grep $NetBiosName | wc -l)
	echo $mountResult
}

#----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------#
doLoop()
{	
	counter=10

	res=$(ls $pidfile 2>/dev/null | wc -l)
	if [ $res -eq 0 ]; then
		sudo echo $$ > $pidfile	
	fi

	while [ $(MustRun) -eq 1 ]; do

		if [ $counter -gt 9 ]; then
			counter=0
			isStillMount=$(CheckNasIsMounted)
			echo [$(CurrentDateTime) $scriptName] "nas mount : $isStillMount"
			if [ $isStillMount -ne 1 ]; then
				ReMountNas
			fi
		fi

		sleep 1
		counter=$((counter + 1))
	done
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

#-------------------- Remove old sessions : history = 1 year -----------------#
LogFull "Removing old sessions"
for element in `ls -l $scriptSessionsDirRoot | sort -r | awk '$5 {print $9}'`
do
	#	IFS="_" read -ra jourHoraire<<<$element	
	jour=$(echo $element | cut -f1 -d_)
	horaire=$(echo $element | cut -f2 -d_)
	previousyear=$(($curyear-1))
	dateToCompare=$previousyear$curmonth$curday

	if [ $jour -gt $dateToCompare ]; then
		echo -n "" # must keep $element
	else
		LogFull "Remove session : $element" 
		rm -r -f $/$element
	fi
done
			
LogFull "Started : $scriptName $1"
doLoop

LogFull "End of : $scriptName $1"
