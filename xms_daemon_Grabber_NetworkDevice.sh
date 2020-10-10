#!/bin/bash
### BEGIN INIT INFO
# Provides:          xms_daemon_Grabber_NetworkDevice
# Required-Start:    $remote_fs $syslog
# Required-Stop:     $remote_fs $syslog
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: Récupere et raffraichit la liste des équipements du réseau local
# Description:       Récupere et raffraichit la liste des équipements du réseau local
### END INIT INFO

#---- Pour créer un service (service <serviceName> start | stop | status ) : ----#
# sudo ln -s /home/pi/scripts/xms_daemon_Grabber_NetworkDevice.sh /etc/init.d/xms_daemon_Grabber_NetworkDevice.sh
# chmod 777 /etc/init.d/xms_daemon_Grabber_NetworkDevice.sh
# chown pi:pi /etc/init.d/xms_daemon_Grabber_NetworkDevice.sh

#---- Pour mettre ce script au démrrage de rasbian : Nom commence par S pour le démarrage, K pour l'arret. ----#
# sudo ln -s /etc/init.d/xms_daemon_Grabber_NetworkDevice.sh /etc/rc4.d/S03xms_daemon_Grabber_NetworkDevice.sh
# sudo ln -s /etc/init.d/xms_daemon_Grabber_NetworkDevice.sh /etc/rc5.d/S03xms_daemon_Grabber_NetworkDevice.sh
# sudo ln -s /etc/init.d/xms_daemon_Grabber_NetworkDevice.sh /etc/rc5.d/xms_daemon_Grabber_NetworkDevice.sh
# etc ...

# ou sudo update-rc.d xms_daemon_Grabber_NetworkDevice.sh defaults 5 (5 est le 5eme à etre exécuté)
# et sudo update-rc.d -f xms_daemon_Grabber_NetworkDevice.sh remove

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
DAEMONFILENAME=NetworkDeviceGrabber.py
DAEMONFULLPATH=$DIR/$DAEMONFILENAME

scriptSessionsDirRoot=/home/pi/$DAEMONFILENAME

DAEMONPIDFILE=$scriptSessionsDirRoot/$DAEMONFILENAME.pid
# This next line determines what user the script runs as. Root generally not recommended but necessary, when, for instance, you are using the Raspberry Pi GPIO from Python.
DAEMON_USER=pi
DAEMON_OPTS=""

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

    start-stop-daemon --start --background --pidfile $DAEMONPIDFILE --make-pidfile --user $DAEMON_USER --chuid $DAEMON_USER --startas $DAEMONFULLPATH -- $DAEMON_OPTS
    log_end_msg $?
	disp_status
}

#-----------------------------------------------------------------------------------------------------------------------#
do_stop () {

    log_daemon_msg "Stopping $scriptName daemon"
	sudo rm -f $DAEMONPIDFILE 2>/dev/null
	sleep 6
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
sudo chmod 777 $scriptSessionsDirRoot
sudo chown pi:pi $scriptSessionsDirRoot

mkdir -p $scriptSessionsDirRoot/cache/NDGrabber 2>/dev/null
sudo chmod 777 $scriptSessionsDirRoot/cache/NDGrabber
sudo chown pi:pi $scriptSessionsDirRoot/cache/NDGrabber

mkdir -p $scriptSessionsDirRoot/devices 2>/dev/null
sudo chmod 777 $scriptSessionsDirRoot/devices
sudo chown pi:pi $scriptSessionsDirRoot/devices

#---------------------- daemon command handling --------------------------#
case "$1" in

    start|stop)
        do_${1}
        ;;
    status)
		disp_status
        ;;
    *)
        echo "Usage: /etc/init.d/$scriptName {start|stop|status}"
        exit 1
        ;;
esac
