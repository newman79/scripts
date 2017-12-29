#! /usr/bin/python
# -*-coding:utf-8 -*
# Liste les renderers presents sur le reseau local a partir du fichier passe en parametre
import random, time, pygame, sys, copy
import urllib2
import os
from sets import Set
import glob
import re
from threading import Thread,RLock
import signal
import subprocess
import argparse
import datetime
from xms.capteurs import TempHumUtils

global verrou_log,progName, MainLoop

progName = os.path.basename(__file__).split(".")[0]
MainLoop = True

global StatDirPath
global globalFileName
global firstLine
global CurrentDay
global daemonPidFile

StatDirPath 	= '/var/run/TempHumGrabber'
firstLine 		= True
daemonPidFile 	= StatDirPath + '/xms_daemon_Grabber_TempHum.sh.pid'

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
	#cmd = 'ls ' + StatDirPath + '/*.json | xargs -n 1 basename | while read filepath; do { prefix=`echo $filepath | sed -e "s/\.[0-9]*_[0-9]*\.json//g"` ; [ $prefix -ge ' + str(limitAfter) + ' ] && [ $prefix -le ' + str(limitBefore) + ' ] &&  echo ' + StatDirPath + '/$filepath  ; }  done'
	cmd = 'ls ' + StatDirPath + '/*.json | sort'
	
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
	
	parser = argparse.ArgumentParser(description='Example with simples options')
	parser.add_argument('-i' 		, '--i'	,			action="store"		, 	help="Grab interval, in seconds")
	parser.add_argument('-start' 	, '--start',		action="store_true"	,  	help="Start program")
	parser.add_argument('-stop' 	, '--stop',			action="store_true"	,  	help="Stop program")
	parser.add_argument('-get' 		, '--get',			action="count"	,  	help="Get from acquired files, must be set with 'd1' and 'd2' options")
	parser.add_argument('-d1' 		, '--d1',			action="store"		,  	help="Start date for get option")
	parser.add_argument('-d2' 		, '--d2',			action="store"		,  	help="End date for get option")
	result = parser.parse_args()
	arguments = dict(result._get_kwargs())

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
	
	processId = os.getpid()
	os.system('sudo echo ' + str(processId) + " 1>" + daemonPidFile)
	
	CreateOutputJsonFile()

	thread_TempHumGraber = TempHumUtils.TempHumGraber(callbackTempHumTrace,21)
	
	if arguments['i'] != None: 
		thread_TempHumGraber.setGrabInterval(float(arguments['i']))
	
	thread_TempHumGraber.start()	
		
	try:
		cpt=0
		while MainLoop == True and Main.mustRun():			
			time.sleep(1)
			cpt=cpt+1
			if cpt > 300:
				cpt=0
				# retention des fichiers de trace
				cmd = 'find ' + StatDirPath + '-name "*json" -mtime 365 | while read filepath; do { echo Remove $filepath; rm -f $filepath; } done			'
				os.system(cmd)
	except KeyboardInterrupt:	
		result = 0
		
	thread_TempHumGraber.stop()		
	time.sleep(0.3)		
	TerminateJsonFile()
	sys.exit(0)
	
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------#
# 									Appelee par un thread
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------#

def callbackTempHumTrace(temperature,humidity):
	global firstLine
	msg = ' temp:' + str(round(temperature,2)) + ", hum:" + str(round(humidity,2))
	message = '%f' % time.time() +  ":" + msg 	
	print  message
	LogItem(message)
	
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------#
# 									
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------#
def CreateOutputJsonFile():
	global globalFileName
	global CurrentDay	
	
	theNow 	= datetime.datetime.utcnow()
	CurrentDay = theNow.strftime('%Y%m%d')
	globalFileName = StatDirPath + '/' +   '%f'%time.time() + '_' + CurrentDay + '.json'	
	logFileHandle = open(globalFileName,'a')
	logFileHandle.close()
	
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------#
# 									Appelee soit par le thread qui gere les arp, soit par le thread qui gere le tcpdump
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------#
def LogItem(msg):
	
	theNow 	= datetime.datetime.utcnow()
	actualDay = theNow.strftime('%Y%m%d')
	if actualDay != CurrentDay:
		TerminateJsonFile()		
		CreateOutputJsonFile()

	logFileHandle = open(globalFileName,'a')
	logFileHandle.write(msg + '\n')
	logFileHandle.close()

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