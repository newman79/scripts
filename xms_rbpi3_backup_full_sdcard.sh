#!/bin/bash
# Usage instructions at http://www.megaleecher.net/Best_Raspberry_Pi_Hot_Backup_Shell_Script
# This version disables backup image compression as it takes too much time on Pi, to enable uncomment the relavent lines
# Setting up directories, Just change SUBDIR and BACKUP_DIR varibales below to get going
#########################################################################################################################
# 						Global variables																				#
#########################################################################################################################
OWNER=owner
horodate=$(date +"%Y%m%d_%H%M%S")
curmonth=`date +%m`
curday=`date +%d`
curyear=`date +%Y`

scriptName=`basename "$0"`
dirname=`dirname "$0"`
sessionDirParent=/var/log/xms_backup_full_sdcard
sessionDir=$sessionDirParent/$horodate
logfile="$sessionDir/main_$horodate.log"
# colors
red=`tput setaf 1`
green=`tput setaf 2`
reset=`tput sgr0`

HOSTNAME=dlink-2a629f
SHARE=Partages
RBPI_VERSION=RBPI3
SUBDIR="ImageSystem"$RBPI_VERSION
BACKUP_DIR=/media/$HOSTNAME/$SHARE/$SUBDIR

#########################################################################################################################
# 						Functions definition 																			#
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
LogOnLine()
{
	arg1="$1"
	echo -n [$(CurrentDateTime) $scriptName] "$arg1"
	echo -n [$(CurrentDateTime) $scriptName] "$arg1" >> $logfile
}

#-----------------------------------------------------------------------------------------------------------------------#
AssertOrQuitValueIs()
{
	Value=$1
	GoodValue=$2
	LibelleOK=$3
	LibelleEchec=$4

	if [ $Value -ne $GoodValue ]; then
		echo "$LibelleEchec"
		exit 1
	else 
		echo "$LibelleOK"
	fi
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
#########################################################################################################################
# 						DEBUT TRAITEMENT					 															#
#########################################################################################################################
#########################################################################################################################
#------------------------- Créer la nouvelle session ----------------------------#
sudo mkdir -p $sessionDir
#sudo touch /var/lock/$scriptName
AssertOrQuitValueIs $? 0 " $scriptName : nouvelle session créée" "$scriptName FATAL : echec de creation nouvelle session, le programme s arrete"

sudo chown -R pi:pi $sessionDir
AssertOrQuitValueIs $? 0 "Changement owner/group du repertoire de session OK" "Changement owner/group du repertoire de session KO"

sudo chmod 777 $sessionDir
AssertOrQuitValueIs $? 0 "Mise en place permission repertoire de log OK" "Mise en place permission repertoire de log KO"
#sudo chmod 666 $logfile
#AssertOrQuitValueIs $? 0 "Mise en place permission fichier de log OK" "Mise en place permission fichier de log KO"

LogFull "Debut traitement"
SCRIPT_LAUCNHED_WITH=$(whoami)
LogFull "Script executed by user : $SCRIPT_LAUCNHED_WITH"

# First check if pv package is installed, if not, install it first
PACKAGESTATUS=`dpkg -s pv | grep Status`;

which pv | grep 'pv' 1>/dev/null 2>&1
if [ $? -eq 0 ]; then
	LogFull "Package 'pv' is installed"
else
    LogFull "Package 'pv' is NOT installed."
    LogFull "Installing package 'pv'. Please wait..."
    sudo apt-get -yq install pv
fi
which pv | grep 'pv' 1>/dev/null 2>&1
if [ $? -ne 0 ]; then
	LogFull "Package 'pv' is NOT installed, or is not accessible. Aborting, exiting with code 1"
	exit 1
fi

# Check if backup directory exists
if [ ! -d "$BACKUP_DIR" ]; then
    LogFull "Backup directory $BACKUP_DIR doesn't exist, exiting with code 2"
	exit 2
fi

# Create a filename with datestamp for our current backup (without .img suffix)
OUTFILE="$BACKUP_DIR/$(date +%Y%m%d.%H%M%S)_backup_sdcard_allparts_mmcblk0p2_et_mmcblk0p1"

# Shut down some services before starting backup process
LogFull "Stopping main services before backup"


sudo service  xms_daemon_Grabber_RFsignals.sh		stop 1>/dev/null 2>&1
sudo service  xms_daemon_Grabber_Cam.sh				stop 1>/dev/null 2>&1
sudo service  xms_daemon_Grabber_NetworkDevice.sh	stop 1>/dev/null 2>&1
sudo service  xms_daemon_Grabber_SystemStats.sh		stop 1>/dev/null 2>&1
sudo service  xms_daemon_Maintain_Lircd.sh			stop 1>/dev/null 2>&1
sudo service  xms_daemon_maintain_nas.sh			stop 1>/dev/null 2>&1
sudo service  xms_daemon_maintain_google_drive.sh	stop 1>/dev/null 2>&1

sudo service tomcat8 								stop 1>/dev/null 2>&1
sudo service apache2 								stop 1>/dev/null 2>&1
sudo service mysql 									stop 1>/dev/null 2>&1
sudo service cron 									stop 1>/dev/null 2>&1
sudo service shellinabox							stop 1>/dev/null 2>&1

# Begin the backup process, should take about 1 hour from 8Gb SD card to HDD
LogFull "Backing up SD card to USB HDD"
LogFull "This will take some time depending on your SD card size and read performance. Please wait..."

# First sync disks
sync; sync
sleep 3


LogFull "Backup has started ..."

#SDSIZE=`sudo blockdev --getsize64 /dev/mmcblk0`;
#sudo pv -tpreb /dev/mmcblk0 -s $SDSIZE | dd of=$OUTFILE bs=1M conv=sync,noerror iflag=fullblock

EMPTY_SPACE_AFTER=1000000
STARTP2=`sudo blockdev --report /dev/mmcblk0p2 | grep /dev/mmcb | sed -e "s/\s\+/ /g" | cut -d' ' -f5`
SIZEP2=`sudo blockdev --getsize64 /dev/mmcblk0p2`;
COUNT=1000000
SDSIZEINBYTE=$(($STARTP2+$SIZEP2+$EMPTY_SPACE_AFTER))
SDSIZE=$(( $SDSIZEINBYTE/$COUNT ))
sudo pv -tpreb /dev/mmcblk0 -s $SDSIZEINBYTE | dd of=$OUTFILE bs=$SDSIZE count=$COUNT

# Wait for DD to finish and catch result
RESULT=$?
LogFull "Backup is done !"

# Start services again that where shutdown before backup process
LogFull "Start the stopped services again"
sudo service mysql 									start 1>/dev/null 2>&1
sudo service apache2 								start 1>/dev/null 2>&1
sudo service cron 									start 1>/dev/null 2>&1
sudo service tomcat8.sh							start 1>/dev/null 2>&1

sudo service  xms_daemon_Grabber_Cam.sh				start 1>/dev/null 2>&1
#sudo service  xms_daemon_Grabber_NetworkDevice.sh	start 1>/dev/null 2>&1
#sudo service  xms_daemon_Grabber_SystemStats.sh	start 1>/dev/null 2>&1
#sudo service  xms_daemon_Maintain_Lircd.sh			start 1>/dev/null 2>&1
#sudo service  xms_daemon_Grabber_RFsignals.sh		stop 1>/dev/null 2>&1
sudo service  xms_daemon_maintain_nas.sh			start 1>/dev/null 2>&1
sudo service  xms_daemon_maintain_google_drive.sh	start 1>/dev/null 2>&1


# If command has completed successfully, delete previous backups and exit
if [ $RESULT = 0 ]; then
    LogFull "Successful backup"	
	# Create final filename, with suffix
	OUTFILEFINAL=$OUTFILE.img
	
    mv $OUTFILE $OUTFILEFINAL
    #LogFull "Backup is being tarred. Please wait..."
    #tar zcf $OUTFILEFINAL.tar.gz $OUTFILEFINAL
    # rm -rf $OUTFILEFINAL
    LogFull "Backup completed, FILE: $OUTFILEFINAL"
	
    LogFull "Process sessions directories purge"
	# Remove oldest sessions dir
	for element in `ls -l $sessionDirParent | sort -r | awk '$5 {print $9}'`
	do
		jour=$(echo $element | cut -f1 -d_)
		horaire=$(echo $element | cut -f2 -d_)
		previousyear=$(($curyear-3))
		dateToCompare=$previousyear$curmonth$curday

		if [ $jour -gt $dateToCompare ]; then
			echo -n "" # must keep $element
		else
			LogFull "Suppression de la session $element" 
			sudo rm -r -f $sessionDirParent/$element
		fi
	done
    LogFull "Process backups purge"
	for element in `ls -l $BACKUP_DIR | grep 'backup_sdcard_allparts_mmcblk0p2_et_mmcblk0p1.img' | sort -r | awk '$5 {print $9}'`
	do
		datetime=$(echo $element | cut -f1 -d_)		
		jour=$(echo $datetime | cut -f1 -d.)
		horaire=$(echo $element | cut -f2 -d.)
		previousyear=$(($curyear-1))
		dateToCompare=$previousyear$curmonth$curday
		if [ $jour -gt $dateToCompare ]; then
			LogFull "Conservation du backup $element" 
			echo -n "" # must keep $element
		else
			LogFull "Suppression du backup $element" 
			sudo rm -r -f $BACKUP_DIR/$element
		fi
	done	
	
	mail -s $RBPI_VERSION"_SDCARD_BACKUP_OK_$(CurrentDateTime)" xavier.marquis@gmail.com < $logfile
	if [ $? -eq 0 ]; then
		LogFull "Mail envoyé"
	else
		LogFull "Le n'a pas pu être envoyé"
	fi
	LogFull "Fin traitement"
    exit 0
# Else remove attempted backup file
else
    LogFull "Backup failed! Previous backup files untouched"
    LogFull "Please check space on target and target's network share authorization"
    sudo rm -f $OUTFILE
    LogFull "Echec traitement"
    exit 3
fi

#########################################################################################################################
#########################################################################################################################
# 						FIN TRAITEMENT				 																	#
#########################################################################################################################
#########################################################################################################################
