#!/bin/bash
### BEGIN INIT INFO 
# Provides: 		 xms_daemon_maintain_google_drive
# Required-Start:   
# Required-Stop:  
# Default-Start: 	 2 3 4 5
# Default-Stop: 	 0 1 6 
# Short-Description: Maintien de la connectivité avec mon espace google drive
# Description: 		 Maintien de la connectivité avec mon espace google drive
### END INIT INFO

#---- Pour créer un service (service <serviceName> start | stop | status ) : ----#
# sudo ln -s /home/pi/scripts/xms_daemon_maintain_google_drive.sh /etc/init.d/xms_daemon_maintain_google_drive.sh
# chmod 777 /etc/init.d/xms_daemon_maintain_google_drive.sh
# chown pi:pi /etc/init.d/xms_daemon_maintain_google_drive.sh

#---- Pour mettre ce script au démrrage de rasbian : Nom commence par S pour le démarrage, K pour l'arret. ----#
# sudo ln -s /etc/init.d/xms_daemon_maintain_google_drive.sh /etc/rc4.d/S03xms_daemon_maintain_google_drive.sh
# sudo ln -s /etc/init.d/xms_daemon_maintain_google_drive.sh /etc/rc5.d/S03xms_daemon_maintain_google_drive.sh
# sudo ln -s /etc/init.d/xms_daemon_maintain_google_drive.sh /etc/rc5.d/K03xms_daemon_maintain_google_drive.sh
# etc ...

# ou sudo update-rc.d xms_daemon_maintain_google_drive.sh defaults 5 (5 est le 5eme à etre exécuté)
# et sudo update-rc.d -f xms_daemon_maintain_google_drive.sh remove

#########################################################################################################################
#                                                     Global variables
#########################################################################################################################
# colors
red=`tput setaf 1`
green=`tput setaf 2`
reset=`tput sgr0`

scriptName=`basename "$0"`

#dirname=`dirname "$0"`
# DIR=$dirname/shell/   ==> will set DIR to /etc/init.d etc ...

DIR=/home/pi/scripts/shell
DAEMONFILENAME=MaintainGoogleDrive.sh
DAEMONFULLPATH=$DIR/$DAEMONFILENAME

scriptSessionsDirRoot=/home/pi/$DAEMONFILENAME

DAEMONPIDFILE=$scriptSessionsDirRoot/$DAEMONFILENAME.pid
DAEMON_USER=pi
DAEMON_OPTS=""

#########################################################################################################################
#                                              Daemon Functions definition 																	
#########################################################################################################################
. /lib/lsb/init-functions

#-----------------------------------------------------------------------------------------------------------------------#
get_status() {
	res=$(ls $DAEMONPIDFILE 2>/dev/null | wc -l)
	if [ $res -eq 1 ]; then
		psId=$(cat $DAEMONPIDFILE)
		if [ "x" == "x"$psId ]; then
			psId=1
		fi
		res=$(ps -p $psId -f | grep $DAEMONFILENAME | wc -l)
	fi
	echo -n $res
}

#-----------------------------------------------------------------------------------------------------------------------#
disp_status () {
	echo -n "status : "
	res=$(get_status)
	if [ $res -eq 1 ]; then 
		echo "${green}ON${reset}"
	else
		echo "${red}OFF${reset}"
	fi
}

#########################################################################################################################
# 						                         SERVICE DEFINITION START
#########################################################################################################################

mkdir $scriptSessionsDirRoot 2>/dev/null
sudo chown pi:pi $scriptSessionsDirRoot

#---------------------- daemon command handling --------------------------#
case "$1" in
   'start')
		sudo chmod 777 $DAEMONFULLPATH
		sudo chown pi:pi $DAEMONFULLPATH

		res=$(get_status)
		if [ $res -eq 1 ]; then
			echo "${red}Daemon $scriptName is already running ${reset}"
			exit 1
		fi
		log_daemon_msg "Starting $scriptName"
		sudo start-stop-daemon --start --background --pidfile $DAEMONPIDFILE --make-pidfile --user $DAEMON_USER --chuid $DAEMON_USER -g pi --startas $DAEMONFULLPATH -- $DAEMON_OPTS
		log_end_msg $?
		sleep 1
    	;;
   'stop')
		sudo rm -f $DAEMONPIDFILE
		sleep 2
		disp_status
    	;;
   'status')
		disp_status
	    ;;
   'setup')
        sudo ln -s /home/pi/scripts/$scriptName /etc/init.d/$scriptName 2>/dev/null
        sudo ln -s /etc/init.d/$scriptName /etc/rc2.d/S03$scriptName 2>/dev/null
        sudo ln -s /etc/init.d/$scriptName /etc/rc3.d/S03$scriptName 2>/dev/null
        sudo ln -s /etc/init.d/$scriptName /etc/rc4.d/S03$scriptName 2>/dev/null
        sudo ln -s /etc/init.d/$scriptName /etc/rc5.d/S03$scriptName 2>/dev/null
        sudo ln -s /etc/init.d/$scriptName /etc/rc0.d/K03$scriptName 2>/dev/null
        sudo ln -s /etc/init.d/$scriptName /etc/rc1.d/K03$scriptName 2>/dev/null
        sudo ln -s /etc/init.d/$scriptName /etc/rc6.d/K03$scriptName 2>/dev/null
	    echo " Setup done : symbolic os startup handling has been created !"
 	   	;;
   *)
        echo "Usage: /etc/init.d/$scriptName {start|stop|status}"
        exit 1
	    ;;
esac
