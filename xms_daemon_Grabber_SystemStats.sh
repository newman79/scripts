#!/bin/bash
### BEGIN INIT INFO
# Provides:          xms_daemon_Grabber_SystemStat
# Required-Start:    $remote_fs $syslog
# Required-Stop:     $remote_fs $syslog
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: Enregistre/historise l'état du systeme
# Description:       Enregistre/historise l'état du systeme
### END INIT INFO

#---- Pour créer un service (service <serviceName> start | stop | status ) : ----#
# sudo ln -s /home/pi/scripts/xms_daemon_Grabber_SystemStat.sh /etc/init.d/xms_daemon_Grabber_SystemStat.sh
# chmod 777 /etc/init.d/xms_daemon_Grabber_SystemStat.sh
# chown pi:pi /etc/init.d/xms_daemon_Grabber_SystemStat.sh

#---- Pour mettre ce script au démrrage de rasbian : Nom commence par S pour le démarrage, K pour l'arret. ----#
# sudo ln -s /etc/init.d/xms_daemon_Grabber_SystemStat.sh /etc/rc4.d/S03xms_daemon_Grabber_SystemStat.sh
# sudo ln -s /etc/init.d/xms_daemon_Grabber_SystemStat.sh /etc/rc5.d/S03xms_daemon_Grabber_SystemStat.sh
# sudo ln -s /etc/init.d/xms_daemon_Grabber_SystemStat.sh /etc/rc5.d/K03xms_daemon_Grabber_SystemStat.sh
# etc ...

# ou sudo update-rc.d xms_daemon_Grabber_SystemStat.sh defaults 5 (5 est le 5eme à etre exécuté)
# et sudo update-rc.d -f xms_daemon_Grabber_SystemStat.sh remove
 
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

DIR=/home/pi/scripts/python/
DAEMONFILENAME=SystemStatGrabber.py
DAEMONFULLPATH=$DIR/$DAEMONFILENAME

scriptSessionsDirRoot=/home/pi/$DAEMONFILENAME

DAEMONPIDFILE=$scriptSessionsDirRoot/$DAEMONFILENAME.pid
DAEMON_USER=pi
DAEMON_OPTS="-i 300"

#########################################################################################################################
# 										Daemon Functions definition 													#
#########################################################################################################################
. /lib/lsb/init-functions

#-----------------------------------------------------------------------------------------------------------------------#
do_start () {
	sudo chmod 777 $DAEMONFULLPATH
	sudo chown pi:pi $DAEMONFULLPATH

	res=$(get_status)
	if [ $res -eq 1 ]; then
		echo "${red}Daemon $scriptName is already running ${reset}"
		exit 1
	fi
	log_daemon_msg "Starting $scriptName"

    start-stop-daemon -v --start --background --pidfile $DAEMONPIDFILE --make-pidfile --user $DAEMON_USER --chuid $DAEMON_USER --startas $DAEMONFULLPATH -- $DAEMON_OPTS
    log_end_msg $?
	disp_status
}

#-----------------------------------------------------------------------------------------------------------------------#
do_stop () {

    log_daemon_msg "Stopping $scriptName daemon"
	sudo rm -f $DAEMONPIDFILE 2>/dev/null
	sleep 3
	disp_status
}

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

mkdir -p $scriptSessionsDirRoot 2>/dev/null


#---------------------- daemon command handling --------------------------#
case "$1" in

    start|stop)
        do_${1}
        ;;
    restart|reload|force-reload)
        do_stop
        do_start
        ;;
    status)
		disp_status			
        ;;
    *)
        echo "Usage: /etc/init.d/$DAEMON_NAME {start|stop|restart|reload|force-reload|status}"
        exit 1
        ;;
esac
