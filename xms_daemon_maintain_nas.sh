#!/bin/bash
### BEGIN INIT INFO 
# Provides: xmscusto
# Required-Start:   
# Required-Stop:  
# Default-Start: 1 2 3 4 5
# Default-Stop: 0 6 
# Short-Description: Maintien de la connectivité avec mon NAS
# Description: Maintien de la connectivité avec mon NAS
### END INIT INFO

# Pour mettre ce script au démrrage de rasbian : Nom commence par S pour le démarrage, K pour l'arret.
# chmod 777 /etc/init.d/xms_daemon_maintain_nas.sh
# chown pi:pi /etc/init.d/xms_daemon_maintain_nas.sh
# ln -s /etc/init.d/xms_daemon_maintain_nas.sh /etc/rc5.d/S05xms_daemon_maintain_nas.sh
# ln -s /etc/init.d/xms_daemon_maintain_nas.sh /etc/rc5.d/K05xms_daemon_maintain_nas.sh

# ou update-rc.d xms_custo defaults 5 (5 est le 5eme à etre exécuté)
# et update-rc.d -f xms_custo remove
 
#########################################################################################################################
#                                                     Global variables
#########################################################################################################################
horodate=$(date +"%Y%m%d_%H%M%S")
curmonth=`date +%m`
curday=`date +%d`
curyear=`date +%Y`

# colors
red=`tput setaf 1`
green=`tput setaf 2`
reset=`tput sgr0`

scriptName=`basename "$0"`
dirname=`dirname "$0"`
scriptSessionsDirRoot=/home/pi/xms_maintain_nas
sessionDir=$scriptSessionsDirRoot/$horodate
logfile="$sessionDir/$scriptName_$horodate.log"
pidFile=/var/log/MaintainNAS/"$scriptName".pid

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
#                                              Daemon Functions definition 																	
#########################################################################################################################
MustRun()
{
	res=$(ls $pidFile 2>/dev/null | wc -l)	
	echo -n $res
}

#----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------#
ReMountNas()
{		
	sudo umount /media/$NetBiosName 2>/dev/null	

	PwdForMount=`cat /home/pi/scripts/MountLoginPassword.cfg | grep "$NetBiosName " | grep "$UserForMount " | awk '{print $3}' | /home/pi/xmsEncodeDecode -d`
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
	sudo echo $$ > $pidFile	
	
	while [ $(MustRun) -eq 1 ]; do
		
		isStillMount=$(CheckNasIsMounted)
		echo [$(CurrentDateTime) $scriptName] "nas mount : $isStillMount"
		if [ $isStillMount -ne 1 ]; then
			ReMountNas
		fi				
		sleep 5
	done
}

#########################################################################################################################
# 						                         SERVICE DEFINITION START
#########################################################################################################################

#---------------------- daemon command handling --------------------------#
case "$1" in
   'start')
		#---------------------- create new session dir and root folders ------------------------#
		mkdir -p $sessionDir 2>/dev/null

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
   ;;

   'stop')
		sudo rm -f $pidFile
		sleep 2
		echo "stopped"		
   ;;

   'status')
		res=$(ls $pidFile 2>/dev/null | wc -l)
		echo -n "status : "
		if [ $res -eq 1 ]; then 
			echo "${green}ON${reset}"
		else
			echo "${red}OFF${reset}"
		fi
   ;;
esac
#########################################################################################################################
# 						                         SERVICE DEFINITION END
#########################################################################################################################

