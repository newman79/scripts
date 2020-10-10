#!/bin/bash
### BEGIN INIT INFO
# Provides:          xms_daemon_Grabber_RFSignals
# Required-Start:    $remote_fs $syslog
# Required-Stop:     $remote_fs $syslog
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: Récupère les signaux 433Mghz
# Description:       Récupère les signaux 433Mghz
### END INIT INFO

#---- Pour créer un service (service <serviceName> start | stop | status ) : ----#
# sudo ln -s /home/pi/scripts/xms_daemon_Grabber_RFSignals.sh /etc/init.d/xms_daemon_Grabber_RFSignals.sh
# chmod 777 /etc/init.d/xms_daemon_Grabber_RFSignals.sh
# chown pi:pi /etc/init.d/xms_daemon_Grabber_RFSignals.sh

#---- Pour mettre ce script au démrrage de rasbian : Nom commence par S pour le démarrage, K pour l'arret. ----#
# sudo ln -s /etc/init.d/xms_daemon_Grabber_RFSignals.sh /etc/rc4.d/S03xms_daemon_Grabber_RFSignals.sh
# sudo ln -s /etc/init.d/xms_daemon_Grabber_RFSignals.sh /etc/rc5.d/S03xms_daemon_Grabber_RFSignals.sh
# sudo ln -s /etc/init.d/xms_daemon_Grabber_RFSignals.sh /etc/rc5.d/xms_daemon_Grabber_RFSignals.sh
# etc ...

# ou sudo update-rc.d xms_daemon_Grabber_RFSignals.sh defaults 5 (5 est le 5eme à etre exécuté)
# et sudo update-rc.d -f xms_daemon_Grabber_RFSignals.sh remove

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

DIR=/home/pi/src/RadioFrequence
DAEMONFILENAME=RFReceptHandler
DAEMONFULLPATH=$DIR/$DAEMONFILENAME

scriptSessionsDirRoot=/home/pi/$DAEMONFILENAME

DAEMONPIDFILE=$scriptSessionsDirRoot/$DAEMONFILENAME.pid
DAEMON_USER=pi
DAEMON_OPTS="-conf=/home/pi/src/RadioFrequence/radioFrequenceSignalConfig.json -call=/var/www/rfirmanager/php/dump.sh"

red=`tput setaf 1`
green=`tput setaf 2`
reset=`tput sgr0`

#########################################################################################################################
# 										Daemon Functions definition 													#
#########################################################################################################################
. /lib/lsb/init-functions

#-----------------------------------------------------------------------------------------------------------------------#
do_start () {
	sudo chmod 777 $DAEMONFULLPATH
	sudo chown pi:pi $DAEMONFULLPATH

	start-stop-daemon --status --pid $DAEMONPIDFILE
	state=$?
	if [ $state -eq 0 ]; then
		echo "${green}[Already Running]${reset}"
	else
		log_daemon_msg "Starting $scriptName"
		sudo rm -f $DAEMONPIDFILE 1>/dev/null 2>&1
		sudo start-stop-daemon --start --background --pidfile $DAEMONPIDFILE --make-pidfile --user root --chuid root --exec $DAEMONFULLPATH -- -conf=/home/pi/src/RadioFrequence/radioFrequenceSignalConfig.json -call=/var/www/rfirmanager/php/dump.sh
		
		log_end_msg $?
		sleep 1
		disp_status	
	fi	
}

#-----------------------------------------------------------------------------------------------------------------------#
do_stop () {

    log_daemon_msg "Stopping $scriptName"
	sudo killall $DAEMONFILENAME
	sudo rm -f $DAEMONPIDFILE 1>/dev/null 2>&1
	sleep 1	
	disp_status	
}

#-----------------------------------------------------------------------------------------------------------------------#
disp_status () {
	if [ -f $DAEMONPIDFILE ]; then
		pid=$(cat $DAEMONPIDFILE)
		start-stop-daemon --status --pid $pid
		state=$?
	else
		state=1
	fi

	if [ $state -eq 0 ]; then
		echo "${green}[Running]${reset}"
	else
		echo "${red}[Stopped]${reset}"
	fi
}

#########################################################################################################################
# 						                         SERVICE DEFINITION START
#########################################################################################################################
mkdir -p $scriptSessionsDirRoot 2>/dev/null
sudo chmod 777 $scriptSessionsDirRoot
sudo chown pi:pi $scriptSessionsDirRoot

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
        echo "Usage: /etc/init.d/$scriptName {start|stop|restart|reload|force-reload|status}"
        exit 1
        ;;
esac
exit 0
