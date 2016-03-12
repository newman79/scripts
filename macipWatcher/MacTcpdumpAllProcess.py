#! /usr/bin/python
# Liste les renderers presents sur le reseau local a partir du fichier passe en parametre
import random, time, pygame, sys, copy
import urllib2
from xml.dom.minidom import parse, parseString
import os
from sets import Set
import glob
import re
from time import sleep
import random
import sys
from threading import Thread
import time

global ht_macToDevice, ht_macToIp, ht_macLastModified,set_allMacs, set_ProcessedMac,workingDirPath,runDirPath,macIpPattern,macLinePattern

#------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------#
re.UNICODE
ht_macToDevice		= dict()
ht_macToIp			= dict()
ht_macLastModified 	= dict()
set_allMacIps 	= Set()
set_ProcessedMac = Set()
workingDirPath 	= os.path.dirname(os.path.realpath(__file__) + "macip")
runDirPath 	= "/var/run/macip"

macIpPattern 		= re.compile("^(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}).*$")
#00:23:25.078356 94:44:52:29:09:65 > 14:0c:76:28:f2:e4, Unknown Ethertype (0x88e1), length 60: 
#09:28:03.352629 b8:27:eb:ab:b5:99 > 1c:6f:65:20:dc:7d, IPv4, length 230: 192.168.1.253.22 > 192.168.1.33.61540: tcp 164
macLinePattern 		= re.compile("^\d\d:\d\d:\d\d.\d\d\d\d\d\d (\w\w:\w\w:\w\w:\w\w:\w\w:\w\w) > (\w\w:\w\w:\w\w:\w\w:\w\w:\w\w), ([^\,]*), length \d*: {0,1}([^ ]*).*$")


#------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------#
#------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------#
class OldDevicesEraser(Thread):
	#Thread charge simplement d'afficher une lettre dans la console.
    def __init__(self, rdpath):
		Thread.__init__(self)
		self.myRDPath = rdpath
		self.myStop = "False"
		
    def run(self):
		self.myStop = "False"
		# Code a executer pendant l execution du thread.
		while self.myStop == "False":
			#print "Erase some old devices2"
			self.eraseOldDevice()
			time.sleep(1)
		
    def eraseOldDevice(self):
		# Code a executer pendant l execution du thread.
		fileCandidates = []
		fileCandidates = glob.glob(self.myRDPath+ '/*')
		for candidateToRemove in fileCandidates:
			lastModifiedFor = time.time() - os.path.getmtime(candidateToRemove)
			#print "fileCandidates : " + candidateToRemove + " for:" + str(lastModifiedFor)
			if lastModifiedFor > 300:
				print "Remove " + candidateToRemove
				os.system("rm -f  " + candidateToRemove + " 1>/dev/null 2>/dev/null")
				
    def stop(self):
		self.myStop = "True"

#------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------#
#------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------#
def main():
	
	#print 'Number of arguments:', len(sys.argv), 'arguments.'
	#print 'Argument List:', str(sys.argv)

	# Lancement du thread d'effacement des vieux fichiers representant des equipements reseaux
	thread_OldDevicesEraser = OldDevicesEraser(runDirPath)
	thread_OldDevicesEraser.start()	
	#print "Eraser launched"
	
	#-------------- parser le fichier de conf mac device --------------"
	macDeviceConfFile=open(workingDirPath + "/MacWatcher.conf",'r')
	macDeviceLines = macDeviceConfFile.readlines()
	macDeviceConfFile.close()
	
	for macDeviceLine in macDeviceLines:
		macDeviceArray=macDeviceLine.split(' ')
		mac 	= macDeviceArray[0].rstrip()
		device 	= macDeviceArray[1].rstrip()
		ht_macToDevice[mac]=device
	# DisplayMacDevice() # afficher les infos
	
	#--------------- Initialisation du set des adresses mac trouvees dans le snif ---------------#
	if (len(sys.argv) == 2):	# get set from specified file
		tsharkStdoutFileStr=sys.argv[1]
		tsharkOutputFile=open(tsharkStdoutFileStr,'r')
		for macLine in tsharkOutputFile:		
			set_allMacIps.add(macLine.rstrip())
		tsharkOutputFile.close()
	else: 						# get set from stdin
		for lineMacIp in sys.stdin:
			#print "Buff process line '" + lineMacIp.rstrip() + "'"
			set_allMacIps.add(lineMacIp.rstrip())
			ProcessOneTSharkStdoutLine(lineMacIp)
	
	#print "Stopping thread and quit"
	thread_OldDevicesEraser.stop()
	
	#for lineMacIp in set_allMacIps:
	#	ProcessOneTSharkStdoutLine(lineMacIp)

#------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------#
def touch(fname):
    if os.path.exists(fname):
        os.utime(fname, None)
    else:
		os.system("mknod " + fname + " p 1>/dev/null 2>/dev/null")
        #open(fname, 'a').close()

#------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------#
def ProcessOneTSharkStdoutLine(macIpLine):	
	device = 'Unknown'
	try:
		m = macLinePattern.match(macIpLine)
		if not m:
			print "Cannot process line '" + macIpLine + "'"
		else:
			macIpArray = macIpLine.split(" ")
			macAdress = m.group(1)
			#macDestAdress = m.group(2)
			ipAdress = m.group(4)
			m2 = macIpPattern.match(ipAdress)
			if not m2:
				ipAdress = 'UnknownIP'
			else: 
				ipAdress = m2.group(1)
				
			lastModifiedFor = 0
			if macAdress in ht_macLastModified.keys():
				lastModifiedFor = time.time() - ht_macLastModified[macAdress]					
			# Si pas deja traite ou alors traite pas sans IP connue ou alors si derniere modif depuis plus de 2s
			if (not macAdress in set_ProcessedMac) or (ht_macToIp[macAdress] == 'UnknownIP' and ipAdress != 'UnknownIP') or lastModifiedFor > 2:
				set_ProcessedMac.add(macAdress)
				ht_macToIp[macAdress]=ipAdress
				ht_macLastModified[macAdress] = time.time()
				#print "Process mac='" + macAdress + "'" + " ip='" + ipAdress + "'     destmac='" + macDestAdress +"'"
				if macAdress in ht_macToDevice.keys():
					device=ht_macToDevice[macAdress]
				else:
					device="Unknown"
					
				fileCandidates = []
				fileCandidates = glob.glob(runDirPath+ '/' + macAdress + '_*')		
					
				if len(fileCandidates)>1 or len(fileCandidates)==0:
					for candidateToRemove in fileCandidates:
						os.system("rm -f  " + candidateToRemove + " 1>/dev/null 2>/dev/null")		
					filepath = runDirPath + '/' + macAdress + '_' + ipAdress + '_' + device
					touch(filepath)
				else:
					touch(fileCandidates[0])
		
	except BaseException as erreur:
		print "Exception when processing process line '" + macIpLine + "'"
		print "Error is : " + erreur
		pass
			
			
#------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------#
def DisplayMacDevice():
	for mac in ht_macToDevice.keys():
		print "Loaded : " + mac.ljust(20) + (" ").ljust(2) + ht_macToDevice[mac].ljust(40)

if __name__ == '__main__':
    main()
