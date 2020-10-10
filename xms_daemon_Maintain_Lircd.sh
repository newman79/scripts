#!/bin/bash
### BEGIN INIT INFO
# Provides:          xms_daemon_lircd_maintain
# Required-Start:    
# Required-Stop:     
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: Démon qui maintient le daemon lircd (qui est plutot instable ... crash du plugin USB_IRTOY)
# Description:       Démon qui maintient le daemon lircd (qui est plutot instable ... crash du plugin USB_IRTOY)
### END INIT INFO

#---- Pour créer un service (service <serviceName> start | stop | status ) : ----#
# sudo ln -s /home/pi/scripts/xms_daemon_Maintain_Lircd.sh /etc/init.d/xms_daemon_Maintain_Lircd.sh
# chmod 777 /etc/init.d/xms_daemon_Maintain_Lircd.sh
# chown pi:pi /etc/init.d/xms_daemon_Maintain_Lircd.sh

#---- Pour mettre ce script au démrrage de rasbian : Nom commence par S pour le démarrage, K pour l'arret. ----#
# sudo ln -s /etc/init.d/xms_daemon_Maintain_Lircd.sh /etc/rc4.d/S03xms_daemon_Maintain_Lircd.sh
# sudo ln -s /etc/init.d/xms_daemon_Maintain_Lircd.sh /etc/rc5.d/S03xms_daemon_Maintain_Lircd.sh
# sudo ln -s /etc/init.d/xms_daemon_Maintain_Lircd.sh /etc/rc5.d/K03xms_daemon_Maintain_Lircd.sh
# etc ...

# ou sudo update-rc.d xms_daemon_Maintain_Lircd.sh defaults 5 (5 est le 5eme à etre exécuté)
# et sudo update-rc.d -f xms_daemon_Maintain_Lircd.sh remove

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
DAEMONFILENAME=MaintainLircd.sh
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

#-----------------------------------------------------------------------------------------------------------------------#
do_start () {
	sudo chmod 777 $DAEMONFULLPATH
	sudo chown pi:pi $DAEMONFULLPATH
	
	res=$(get_status)
	if [ $res -eq 1 ]; then
		echo "${red}Daemon $scriptName is already running ${reset}"
		exit 1
	fi
    log_daemon_msg "Starting $DAEMON_NAME daemon"
    start-stop-daemon --start --background --pidfile $DAEMONPIDFILE --make-pidfile --user $DAEMON_USER --chuid $DAEMON_USER --startas $DAEMONFULLPATH -- $DAEMON_OPTS
    log_end_msg $?
	sleep 1
	disp_status
}

#########################################################################################################################
# 						                         SERVICE DEFINITION START
#########################################################################################################################

mkdir $scriptSessionsDirRoot 2>/dev/null
sudo chown pi:pi $scriptSessionsDirRoot

#---------------------- daemon command handling --------------------------#
case "$1" in

    start)
		do_start
		;;
	stop)
        log_daemon_msg "Stopping $scriptName daemon"
		sudo rm -f $DAEMONPIDFILE 	
		sleep 3
		disp_status	
        ;;
    status)
		disp_status			
        ;;
    *)
        echo "Usage: /etc/init.d/$DAEMON_NAME {start|stop|status}"
        exit 1
        ;;
esac
