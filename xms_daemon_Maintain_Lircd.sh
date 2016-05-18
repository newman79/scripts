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
# ---------------------------------------------------------------------------------------------------------------------------------------------------------------------#
# Pour créer un service, faire un lien symbolique : ln -s /etc/init.d/xms_daemon_<NomDeMonService>.sh /home/pi/scripts/xms_daemon_<NomDeMonService>.sh
# Pour activer le service au boot
#		sudo update-rc.d -f /etc/init.d/xms_daemon_<NomDeMonService>.sh defaults 5
# 	OU
# 		1) créer un service /etc/init.d/xms_lirc_maintain_svc.sh     et mettre un case in   start), un stop) et un status) dedans.
# 		2) Le start se contentera de faire un startproc -f -p  $LE_PID_DU_DAEMON /home/pi/scripts/xms_daemon_lircd_maintain.sh
# 		3) Le stop se contentera de supprimer le fichier $DAEMONPIDFILE. Et de vérifier qu'il n'y aie plus de process nommé /etc/init.d/xms_lirc_maintain_svc.sh (avec pidof par exemple)
# 		4) Le status regardera si le fichier $DAEMONPIDFILE et si au moins un process nommé /etc/init.d/xms_lirc_maintain_svc.sh existe bien (avec pidof par exemple)
#  		 Apres cela, on peut faire service xms_lirc_maintain_svc [start|stop|status]
# 		5) Rajouter l'exécution du daemon au démarrage et l'arrêt à l'arrêt du système d'exploitation
#  		ln -s /etc/init.d/xms_lirc_maintain_svc.sh /etc/rc.d/rc3.d/S43_lircd_maintain.sh
# 			ln -s /etc/init.d/xms_lirc_maintain_svc.sh /etc/rc.d/rc3.d/K43_lircd_maintain.sh
#-----------------------------------------------------------------------------------------------------------------------#
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

scriptName=`basename "$0"`
dirname=`dirname "$0"`

#Variables globales de ce daemon
DIR=/home/pi/scripts/shell/
DAEMON=$DIR/MaintainLircd.sh

RUNDIR=/var/run/MaintainLircd
DAEMONPID=$$
DAEMON_NAME=xms_daemon_Maintain_Lircd.sh
DAEMONPIDFILE=$RUNDIR/$DAEMON_NAME.pid
DAEMON_USER=pi

red=`tput setaf 1`
green=`tput setaf 2`
reset=`tput sgr0`

#########################################################################################################################
# 										Daemon Functions definition 													#
#########################################################################################################################
. /lib/lsb/init-functions

#-----------------------------------------------------------------------------------------------------------------------#
do_start () {

	sudo mkdir $RUNDIR 2>/dev/null
	sudo chmod 777 $RUNDIR 2>/dev/null
	
	daemonNotRunning=1
	ls $DAEMONPIDFILE >/dev/null 2>&1
	if [ $? -eq 0 ]; then
		ps -p $(cat $DAEMONPIDFILE 2>/dev/null) 1>/dev/null 2>&1
		daemonNotRunning=$?
	fi
	if [ $daemonNotRunning -eq 0 ]; then
		echo "${red}Daemon $DAEMON_NAME is already running ${reset}"
		return
	fi
    log_daemon_msg "Starting $DAEMON_NAME daemon"
    start-stop-daemon --start --background --pidfile $DAEMONPIDFILE --make-pidfile --user $DAEMON_USER --chuid $DAEMON_USER --startas $DAEMON -- $DAEMON_OPTS
    log_end_msg $?
	sleep 1
	disp_status
}

#-----------------------------------------------------------------------------------------------------------------------#
do_stop () {

    log_daemon_msg "Stopping $DAEMON_NAME daemon"
	sudo rm -f $DAEMONPIDFILE 	
	sleep 3
	disp_status	
}

#-----------------------------------------------------------------------------------------------------------------------#
disp_status () {

	daemonNotRunning=1
	ls $DAEMONPIDFILE >/dev/null 2>&1
	if [ $? -eq 0 ]; then
		ps -p $(cat $DAEMONPIDFILE 2>/dev/null) 1>/dev/null 2>&1
		daemonNotRunning=$?
	fi
	
	echo -n "Status of daemon $DAEMON_NAME : "
	if [ $daemonNotRunning -eq 0 ]; then
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



