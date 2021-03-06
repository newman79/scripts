#!/bin/bash
# Démon qui doit normalement maintenir le démon LIRCD actif malgré les crash du plugin USB_IRTOY
# Pour créer un service
# 		1) créer un service /etc/init.d/xms_lirc_maintain_svc.sh     et mettre un case in   start), un stop) et un status) dedans.
# 		2) Le start se contentera de faire un  /home/pi/scripts/xms_<program>.sh &
# 		3) Le stop se contentera de supprimer le fichier $DAEMONPIDFILE. Et de vérifier qu'il n'y aie plus de process nommé /etc/init.d/xms_lirc_maintain_svc.sh (avec pidof par exemple)
# 		4) Le status regardera si le fichier $DAEMONPIDFILE et si au moins un process nommé /etc/init.d/xms_lirc_maintain_svc.sh existe bien (avec pidof par exemple)
#  		 Apres cela, on peut faire service xms_lirc_maintain_svc [start|stop|status]
# 		5) Rajouter l'exécution du daemon au démarrage et l'arrêt à l'arrêt du système d'exploitation
#  		ln -s /etc/init.d/xms_lirc_maintain_svc.sh /etc/rc.d/rc3.d/S43_lircd_maintain.sh
# 			ln -s /etc/init.d/x

scriptName=`basename "$0"`
dirname=`dirname "$0"`

#Variables globales de ce daemon
DAEMONPIDFILE=$dirname/$scriptName".pid"
DAEMONPID=$$

logfile=/home/pi/$scriptName.log

# Variables globales liées au traitement
runDir=/var/run/macip
cacheDir=/var/cache/macip
pythonDir=/home/pi/scripts/python
stdoutFifoFileName=tmp.stdout

allMacToSnif=""
Conf_Macs=()
Conf_Devices=()


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
# $1 : mac adress
GetDeviceNameByMAC()
{
	count=0
	while [ "x${Conf_Macs[$count]}" != "x" ]; do		
			mac=${Conf_Macs[$count]}			
			if [ "$mac""X" == $1"X"  ]; then 
				echo ${Conf_Devices[$count]}
				break
			fi
			count=$(( $count + 1 ))
	done 
}

#-----------------------------------------------------------------------------------------------------------------------#
#													Debut program 														#
#-----------------------------------------------------------------------------------------------------------------------#
LogFull "Start program : scriptName Sniffing all mac adresses on local network "

# A etudier
# nmblookup -R -S -A 192.168.1.13
# sudo nmap -T4 -A -v 192.168.1.13
# sudo nmap -sn -PE 192.168.1.0/24

# Permet de sniffer réellement le réseau local 192.168.1.0 --> retourne les ip et les macs (si la mac n'est pas une des adresse des interfaces réseau du PC effectuant la requete)
# sudo nmap -sP 192.168.1.1-254

# Effacer toutes les entrées arp, faire un ping broadcast du réseau puis arp -a pour lister
# arp -d 
# ping ...
# arp -a

#while [ true ]; do { ps -p 15258 -o %cpu | sed -n 2p ; sleep 1; } done
#

function stopProcesses()
{
	ps ax | grep NetworkDeviceGrabber.py | awk '{print $1}' | while read thepid; do { sudo kill -9 $thepid ; } done
	ps ax | grep tcpdump | awk '{print $1}' | while read thepid; do { sudo kill -9 $thepid ; } done
	ps ax | grep cpugraber.py | awk '{print $1}' | while read thepid; do { sudo kill -9 $thepid ; } done
}

function finish()
{
	stopProcesses
	LogFull "$scriptName Daemon ended"
	exit 0
}
trap finish EXIT SIGINT

sudo mkdir $cacheDir 	 1>/dev/null 2>&1
sudo chmod 777 $cacheDir 1>/dev/null 2>&1
sudo mkdir $runDir 	 	 1>/dev/null 2>&1
sudo chmod 777 $runDir   1>/dev/null 2>&1

ps ax | grep cpugraber.py | awk '{print $1}' | while read thepid; do { sudo kill -9 $thepid ; } done
ps ax | grep tcpdump | awk '{print $1}' | while read thepid; do { sudo kill -9 $thepid ; } done
ps ax | grep NetworkDeviceGrabber.py | awk '{print $1}' | while read thepid; do { sudo kill -9 $thepid ; } done

rm -f $runDir/*
rm -f $cacheDir/*
rm -f $cacheDir/$stdoutFifoFileName 2>/dev/null
mknod $cacheDir/$stdoutFifoFileName p
#Not only is a FIFO buffered, but that's basically all a FIFO is. A FIFO is little more than a buffer in the kernel.
#Discussion: The kernel has a policy that it refuses to write data to the buffer unless a process has the FIFO open for reading. 
#This behavior is similar to pipes and TCP connections, although if theres no reader for a pipe or a TCP connection, the kernel will actually signal the writing process, terminating it (unless you install a handler). 

$pythonDir/cpugraber.py -psfile=$cacheDir/pidlist.conf 1>$cacheDir/dumpcpu.log  &

nbPacket=16000
while [ true ]; do 		# remarque : on peut enlever dans la commande tcpdump l'option -c $nbPacket et ca marchera encore en boucle infini (pas besoin du while)
	LogFull "  New scan and on the fly processing for $nbPacket packets; "
	$pythonDir/NetworkDeviceGrabber.py --devicesDirPath=$runDir -eraseAfter=90 -devices=$pythonDir/MacWatcher.conf -cacheDir=$cacheDir -log=$logfile # < $cacheDir/$stdoutFifoFileName &

	#sudo tcpdump -e -K -l -n -q -c $nbPacket >$cacheDir/$stdoutFifoFileName 2>/dev/null
	#tcpdumpPid=$(echo $!)
	#(echo 11111; echo 22222 ; echo 33333) | buffer -z 1000 >$cacheDir/$stdoutFifoFileName &
	
	# echo "curProcPid=" $$
	# echo "tcpdumpPid=" $tcpdumpPid
	# sudo rm -f $cacheDir/pidlist.conf
	# sudo echo $tcpdumpPid > $cacheDir/pidlist.conf	
	# ps xao pid,ppid,cmd | grep tcpdump | grep $tcpdumpPid 
	#sudo ps xao pid,ppid,cmd | grep tcpdump | grep $tcpdumpPid | awk '{print $1}' >> $cacheDir/pidlist.conf
	
done

finish


#cpt=0
#while read macToDevice; do
#		mac=$( echo $macToDevice | awk 'FS=" " {print $1}' )		
#		device=$( echo $macToDevice | awk 'FS=" " {print $2}' )
#		if [ "$mac""X" != "X"  ]; then	
#			allMacToSnif=$allMacToSnif" or ether src "$mac
#			#echo "  " $mac			
#			Conf_Macs[cpt]=${mac,,}
#			Conf_Devices[cpt]=${device,,}
#			cpt=$(( $cpt + 1 ))
#		fi
#done < $pythonDir/MacWatcher.conf
#allMacToSnif=${allMacToSnif:4}
#echo allMacToSnif = $allMacToSnif

#-------------------------------------------------------- Solution2 : Boucle principale ------------------------------------------------------------------------------------------#
#while [ true ]; do
#	LogFull "New scan"
#	#sudo tcpdump -K -e -n -i eth0 -q -c 1500 2>/dev/null | | sed "s/^[0-9][0-9]:[0-9][0-9]:[0-9][0-9].[0-9][0-9][0-9][0-9][0-9][0-9] \([0-9a-z][0-9a-z]:[0-9a-z][0-9a-z]:[0-9a-z][0-9a-z]:[0-9a-z][0-9a-z]:[0-9a-z][0-9a-z]:[0-9a-z][0-9a-z]\) > \([0-9a-z][0-9a-z]:[0-9a-z][0-9a-z]:[0-9a-z][0-9a-z]:[0-9a-z][0-9a-z]:[0-9a-z][0-9a-z]:[0-9a-z][0-9a-z]\), \([^\,]*\), length [0-9]*: \([^ ]*\).*$/\1 \4/g" | $pythonDir/MacTcpdumpAllProcess.py
#	sudo tcpdump -K -e -n -i eth0 -q -c 1500 2>/dev/null | $pythonDir/MacTcpdumpAllProcess.py
#	#cat $cacheDir/dmpstdout.txt | $pythonDir/MacTcpdumpAllProcess.py
#done

#-------------------------------------------------------- Solution3 : Boucle principale ------------------------------------------------------------------------------------------#
# while [ true ]; do
	# echo "------------------- New arp request -------------------"
	# arp -a | sed "s/[()]//g" | awk '{print $4"_"$2}' 1>$cacheDir/$stdoutFifoFileName & 
	# $pythonDir/MacPingProcess.py < $cacheDir/$stdoutFifoFileName
	# Remarque les 2 commandes suivantes correspondent exactement à un pipe de la 1ere vers la 2e
	
	# echo "------------------- New tshark snif -------------------"	
	# sudo tcpdump -l -c 500 -i eth0 -qe ether proto 0x88e1 or ether proto 0x88e2 or $allMacToSnif | awk '{print $2}' 1>$cacheDir/$stdoutFifoFileName &
	# $pythonDir/MacTsharkProcess.py < $cacheDir/$stdoutFifoFileName	
# done	


#-------------------------------------------------------- Solution4 : Boucle principale ------------------------------------------------------------------------------------------#
# while [ true ]; do

	#-------------------------------------------------------------------------------- Raffraichissement des ip à partir des requêtes arp --------------------------------------------------------------------------------#
	# echo "------------------- New arp request -------------------"
	# arp -a | sed "s/[()]//g" | awk '{print $4"_"$2}' | $pythonDir/MacPingProcess.py
	
	#for element in `arp -a | sed "s/[()]//g" | awk '{print $4"_"$2}'`; do		
	#	mac=$( echo $element | awk -F\_ '{print $1}' )
	#	ip=$( echo $element | awk -F\_ '{print $2}' )

	#	ping -c1 -w100 $ip 1>/dev/null 2>&1
	#	isNotReachable=$?
		
	#	if [ $isNotReachable -eq 0 ]; then
	#		deviceName=$(GetDeviceNameByMAC $mac)
	
	#		targetFilePath=$cacheDir/"$mac"_"$ip"_"$deviceName"
	#		filePath=$(ls $cacheDir/"$mac"* 2>/dev/null)
	#		if [ $? -eq 0 ]; then
	#			mv $filePath $targetFilePath 2>/dev/null
	#		else
	#			mknod $targetFilePath p
	#			#echo "" > $targetFilePath
	#		fi
	#		touch -c $targetFilePath		
	#	else
	#		rm -f $cacheDir/"$mac"* 2>/dev/null
	#	fi
	#done
		
	#count=0
	#while [ $count -lt 254  ]; do
	#	currentIp=192.168.1.$count
	#	macAdress=$( arp -a $currentIp | awk 'FS=" " {print $4}' | uniq) # | sed -e "s/:/-/g" 

	#	echo $macAdress | grep :  #1>/dev/null
	#	isWrongMac=$?
	#	if [ $isWrongMac -eq 0 ];then
	#		filePath=$(ls $cacheDir/MAC_"$macAdress"* 2>/dev/null)	
	#		if [ $? -eq 0 ]; then
	#			deviceName=$(basename $filePath | awk -F\_ '{print $3}')
	#			filetargetPath=$cacheDir/MAC_"$macAdress"_"$deviceName"_"$currentIp"			
	#			mv $filePath $filetargetPath 2>/dev/null
	#		fi			
	#	fi
	#	count=$(( $count + 1 ))
	#done


	#-------------------------------------------------------------------------------- Raffraichissement à partir de tshark sur 1500 frames --------------------------------------------------------------------------------#
	# echo "------------------- New tshark snif -------------------"
	# rm -f $cacheDir/$stdoutFifoFileName 2>/dev/null
	# mknod $cacheDir/$stdoutFifoFileName p
	#sudo tshark -l -c 1000 -T fields -e eth.src -f "$allMacToSnif" 1>$cacheDir/$stdoutFifoFileName 2>/dev/null  &
	
#	sudo tcpdump -l -c 500 -i eth0 -qe ether proto 0x88e1 or ether proto 0x88e2 or $allMacToSnif | awk '{print $2}' 1>$cacheDir/$stdoutFifoFileName &
	
	#sudo tshark -l -c 1000 -T fields -e eth.src -f "ether" 1>$cacheDir/$stdoutFifoFileName 2>/dev/null  &
#	$pythonDir/MacTsharkProcess.py < $cacheDir/$stdoutFifoFileName 
	
	#cat $cacheDir/$stdoutFifoFileName | while read macAdress; do
	#{
	#	macAdress=${macAdress,,}
	#	count=0
	#	while [ "x${Conf_Macs[count]}" != "x" ]; do		
	#			mac=${Conf_Macs[count]}			
	#			if [ "$mac""X" == $macAdress"X"  ]; then # met a jour le fichier
	#				filePath=$(ls $cacheDir/"$macAdress"* 2>/dev/null)	
	#				if [ $? -ne 0 ]; then
	#					mknod $cacheDir/"$macAdress"_UnknownIP_"${Conf_Devices[$count]}" p
	#				else
	#					touch $filePath
	#				fi
	#				break
	#			fi
	#		count=$(( $count + 1 ))
	#	done 
	#	previousMac=$macAdress	
	#} done	
#done	