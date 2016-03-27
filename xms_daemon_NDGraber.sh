#!/bin/sh

### BEGIN INIT INFO
# Provides:          myservice
# Required-Start:    $remote_fs $syslog
# Required-Stop:     $remote_fs $syslog
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: Put a short description of the service here
# Description:       Put a long description of the service here
### END INIT INFO

# Change the next 3 lines to suit where you install your script and what you want to call it
DIR=/home/pi/scripts/python/
DAEMON=$DIR/NetworkDeviceGrabber.py
DAEMON_NAME=NDGraber

# Add any command line options for your daemon here
DAEMON_OPTS=""

# This next line determines what user the script runs as.
# Root generally not recommended but necessary if you are using the Raspberry Pi GPIO from Python.
DAEMON_USER=pi

# The process ID of the script when it runs is stored here:
PIDFILE=/var/run/$DAEMON_NAME.svc.pid # custom de Xavier ; attention, ce script a déjà python a déjà un mécanisme
PYTHONPIDFILE=/var/run/NDGraber/$DAEMON_NAME.pid

red=`tput setaf 1`
green=`tput setaf 2`
reset=`tput sgr0`

#########################################################################################################################
# 						Functions definition 																			#
#########################################################################################################################

. /lib/lsb/init-functions

#-----------------------------------------------------------------------------------------------------------------------#
do_start () {
    log_daemon_msg "Starting system $DAEMON_NAME daemon"
    start-stop-daemon --start --background --pidfile $PIDFILE --make-pidfile --user $DAEMON_USER --chuid $DAEMON_USER --startas $DAEMON -- $DAEMON_OPTS
    #start-stop-daemon --start --background --pidfile $PIDFILE --user $DAEMON_USER --chuid $DAEMON_USER --startas $DAEMON -- $DAEMON_OPTS
    log_end_msg $?
}

#-----------------------------------------------------------------------------------------------------------------------#
do_stop () {

    log_daemon_msg "Stopping system $DAEMON_NAME daemon"
    #start-stop-daemon --stop --pidfile $PIDFILE --retry 10
    #log_end_msg $?
	sudo rm -f $PYTHONPIDFILE 2>/dev/null
	sleep 6
	disp_status
}

#-----------------------------------------------------------------------------------------------------------------------#
disp_status () {

	pythonpidFileExist=0
	pythonProcessNotRunning=1
	ls $PYTHONPIDFILE >/dev/null 2>&1
	if [ $? -eq 0 ]; then
		pythonpidFileExist=1
		ps -p $(cat $PYTHONPIDFILE 2>/dev/null) 1>/dev/null 2>&1
		pythonProcessNotRunning=$?
	fi
	
	daemonIsRunning=0
	ps -p $(cat $PIDFILE 2>/dev/null) 1>/dev/null 2>&1
	if [ $? -eq 0 ]; then
		daemonIsRunning=1
	fi
			
	echo -n "Status of daemon $DAEMON_NAME : "
	if [ $daemonIsRunning -eq 1 ]; then
		if [ $pythonProcessNotRunning -eq 0 ]; then
			echo "${green}[Running]${reset}"
		else
			echo "${green}[INCONSISTENT_Running]${reset} : Daemon is still running but no python pid file"
		fi
	else
		if [ $pythonProcessNotRunning -ne 0 ]; then
			echo "${red}[Stopped]${reset}"
		else
			echo "${red}[INCONSISTENT_Stopped]${reset} : Daemon seems to be killed but "
		fi
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
        #status_of_proc "$DAEMON_NAME" "$DAEMON" && exit 0 || exit $? # status_of_proc is a function of /lib/lsb/init-functions
        ;;

    *)
        echo "Usage: /etc/init.d/$DAEMON_NAME {start|stop|restart|reload|force-reload|status}"
        exit 1
        ;;

esac
exit 0