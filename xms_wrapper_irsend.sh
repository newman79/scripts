#!/bin/bash

scriptName=`basename "$0"`
dirname=`dirname "$0"`

tmpOutFilePath=$dirname"/"$scriptName".tmpout"

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
		sudo kill -9 $lircdForUsbIrtoyDaemonPid	2>/dev/null	
		killError=`expr "$killError" + "$?"`
	done
	return $killError	
}

#-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------#
function List()
{
	rm -f $tmpOutFilePath

	timeout 3 irsend LIST "$1" "$2" > $tmpOutFilePath 2>/dev/null
	if [ $? -eq 124 ]; then
		echo "Error : irsend timeout"
		KillLircdForUsbIrtoy
		exit 3
	fi
	
	#IFS=$'\n' GLOBIGNORE='*' :; cmdResultsArray=(`cat /home/pi/scripts/xms_wrapper_irsend.sh.tmpout`)
	readarray cmdResultsArray < $tmpOutFilePath
	cmdResultsArrayLength=${#cmdResultsArray[@]}
	
	if [ $cmdResultsArrayLength -lt 3 ]; then
		echo "Error : answer has $cmdResultsArrayLength lines, so less than 2 lines : you must check if lircd is running"
		exit 2
	fi

	result=${cmdResultsArray[2]}
	result=`echo $result | sed 's/^[ \t]*//;s/[ \t]*$//'`	

	if [[ ! "X$result" == "Xbuffer: -SUCCESS-" ]]; then
		echo "Error in command"
		exit 1
	fi
	
	ItemNb=`echo ${cmdResultsArray[4]}|cut -d ' ' -f2  | sed  "s/-//g"`
	ItemNbMoins1=$(($ItemNb-1))
	
	for index in `seq 0 $ItemNbMoins1`
	do
		dataIndex=`expr "$index + 5"`		
		data=${cmdResultsArray[$dataIndex]}
		dataValue=`echo $data | cut -d " " -f2,3`
		echo $dataValue | sed  "s/^-*//;s/-*$//"
	done
	
	rm -f $tmpOutFilePath 2>/dev/null
	exit 0
}

#-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------#
SendOnce()
{
	res=0
	timeout 3 irsend SEND_ONCE "$1" "$2" > $tmpOutFilePath 2>&1
	cat $tmpOutFilePath | grep "irsend: timeout" >/dev/null	
	if [ $? -eq 0 ]; then
		echo "Error : irsend timeout"
		KillLircdForUsbIrtoy
		res=3
	fi	
	rm -f $tmpOutFilePath 2>/dev/null
	return $res
}

#-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------#
SendN()
{
	entier=$1
	remote=$2
	command=$3
	
	if [ $? -ne 0 ]; then
		echo "Le nombre de repetition n est pas un entier : '"$entier"'"
		exit 4
	fi	
	
	for index in `seq 1 $entier`
	do
		SendOnce $remote $command				
		if [ $? -ne 0 ]; then
			rm -f $tmpOutFilePath 2>/dev/null
			exit 4			
		fi
		sleep 0.2
	done

	rm -f $tmpOutFilePath 2>/dev/null
	exit 0
}

#-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------#
#-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------#
#-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------#
case "$1" in
   'LIST')
	   List $2 $3
   ;;
   'ONCE')
	   SendOnce $2 $3
   ;;
   'N')
	   SendN $2 $3 $4
   ;;
   *)
        echo "Usage:  {LIST <Remote> <Key>|ONCE <Remote> <Key>|N <delaiBetweenSend> <Remote> <Key>}"
        echo "Exit with 0 if all commands are successful, 1 if errors occur when processing, 2 if irsend cannot connect to lirc socket (lircd is not running)"
   ;;
esac
