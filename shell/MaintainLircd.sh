#!/bin/bash

horodate=$(date +"%Y%m%d_%H%M%S")
curmonth=`date +%m`
curday=`date +%d`
curyear=`date +%Y`

scriptName=`basename "$0"`
scriptSessionsDirRoot=/home/pi/$scriptName
sessionDir=$scriptSessionsDirRoot/$horodate
logfile="$sessionDir/$scriptName_$horodate.log"
pidfile=$scriptSessionsDirRoot/$scriptName.pid
lastlogfile="$scriptSessionsDirRoot/lastlog.log"

# Variables globales liées à LIRCD
lircdLogFile=/home/pi/domotique/IR_remotes/lircd.log
lircdListenPort=49999

#########################################################################################################################
#                                                Logs Functions definition
#########################################################################################################################
CurrentDateTime()
{
	res=$(date +"%Y%m%d_%H%M%S")
	echo $res
}

#-----------------------------------------------------------------------------------------------------------------------#
LogFull()
{
	arg1="$1"
	echo [$(CurrentDateTime)][$scriptName] "$arg1"
	echo [$(CurrentDateTime)][$scriptName] "$arg1" >> $logfile
}

#########################################################################################################################
#                                              Functions definition 																	
#########################################################################################################################
#----------------------------- Identify usb branch of a device given its idVendor and its idProduct --------------------#
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

#-----------------------------------------------------------------------------------------------------------------------#
MustRun()
{
	res=$(ls $pidfile 2>/dev/null | wc -l)
	if [ $res -eq 1 ]; then
		psId=$(cat $pidfile)
		if [ "x" == "x"$psId ]; then
			psId=1
		fi
		res=$(ps -p $psId -f | grep $scriptName | wc -l)
	fi
	echo -n $res
}

#---------------------------------------------------------------------------------------#
#--------------------------------------- PROGRAM START ---------------------------------#
#---------------------------------------------------------------------------------------#

#---------------------- create new session dir and root folders ------------------------#
mkdir -p $sessionDir 2>/dev/null

sudo rm -f $lastlogfile
sudo ln -s $logfile $lastlogfile

LogFull "Start of daemon"

res=$(ls $pidfile 2>/dev/null | wc -l)
if [ $res -eq 0 ]; then
	sudo echo $$ > $pidfile	
fi

# Boucle principale du daemon. Elle s'arrêtera quand le fichier $pidfile aura été supprimé.
while [ $(MustRun) -eq 1 ] ; do # If pid file exist, I assume that this daemon shoud run since it is its pid

	devUsbBranchPath=`IdentifyUsbBranchWith_IdVendorAndIdProduct 04d8 f58b`
	sleep 1
	if [[ "X$devUsbBranchPath" == "X" ]]; then
		sleep 2
		LogFull "Le recepteur Irtoy Irdroid n a pas ete detecte par l'OS. Il faut le rebrancher."
		continue
	fi
	
	CDCACMISNOTOK=0	
	tail --lines=4 $lircdLogFile | grep "No USB Irtoy"
	if [ $? -eq 0 ]; then
		LogFull "Detecting error : No USB Irtoy"
		CDCACMISNOTOK=1
	fi
	tail --lines=4 $lircdLogFile | grep "usb_irtoy: could not open /dev/ttyACM0"
	if [ $? -eq 0 ]; then
		LogFull "Detecting error : usb_irtoy: could not open /dev/ttyACM0 in $lircdLogFile"
		CDCACMISNOTOK=1
	fi	
	tail --lines=4 $lircdLogFile | grep "usb_irtoy: could not create lock files"
	if [ $? -eq 0 ]; then
		LogFull "Detecting error : usb_irtoy: could not create lock files in $lircdLogFile"
		CDCACMISNOTOK=1
	fi

	# Si lircd a planté à cause du crash connu avec USB Irtoy
	if [ $CDCACMISNOTOK -eq 1 ]; then
		message="Resolution crash plugin USB Irtoy detecte dans le log de LIRCD : $lircdLogFile ; device=$devUsbBranchPath"
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
		#			echo $message >> $lircdLogFile
		#			LogFull $message
		#		fi
	fi
	
	# Vérification de la taille du log de lircd et rotation du log si dépasse taille
	logSize=$(ls -l $lircdLogFile | cut -d " " -f5)	
	if [ "$logSize" -gt "1000000" ]; then		
		KillLircdForUsbIrtoy # Arrêter lircd pour compresser et faire tourner le fichier de log qui est devenu trop volumineux
		gzip -f $lircdLogFile
		horodate=$(date +"%Y%m%d_%H%M%S")
		rotated=$lircdLogFile"_"$horodate".gz"
		mv -f $lircdLogFile".gz"  $rotated
		sudo rm -f $lircdLogFile 2>/dev/null
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
		sudo /usr/local/sbin/lircd --listen=$lircdListenPort  --device=/dev/ttyACM0 --driver=usb_irtoy --output=/var/run/lirc/lircd --LOGFILE=$lircdLogFile
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

LogFull  "End of daemon"
