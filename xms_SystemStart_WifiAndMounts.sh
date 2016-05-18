#!/bin/bash
### BEGIN INIT INFO 
# Provides: xmscusto
# Required-Start:   
# Required-Stop:  
# Default-Start: 1 2 3 4 5
# Default-Stop: 0 6 
# Short-Description: Initialisation du raspberry
# Description: Initialisation du raspberry
#              et autre infos a completer
### END INIT INFO


# Pour mettre ce script au démrrage de rasbian : Nom commence par S pour le démarrage, K pour l'arret.
# chmod 777 /etc/init.d/xms_custo.sh
# chown pi:pi /etc/init.d/xms_custo.sh
# ln -s /etc/init.d/xms_custo.sh /etc/rc5.d/S05xmscusto
# ln -s /etc/init.d/xms_custo.sh /etc/rc5.d/K05xmscusto
# ou update-rc.d xms_custo defaults 5 (5 est le 5eme à etre exécuté)
# et update-rc.d -f xms_custo remove
 

#########################################################################################################################
# 						Global variables																				#
#########################################################################################################################

OWNER=owner
horodate=$(date +"%Y%m%d_%H%M%S")
curmonth=`date +%m`
curday=`date +%d`
curyear=`date +%Y`

scriptName=`basename "$0"`
dirname=`dirname "$0"`
sessionDir=/home/pi/xms_custo/$horodate
logfile="$sessionDir/main_$horodate.log"
# colors
red=`tput setaf 1`
green=`tput setaf 2`
reset=`tput sgr0`

#########################################################################################################################
# 						Functions definition 																			#
#########################################################################################################################
CurrentDateTime()
{
	res=$(date +"%Y%m%d_%H%M%S")
	echo $res
}
#-----------------------------------------------------------------------------------------------------------------------#
Log()
{
	arg1="$1"
	arg2="$2"
	if [ ! X$arg2 = X ]; then
		if [ "$arg2" = "1" ]; then
				echo "${red}$arg1${reset}"
		else
			if [ "$arg2" = "0" ]; then
				echo "${green}$arg1${reset}"
			else
				echo "$arg1"
			fi
		fi
	else
		echo "$arg1"
	fi

	echo "$arg1" >> $logfile
}
#-----------------------------------------------------------------------------------------------------------------------#
LogFull()
{
	arg1="$1"
	echo [$(CurrentDateTime) $scriptName] "$arg1"
	echo [$(CurrentDateTime) $scriptName] "$arg1" >> $logfile
}
#-----------------------------------------------------------------------------------------------------------------------#
LogOnLine()
{
	arg1="$1"
	echo -n [$(CurrentDateTime) $scriptName] "$arg1"
	echo -n [$(CurrentDateTime) $scriptName] "$arg1" >> $logfile
}


#-----------------------------------------------------------------------------------------------------------------------#
AssertOrQuitValueIs()
{
	Value=$1
	GoodValue=$2
	LibelleOK=$3
	LibelleEchec=$4

	if [ $Value -ne $GoodValue ]; then
		echo "$LibelleEchec"
		exit 1
	else 
		echo "$LibelleOK"
	fi
}

#-----------------------------------------------------------------------------------------------------------------------#
CheckValueIs()
{
	Value=$1
	GoodValue=$2
	LibelleIfNotOK=$3
	LibelleIfOK=$4

	if [ $Value -ne $GoodValue ]; then
		Log "$LibelleIfNotOK" 1
	else
		if [ ! "X$LibelleIfOK"  = "X" ]; then
			Log "$LibelleIfOK" 0
		else
			Log " : OK" 0
		fi
	fi
}


#-----------------------------------------------------------------------------------------------------------------------#
EthernetIsUpButDownAndNoCarrierInIpAddr()
{
	testEth0=$(ip addr | grep eth0 | grep NO-CARRIER | wc -c)
	if [ $testEth0 -ne 0 ]; then
		return 1
	else
		return 0
	fi
}

#-----------------------------------------------------------------------------------------------------------------------#
ReinitWifiConnection()
{
	WifiInterfaceName=$1
	GateWay=$2

	LogFull "---- Debut analyse et corrections des connection ethernet et wifi -----"

	ping -c 3 -w 3 -I eth0 google.fr 1>/dev/null 2>&1
	ping -c 3 -w 3 -I eth0 google.fr 1>/dev/null 2>&1
	ethernetConnectIsNotOK=$?
	if [ $ethernetConnectIsNotOK -eq 0 ]; then 
		LogFull "	   Connection internet via ethernet : OK"
	else
		LogFull "	   Connection internet via ethernet : KO"
	fi

	ping -c 2 -w 6 google.fr -I wlan0 1>/dev/null 2>&1
	wifiConnectIsNotOK=$?
	if [ $wifiConnectIsNotOK -eq 0 ]; then 
		LogFull "    Connection internet via wifi : OK via $(iwgetid) "
		return 0
	fi

	#LogFull "	Tente execution commande suivante : #ip addr flush dev $WifiInterfaceName"

	#LogFull "	Tente execution commande suivante : #ifdown $WifiInterfaceName"

	#LogFull "	Tente execution commande suivante : #ifup $WifiInterfaceName"

	#killall dhclient 2>/dev/null 1>&2
	#LogFull "	Tente execution commande suivante : #dhclient"
	#sudo dhclient 2>/home/pi/xms_custo_dhclient_errors
	#AssertOrQuitValueIs $? 0 "		echec"


	# Le wifi ne peut acceder a internet. 
	if [ $wifiConnectIsNotOK -ne 0 ]; then

		LogFull "    Connection internet via wifi KO : on tente une correction"		
		# Ca vient d un probleme quand ethernet n est pas connecte mais activé (up) ==> on va tenter de resetter les routes réseau du wifi et ethernet ...
		EthernetIsUpButDownAndNoCarrierInIpAddr
		ethIsNotConnected=$?
		
		if [ $ethIsNotConnected -eq 1 ]; then
	
			LogFull "    Reinitialisation de la connection wifi du a ethernet non connecte"
	
			LogFull "	   Ethernet n'est pas connecté. Sur mon raspberrypi, ça créé un pb de routage pour le wifi. Il faut faire ce qui suit"
			LogOnLine "	Vidage fichier systemes de l'interface eth0"
			sudo ip addr flush dev eth0 2>>$sessionDir/ethFlush_errors.log
			CheckValueIs $? 0  " : KO" " : OK"
		
			LogFull "	      Mofification table routage : suppression routage ethernet"
			#LogOnLine "	  sudo ip route del default"
			#sudo ip route del default
			#CheckValueIs $? 0  " : KO" " : OK"

			LogFull "	      Mofification table routage : suppression routage local et passerelle pour le ethernet"
			# Suppression de la route du réseau local pour l'interface eth0
			LogOnLine "      sudo ip route del 192.168.1.0/24 dev eth0" 
			sudo ip route del 192.168.1.0/24 dev eth0 2>>$sessionDir/routage_errors.log 1>&2
			CheckValueIs $? 0  " : KO" " : OK , voir $sessionDir/routage_errors.log"

			# Suppression de la route de la passerelle internet pour l'interface eth0
			LogOnLine "      sudo ip route del default via 192.168.1.254 dev eth0"
			sudo ip route del default via 192.168.1.254 dev eth0 2>>$sessionDir/routage_errors.log 1>&2
			CheckValueIs $? 0  " : KO" " : OK , voir $sessionDir/routage_errors.log"

			LogFull "      Mofification table routage : ajout routage passerelle pour le wifi si besoin"
			ip route show | grep "default via $GateWay" 1>/dev/null
			routeGWWifiError=$?		
			if [ $routeGWWifiError -eq 1 ]; then # la route de la passerelle d access a internet via le wifi n est pas fixé
				LogOnLine "      sudo route add default gw 192.168.1.254 $WifiInterfaceName"	
				addWifiRouteError=$sessionDir/"routage_"$WifiInterfaceName"_errors.log"
				sudo route add default gw 192.168.1.254 $WifiInterfaceName  2>$addWifiRouteError
				wifiGWAddError=$?
				echo RTNETLINK answers: No such process>$sessionDir/testNormalErrorFile
				echo RTNETLINK answers: No such process>>$sessionDir/testNormalErrorFile
				echo SIOCADDRT: Network is unreachable>>$sessionDir/testNormalErrorFile
				diff $addWifiRouteError  $sessionDir/testNormalErrorFile
				$diffWifiErrors=$?
			
				if [ $wifiGWAddError -ne 0 ]; then
					addWifiRouteError=$diffWifiErrors
				fi
				CheckValueIs $addWifiRouteError 0  " : KO, voir $sessionDir/routage_errors.log" " : OK"
			fi
			sudo ip route show >>$sessionDir/route_state.log
			tail $sessionDir/route_state.log
			tail $sessionDir/route_state.log >> $logfile
								
			LogFull "	      Fin remise en place du routage avec la passerelle pour le wifi"
		fi
		
		# Ethernet est connecté à internet, c'est donc un probleme purement wifi
		# Pour l'instant on suppose que le wifi est connecté à FreeWifi
		if [ $ethIsNotConnected -eq 0 ] ; then
			LogFull "	      A resoudre : on a ethernet, normalement on ne devrait pas avoir de probleme"
		fi
	fi

	# Dans tous les cas si on est ici, c'est que la connection wifi avait un probleme. On a essayé de le résoudre.==> On regarde si ca a marché ...
	LogFull "      Vérification connection internet via wifi bien remise en place"
	LogOnLine "	#ping $GateWay -I $WifiInterfaceName -c 4"
	ping $GateWay -I $WifiInterfaceName -c 4 1>/dev/null  2>>$sessionDir/ping_errors_$WifiInterfaceName.log
	CheckValueIs $? 0  " : KO" " : OK"
	LogFull "	Attente 1s"
	sleep 1

	LogOnLine "	#ping $GateWay"
	ping $GateWay -c 2  1>/dev/null 2>>$sessionDir/ping_error_$WifiInterfaceName.log
	CheckValueIs $? 0  " : KO" " : OK"

	LogOnLine "	#ping www.google.fr"
	ping www.google.fr -c 2  1>/dev/null 2>>$sessionDir/ping_error_$WifiInterfaceName.log
	finalPingResult=$?
	CheckValueIs $? 0  " : KO" " : OK"

	if [ $finalPingResult -eq 0 ]; then
		wifiReset="OK"
	else
		wifiReset="KO"
	fi

	LogFull "---- Fin réinitialisation de la connection wifi : [$wifiReset] ----"
	return $finalPingResult
}

#----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------#
# Nécessite l'installation du package gupnp (sudo apt-get install gupnp)
#----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------#
ListUpnpDevicesAndServices()
{
	upnpListOutFile=/home/pi/upnpList
	#gssdp-discover -i eth0  --timeout=5 | grep Location | grep :[0-9] | uniq > $upnpListOutFile
	python  /home/pi/scripts/python/xms_parse_upnprenderers.py $upnpListOutFile	
}

#----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------#
# Nécessite l'installation du package gupnp (sudo apt-get install gupnp)
#----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------#
Set_Internet_Via_FreeWifi()
{
	# sudo iwconfig wlan0 essid "FreeWifi" && sudo wpa_supplicant -i wlan0 -c /etc/wpa_supplicant/wpa_supplicant.conf &
	kill $(ps ax | grep xms_test_internetaccess_via_freewifi.sh | grep bash | awk '{print $1}')
	sudo cp -p -f   /etc/wpa_supplicant/wpa_supplicant.freewifi.conf /etc/wpa_supplicant/wpa_supplicant.conf
	sudo ifdown wlan0
	sudo ifup wlan0 2>/dev/null
	sleep 2
	sudo ip route del default via 192.168.1.254 dev eth0
	sleep 1
	/home/pi/scripts/xms_test_internetaccess_via_freewifi.sh &
}

#----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------#
# Nécessite l'installation du package gupnp (sudo apt-get install gupnp)
#----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------#
Set_Internet_Via_MaFreeBox()
{
	# sudo iwconfig wlan0 essid "FreeWifi" && sudo wpa_supplicant -i wlan0 -c /etc/wpa_supplicant/wpa_supplicant.conf &
	kill $(ps ax | grep xms_test_internetaccess_via_freewifi.sh | grep bash | awk '{print $1}')
	sudo cp -p -f   /etc/wpa_supplicant/wpa_supplicant.mafreebox.conf /etc/wpa_supplicant/wpa_supplicant.conf
	sudo ifdown wlan0
	sudo ifup wlan0 2>/dev/null
	sleep 2
	sudo ip route del default via 192.168.1.254 dev eth0
	sleep 1
}


#----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------#
#----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------#
#----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------#
ReMount()
{
	NetBiosName=$1
	CifsShare=$2
	UserForMount=$3
		
	PwdForMount=`cat /home/pi/scripts/MountLoginPassword.cfg | grep "$NetBiosName " | grep "$UserForMount " | awk '{print $3}' | /home/pi/xmsEncodeDecode -d`

	if [ ! -d /media/$NetBiosName ]; then 
		mkdir /media/$NetBiosName
	fi

	LogOnLine "	Mounting //$NetBiosName/$CifsShare   user=$UserForMount "
	# cette commande utilise le module samba --> samba doit etre installé
	#string=$( nmblookup $NetBiosName | grep $NetBiosName )
	
	nmbLookupOutputFile=$sessionDir"/nmblookup_"$NetBiosName"_"$CifsShare".log"
	nmbLookupOutputFile=$(echo $nmbLookupOutputFile | sed -e "s/ /_/g")
	
	sudo nmblookup -B 192.168.1.255 $NetBiosName > "$nmbLookupOutputFile"
	test=$(cat $nmbLookupOutputFile | grep "name_query failed")
	
	if [ ! "$test"X = X ]; then # error
		Log "nmblookup : hôte $NetBiosName non trouvé" 
		return 1
	fi
	
	# hote trouvé
	#IFS= 
	ipAndName=$(cat $nmbLookupOutputFile | grep $NetBiosName | grep -v querying | sed -n 1p)
	# fonctionne en bash mais ne fonctionne pas en sh
	# ipAndNameArray="( $ipAndName )"
	# pcIP="${ipAndNameArray[0]}"	 
	# on contourne par exemple comme ceci

	ipAndNameFile=$sessionDir/"ipAndNameFile"	
	echo $ipAndName > $ipAndNameFile
	ipAndNameWithoutInfSup=$sessionDir/"ipAndNameWithoutInfSup"
	cat $ipAndNameFile | sed -e s/\</L/g | sed -e s/\>/R/g > $ipAndNameWithoutInfSup
	IFS=' ' read pcIP ccc < $ipAndNameWithoutInfSup
	pcIP=$pcIP
	# je lit le 4e élement dans $pcIP	
	#	tokens=( $string )
	#	pcIP=${tokens[4]}

	echo "$pcIP" | grep '[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*' 1>/dev/null
	if [ $? -ne 0 ]; then 
		Log "hôte $NetBiosName non trouvé : $pcIP" 1
		return 2
	else
		echo -n "ip="$pcIP" "
	fi
		
	# montage
	sudo umount /media/$NetBiosName 2>/dev/null	
	cifsMountError="$sessionDir/cifs_"$NetBiosName"_"$CifsShare"_errors".log
	cifsMountError=$(echo $cifsMountError | sed -e "s/ /_/g")
	#LogFull "sudo mount   -v   -t   cifs   //"$pcIP"/"$CifsShare" /media/"$NetBiosName" -o user="$UserForMount",pass="$PwdForMount",file_mode=0777,dir_mode=0777"
	sudo mount -v -t cifs   //$pcIP/"$CifsShare" /media/$NetBiosName -o user=$UserForMount,pass=$PwdForMount,file_mode=0777,dir_mode=0777 1>$cifsMountError 2>&1
	ls /media/$NetBiosName >/dev/null 2>&1
	mountResult=$?
	CheckValueIs $mountResult 0 "failed ; for details, just execute this command : #cat $errorFile" "OK ; IP="$pcIP
	return $mountResult
}

#########################################################################################################################
#########################################################################################################################
# 						DEBUT TRAITEMENT					 															#
#########################################################################################################################
#########################################################################################################################


#------------------------ Traitement proprement dit --------------------------#
case "$1" in
   'start')
	  	#su - $OWNER -c "/home/owner/start.sh"

		#------------------------- Créer la nouvelle session ----------------------------#
		mkdir -p $sessionDir
		#sudo touch /var/lock/$scriptName
		AssertOrQuitValueIs $? 0 " $scriptName : nouvelle session créée" "$scriptName FATAL : echec de creation nouvelle session, le programme s arrete"

		LogFull "-------------------------------------------------------"
		LogFull "Debut script $scriptName $1"

		#------------------------ Effacer les anciennes sessions --------------------------#
		LogFull "Running in following lunix Init level : $(runlevel)"
		LogFull "Debut suppression des anciennes sessions"
		for element in `ls -l /home/pi/xms_custo/ | sort -r | awk '$5 {print $9}'`
		do
			#	IFS="_" read -ra jourHoraire<<<$element	
			jour=$(echo $element | cut -f1 -d_)
			horaire=$(echo $element | cut -f2 -d_)
			previousyear=$(($curyear-1))
			dateToCompare=$previousyear$curmonth$curday

			if [ $jour -gt $dateToCompare ]; then
				echo -n "" # must keep $element
			else
				LogFull "Suppression de la session $element" 
				rm -r -f /home/pi/xms_custo/$element
			fi
		done
	  	
	
		#------------------------------------------------------------ Réinitialise la connection wifi ------------------------------------------------------------#
		ReinitWifiConnection "wlan0" "192.168.1.254"
		wifiConnReset=$?
		#if [ $wifiConnReset -ne 0 ]; then
		#	exit 1
		#fi
	
		#------------------------------------------------------------ Montage des lecteurs réseaux -----------------------------------------------------------#		
		LogFull "---- Montage des lecteurs réseaux ----"
				
		ReMount "xms-fixe" 			"D$" 				"xavier" 
		ReMount "xms-fixe-mus" 		"C$" 				"xavier" 
		ReMount "dlink-00c3c7" 		"Volume_1"			"xavier" 
		ReMount "freebox" 			"Disque dur"		"xavier" 
		
		#------------------------------------ Liste des server, player, renderer UPNP sur le réseau local ------------------------------------#		
		LogFull "---- Analyse server, player, renderer UPNP sur le réseau local ----"
		ListUpnpDevicesAndServices		
		
		LogFull "Fin script $scriptName $1"
		LogFull "-------------------------------------------------------"
   ;;
   'upnplist')
	   ListUpnpDevicesAndServices
   ;;
   'freewifi')
	   Set_Internet_Via_FreeWifi
   ;;
   'freebox')
	   Set_Internet_Via_MaFreeBox   
   ;;
   'stop')
      	#su - $OWNER -c "/home/owner/stop.sh"
   ;;
esac


#########################################################################################################################
#########################################################################################################################
# 						FIN SCRIPT				 															#
#########################################################################################################################
#########################################################################################################################
