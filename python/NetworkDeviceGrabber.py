#! /usr/bin/python
# -*-coding:utf-8 -*
# Liste les renderers presents sur le reseau local a partir du fichier passe en parametre
import time
import sys
import os
import sets
import glob
import re
from threading import Thread,RLock
import signal
import subprocess
import argparse
import datetime
import json
import thread


global ht_macToDevice, ht_macToIp
global workingDirPath,logFilePath, devicesDefPath
global PatternWithIp,PatternJustMac,PatternTcpDump
global UNKNOWN_IP_ADDR,tcpDumpNbPacket, NotifAtEachNBPackets
global fileIn, eraseAfter, tcpdumpIn
global fatherProcessCmdLine
global daemonPidFile
global processId
global mainProcessLoop

global verrou_ip, verrou_log
global thread_OldDevicesEraser, thread_MacIpUpdater, thread_CpuGraber

#------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------#
re.UNICODE
ht_macToDevice		= dict()
ht_macToIp			= dict()
workingDirPath 		= os.path.dirname(os.path.realpath(__file__))
progName 			= os.path.basename(__file__).split(".")[0]
# Default values 
devicesDefPath		= workingDirPath + "/MacWatcher.conf"
runDirPath 			= "/var/run/NDGraber"
runDevicesDirPath 	= runDirPath + "/devices"
daemonPidFile		= runDirPath + "/NDGraber.pid"
logFilePath			= runDirPath + "/NDGraber.log"
prevMacIpFileName 	= '/MacIp.previous'
pidsFilePathName	= '/processpidtree.pids'

cacheDirPath		= "/var/cache/NDGraber"
eraseAfter			= 30
tcpDumpNbPacket		= 8000
NotifAtEachNBPackets= 1000

UNKNOWN_IP_ADDR 	= "__" + "UnknownIP".ljust(16).replace(" ","_")
PatternWithIp 		= re.compile("^\s*(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}).\d*$")
PatternJustMac 		= re.compile("^([a-f0-9][a-f0-9]:){5}[a-f0-9][a-f0-9]$")

#00:23:25.078356 94:44:52:29:09:65 > 14:0c:76:28:f2:e4, Unknown Ethertype (0x88e1), length 60: 
#09:28:03.352629 b8:27:eb:ab:b5:99 > 1c:6f:65:20:dc:7d, IPv4, length 230: 192.168.1.253.22 > 192.168.1.33.61540: tcp 164
PatternTcpDump 		= re.compile("^\d\d:\d\d:\d\d.\d\d\d\d\d\d (\w\w:\w\w:\w\w:\w\w:\w\w:\w\w) > (\w\w:\w\w:\w\w:\w\w:\w\w:\w\w), ([^\,]*), length \d*: {0,1}([^ ]*).*$")

mainProcessLoop 	= True
verrou_mainProcess 	= RLock()

verrou_ip	  		= RLock()
verrou_log	  		= RLock()
verrou_FileSysUpd	= RLock()

#-------------------------------------------------------------------------------------------------------------------------------------------------------------------#
#										Fonction d'arret du programme
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------#
def signal_handler(signal, frame):
    Terminate()

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
#										Classe thread de suppression des vieux equipements
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------#
class OldDevicesEraser(Thread):
    def __init__(self, rdpath):
		Thread.__init__(self)
		self.myRDPath = rdpath
		self.myStop = False
		
    def run(self):
		global mainProcessLoop
		LogMsg(0, 'Thread OldDevicesEraser started')
		self.myStop = False
		try:
			while self.myStop == False:
				self.eraseOldDevice()
				i = 0
				while i < 10 and self.myStop == False:
					time.sleep(0.4)
					i += 1
		except KeyboardInterrupt:
			with verrou_mainProcess:
				mainProcessLoop = False
		os.system('rm -f ' + daemonPidFile + ' 1>/dev/null 2>&1')
		LogMsg(0, 'Thread OldDevicesEraser ended')
		
    def eraseOldDevice(self):
		with verrou_FileSysUpd:
			fileCandidates = []
			fileCandidates = glob.glob(self.myRDPath+ '/*')
			for candidateToRemove in fileCandidates:
				lastModifiedFor = time.time() - os.path.getmtime(candidateToRemove)
				if lastModifiedFor > eraseAfter: # 60s
					LogMsg(0, "Remove " + candidateToRemove)
					filename = os.path.basename(candidateToRemove)
					mac = filename[:17] # nom d'un fichier mac_ip_device = XX:XX:XX:XX:XX:XX...
					with verrou_ip:
						os.system("rm -f  " + candidateToRemove + " 1>/dev/null 2>/dev/null")
						if mac in ht_macToIp.keys():	del ht_macToIp[mac]
				
    def stop(self):
		self.myStop = True

#-------------------------------------------------------------------------------------------------------------------------------------------------------------------#
#										Classe thread de mise a jour a partir d arp
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------#
class MacIpUpdater(Thread):
    def __init__(self):
		Thread.__init__(self)
		self.myStop = False
		
    def run(self):
		global mainProcessLoop
		LogMsg(0, 'Thread MacIpUpdater started')
		self.myStop = False
		time.sleep(2)
		try:
			while self.myStop == False:
				self.updateMacIp()
				# waiting
				i = 0
				while i < 1 and self.myStop == False:
					time.sleep(0.2)
					i += 1
				
		except KeyboardInterrupt:	
			with verrou_mainProcess:
				mainProcessLoop = False
		os.system('rm -f ' + daemonPidFile + ' 1>/dev/null 2>&1')
		LogMsg(0, 'Thread MacIpUpdater ended')
		
    def updateMacIp(self):
		arpCommand = "arp -a | sed \"s/[()]//g\" | awk '{print $4\"_\"$2}'  2>/dev/null"
		proc = subprocess.Popen(arpCommand,shell=True,stdout=subprocess.PIPE)
		while self.myStop == False:
			time.sleep(0.2)
			line = proc.stdout.readline().rstrip()
			if line != '':
				with verrou_FileSysUpd:
					macIp = line.rstrip().split("_")
					if PatternJustMac.match(macIp[0]):
						ip = macIp[1]
						pingResult = os.system("ping -c1 -w1 " + ip + " 1>/dev/null 2>&1")
						if pingResult == 0:
							with verrou_ip:
								ht_macToIp[macIp[0]]=ip
								UpdateDevice(macIp[0], ip, "")
						else:
							with verrou_ip:
								try:
									del ht_macToIp[macIp[0]]
									fileCandidates = glob.glob(runDevicesDirPath+ '/' + mac + '_*')
									os.system("rm -f  " + fileCandidates[0] + " 1>/dev/null 2>/dev/null")
								except:
									erreur = True
			else:
				break
				
    def stop(self):
		self.myStop = True
		
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------#
#										Classe thread de mise a jour a partir des packets tcpdump
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------#
class TcpdumpGraber(Thread):
    def __init__(self):
		Thread.__init__(self)
		self.myStop = False
		self.myStdinHandle = None
		self.compteur = 0

    def run(self):
		global mainProcessLoop
		self.myStop = False
		LogMsg(0, 'Thread TcpdumpGraber started')
		try:		
			compteur = 0
			#------- wait until main process is setting self.myStop -------#
			while self.myStdinHandle == None and self.myStop == False:
				time.sleep(0.1)
			#-------------------------- process loop ----------------------#
			lineMacIp = self.myStdinHandle.readline().rstrip()
			while (lineMacIp != '' and self.myStop == False):
				ProcessOneTcpdumpStdoutLine(lineMacIp)
				self.compteur += 1
				time.sleep(0.002)
				lineMacIp = self.myStdinHandle.readline().rstrip()
		except KeyboardInterrupt:	
			with verrou_mainProcess:
				mainProcessLoop = False
		os.system('rm -f ' + daemonPidFile + ' 1>/dev/null 2>&1')
		LogMsg(0, 'Thread TcpdumpGraber ended')
				
    def setStdIn(self, theInputFileHandle):
		self.myStdinHandle = theInputFileHandle
		
    def getProcessPacquetsNb(self):
		return self.compteur

    def stop(self):
		self.myStop = True
		
		
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------#
# 																				MAIN  																				
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------#
def main():
	#print 'Number of arguments:', len(sys.argv), 'arguments.'
	#print 'Argument List:', str(sys.argv)	
	parser = argparse.ArgumentParser(description='Example with simples options')
	parser.add_argument('-eraseAfter'		, '--eraseAfter' 		,	action="store", type=int, 	help="Delai apres lequel un fichier 'mac_ip_devices' est mis a jour")	
	parser.add_argument('-log' 				, '--log'				,	action="store", 			help="Chemin complet vers le fichier de log")
	parser.add_argument('-devicesOut'		, '--devicesOut'		,	action="store", 			help="Chemin complet du dossier cible dans lequel sont ecrits les fichiers 'mac_ip_devices'")
	parser.add_argument('-devdef'			, '--devdef' 			,	action="store", 		 	help="Fichier d'association mac <--> devices")	
	parser.add_argument('-cacheDir'			, '--cacheDir' 			,	action="store", 			help="Fichier dans lequel placer la liste des pids des processus cree par ce process")	
	result = parser.parse_args()
	arguments = dict(result._get_kwargs())
	
	global devicesDefPath
	global runDevicesDirPath
	global logFilePath
	global eraseAfter
	global cacheDirPath
	global PrevMacIpFilePath
	global mainProcessLoop
	
	if arguments['devdef'] 		!= None	: devicesDefPath 	= arguments['devdef']
	if arguments['eraseAfter'] 	!= None	: eraseAfter 		= arguments['eraseAfter']
	if arguments['cacheDir'] 	!= None	: cacheDirPath		= arguments['cacheDir']
	if arguments['devicesOut'] 	!= None	: runDevicesDirPath = arguments['devicesOut']
	if arguments['log'] 		!= None	: logFilePath 		= arguments['log']
			
	LogMsg(0, '---------- Context -----------')
	LogMsg(0, '  devices           : ' + devicesDefPath)
	LogMsg(0, '  runDevicesDirPath : ' + runDevicesDirPath)
	LogMsg(0, '  logFilePath       : ' + logFilePath)
	LogMsg(0, '  eraseAfter        : ' + str(eraseAfter))
	LogMsg(0, '  cacheDir          : ' + cacheDirPath)	
	
	PrevMacIpFilePath 	= cacheDirPath + prevMacIpFileName
	PidsFilePath		= cacheDirPath + pidsFilePathName

	signal.signal(signal.SIGINT, signal_handler)	
	
	global fatherPID
	fatherPID = os.getppid()
	global processId
	processId = os.getpid()

	# Creer le repertoire cache si nécessaire
	if not os.path.isdir(cacheDirPath):	
		os.system("sudo mkdir " 	+ cacheDirPath)
		os.system("sudo chmod 777 " + cacheDirPath)
		
	if not os.path.isdir(runDevicesDirPath):	
		os.system("sudo mkdir " 	+ runDevicesDirPath)
		os.system("sudo chmod 777 " + runDevicesDirPath)

	# S assurer qu aucun autre daemon ne tourne deja
	pidFileExists = os.system('sudo ls ' + daemonPidFile + ' 1>/dev/null 2>&1')
	if pidFileExists == 0:
		process = subprocess.Popen('sudo cat ' + daemonPidFile,shell=True, stdout=subprocess.PIPE)
		prevDaemonPid = process.communicate()[0].rstrip()
		resPrevDP = os.system('ps -p ' + prevDaemonPid + ' 1>/dev/null 2>&1')
		if resPrevDP == 0:
			LogMsg(3, 'This daemon is already running. pid : ' + str(fatherPID))
			LogMsg(3, 'To restart it, you must add -restart option in commandline args')
			sys.exit(3)
	os.system('sudo echo ' + str(processId) + " 1>" + daemonPidFile)
	
	global fatherProcessCmdLine
	process = subprocess.Popen('sudo cat /proc/' + str(fatherPID) + '/cmdline',shell=True, stdout=subprocess.PIPE)
	fatherProcessCmdLine = process.communicate()[0]
	LogMsg(0, '  FatherProcess     : ' + 'pid:' + str(fatherPID) + ' cmd:' + fatherProcessCmdLine)
	
	try:		
		#------------------------------------------ parser le fichier de conf mac device ----------------------------------------------------#
		macDeviceConfFile	= open(devicesDefPath,'r')
		macDeviceLines 		= macDeviceConfFile.readlines()
		macDeviceConfFile.close()
		#---------------------------------- Initialisation du set des adresses mac trouvees dans le snif ------------------------------------#
		for macDeviceLine in macDeviceLines:
			if macDeviceLine.rstrip() != "":
				macDeviceArray 	= macDeviceLine.split(' ')
				mac 			= macDeviceArray[0].rstrip()
				device 			= macDeviceArray[1].rstrip()
				ht_macToDevice[mac]=device

		#------------------------------------------ Recuperation des ips precedemment tracees -----------------------------------------------#
		if os.path.exists(PrevMacIpFilePath): 
			previousMacIpFileHandle = open(PrevMacIpFilePath,'r')	
			tmpMacIpFile = previousMacIpFileHandle.read()
			json_acceptable_string = tmpMacIpFile.replace("'", "\"")
			global ht_macToIp
			ht_macToIp = json.loads(json_acceptable_string)
			previousMacIpFileHandle.close()
				
		#------------ Lancement du thread d'effacement des vieux fichiers "mac_ip_device" (representant des equipements reseaux) ------------#
		global thread_OldDevicesEraser
		thread_OldDevicesEraser = OldDevicesEraser(runDevicesDirPath)
		thread_OldDevicesEraser.start()
		#-------------- Lancement du thread de mise a jour des fichiers "mac_ip_device" (representant des equipements reseaux) --------------#
		global thread_MacIpUpdater
		thread_MacIpUpdater 	= MacIpUpdater()
		thread_MacIpUpdater.start()			
		#-------------- Lancement du thread de mise a jour des fichiers "mac_ip_device" (representant des equipements reseaux) --------------#
		global thread_TcpdumpGraber
		thread_TcpdumpGraber 	= TcpdumpGraber()
		thread_TcpdumpGraber.start()			
		
		#tcpDumpCommand = "sudo tcpdump -U -e -K -l -n -q -c " + str(tcpDumpNbPacket) + " 2>/dev/null"
		tcpDumpCommand = "sudo tcpdump -e -K -l -n -q 2>/dev/null"
		tcpDumpProc = subprocess.Popen(tcpDumpCommand, shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
		time.sleep(0.2)		
		thread_TcpdumpGraber.setStdIn(tcpDumpProc.stdout)

		#-------------- Recencensement des pids de tous les processus appelés --------------#
		os.system('sudo echo ' + str(processId) + ' >' + PidsFilePath)
		
		# Je n'ai pas trouvé mieux pour l'instant : La commande qui lance tcpdump lance en fait un bash qui lance un sudo qui lance tcpdump avec les privilèges root ==> 3 processus : 
		# ps xao pid,ppid,cmd | grep tcpdump  renverra : 
		# <rootPid> 	<pythonPgrmPid> /bin/sh -c sudo tcpdump -e -K -l -n -q -c 8000 2>/dev/null
		# <middlePid> 	<rootPid>		sudo tcpdump -e -K -l -n -q -c 8000
		# <childPid> 	<middlePid>		tcpdump -e -K -l -n -q -c 8000
		# La commande suivante permet de récupérer les 3 processus : # ps xao pid,ppid,cmd | grep tcpdump | grep -v grep | awk '{print $1}'
		# tcpDumpProc.pid   correspond au processus /bin/sh -c sudo tcpdump ...
		
		os.system('sudo echo ' + str(tcpDumpProc.pid) + ' >>' + PidsFilePath)
		getSudoTcpdumpPid = subprocess.Popen("ps -o pid --ppid " + str(tcpDumpProc.pid) + " | awk 'NR>1'",shell=True, stdout=subprocess.PIPE)
		sudoTcpdumpPid = getSudoTcpdumpPid.communicate()[0].rstrip()
		os.system('sudo echo ' + sudoTcpdumpPid + ' >>' + PidsFilePath)		
		getTcpdumpPid = subprocess.Popen("ps -o pid --ppid " + sudoTcpdumpPid + " | awk 'NR>1'",shell=True, stdout=subprocess.PIPE)
		tcpdumpPid = getTcpdumpPid.communicate()[0].rstrip()
		os.system('sudo echo ' + tcpdumpPid + ' >>' + PidsFilePath)		
		
		while True:
			LogMsg(0, str(thread_TcpdumpGraber.getProcessPacquetsNb()) + ' packets processed')
			i = 0
			with verrou_mainProcess:
				if mainProcessLoop == False:
					break			
			if Main.mustRun() == False:
				break			
				
			while i < 200:
				i = i + 1
				time.sleep(0.05)			
				with verrou_mainProcess:
					if mainProcessLoop == False:
						break			
		
	except KeyboardInterrupt:	
		mainProcessLoop = False
		
	Terminate()
		
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------#
# 									Function called by CPUGraber
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------#
def callbackFromCPUGraber(msg):
	LogMsg(0,msg)
	
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------#
# 									Termine le processus
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------#
def Terminate():
		LogMsg(0, 'Main Process is stopping threads')
		thread_OldDevicesEraser.stop()
		thread_MacIpUpdater.stop()
		thread_TcpdumpGraber.stop()
		thread_OldDevicesEraser.join()
		thread_MacIpUpdater.join()		
		thread_TcpdumpGraber.join()		
		LogMsg(0, 'All threads has been stopped')
		LogMsg(0, 'Main Process ending')

		try:	fileIn.close() 
		except:	pass		
		#------------- Serialize MacIp -------------#
		macIpFileHandle = open(PrevMacIpFilePath,'w')
		tmpstr = ""
		macIpFileHandle.write("{\n");
		for mac in ht_macToIp.keys():
			tmpstr = tmpstr + "    '" + mac + "':'" + ht_macToIp[mac] + "',\n"
		macIpFileHandle.write(tmpstr[:-2] + "\n")
		macIpFileHandle.write("}\n");
		macIpFileHandle.close()		
		LogMsg(0, 'Main Process ended')
		os.system("sudo kill -9 " + str(processId) + " 1>/dev/null 2>/dev/null") # Pour etre certain qu'il quitte
		
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------#
# 									Appelee soit par le thread qui gere les arp, soit par le thread qui gere le tcpdump
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------#
def LogMsg(level, msg):
	theNow 	= datetime.datetime.utcnow()
	with verrou_log:
		message = '[' + theNow.strftime('%Y%m%d_%H%M%S.%f') + '][' + progName + '][' + str(thread.get_ident()) + '][' + str(level) + '] ' + msg 
		logFileHandle = open(logFilePath,'a')
		logFileHandle.write(message + '\n')
		logFileHandle.close()
		print  message
		
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------#
# 									Appelee soit par le thread qui gere les arp, soit par le thread qui gere le tcpdump
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------#
def UpdateDevice(mac, ip, device):
	global targetMacFilePath,currentMacFilePath
	targetMacFilePath 	= ""
	currentMacFilePath 	= ""
	try:
		with verrou_FileSysUpd:	
			#---------------------- get files with specified mac adress ----------------#
			fileCandidates = []
			fileCandidates = glob.glob(runDevicesDirPath+ '/' + mac + '_*')
			
			currentMacFilePath = ""
			if len(fileCandidates) > 1:
				besttime = -1
				for candidate in fileCandidates:
					if os.path.getmtime(candidate) > besttime:
						besttime = os.path.getmtime(candidate)
						currentMacFilePath = candidate
						
				for candidate in fileCandidates:
					if candidate != currentMacFilePath:		os.system("rm -f  " + candidate + " 1>/dev/null 2>/dev/null")
					
			else:
				if len(fileCandidates) == 0	: currentMacFilePath = "" # il n'y a pas de fichier de device
				else						: currentMacFilePath = fileCandidates[0]   # Il n'y en a qu'un
			
			lastModifiedFor = 0.2 + 1		
			if currentMacFilePath != "":
				besttime = os.path.getmtime(currentMacFilePath)
				lastModifiedFor = time.time() - besttime
				
			if lastModifiedFor > 0.2:
				# Construire le chemin du fichier cible
				if ip == "": 		# ==> il s agit d une mise a jour a partir d un pacquet tcpdump
					with verrou_ip:
						if mac in ht_macToIp.keys()	: ip = ht_macToIp[mac]
						else						: ip = "UnknownIP"
				if device == "":	# ==> il s agit d une mise a jour a partir d arp
					if mac in ht_macToDevice.keys()	: device = ht_macToDevice[mac]
					else							: device = "Unknown"
				targetMacFilePath = runDevicesDirPath + '/' + mac + '_' + ip + '_' + device
				
				# Mettre a jour ou creer le fichier
				if currentMacFilePath == "" : # il faut le creer
					os.system("mknod " + targetMacFilePath + " p 1>/dev/null 2>/dev/null") #LogMsg(0, "Add " + "mac='" + mac + "' ip='" + ip + "' device='" + device)
				else:
					if currentMacFilePath == targetMacFilePath: # juste un touch
						os.utime(currentMacFilePath, None) #LogMsg(0, "Touch " + currentMacFilePath)
					else:										# il faut renommer le fichier
						os.system("mv " + currentMacFilePath + " " + targetMacFilePath + " 2>/dev/null") #LogMsg(0, "Move " + currentMacFilePath + ' --> ' + targetMacFilePath)
	except BaseException as erreur:
		LogMsg(2,"UpdateDevice:Exception mac='" + mac + "' ip='" + ip + "' device='" + device + "' currentMacFilePath=" + currentMacFilePath + "' targetMacFilePath=" + targetMacFilePath)
		LogMsg(2,"Error is " + str(erreur))
		LogMsg(2,traceback.format_exc())		
		pass
		
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------#
#                                      Process one line of tcpdump line grab from stdout
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------#
def ProcessOneTcpdumpStdoutLine(macIpLine):	
	device = 'Unknown'
	try:
		m = PatternTcpDump.match(macIpLine)
		if not m	: LogMsg(1,"Cannot process line '" + macIpLine + "'")
		else		:
			macAdress = m.group(1)
			device = ""
			if macAdress in ht_macToDevice.keys():
				device = ht_macToDevice[macAdress]
			UpdateDevice(macAdress,"",device)
			
	except KeyboardInterrupt:	Terminate()
	except BaseException as erreur:
		LogMsg(2,"Exception when processing process line '" + macIpLine + "'")
		LogMsg(2,"Error is " + str(erreur))			
			
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------#
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------#
def DisplayMacIp():
	for mac in ht_macToIp.keys():
		print "Loaded : " + mac.ljust(20) + (" ").ljust(2) + ht_macToIp[mac].ljust(40)

#-------------------------------------------------------------------------------------------------------------------------------------------------------------------#
if __name__ == '__main__':
	try:
		main()
	except KeyboardInterrupt:	Terminate()