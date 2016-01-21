#!/bin/bash
# Démon qui doit normalement maintenir le démon LIRCD actif malgré les crash du plugin USB_IRTOY
# Pour créer un service
# 		1) créer un service /etc/init.d/xms_lirc_maintain_svc.sh     et mettre un case in   start), un stop) et un status) dedans.
# 		2) Le start se contentera de faire un startproc -f -p  $LE_PID_DU_DAEMON /home/pi/scripts/xms_daemon_lircd_maintain.sh
# 		3) Le stop se contentera de supprimer le fichier $DAEMONPIDFILE. Et de vérifier qu'il n'y aie plus de process nommé /etc/init.d/xms_lirc_maintain_svc.sh (avec pidof par exemple)
# 		4) Le status regardera si le fichier $DAEMONPIDFILE et si au moins un process nommé /etc/init.d/xms_lirc_maintain_svc.sh existe bien (avec pidof par exemple)
#  		 Apres cela, on peut faire service xms_lirc_maintain_svc [start|stop|status]
# 		5) Rajouter l'exécution du daemon au démarrage et l'arrêt à l'arrêt du système d'exploitation
#  		ln -s /etc/init.d/xms_lirc_maintain_svc.sh /etc/rc.d/rc3.d/S43_lircd_maintain.sh
# 			ln -s /etc/init.d/xms_lirc_maintain_svc.sh /etc/rc.d/rc3.d/K43_lircd_maintain.sh

scriptName=`basename "$0"`
dirname=`dirname "$0"`

#Variables globales de ce daemon
DAEMONPIDFILE=$dirname/$scriptName".pid"
DAEMONPID=$$

logfile=/home/pi/$scriptName.log

# Variables globales liées à LIRCD
LIRCDLOGFILE=/home/pi/domotique/IR_remotes/lircd.log
LIRCDLISTENPORT=49999

CurrentDateTime()
{
	res=$(date +"%Y%m%d_%H%M%S")
	echo $res
}

#-----------------------------------------------------------------------------------------------------------------------#
LogFull()
{
	arg1="$1"
	echo [$(CurrentDateTime) $scriptName] "$arg1"
	echo [$(CurrentDateTime) $scriptName] "$arg1" >> $logfile
}


#-----------------------------------------------------------------------------------------------------------------------#
# Identify usb branch of a device given its idVendor and its idProduct
#-----------------------------------------------------------------------------------------------------------------------#
function IdentifyUsbBranchWith_IdVendorAndIdProduct()
{
	if [ X$1 = X ]; then
		echo "IdentifyUsbBranchWith _IdVendorAndIdProduct need 2 arguments in call"
		return 1
	fi

	if [ X$2 = X ]; then
		echo "IdentifyUsbBranchWith _IdVendorAndIdProduct need 2 arguments in call"
		return 1
	fi

	idVendor="$1"
	idProduct="$2"	

	for deviceFullNum in `ls /sys/bus/usb/devices/*/idVendor | awk 'BEGIN { FS = "/" } ; {print $6}' `
	do
		devVendor=`cat /sys/bus/usb/devices/$deviceFullNum/idVendor`
		devProduct=`cat /sys/bus/usb/devices/$deviceFullNum/idProduct`

		if [  "$idVendor" = "$devVendor" ]; then
			if [ "$idProduct" = "$devProduct" ]; then
				break
			fi
		fi
	done
	echo $deviceFullNum
}

#-----------------------------------------------------------------------------------------------------------------------#
# Unbind USB Device At specified Usb Branch
#-----------------------------------------------------------------------------------------------------------------------#
function UnbindUSBDeviceAtUsbBranch()
{
	if [ X$1 = X ]; then
		LogFull "UnbindUSBDeviceAtUsbBranch : argument 'usbbranch' is not specified"
		return 1
	fi	
	usbbranch=$1
	LogFull "Unbind device at following usb branch : $usbbranch"
	sudo sh -c "echo -n "$usbbranch":1.0 >/sys/bus/usb/drivers/cdc_acm/unbind"
	return $?
}

#-----------------------------------------------------------------------------------------------------------------------#
# Bind USB Device At specified Usb Branch
#-----------------------------------------------------------------------------------------------------------------------#
function BindUSBDeviceAtUsbBranch()
{
	if [ X$1 = X ]; then
		LogFull "BindUSBDeviceAtUsbBranch : argument 'usbbranch' is not specified"
		return 1
	fi	
	usbbranch=$1
	LogFull "Bind device at following usb branch : $usbbranch"
	sudo sh -c "echo -n "$usbbranch":1.0 > /sys/bus/usb/drivers/cdc_acm/bind"
	return $?
}

#-----------------------------------------------------------------------------------------------------------------------#
# Kill lircd for usb_irtoy
#-----------------------------------------------------------------------------------------------------------------------#
function KillLircdForUsbIrtoy()
{
	killError=0
	ps ax | grep lircd | grep usb_irtoy | cut -d " " -f2
	arrayOfSuchLircdPid=(`ps ax | grep lircd | grep usb_irtoy | sed 's/^[ \t]*//;s/[ \t]*$//' | cut -d " " -f1`)
	for lircdForUsbIrtoyDaemonPid in $arrayOfSuchLircdPid
	do
		LogFull "Killing lircd process : $lircdForUsbIrtoyDaemonPid"
		sudo kill -9 $lircdForUsbIrtoyDaemonPid	2>/dev/null	
		killError=`expr "$killError" + "$?"`
	done
	return $killError	
}

#-----------------------------------------------------------------------------------------------------------------------#
# Is lircd for usb_irtoy running
#-----------------------------------------------------------------------------------------------------------------------#
function IsLircdForUsbIrtoyRunning()
{
	# Construit un tableau des pid de lircd
	arrayOfSuchLircdPid=(`ps ax | grep lircd | grep usb_irtoy | sed 's/^[ \t]*//;s/[ \t]*$//' | cut -d " " -f1`)
	arrayLength=${#arrayOfSuchLircdPid[@]}
		
	#LogFull "Number of lircd running daemon process for usb_irtoy $arrayLength"	
		
	if [ $arrayLength -eq 0 ]; then
		return 0
	else
		return 1
	fi
}

#-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------#
#-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------#
#-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------#
LogFull "Starting daemon"

# Vérifier que le fichier $DAEMONPIDFILE existe ; si non, alors on considère que ce daemon doit être lancé (le daemon précédent s'est forcément arrêté)
if [ ! -f $DAEMONPIDFILE ]; then
	echo $DAEMONPID > $DAEMONPIDFILE 2>/dev/null
	if [ $? -ne 0 ]; then
		LogFull "Impossible de créer le fichier $DAEMONPID. Le service $scriptName ne peut pas être lancé"
		exit 1
	fi
fi

# Vérifier que le PID de ce process est le même que le pid dans le fichier
pidFromFile=$(cat $DAEMONPIDFILE)
if [ $DAEMONPID -ne $pidFromFile ]; then
	LogFull "$scriptName est déjà démarré"
	exit 2
fi

echo "PID=$DAEMONPID"

sudo mkdir -p /var/run/lirc 1>/dev/null 2>/dev/null

LogFull "$scriptName has been started"

# Boucle principale du daemon. Elle s'arrêtera quand le fichier $DAEMONPIDFILE aura été supprimé.
while [ -a $DAEMONPIDFILE ] ; do # If pid file exist, I assume that this daemon shoud run since it is its pid

	devUsbBranchPath=`IdentifyUsbBranchWith_IdVendorAndIdProduct 04d8 f58b`
	sleep 0.5
	if [[ "X$devUsbBranchPath" == "X" ]]; then
		sleep 2
		LogFull "Le recepteur Irtoy Irdroid n a pas ete detecte par l'OS. Il faut le rebrancher."
		continue
	fi
	
	CDCACMISNOTOK=0	
	tail --lines=4 $LIRCDLOGFILE | grep "No USB Irtoy"
	if [ $? -eq 0 ]; then
		LogFull "Detecting error : No USB Irtoy"
		CDCACMISNOTOK=1
	fi
	tail --lines=4 $LIRCDLOGFILE | grep "usb_irtoy: could not open /dev/ttyACM0"
	if [ $? -eq 0 ]; then
		LogFull "Detecting error : usb_irtoy: could not open /dev/ttyACM0 in $LIRCDLOGFILE"
		CDCACMISNOTOK=1
	fi	
	tail --lines=4 $LIRCDLOGFILE | grep "usb_irtoy: could not create lock files"
	if [ $? -eq 0 ]; then
		LogFull "Detecting error : usb_irtoy: could not create lock files in $LIRCDLOGFILE"
		CDCACMISNOTOK=1
	fi

	# Si lircd a planté à cause du crash connu avec USB Irtoy
	if [ $CDCACMISNOTOK -eq 1 ]; then
		message="Resolution crash plugin USB Irtoy detecte dans le log de LIRCD : $LIRCDLOGFILE ; device=$devUsbBranchPath"
		# cat /proc/bus/input/devices
		LogFull "$message"

		# Arret des instances lircd		
		KillLircdForUsbIrtoy
		sleep 0.1
		IsLircdForUsbIrtoyRunning
		lircdIsWorking=$?		
		if [ $lircdIsWorking -ne 0 ]; then
			LogFull "lircd for usb_irtoy est toujours actif ..."
			break
		fi
		
		UnbindUSBDeviceAtUsbBranch $devUsbBranchPath		
		sleep 0.1
		BindUSBDeviceAtUsbBranch $devUsbBranchPath
		sleep 0.1
		#sudo rmmod cdc_acm
		#sleep 0.1
		#sudo modprobe cdc_acm
		#sleep 0.1
		# Visiblement, meme avec un unbind et bind ca ne marche pas a tous les coup
		# En effet, on retrouve ça dans dmesg :     cdc_acm 1-1.5.3:1.0: failed to set dtr/rts
		# Ou alors c que mon hub usb était mal connecté
		# Non, ça continue ...
		# J'ai meme fait un unbind/bind sur le hub, ce qui me donne une réactivation de tous ses devices sauf l'IrDroid (dmesg montre)
		# 		[mar. déc.  1 08:22:39 2015] usb 1-1.5.3: new full-speed USB device number 27 using dwc_otg
		# 		[mar. déc.  1 08:22:44 2015] usb 1-1.5.3: device descriptor read/64, error -32
		# Je fais un sudo rmmod cdc_acm puis sudo modprobe cdc_acm --> ca donne ca :		
				# [mar. déc.  1 08:22:44 2015] usb 1-1.5.3: device descriptor read/64, error -32
				# [mar. déc.  1 08:22:50 2015] usb 1-1.5.3: device descriptor read/64, error -32
				# [mar. déc.  1 08:22:50 2015] usb 1-1.5.3: new full-speed USB device number 28 using dwc_otg
				# [mar. déc.  1 08:22:55 2015] usb 1-1.5.3: device descriptor read/64, error -32
				# [mar. déc.  1 08:23:00 2015] usb 1-1.5.3: device descriptor read/64, error -32
				# [mar. déc.  1 08:23:00 2015] usb 1-1.5.3: new full-speed USB device number 29 using dwc_otg
				# [mar. déc.  1 08:23:06 2015] usb 1-1.5.3: device not accepting address 29, error -32
				# [mar. déc.  1 08:23:06 2015] usb 1-1.5.3: new full-speed USB device number 30 using dwc_otg
				# [mar. déc.  1 08:23:11 2015] usb 1-1.5.3: device not accepting address 30, error -32
				# [mar. déc.  1 08:23:11 2015] usb 1-1.5-port3: unable to enumerate USB device
				# [mar. déc.  1 08:27:10 2015] usbcore: deregistering interface driver cdc_acm
				# [mar. déc.  1 08:27:15 2015] usbcore: registered new interface driver cdc_acm
				# [mar. déc.  1 08:27:15 2015] cdc_acm: USB Abstract Control Model driver for USB modems and ISDN adapters		
		# cat /dev/ttyACM0 --> permet de revoir le :		 cdc_acm 1-1.5.3:1.0: failed to set dtr/rts		
		# Je viens de changer le cable usb suite à un post sur internet.  Ca ne change rien
		# sudo sh -c "echo 0 > /sys/bus/usb/drivers/usb/1-1.5.1/authorized"			
				# --> dmesg trace 	usb 1-1.5.1: can't set config #1, error -32 
		# sudo sh -c "echo 1 > /sys/bus/usb/drivers/usb/1-1.5.1/authorized"
				# --> dmesg trace usb 1-1.5.1: authorized to connect  et je me rend compte que /dev/ttyACM0 n'existe plus
		# Autres commandes : usb-devices
				
		# Autre probleme : 
		# lircd a l'air de bloquer (deadlock) sur des irsend alors que les meme précédent étaient passés
		# Je n'ai pas trouvé la cause : dmesg ne dit rien et le récepteur à l'air ok, lircd tourne et le lancement de irw ne crache pas d'erreur ....
			# workaround : relancer régulièrement lircd
		 
		
		

		# Ancienne méthode avec usbreset, qui resettait le device usb, mais qui parfois, le désactivait complètement en n'arrivant pas à le trouver
		#		# donne le bus sur lequel est l'IrDroid
		#		thebusnum=$(cat /sys/bus/usb/devices/1-1.5/busnum)
		#		thebusnum=`printf %03d $thebusnum`
		#		# donne le numéro de l'Irdroid sur ce bus USB_transceiver_LIRC
		#		thedevnum=$(cat /sys/bus/usb/devices/1-1.5/devnum)
		#		thedevnum=`printf %03d $thedevnum`
		#		# reset du device USB (en l'occurence mon IRDROID)
		#		#timeout "3s" "sudo /home/pi/domotique/IR_remotes/usbreset /dev/bus/usb/$thebusnum/$thedevnum"
		#		sudo /home/pi/domotique/IR_remotes/usbreset /dev/bus/usb/$thebusnum/$thedevnum
		#		# 124 est le code de sortie de timeout si il a eu besoin de killer usbreset
		#		if [ $? -eq 124 ]; then 
		#		    message="$scriptName :  Malheureusement usbreset a echoue ! il faut rebrancher manuellement le device usb (IrDroid ou autre)"
		#			echo $message >> $LIRCDLOGFILE
		#			LogFull $message
		#		fi
	fi
	
	# Vérification de la taille du log de lircd et rotation du log si dépasse taille
	logSize=$(ls -l $LIRCDLOGFILE | cut -d " " -f5)	
	if [ "$logSize" -gt "1000000" ]; then		
		KillLircdForUsbIrtoy # Arrêter lircd pour compresser et faire tourner le fichier de log qui est devenu trop volumineux
		gzip -f $LIRCDLOGFILE
		horodate=$(date +"%Y%m%d_%H%M%S")
		rotated=$LIRCDLOGFILE"_"$horodate".gz"
		mv -f $LIRCDLOGFILE".gz"  $rotated
		sudo rm -f $LIRCDLOGFILE 2>/dev/null
	fi

	# Relancer lircd si le daemon est arrêté
	IsLircdForUsbIrtoyRunning
	lircdIsWorking=$?
	if [ $lircdIsWorking -eq 0 ]; then
		# pour relancer en mode "pas démon", ajouter --nodaemon, pour disposer d'une sortie en mode debug	, ajouter l'option -D
		sudo rm -f /var/run/lirc/lircd
		sudo rm -f /var/run/lirc/lircd.pid
		sudo rm -f /var/lock/LCK..ttyACM0
		sudo rm -f /tmp/.lircd
		sleep 0.1
		sudo /usr/local/sbin/lircd --listen=$LIRCDLISTENPORT  --device=/dev/ttyACM0 --driver=usb_irtoy --output=/var/run/lirc/lircd --logfile=$LIRCDLOGFILE
		sleep 0.5
		IsLircdForUsbIrtoyRunning
		lircdIsWorking=$?
		if [ $lircdIsWorking -eq 0 ]; then
			lircLaunchStatus="KO"
		else
			lircLaunchStatus="OK"
		fi
		LogFull  "Lancement de lircd pour usb_irtoy : $lircLaunchStatus"
	fi	
done

if [ ! -f $DAEMONPIDFILE ]; then
	LogFull  "Arret de $scriptName"
fi

LogFull  "Stopping daemon"
