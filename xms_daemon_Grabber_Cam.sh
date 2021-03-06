#!/bin/bash
### BEGIN INIT INFO 
# Provides: 		 xms_daemon_Grabber_Cam
# Required-Start:   
# Required-Stop:  
# Default-Start: 	 2 3 4 5
# Default-Stop: 	 0 6 
# Short-Description: Maintien de l'enregistrement des cameras sur mon NAS
# Description: 		 Maintien de l'enregistrement des cameras sur mon NAS
### END INIT INFO

#---- Pour cr�er un service (service <serviceName> start | stop | status ) : ----#
# sudo ln -s /home/pi/scripts/xms_daemon_Grabber_Cam.sh /etc/init.d/xms_daemon_Grabber_Cam.sh
# chmod 777 /etc/init.d/xms_daemon_Grabber_Cam.sh
# chown pi:pi /etc/init.d/xms_daemon_Grabber_Cam.sh

#---- Pour mettre ce script au d�mrrage de rasbian : Nom commence par S pour le d�marrage, K pour l'arret. ----#
# sudo ln -s /etc/init.d/xms_daemon_Grabber_Cam.sh /etc/rc4.d/S03xms_daemon_Grabber_Cam.sh
# sudo ln -s /etc/init.d/xms_daemon_Grabber_Cam.sh /etc/rc5.d/S03xms_daemon_Grabber_Cam.sh
# sudo ln -s /etc/init.d/xms_daemon_Grabber_Cam.sh /etc/rc5.d/xms_daemon_Grabber_Cam.sh
# etc ...

# ou sudo update-rc.d xms_daemon_Grabber_Cam.sh defaults 5 (5 est le 5eme � etre ex�cut�)
# et sudo update-rc.d -f xms_daemon_Grabber_Cam.sh remove
 
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
DAEMONFILENAME=CamGrabber.sh
DAEMONFULLPATH=$DIR/$DAEMONFILENAME

scriptSessionsDirRoot=/home/pi/$DAEMONFILENAME

DAEMONPIDFILE=$scriptSessionsDirRoot/$DAEMONFILENAME.pid
DAEMON_USER=pi
DAEMON_OPTS=""

#########################################################################################################################
# 										Daemon Functions definition 													#
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
	    sudo start-stop-daemon --start --background --pidfile $DAEMONPIDFILE --make-pidfile --user $DAEMON_USER --chuid $DAEMON_USER --startas $DAEMONFULLPATH -- $DAEMON_OPTS
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
    *)
        echo "Usage: /etc/init.d/$scriptName {start|stop|status}"
        exit 1
        ;;
esac
