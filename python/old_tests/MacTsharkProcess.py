#! /usr/bin/python
# Liste les renderers presents sur le reseau local a partir du fichier passe en parametre
import random, time, pygame, sys, copy
import urllib2
from xml.dom.minidom import parse, parseString
import os
from sets import Set
import glob

global ht_macToDevice,set_allMacs,workingDirPath,runDirPath

ht_macToDevice	= dict()
set_allMacs 	= Set()
workingDirPath 	= os.path.dirname(os.path.realpath(__file__) + "macip")
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
		tsharkStdoutFileStr=sys.argv[1]
		tsharkOutputFile=open(tsharkStdoutFileStr,'r')
		for macLine in tsharkOutputFile:		
			set_allMacs.add(macLine.rstrip())
		tsharkOutputFile.close()
	else: 						# get set from stdin
		for line in sys.stdin:
			#print "parse text : " + line.rstrip()
			set_allMacs.add(line.rstrip())
	
	for macLine in set_allMacs:
		ProcessOneTSharkStdoutLine(macLine)

#------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------#
def touch(fname):
    if os.path.exists(fname):
        os.utime(fname, None)
    else:
		os.system("mknod " + fname + " p 1>/dev/null 2>/dev/null")
        #open(fname, 'a').close()

#------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------#
def ProcessOneTSharkStdoutLine(macLine):	
	print "Process '" + macLine + "'"
	device = 'Unknown'
	if macLine in ht_macToDevice.keys():
		device=ht_macToDevice[macLine]
		
	fileCandidates = []
	fileCandidates = glob.glob(runDirPath+ '/' + macLine + '_*')		
	# try:
	# except OSError as osError:
		# pass
		
	if len(fileCandidates)>1 or len(fileCandidates)==0:
		for candidateToRemove in fileCandidates:
			os.system("rm -f  " + candidateToRemove + " 1>/dev/null 2>/dev/null")
		
		filepath = runDirPath + '/' + macLine + '_UnknownIP_' + device
		touch(filepath)
	else:
		touch(fileCandidates[0])
			

#------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------#
def DisplayMacDevice():
	for mac in ht_macToDevice.keys():
		print "Loaded : " + mac.ljust(20) + (" ").ljust(2) + ht_macToDevice[mac].ljust(40)

if __name__ == '__main__':
    main()
