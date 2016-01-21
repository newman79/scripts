
#!/bin/bash

scriptName=`basename "$0"`
dirname=`dirname "$0"`

tmpOutFilePath=$dirname"/"$scriptName".tmpout"

#-----------------------------------------------------------------------------------------------------------------------#
#
#-----------------------------------------------------------------------------------------------------------------------#
function start()
{	
	# Allumage télé
	echo "Allumage tele"
	/home/pi/scripts/xms_wrapper_irsend.sh N 2 Samsung_BN59-01014A_To_Test KEY_POWER

	# Attente récupération renderer de la télé
	echo "Attente reveil tele"
	upnpListOutFile=/home/pi/upnpList
	python  /home/pi/scripts/xms_parse_upnprenderers.py $upnpListOutFile | grep "[TV] Home"
	result=$?	 
	if [ $result -ne 0 ]; then
		python  /home/pi/scripts/xms_parse_upnprenderers.py $upnpListOutFile | grep "[TV] Home"
	fi
	
	if [ $result -ne 0 ]; then
		echo "La tele n est toujours pas allumee"
		exit 1
	fi

# Pour récupérer le programme télé
#	http://192.168.1.43:9090/BinaryBlob/3/CurrentProgInfo.dat

}

#-----------------------------------------------------------------------------------------------------------------------#
#
#-----------------------------------------------------------------------------------------------------------------------#
function stop()
{
	echo stopping
}


#-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------#
#-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------#
#-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------#
case "$1" in
   'start')
	   start
   ;;
   'stop')
	   stop
   ;;
   *)
        echo "Usage:  {start|stop}"
   ;;
esac
