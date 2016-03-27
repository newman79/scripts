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
from xms.system import SystemUtils

global verrou_log,progName

progName = os.path.basename(__file__).split(".")[0]

#-------------------------------------------------------------------------------------------------------------------------------------------------------------------#
# 																				MAIN  																				
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------#
def main():	
	
	parser = argparse.ArgumentParser(description='Example with simples options')
	parser.add_argument('-pslist' 		, '--pslist'		,	action="store", 	help="Liste des pid pour lesquels cumuler la charge cpu")
	parser.add_argument('-psfile' 		, '--psfile'		,	action="store", 	help="Fichier contenant la liste des pid pour lesquels cumuler la charge cpu")
	parser.add_argument('-displayover' 	, '--displayover'	,	action="store", 	help="Charge CPU au dessus de laquelle chaque processus sera affiche")
	result = parser.parse_args()
	arguments = dict(result._get_kwargs())

	thepslist = []
	if arguments['pslist'] != None: 
		thepslist = arguments['pslist'].split(',')
		#thepslist.append("this")
	else:
		if arguments['psfile'] != None: 
			psfile = arguments['psfile'].rstrip()
	
	over = 4
	if arguments['displayover'] != None: 
		over = arguments['displayover']
	
	global thread_CpuGraber
	
	thread_CpuGraber = SystemUtils.CPUGraber(callbackFromCPUGraber)
	
	if len(thepslist) != 0:
		for pid in thepslist:
			if pid != "this": thread_CpuGraber.addPid(pid)
			else			: thread_CpuGraber.addPid(str(os.getpid()))
	else:
		if psfile != None:
			thread_CpuGraber.setPidListFromFile(psfile)
		
	thread_CpuGraber.displayProcessesOver(over)
	
	thread_CpuGraber.start()	
		
	while True:
		try:	
			time.sleep(0.5)
		except KeyboardInterrupt:	
			thread_CpuGraber.stop()
			sys.exit(0)
		
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------#
# 									Appelee soit par le thread qui gere les arp, soit par le thread qui gere le tcpdump
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------#
def callbackFromCPUGraber(msg):
	theNow 	= datetime.datetime.utcnow()
	message = '[' + theNow.strftime('%Y%m%d_%H%M%S.%f') + '][' + progName + '][0] ' + msg 
	print  message
	sys.stdout.flush()
		
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------#
if __name__ == '__main__':
	main()
