#!/bin/bash

FREE_BANNER='<h1>CONNEXION AU SERVICE <span class="red">FreeWiFi</span></h1>'

USERNAME="2106707224"
PASSWORD="XXXXXXXXXXXXXXX"

MUSTRELOGIN=0

# Ce script a pour objectif de maintenir la connection internet freewifi active
# Il fonctionne avec les config suivantes :
#--------------------------------------------------------------------------------------------------------------------------#
# cat /etc/wpa_supplicant/wpa_supplicant.freewifi.conf
		# ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
		# update_config=1
		# 
		# network={
		# 	ssid="FreeWifi"
		# 	key_mgmt=NONE
		# }
#--------------------------------------------------------------------------------------------------------------------------#
# cat /etc/network/interface
		# auto lo
		# iface lo inet loopback

		# auto eth0
		# allow-hotplug eth0
		# iface eth0 inet static
		# address 192.168.1.253
		# netmask 255.255.255.0
		# gateway 192.168.1.254

		# allow-hotplug wlan0
		# auto wlan0

		# iface wlan0 inet manual
		# wpa-ssid "FreeWifi"
		# wpa-conf /etc/wpa_supplicant/wpa_supplicant.freewifi.conf
#--------------------------------------------------------------------------------------------------------------------------#
# ip route
		# default via 10.55.255.254 dev wlan0  metric 303
		# 10.48.0.0/13 dev wlan0  proto kernel  scope link  src 10.50.233.149  metric 303
		# 192.168.1.0/24 dev eth0  proto kernel  scope link  src 192.168.1.253  metric 202


# Pour utiliser la connection internet via freewifi, je n'ai pas trouvé mieux que de faire ça :  # sudo ip route del default via 192.168.1.254 dev eth0
# --> ca permet de retirer la passerelle de ma box pour internet, et donc de forcer l'utiliser de la passerelle Freewifi (voir résultats précédent de ip route)
# Idéalement, j'aurais aimé pouvoir requêter les pages en forcant l'interface wlan0, mais ni wget, ni curl n'ont l'air de fonctionner correctement si ethernet est branché
while true; do
	
	iwgetid | grep FreeWifi 1>/dev/null
	if [ $? -eq 0 ]; then 
		# Si on est ici, l'interface wlan pointe bien sur le SSID FreeWifi
		
		TEST_PAGE=$(wget -O - www.google.fr 2>/dev/null)
		IS_FREE=`echo "$TEST_PAGE" | grep "$FREE_BANNER"`

		if [ "X$IS_FREE" != "X" ]; then # Page d'identification de free
			MUSTRELOGIN=1
			echo "KO" > /home/pi/freewifi.status
			echo $(date +"%Y%m%d_%H%M%S") " Connection loosed"
		else
			MUSTRELOGIN=0
			echo "OK" > /home/pi/freewifi.status
			echo $(date +"%Y%m%d_%H%M%S") " Connection OK"
		fi
		
		if [ $MUSTRELOGIN -eq 1 ]; then    
			echo -n $(date +"%Y%m%d_%H%M%S") " Try to reauthenticate ........"
			wget -O /home/pi/freewifi.reauth.download  -I wlan0 --post-data="login=$USERNAME&password=$PASSWORD" "https://wifi.free.fr/Auth" 1>/dev/null 2>&1
			TESTREAUT=$(cat /home/pi/freewifi.reauth.download | grep -c 'CONNEXION AU SERVICE REUSSIE')
			if [ $? -eq 0 ]; then
				echo "  OK"
				sleep 5
			else
				echo "  failed"
			fi
		fi    				
	fi
    
	sleep 10
    
done
