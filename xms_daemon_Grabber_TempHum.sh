#!/bin/bash
### BEGIN INIT INFO
# Provides:          xms_daemon_Grabber_TempHum
# Required-Start:    $remote_fs $syslog
# Required-Stop:     $remote_fs $syslog
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: Démon systemstat
# Description:       Put a long description of the service here
### END INIT INFO

#---- Pour créer un service (service <serviceName> start | stop | status ) : ----#
# sudo ln -s /home/pi/scripts/xms_daemon_Grabber_TempHum.sh /etc/init.d/xms_daemon_Grabber_TempHum.sh
# chmod 777 /etc/init.d/xms_daemon_Grabber_TempHum.sh
# chown pi:pi /etc/init.d/xms_daemon_Grabber_TempHum.sh

#---- Pour mettre ce script au démrrage de rasbian : Nom commence par S pour le démarrage, K pour l'arret. ----#
# sudo ln -s /etc/init.d/xms_daemon_Grabber_TempHum.sh /etc/rc4.d/xms_daemon_Grabber_TempHum.sh
# sudo ln -s /etc/init.d/xms_daemon_Grabber_TempHum.sh /etc/rc5.d/xms_daemon_Grabber_TempHum.sh
# sudo ln -s /etc/init.d/xms_daemon_Grabber_TempHum.sh /etc/rc5.d/xms_daemon_Grabber_TempHum.sh
# etc ...

# ou sudo update-rc.d xms_daemon_Grabber_TempHum.sh defaults 5 (5 est le 5eme à etre exécuté)
# et sudo update-rc.d -f xms_daemon_Grabber_TempHum.sh remove

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

DIR=/home/pi/scripts/python
DAEMONFILENAME=TempHumGrabber.py
DAEMONFULLPATH=$DIR/$DAEMONFILENAME

DAEMONCOMMAND='/usr/bin/python '$DAEMONFULLPATH
if [ -f $DIR/"WirePusherNotificationTokens.conf" ]; then
	DAEMONCOMMAND_ARGS="--i 300 --wirepushertokens="$(cat $DIR/WirePusherNotificationTokens.conf)
else 
	DAEMONCOMMAND_ARGS="--i 300"
fi

scriptSessionsDirRoot=/home/pi/$DAEMONFILENAME

DAEMONPIDFILE=$scriptSessionsDirRoot/$DAEMONFILENAME".pid"
DAEMON_USER=root

#########################################################################################################################
# 										Daemon Functions definition 													#
#########################################################################################################################
. /lib/lsb/init-functions

#-----------------------------------------------------------------------------------------------------------------------#
do_stop () {

    log_daemon_msg "Stopping $scriptName"
	sudo rm -f $DAEMONPIDFILE 	
	sleep 3
	echo ""
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

#-----------------------------------------------------------------------------------------------------------------------#
# 						                         SERVICE DEFINITION START
#-----------------------------------------------------------------------------------------------------------------------#

mkdir $scriptSessionsDirRoot 2>/dev/null
sudo chown pi:pi $scriptSessionsDirRoot

#---------------------- daemon command handling --------------------------#
case "$1" in

    start)
		sudo chmod 777 $DAEMONFULLPATH
		sudo chown pi:pi $DAEMONFULLPATH

		res=$(get_status)
		if [ $res -eq 1 ]; then
			echo "${red}Daemon $scriptName is already running ${reset}"
			exit 1
		fi

		log_daemon_msg "Starting $scriptName"
		sudo start-stop-daemon --start --background  --pidfile $DAEMONPIDFILE --make-pidfile     --user $DAEMON_USER --chuid $DAEMON_USER --exec $DAEMONCOMMAND -- $DAEMONCOMMAND_ARGS
		
		log_daemon_msg "Is $scriptName started :  " $?
		echo ""
		sleep 1
		sudo chmod 777 $DAEMONPIDFILE
		sleep 1
		disp_status
		;;
	stop)
        do_stop
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

