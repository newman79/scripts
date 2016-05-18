#!/bin/bash

# Starting listener on some port
# we will run it as deamon and we will send commands to it.

scriptName=`basename "$0"`
dirname=`dirname "$0"`

IP=$(hostname --ip-address)
PORT=1024
DAEMONPIDFILE=/home/pi/$scriptName".pid"
FIFOFILE=/home/pi/$scriptName".fifo"
DAEMONPID=$$

echo "Starting daemon"
echo "PID=$DAEMONPID"
echo $PID > $DAEMONPIDFILE

# Créé un fichier spécial qui est de type FIFO
sudo rm -f $FIFOFILE 2>/dev/null
mknod $FIFOFILE p

count=0
while [ -a $DAEMONPIDFILE ] ; do # If pid file exist, I assume that this daemon shoud run since it is its pid

	echo "Listen for new netcat commands session (alt session with CTRL+C)"
	# lance netcat en mode serveur ; Toutes les commandes (shell) envoyées par réseau à netcat sont transmises par le pipe a /bin/bash qui les exécute
	# la sortie standard de /bin/bash est envoyée dans $FIFOFILE. Comme $FIFOFILE est aussi l'entrée standard de netcat ( < ), la sortie standard de la commande /bin/bash <command>
	# exécutée est envoyée sur l'entrée standard de netcat qui l'envoie donc par réseau au client netcat.
  	netcat  -l -p $PORT < $FIFOFILE |/bin/bash > $FIFOFILE
	# L'option -w 20 fait que le listener s'arrête si un client s'est connecté mais est resté inactif depuis plus de 20s
  	# netcat  -w 20 -l -p $PORT < $FIFOFILE |/bin/bash > $FIFOFILE
done

if [ ! -f $DAEMONPIDFILE ]; then
	echo Le fichier /home/pi/$scriptName".pid" n existe plus
fi

rm $FIFOFILE

echo "Stopping daemon"

# Les client qui veulent utiliser le service feront cela :
# test_host#netcat 10.184.200.22 1024
# uptime
# 20:01pm  up 21 days  5:10,  44 users,  load average: 0.62, 0.61, 0.60
# date
# Tue Jan 28 20:02:00 IST 2014
# punt! (Cntrl+C)
