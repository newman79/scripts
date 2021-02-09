#! /usr/bin/python
# -*-coding:utf-8 -*
# Liste les renderers presents sur le reseau local a partir du fichier passe en parametre
import random, time, pygame, sys, copy
import urllib2
import os
from os import path
from sets import Set
import glob
import re
from threading import Thread,RLock
import signal
import subprocess
import argparse
import datetime
import mysql.connector
import thread

from urllib import quote_plus

from xms.capteurs import TempHumUtils


global progName,progNameWithExtension, MainLoop
global SessionsPath
global globalFileName
global firstLine
global CurrentDay
global daemonPidFile
global logFilePath

progNameWithExtension = os.path.basename(__file__)
progName = progNameWithExtension.split(".")[0]
#progName		= 'TempHumGrabber.py'
MainLoop = True

verrou_log	  		= RLock()

SessionsPath 	= '/home/pi/' + progNameWithExtension
firstLine 		= True
daemonPidFile 	= SessionsPath + '/' + progNameWithExtension + '.pid'
logFilePath 	= SessionsPath + "/" + datetime.datetime.utcnow().strftime('%Y%m%d_%H%M%S.%f') + '.' + progName + ".log"

#-------------------------------------------------------------------------------------------------------------------------------------------------------------------#
#										Classe Main
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------#
class Main:
	@staticmethod
	def mustRun():
		result = os.system('ls ' + daemonPidFile + ' 1>/dev/null 2>&1')
		if result == 0:		return True
		else: 				return False

#-------------------------------------------------------------------------------------------------------------------------------------------------------------------#
# start = time since the epoque 01/01/1970 : exemple : 1423290000
# end 	= time since the epoque 01/01/1970 : exemple 1503220000
# Exemples shell : date +%s	ou date --date="19-FEB-12" +%s              dans l'autre sens		date -d @1423290000
def GetMeasures(start, end):
	
	limitAfter	= int(start) - 86400
	limitBefore	= int(end) + 86400
	start 		= float(start)
	end 		= float(end)

	# Trouver les fichiers dont le prefix est apres <start> - 1jour et avant <end> + 1 jour
	# Pure shell command is  :   ls /var/run/StatGrabber/*.json | xargs -n 1 basename | while read filepath; do { prefix=`echo $filepath | sed -e "s/\.[0-9]*_[0-9]*\.json//g"` ; [ $prefix -ge 1423290000 ] && [ $prefix -le 1503220000 ] &&  cat /var/run/StatGrabber/$filepath  ; }  done
	#cmd = 'ls ' + SessionsPath + '/*.json | xargs -n 1 basename | while read filepath; do { prefix=`echo $filepath | sed -e "s/\.[0-9]*_[0-9]*\.json//g"` ; [ $prefix -ge ' + str(limitAfter) + ' ] && [ $prefix -le ' + str(limitBefore) + ' ] &&  echo ' + SessionsPath + '/$filepath  ; }  done'
	cmd = 'ls ' + SessionsPath + '/*.json | sort'
	
	# Filtrer les traces
	# Pure shell command is : cat /var/run/StatGrabber/1463322803.882795_20160515.json | while read statline; do { prefix=`echo $statline | sed -e "s/\,*\([0-9]*\)\.[0-9].*/\1/g"` ;  [ $prefix -ge 1463322825 ] && [ $prefix -le 1463322844 ]  &&  echo $statline  ; } done																											
	# Traitement trop long en shell, on abandonne le 'cat' de fin de commande précédente pour afficher les fichiers. On les traite dans le python
	#cmd += ' | while read statline; do { prefix=`echo $statline | sed -e "s/\,*\([0-9]*\)\.[0-9].*/\\1/g"` ;  [ $prefix -ge ' + str(start) + ' ] && [ $prefix -le ' + str(end) + ' ]  &&  echo $statline  ; } done'

	print '{'
	FirstLine = '    "'
	grabfileProc = subprocess.Popen(cmd, shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
	grabFilePath = grabfileProc.stdout.readline().rstrip()
	
	while (grabFilePath != ''):
	
		prefix		= os.path.basename(grabFilePath).split(".")[0]
		prefixFloat	= float(prefix)
		if prefixFloat > limitAfter and prefixFloat < limitBefore:
		
			fileHandle = open(grabFilePath,'r')
			grabLine = fileHandle.readline().rstrip()
			while (grabLine != ''):
				grabLineArray = grabLine.split(' ')
				StatLineTime = float(grabLineArray[0].split(':')[0])
				if StatLineTime > start:
					if StatLineTime > end:
						print '}'
						sys.exit(0)
					grabLine1 = grabLineArray[1].split(":")
					grabLine2 = grabLineArray[2].split(":")
					grabLine3 = grabLineArray[3].split(":")
					grabLine4 = grabLineArray[4].split(":")
					grabLine5 = grabLineArray[5].split(":")
					grabLine6 = grabLineArray[6].split(":")
					grabLine7 = grabLineArray[7].split(":")
					grabLine9 = grabLineArray[9].split(":")
					grabLine10 = grabLineArray[10].split(":")
					grabLine11 = grabLineArray[11].split(":")
					grabLine12 = grabLineArray[12].split(":")
					grabLine13 = grabLineArray[13].split(":")
					msg = FirstLine + str(StatLineTime) + '":{"cpu":{"' + grabLine1[0]+'":'+grabLine1[1] + ',"' + grabLine2[0]+'":'+grabLine2[1] + ',"' + grabLine3[0]+'":'+grabLine3[1] + ',"' + grabLine4[0]+'":'+grabLine4[1] + ',"' + grabLine5[0]+'":'+grabLine5[1] + ',"' + grabLine6[0]+'":'+grabLine6[1] + ',"' + grabLine7[0]+'":'+grabLine7[1] + '},"mem":{"' + grabLine9[0]+'":'+grabLine9[1] + ',"' + grabLine10[0]+'":'+grabLine10[1] + ',"' + grabLine11[0]+'":'+grabLine11[1] + ',"' + grabLine12[0]+'":'+grabLine12[1] + ',"' + grabLine13[0]+'":'+grabLine13[1] + '} }'
					print msg
					if FirstLine == '    "':
						FirstLine = '   ,"'
					
				grabLine = fileHandle.readline().rstrip()
			fileHandle.close()
		
		grabFilePath = grabfileProc.stdout.readline().rstrip()
		if prefixFloat > limitBefore: # on a passe tous les fichiers qui etait susceptibles de contenir les traces voulues
			grabFilePath = ''
		
	print '}'
		
	
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------#
# 																				MAIN  																				
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------#
def main():	
		
	global MainLoop
	global D1
	global D2
	global WirePusherTokens
	global WirePusherTokensArray
	
	LogMsg('Start of ' + progName)
	
	LogMsg('Create json file if new day')	
	CreateOutputJsonFile()

	LogMsg('Parse command line args')
	parser = argparse.ArgumentParser(description='Example with simples options')
	parser.add_argument('-i' 				, '--i'	,				action="store"		, 	help="Grab interval, in seconds")
	parser.add_argument('-start' 			, '--start',			action="store_true"	,  	help="Start program")
	parser.add_argument('-stop' 			, '--stop',				action="store_true"	,  	help="Stop program")
	parser.add_argument('-get' 				, '--get',				action="count"		,  	help="Get from acquired files, must be set with 'd1' and 'd2' options")
	parser.add_argument('-d1' 				, '--d1',				action="store"		,  	help="Start date for get option")
	parser.add_argument('-d2' 				, '--d2',				action="store"		,  	help="End date for get option")
	parser.add_argument('-wirepushertokens' , '--wirepushertokens',	action="store"		,  	help="list of wirepusher notification tokens")
	
	result = parser.parse_args()
	arguments = dict(result._get_kwargs())

	WirePusherTokensArray = []
	if arguments['wirepushertokens'] != None:
		WirePusherTokens = arguments['wirepushertokens']
		WirePusherTokensArray = WirePusherTokens.split(',')

	if arguments['get'] != None:
		if arguments['d1'] != None:
			D1 = arguments['d1']
		else:
			print "Wrong parameters"
			sys.exit(1)
		if arguments['d2'] != None:
			D2 = arguments['d2']
			if D2 == True:
				D2 = int(time.time() + 86400)
		else:
			D2 = int(time.time() + 86400)
		GetStats(D1,D2)
		sys.exit(0)
	
	LogMsg('If needed, put process pid  in ' + daemonPidFile)
	result = os.system('ls ' + daemonPidFile + ' 1>/dev/null 2>&1')
	if result != 0:
		processId = os.getpid()
		os.system('sudo echo ' + str(processId) + " 1>" + daemonPidFile)
	
	thread_TempHumGraber = TempHumUtils.TempHumGraber(callbackTempHumTrace, callbackLog,21)
	
	if arguments['i'] != None: 
		thread_TempHumGraber.setGrabInterval(float(arguments['i']))
	
	LogMsg('Start graber thread')
	thread_TempHumGraber.start()	

	LogMsg('Start main loop')
	try:
		cpt=0
		while MainLoop == True and Main.mustRun():
			time.sleep(1)
			cpt=cpt+1
			if cpt > 300:
				cpt=0
				# retention des fichiers de trace
				cmd = 'find ' + SessionsPath + ' -name "*json" -mtime 365 | while read filepath; do { echo Remove $filepath; rm -f $filepath; } done			'
				os.system(cmd)
	except KeyboardInterrupt:	
		result = 0

	LogMsg('Stop graber thread')
	thread_TempHumGraber.stop()		
	time.sleep(0.3)		
	LogMsg('Close json file')
	TerminateJsonFile()
	sys.exit(0)
	
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------#
# 									Appelee par un thread
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------#

def callbackTempHumTrace(temperature,humidity):
	global firstLine
	temperatureStr = str(round(temperature,2))
	humidityStr = str(round(humidity,2))
	registerEvent(temperatureStr, humidityStr)

	msg = quote_plus(temperatureStr + " °C, " + humidityStr + " %")
	os.system("/home/pi/scripts/python/notify-wire-pusherclient.py -s xmsIndoorTempHum -w " + WirePusherTokens + " -t " + msg + " -m " + msg)

		#msg 		= "warning : " + " temp:" + temperatureStr + ",hum:" + humidityStr
		#msgTitle	= "home temp./hum."
		#msgType 	= "xmsTempHum"
		#for token in WirePusherTokensArray:
		#	# get notification file path
		#	lastTokenNotificationTouchFilePath = SessionsPath + "/last.notification.xmsTempHum.for." + token

		#	mustNotifyToken = False

		#	if not path.exists(lastTokenNotificationTouchFilePath):
		#		mustNotifyToken = True
		#	else:
		#		# get last modification in seconds
		#		lastModifiedTokenFileTimeInSecondsSinceEpoch = os.path.getmtime(lastTokenNotificationTouchFilePath)
		#		currentTimeInSecondsSinceEpoch 				 = time.time()
		#		lastModifiedTokenFileSinceInSeconds 		 = currentTimeInSecondsSinceEpoch - lastModifiedTokenFileTimeInSecondsSinceEpoch
		#		mustNotifyToken = lastModifiedTokenFileSinceInSeconds > 14400

		#	# if last modified is very far, send notif and touch it
		#	if mustNotifyToken:
		#		curlCommand = "curl -k 'https://wirepusher.com/send?id=" + token + "&title=" + msgTitle + "&message=" + msg + "&type=" + msgType + "' 2>&1 1>/dev/null"
		#		os.system(curlCommand)
		#		os.system("touch " + lastTokenNotificationTouchFilePath + " 2>/dev/null")

def callbackLog(message):
	LogItem(message)
	print message


#-------------------------------------------------------------------------------------------------------------------------------------------------------------------#
# 									Appelee soit par le thread qui gere les arp, soit par le thread qui gere le tcpdump
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------#
def registerEvent(temperatureStr, humidityStr):
	msg = ' temp:' + temperatureStr + ", hum:" + humidityStr
	message = '%f' % time.time() +  ":" + msg 	
	LogMsg('register : ' + message)
	
	theNow 	= datetime.datetime.utcnow()
	measureDateStr = theNow.strftime('%Y-%m-%d %H:%M:%S')

	try:
		#-------- Debut connection a la base de donnee --------#
		cnx = mysql.connector.connect(user='xavier', database='Evenements', password='free1979')
		cursor = cnx.cursor()
		#-------- recuperer le device id pour lequel enregistrer l evenement --------#
		cursor.execute("select id from TR_DeviceName where nomDNS='xms-rbpi'")
		result = cursor.fetchone()
		deviceId = result[0]
		
		#-------- enregistrer l evenement --------#
		message = '' + str(deviceId) + ' m=' + measureDateStr + ' s=' + str(6) + ' t=' + temperatureStr + ' h=' + humidityStr
		print  message
		LogItem(message)
		request_insert_measure_event = ("INSERT INTO EventLanDevice(id,date,state,ip,measure1,measure2) VALUES(%s,%s,%s,%s,%s,%s)")
		data_measure_event = (deviceId, measureDateStr, 6, "192.168.1.253", temperatureStr,humidityStr)
		# Insert 
		cursor.execute(request_insert_measure_event, data_measure_event)
		#insertedEventRowId = cursor.lastrowid

		#-------- Commit et fin de connection a la base de donnee --------#
		cnx.commit()
	except:
		LogMsg('could not insert following event in database : ' + message)
	finally:
		try:
			cursor.close()
			cnx.close()
		finally:
			LogMsg('could not close connection')
			

#-------------------------------------------------------------------------------------------------------------------------------------------------------------------#
# 									
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------#
def CreateOutputJsonFile():
	global globalFileName
	global CurrentDay	
	
	theNow 	= datetime.datetime.utcnow()
	CurrentDay = theNow.strftime('%Y%m%d')
	globalFileName = SessionsPath + '/' +   '%f'%time.time() + '_' + CurrentDay + '.json'	
	logFileHandle = open(globalFileName,'a')
	#LogItem("")
	logFileHandle.close()
	
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------#
# 									Appelee soit par le thread qui gere les arp, soit par le thread qui gere le tcpdump
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------#
def LogItem(msg):
	
	LogMsg(msg)
	
	theNow 	= datetime.datetime.utcnow()
	actualDay = theNow.strftime('%Y%m%d')
	if actualDay != CurrentDay:
		TerminateJsonFile()		
		CreateOutputJsonFile()

	logFileHandle = open(globalFileName,'a')
	logFileHandle.write(msg + '\n')
	logFileHandle.close()

#-------------------------------------------------------------------------------------------------------------------------------------------------------------------#
# 									Appelee soit par le thread qui gere les arp, soit par le thread qui gere le tcpdump
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------#
def LogMsg(msg):
	theNow 	= datetime.datetime.utcnow()
	with verrou_log:
		message = '[' + theNow.strftime('%Y%m%d_%H%M%S.%f') + '][' + progName + '][' + str(thread.get_ident()) + '] ' + msg 
		logFileHandle = open(logFilePath,'a')
		logFileHandle.write(message + '\n')
		logFileHandle.close()
		print  message


#-------------------------------------------------------------------------------------------------------------------------------------------------------------------#
# 									
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------#
def TerminateJsonFile():
	#logFileHandle = open(globalFileName,'a')
	#logFileHandle.write('}\n')
	#logFileHandle.close()
	result=0
	
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------#
if __name__ == '__main__':
	main()	
