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

global ht_macToDevice,set_allMacs,macPattern, workingDirPath,runDirPath

ht_macToDevice	= dict()
ht_macToIp		= dict()
macPattern 		= re.compile("^([a-f0-9][a-f0-9]:){5}[a-f0-9][a-f0-9]$")
workingDirPath 	= os.path.dirname(os.path.realpath(__file__))
runDirPath 	= "/var/run/macip"

#------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------#
def main():
	
	#print 'Number of arguments:', len(sys.argv), 'arguments.'
	#print 'Argument List:', str(sys.argv)

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
		MacIpStdoutFileStr=sys.argv[1]
		MacIpStdoutFile=open(MacIpStdoutFileStr,'r')
		for macIpLine in MacIpStdoutFile:		
			lineArray=macIpLine.rstrip().split('_')
			ht_macToIp[lineArray[0]]=lineArray[1]
		MacIpStdoutFile.close()
	else: 						# get set from stdin
		for line in sys.stdin:
			lineArray=line.rstrip().split('_')
			if macPattern.match(lineArray[0]):
				ht_macToIp[lineArray[0]]=lineArray[1]
	
	for mac in ht_macToIp.keys():
		ProcessOneMacIp(mac)
		sleep(0.2)

#------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------#
def touch(fname):
    if os.path.exists(fname):
        os.utime(fname, None)
    else:
		os.system("mknod " + fname + " p 1>/dev/null 2>/dev/null")
        #open(fname, 'a').close()

#------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------#
def ProcessOneMacIp(mac):	
	print "Process '" + mac + "'"
	
	fileCandidates = []
	# try:
	fileCandidates = glob.glob(runDirPath + '/' + mac+'_*')		
	# except OSError as osError:
		# pass
	
	device='Unknown'
	if mac in ht_macToDevice:
		device 	= ht_macToDevice[mac]
	ip = ht_macToIp[mac]
	
	#pingResult = os.system("ping -c1 -w1 " + ip + " 1>/dev/null 2>&1")
	
	targetFilepath = runDirPath + '/' + mac + '_' + ip + '_' + device
	if len(fileCandidates)>1 or len(fileCandidates)==0:
		for candidateToRemove in fileCandidates:
			os.system("rm -f  " + candidateToRemove + " 1>/dev/null 2>/dev/null")
		if pingResult == 0:
			touch(targetFilepath)
	else:
		if pingResult == 0:
			os.system("mv " + fileCandidates[0] + " " + targetFilepath + " 1>/dev/null 2>/dev/null")
		else:
			os.system("rm -f  " + fileCandidates[0] + " 1>/dev/null 2>/dev/null")


#------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------#
def DisplayMacDevice():
	for mac in ht_macToDevice.keys():
		print "Loaded : " + mac.ljust(20) + (" ").ljust(2) + ht_macToDevice[mac].ljust(40)

if __name__ == '__main__':
    main()
