#! /usr/bin/python
# -*-coding:utf-8 -*

import time
import urllib2
import os
from sets import Set
from threading import Thread,RLock
import subprocess

#-------------------------------------------------------------------------------------------------------------------------------------------------------------------#
#										Classe thread de recuperation de la cpu des processus
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------#
class CPUGraber(Thread):

	# notifyFunction prend en paramètre : wholeCpuLoad, selectedProcessesPidList, selectedProcessesCpuLoad
    def __init__(self, notifyFunctionStr,notifyInfoFunctionStr):
		Thread.__init__(self)
		self.notifyFunction 	= notifyFunctionStr
		self.notifyInfo 		= notifyInfoFunctionStr
		self.myStop 			= "False"
		self.myPidList 			= Set()
		self.processesOver 		= 20
		self.pidlistfilepath 	= None
		self.pidlistlastupdated = None

    def displayProcessesOver(self, over):
		self.processesOver = over
		
    def setPidListFromFile(self, filepath):
		self.pidlistfilepath = filepath

    def addPid(self, aPid):
		self.myPidList.add(aPid)
	
    def removePid(self, aPid):
		self.myPidList.remove(aPid)
		
    def getAllPid(self):
		return self.myPidList

	# entre 2 prise,   duree d'occupation cpu / duree reelle			
    def run(self):
	
		sc_clk_tck = os.sysconf_names['SC_CLK_TCK']
		HZ = float(os.sysconf(sc_clk_tck))

		self.myStop = "False"
		self.notifyInfo('Thread ProcessCPUGraber started with following PID selection : ')
		self.notifyInfo(repr(self.myPidList))
		
		self.curCpuUsed 			= 0
		self.curCpuTotal 			= 0
		self.curProcessesCpuUsed 	= 0
		self.curUsedByProcess		= dict()
		self.newUsedByProcess		= dict()
		
		self.grabUsedAndTotalCPUTimes()
		
		try:
			while self.myStop == "False":
				time.sleep(0.5)
				time.sleep(0.5)
				self.grabUsedAndTotalCPUTimes() # grab cpu times stats
				CPU_TOTAL_DELTA = (self.newCpuTotal - self.curCpuTotal)
				cpuUsedByAllProcessesPer 	= 100 * (self.newCpuUsed 			- self.curCpuUsed) 			/ CPU_TOTAL_DELTA
				if self.newProcessesCpuUsed < self.curProcessesCpuUsed:
					self.newProcessesCpuUsed = self.curProcessesCpuUsed
				cpuProcUsedByProcessesPer 	= 100 * (self.newProcessesCpuUsed 	- self.curProcessesCpuUsed) / CPU_TOTAL_DELTA				
				for pid in self.newUsedByProcess.keys():
					if pid in self.curUsedByProcess.keys():
						pidCpuUsed = 100 * (self.newUsedByProcess[pid] - self.curUsedByProcess[pid]) / CPU_TOTAL_DELTA
						if pidCpuUsed > self.processesOver:
							process = subprocess.Popen("cat /proc/" + pid + "/cmdline",shell=True, stdout=subprocess.PIPE)
							cmdLineCmd = process.communicate()[0]
							self.notifyInfo("CPU=" + str(round(pidCpuUsed,1)).rjust(5) + "% for PID:" + pid + "," + cmdLineCmd.ljust(20))
							
				self.notifyFunction(round(cpuUsedByAllProcessesPer,1), self.myPidList, round(cpuProcUsedByProcessesPer,1))
							
				self.curCpuUsed 			= self.newCpuUsed
				self.curCpuTotal 			= self.newCpuTotal
				self.curUsedByProcess		= self.newUsedByProcess
				self.curProcessesCpuUsed	= self.newProcessesCpuUsed
		except KeyboardInterrupt:		
			fin = True
			#self.endMainPgrm(True)			
		self.notifyInfo('Thread ProcessCPUGraber ended')
		
    def grabUsedAndTotalCPUTimes(self):
		result = float(0)
		try:
			with open('/proc/stat', 'r') as procfile:
				cputimes = procfile.readline()
				# First line of /proc/stat is agregation of all cpu times in in USER_HZ or Jiffies (typically hundredths of a second): 
				# Values are "cpu"  <user> <nice> <system> <idle> <iowait> <irc> <softirq> <steal> <guest> <guest_nice>
				arrayCpu = cputimes.split(' ')
				self.newCpuUsed = float(arrayCpu[2]) + float(arrayCpu[3]) + float(arrayCpu[4]) + float(arrayCpu[6]) + float(arrayCpu[7]) + float(arrayCpu[8]) + float(arrayCpu[9]) + float(arrayCpu[10])
				self.newCpuTotal = self.newCpuUsed + float(arrayCpu[5])							
		except IOError as erreur:
			result = 0
				
		#---------------- Recuperation pour les processus selectionnes ---------------#
		self.processes_usertime = 0
		self.processes_systime 	= 0
		
		if self.pidlistfilepath != None:
			process = subprocess.Popen('cat ' + self.pidlistfilepath,shell=True, stdout=subprocess.PIPE)
			self.myPidList 	= Set()
			for lineOut in process.stdout:
				line = lineOut.rstrip()
				self.myPidList.add(line)
		
		for pid in self.myPidList:	
			try:
				statfilepath = os.path.join('/proc/', str(pid), 'stat')
				with open(statfilepath, 'r') as pidfile:
					proctimes = pidfile.readline()		
					self.processes_usertime += float(proctimes.split(' ')[13]) + float(proctimes.split(' ')[15])	# get usertime from /proc/<pid>/stat, 14 item
					self.processes_systime 	+= float(proctimes.split(' ')[14]) + float(proctimes.split(' ')[16])	# get systemtime from proc/<pid>/stat, 15 item					
			except IOError as erreur:
				pass
		self.newProcessesCpuUsed = self.processes_usertime + self.processes_systime
				
		#---------------- Recuperation pour tous les processus ---------------#
		proc = subprocess.Popen("ps ax | cut -f1 -d' ' | paste -s | sed -e \"s/\t\t\t*//g\"",shell=True,stdout=subprocess.PIPE)
		line = proc.stdout.readline().rstrip()
		processes=line.split('\t')		
		#processes = [pid for pid in os.listdir('/proc') if pid.isdigit()]
		self.newUsedByProcess = {}
		for pid in processes:
			try:
				with open('/proc/' + pid + 'stat', 'r') as pidfile:
					proctimesArray = pidfile.readline().split(' ')
					self.newUsedByProcess[pid] = float(proctimesArray[13]) + float(proctimesArray[14])
			except:
				pass
		
    def stop(self):
		self.myStop = "True"
		
		
		
		
		
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------#
#										Classe thread de recuperation de la cpu et de la ram des processus
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------#
class StatsGraber(Thread):

	# notifyFunction prend en paramètre : wholeCpuLoad, selectedProcessesPidList, selectedProcessesCpuLoad
    def __init__(self, notifyFunctionStr):
		Thread.__init__(self)
		self.notifyFunction 	= notifyFunctionStr
		self.myStop 			= "False"
		self.GrabInterval		= 1
		self.countSleep			= 20

    def setGrabInterval(self, grabInterval):
		self.GrabInterval 	= grabInterval		
		self.sleepInter 	= self.GrabInterval / self.countSleep
	
	
	# entre 2 prise,   duree d'occupation cpu / duree reelle			
    def run(self):
	
		global MainLoop
		self.myStop = False
		
		sc_clk_tck = os.sysconf_names['SC_CLK_TCK']
		HZ = float(os.sysconf(sc_clk_tck))
		
		self.grabNewCPUValues() # grab cpu times stats		
		self.curCpuUsr	 = self.newCpuUsr
		self.curCpuSys	 = self.newCpuSys
		self.curCpuIdl	 = self.newCpuIdl
		self.curCpuIOW	 = self.newCpuIOW
		self.curCpuIrq	 = self.newCpuIrq
		self.curCpuSIrq	 = self.newCpuSIrq
		self.curCpuVirt	 = self.newCpuVirt
		self.curCpuTot	 = self.newCpuTot		
		
		while self.myStop == False:
			try:
				cpt = 0
				while cpt < self.countSleep and self.myStop == False:
					time.sleep(self.sleepInter)
					cpt += 1
			except KeyboardInterrupt:
				MainLoop = False
				self.myStop = True
			
			self.grabMem()
			self.grabNewCPUValues() # grab cpu times stats
							
			CPU_TOTAL_DELTA = (self.newCpuTot - self.curCpuTot)
			
			cpuUsr 	= 100 * (self.newCpuUsr - self.curCpuUsr) 	/ CPU_TOTAL_DELTA
			cpuSys 	= 100 * (self.newCpuSys - self.curCpuSys) 	/ CPU_TOTAL_DELTA
			cpuIdl 	= 100 * (self.newCpuIdl - self.curCpuIdl) 	/ CPU_TOTAL_DELTA
			cpuIOW 	= 100 * (self.newCpuIOW - self.curCpuIOW) 	/ CPU_TOTAL_DELTA
			cpuIrq 	= 100 * (self.newCpuIrq - self.curCpuIrq) 	/ CPU_TOTAL_DELTA
			cpuSIrq = 100 * (self.newCpuSIrq - self.curCpuSIrq) / CPU_TOTAL_DELTA
			cpuVirt	= 100 * (self.newCpuVirt - self.curCpuVirt) / CPU_TOTAL_DELTA
			
			self.notifyFunction(cpuUsr,cpuSys,cpuIdl,cpuIOW,cpuIrq,cpuSIrq,cpuVirt,self.memTotal,self.memFree,self.memUsed,self.memBuff,self.memCach)
					
			self.curCpuUsr	 = self.newCpuUsr
			self.curCpuSys	 = self.newCpuSys
			self.curCpuIdl	 = self.newCpuIdl
			self.curCpuIOW	 = self.newCpuIOW
			self.curCpuIrq	 = self.newCpuIrq
			self.curCpuSIrq	 = self.newCpuSIrq
			self.curCpuVirt	 = self.newCpuVirt
			self.curCpuTot	 = self.newCpuTot
	
	#-----------------------------------------------------------------
    def grabNewCPUValues(self):
		result = float(0)
		try:
			with open('/proc/stat', 'r') as procfile:
				cputimes = procfile.readline()
				# First line of /proc/stat is agregation of all cpu times in in USER_HZ or Jiffies (typically hundredths of a second): 
				# Values are time for which cpu was used in each of 10 modes
					# user: normal processes executing in user mode
					# nice: niced processes executing in user mode
					# system: processes executing in kernel mode
					# idle: twiddling thumbs
					# iowait: waiting for I/O to complete
					# irq: servicing interrupts
					# softirq: servicing softirqs
					# Since Linux 2.6.11, 'steal' - counts the ticks spent executing other virtual hosts (in virtualised environments like Xen)
					# Since Linux 2.6.24, 'guest' - counts the time spent running a virtual CPU for guest operating systems under the control of the Linux 
					# Since Linux 2.6.24, 'guest nice' - counts the time spent running a virtual CPU for guest operating systems under the control of the Linux kernel
				
				
				arrayCpu = cputimes.split(' ')
				# usr + nice
				self.newCpuUsr = float(arrayCpu[2]) + float(arrayCpu[3]) 
				self.newCpuSys	= float(arrayCpu[4])
				self.newCpuIdl	= float(arrayCpu[5])
				self.newCpuIOW	= float(arrayCpu[6])
				self.newCpuIrq	= float(arrayCpu[7])
				self.newCpuSIrq	= float(arrayCpu[8])
				self.newCpuVirt = float(arrayCpu[9]) + float(arrayCpu[10]) + float(arrayCpu[11])
				self.newCpuTot = self.newCpuUsr + self.newCpuSys + self.newCpuIdl + self.newCpuIOW + self.newCpuIrq + self.newCpuSIrq + self.newCpuVirt				
		except IOError as erreur:
			result = 0			
				
	#-----------------------------------------------------------------
    def grabMem(self):
		memInfoFile = open('/proc/meminfo', "r") 
		memArray = memInfoFile.readlines() 
		memInfoFile.close()
		self.memTotal = int(memArray[0].split(':')[1].replace(' kB','').rstrip())
		self.memFree  = int(memArray[1].split(':')[1].replace(' kB','').rstrip())
		self.memUsed  = self.memTotal - self.memFree
		self.memBuff  = int(memArray[3].split(':')[1].replace(' kB','').rstrip())
		self.memCach  = int(memArray[4].split(':')[1].replace(' kB','').rstrip())
		
	#-----------------------------------------------------------------
    def stop(self):
		self.myStop = True