#!/bin/bash
### BEGIN INIT INFO
# Provides:          xms_daemon_Grabber_RFSignals
# Required-Start:    $remote_fs $syslog
# Required-Stop:     $remote_fs $syslog
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: Démon RFSignals
# Description:       Put a long description of the service here
### END INIT INFO
# ---------------------------------------------------------------------------------------------------------------------------------------------------------------------#
# Pour créer un service, faire un lien symbolique : ln -s /home/pi/scripts/xms_daemon_<NomDeMonService>.sh /etc/init.d/xms_daemon_<NomDeMonService>.sh
# Pour activer le service au boot
#		sudo update-rc.d -f /etc/init.d/xms_daemon_<NomDeMonService>.sh defaults 5
# 	OU
# 		1) créer un service /etc/init.d/xms_lirc_maintain_svc.sh     et mettre un case in   start), un stop) et un status) dedans.
# 		2) Le start se contentera de faire un  /home/pi/scripts/xms_<program>.sh &
# 		3) Le stop se contentera de supprimer le fichier $DAEMONPIDFILE. Et de vérifier qu'il n'y aie plus de process nommé /etc/init.d/xms_lirc_maintain_svc.sh (avec pidof par exemple)
# 		4) Le status regardera si le fichier $DAEMONPIDFILE et si au moins un process nommé /etc/init.d/xms_lirc_maintain_svc.sh existe bien (avec pidof par exemple)
#  		 Apres cela, on peut faire service xms_lirc_maintain_svc [start|stop|status]
# 		5) Rajouter l'exécution du daemon au démarrage et l'arrêt à l'arrêt du système d'exploitation
#  		ln -s /etc/init.d/xms_lirc_maintain_svc.sh /etc/rc.d/rc3.d/S43_lircd_maintain.sh
# 			ln -s /etc/init.d/x

#Variables globales de ce daemon
DIR=/home/pi/scripts/python/
DAEMON="/home/pi/src/RadioFrequence/RFReceptHandler"
DAEMON_NAME=xms_daemon_Grabber_RFsignals.sh

RUNDIR=/var/run/RFSignalsGrabber
DAEMONPID=$$
#DAEMONPIDFILE=/home/pi/$DAEMON_NAME.pid
DAEMONPIDFILE=$RUNDIR/$DAEMON_NAME.pid
DAEMON_USER=pi
DAEMON_OPTS="-conf=/home/pi/src/RadioFrequence/radioFrequenceSignalConfig.json -call=/var/www/rfirmanager/php/dump.sh"

ARGS[0]="-conf=/home/pi/src/RadioFrequence/radioFrequenceSignalConfig.json"
ARGS[1]="-call=/var/www/rfirmanager/php/dump.sh"

red=`tput setaf 1`
green=`tput setaf 2`
reset=`tput sgr0`

#########################################################################################################################
# 										Daemon Functions definition 													#
#########################################################################################################################
. /lib/lsb/init-functions

#-----------------------------------------------------------------------------------------------------------------------#
do_start () {

	sudo mkdir -p $RUNDIR 2>/dev/null
	sudo chmod 777 $RUNDIR 2>/dev/null

	start-stop-daemon --status --pid $DAEMONPIDFILE
	thestate=$?
	if [ $thestate -eq 0 ]; then
		echo "${green}[Already Running]${reset}"
	else
		log_daemon_msg "Starting $DAEMON_NAME daemon"
		sudo rm -f $DAEMONPIDFILE 1>/dev/null 2>&1
		start-stop-daemon -v --start --background --pidfile $DAEMONPIDFILE --make-pidfile --name $DAEMON_NAME --user root --chuid root --exec $DAEMON -- -conf=/home/pi/src/RadioFrequence/radioFrequenceSignalConfig.json -call=/var/www/rfirmanager/php/dump.sh
		
		log_end_msg $?
		sleep 1
		disp_status	
	fi	
}

#-----------------------------------------------------------------------------------------------------------------------#
do_stop () {

    log_daemon_msg "Stopping $DAEMON_NAME daemon"	
	start-stop-daemon --stop --exec $DAEMON	
	sudo rm -f $DAEMONPIDFILE 1>/dev/null 2>&1
	sleep 1	
	disp_status	
}

#-----------------------------------------------------------------------------------------------------------------------#
disp_status () {

	start-stop-daemon --status --pid $DAEMONPIDFILE
	thestate=$?
	if [ $thestate -eq 0 ]; then
		echo "${green}[Running]${reset}"
	else
		echo "${red}[Stopped]${reset}"
	fi
}

#-----------------------------------------------------------------------------------------------------------------------#
#-----------------------------------------------------------------------------------------------------------------------#
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
exit 0