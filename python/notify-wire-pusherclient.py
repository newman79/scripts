#!/usr/bin/python
# -*-coding:utf-8 -*
import random, time, sys, copy
import os
from os import path
from sets import Set
import re
import argparse
import datetime
from urllib import quote_plus

global NotificationDirPath

NotificationDirPath = '/home/pi/wirepusher-notification'

#-------------------------------------------------------------------------------------------------------------------------------------------------------------------#
# Description : aims to send notify to smartphone or tablet devices via pushnotification on wirepusher app channel and our own customized channels
# Prerequisite : To be able to receive notification, smartphone or tablet's owners have to install wirepusher application, launch it and give their token to me.
# I then append with it in /home/pi/scripts/python/WirePusherNotificationTokens.conf
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------#
def main():

	global tokens, tokensArray
	global notifSubject, msgTitle, message
	global NotificationDirPath
	
	parser = argparse.ArgumentParser(description='Example with simples options')
	parser.add_argument('-s' , '--subject'			,		action="store"		,  	help="subject of notification"				 					, required="true")
	parser.add_argument('-t' , '--title'			,		action="store"		,  	help="notification title"					 					, required="true")
	parser.add_argument('-m' , '--msg'				,		action="store"		,  	help="notification message"					 					, required="true")
	parser.add_argument('-w' , '--wirepushertokens'	,		action="store"		,  	help="comma separated list of wirepusher notification tokens"	, required="true")

	result = parser.parse_args()
	arguments = dict(result._get_kwargs())

	tokens 			= arguments['wirepushertokens']
	notifSubject 	= arguments['subject']
	title			= arguments['title']
	message			= arguments['msg']

	tokensArray = tokens.split(',')

	for token in tokensArray:
		# get notification file path
		lastTokenNotificationTouchFilePath = NotificationDirPath + "/last.notification." + notifSubject + ".for." + token

		mustNotifyToken = False

		if not path.exists(lastTokenNotificationTouchFilePath):
			mustNotifyToken = True
		else:
			# get last modification in seconds
			lastModifiedTokenFileTimeInSecondsSinceEpoch = os.path.getmtime(lastTokenNotificationTouchFilePath)
			currentTimeInSecondsSinceEpoch 				 = time.time()
			lastModifiedTokenFileSinceInSeconds 		 = currentTimeInSecondsSinceEpoch - lastModifiedTokenFileTimeInSecondsSinceEpoch
			mustNotifyToken = lastModifiedTokenFileSinceInSeconds > 14400

		# if last modified is very far, send notif and touch it

		now = datetime.datetime.now()
		dateTimeStr = now.strftime("%Y-%m-%d %H:%M:%S")
		completeTitle = quote_plus("[" + dateTimeStr + "] : ") + title

		if mustNotifyToken:
			curlCommand = "curl -k 'https://wirepusher.com/send?id=" + token + "&title=" + completeTitle + "&message=" + message + "&type=" + notifSubject + "'" # + "' 2>&1 1>/dev/null"
			print(curlCommand)
			os.system(curlCommand)
			print()
			os.system("sudo touch " + lastTokenNotificationTouchFilePath + " 2>/dev/null")
		else:
			print("Not sending to following token because it has recently been notified : " + token)

#-------------------------------------------------------------------------------------------------------------------------------------------------------------------#
if __name__ == '__main__':
	main()	

