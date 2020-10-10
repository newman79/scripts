#!/bin/bash

# Prerequisites :
#
# E1: curl -O https://downloads.rclone.org/v1.41/rclone-v1.41-linux-arm.zip
# Extract zip and copy rclone to /usr/bin, and chmod 777 it
#
# E2: Then enter "rclone config" to add a new connection to your google-drive space
# When finished, a new rclone conf file is generated in /home/pi/.config/rclone/rclone.conf, and looks like this : 
#
# [xms-google-drive]
# type = drive
# client_id = <xxxxxx>
# client_secret = <xxxxxx>
# scope = drive
# root_folder_id =
# service_account_file =
# token = <xxxxx>
#
# E3: sudo chmod 4777 /bin/fusermount
# Previous line seems to be needed to be able to make rclone mount commands working.
#
#
# Optional : make a symlink /etc/rclone/rclone.conf -> /home/pi/.config/rclone/rclone.conf



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
ReMountXmsGoogleDrive()
{		
	fusermount -uz /media/xms-google-drive
	sleep 1
	whoami
	echo "Mounting ...."
	rclone mount "xms-google-drive:" "/media/xms-google-drive"  &
	# --config /home/pi/.config/rclone/rclone.conf
	sleep 1
	
	mountResult=$(CheckXmsGoogleDriveIsMounted)
	CheckValueIs $mountResult 1 "xms-google-drive mount has failed"
	return $mountResult
}

#----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------#
CheckXmsGoogleDriveIsMounted()
{		
	ls /media/xms-google-drive/ 1>/dev/null 2>&1
	result=$?
	
	if [ $result -eq 0 ]; then
		mountResult=$(sudo mount | grep xms-google-drive | wc -l)	
		echo $mountResult
	else
		echo 0
	fi
}


#----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------#
doLoop()
{	
	counter=10

	res=$(ls $pidfile 2>/dev/null | wc -l)
	if [ $res -eq 0 ]; then
		sudo echo $$ > $pidfile	
	fi


	res=$(ls $pidfile 2>/dev/null | wc -l)
	if [ $res -eq 1 ]; then
		psId=$(cat $pidfile)
		if [ "x" == "x"$psId ]; then
			psId=1
		fi
		echo "aaaa" $psId $$
		ps -p $psId -f
		res=$(ps -p $psId -f | grep $scriptName | wc -l)
	fi


	while [ $(MustRun) -eq 1 ]; do

		if [ $counter -gt 9 ]; then
			counter=0
			isStillMount=$(CheckXmsGoogleDriveIsMounted)
			echo [$(CurrentDateTime) $scriptName] "nas mount : $isStillMount"
			if [ $isStillMount -ne 1 ]; then
				ReMountXmsGoogleDrive
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

