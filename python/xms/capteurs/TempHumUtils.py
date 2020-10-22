#! /usr/bin/python
# -*-coding:utf-8 -*

import time
import urllib2
import os
from sets import Set
from threading import Thread,RLock
import subprocess
from xms.capteurs import dth11_szazo
import RPi.GPIO as GPIO

#-------------------------------------------------------------------------------------------------------------------------------------------------------------------#
#										Classe thread de recuperation de la température et de l'humidité à partir du capteur dth11
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------#
class TempHumGraber(Thread):

	# notifyFunction prend en paramètre : temperature, humidity
    def __init__(self, notifyFunctionStr,logFunctionStr, pin):
		Thread.__init__(self)
		self.notifyFunction 	= notifyFunctionStr
		self.logFunction 		= logFunctionStr
		self.myStop 			= "False"
		self.GrabInterval		= 120.0
		self.countSleep			= 120.0
		self.dth11_pin 			= pin
		self.sleepInter 		= self.GrabInterval / self.countSleep

    def setGrabInterval(self, grabInterval):
		self.GrabInterval 	= grabInterval		
		self.sleepInter 	= self.GrabInterval 	/ self.countSleep
	
    def stop(self):
		self.myStop = True

    def run(self):
		# initialize GPIO
		GPIO.setwarnings(False)
		GPIO.setmode(GPIO.BCM)
		GPIO.cleanup()
		# read data using pin 14
		instance = dth11_szazo.DHT11(pin = self.dth11_pin)

		global MainLoop
		self.myStop = False
				
		while self.myStop == False:
			#-------------------- wait some time --------------------#
			cpt = 0
			#self.logFunction("sleepInter : " + str(self.sleepInter))
			while cpt < self.countSleep and self.myStop == False:
				time.sleep(self.sleepInter)
				cpt += 1

			#self.logFunction("now get a new value")
			cptTest = 0
			while cptTest < 50 and self.myStop == False:
				cptTest = cptTest + 1
				result = instance.read()
				if result.is_valid():
					self.notifyFunction(result.temperature,result.humidity)
					cptTest = 50
				else:
					time.sleep(0.1)
			#if self.myStop:
			#	self.logFunction("now terminate thread : stopped")

