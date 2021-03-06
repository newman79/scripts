# Liste les renderers presents sur le reseau local a partir du fichier passe en parametre
import random, time, pygame, sys, copy
import urllib2
from xml.dom.minidom import parse, parseString
import os

#------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------#
def main():
	global var1, var2,ht_renderers,ht_upnpName,ht_SerialNumber,ht_DeviceType
	
	ht_renderers=dict()
	ht_upnpName=dict()
	ht_SerialNumber=dict()
	ht_DeviceType=dict()
	
	#print 'Number of arguments:', len(sys.argv), 'arguments.'
	#print 'Argument List:', str(sys.argv)

	inputRenderersFilePath=sys.argv[1]

	os.system("gssdp-discover -i eth0  --timeout=5 | grep Location | grep :[0-9] | uniq >" + inputRenderersFilePath)
 
	inputRenderersFile=open(inputRenderersFilePath,'r')
	renderers = inputRenderersFile.readlines()
	inputRenderersFile.close()

	os.system("sudo rm -f  " + inputRenderersFilePath)

	# parser le fichier en entree pour construire le dictionnaire  IP --> liste des url xml de l IP
	for rendererDescription in renderers:
		rendererDesc=rendererDescription.rstrip()
		rendererXMLURLArray=rendererDesc.split(': ')
		rendererXMLURL=rendererXMLURLArray[1]
	
		IPandPort=rendererXMLURL.split('/')[2]
		IP=IPandPort.split(':')[0]
		tcpPort=IPandPort.split(':')[1]
		
		if IP in ht_renderers.keys():
			if not rendererXMLURL in ht_renderers[IP]:
				ht_renderers[IP].append(rendererXMLURL)
		else:
			ht_renderers[IP]=[]
			ht_renderers[IP].append(rendererXMLURL)

	# parser le dict IP --> liste des url xml de l'IP
	for rendererKey in ht_renderers.keys():
		#print "Traitement de " + rendererKey
		renderersURLS=ht_renderers[rendererKey]
		for url in renderersURLS:
			uXml=urllib2.urlopen(url)
			#print "   Traitement url " + url
			doc = parse(uXml)
			#print doc
			#for friendlyName in doc.getElementsByTagName('friendlyName'):
				#print '    friendlyName=' + str(friendlyName.firstChild.nodeValue)				
			friendlyNameList=doc.getElementsByTagName('friendlyName')
			if friendlyNameList.length != 0:
				upnpName=str(friendlyNameList.item(0).firstChild.nodeValue)
				if not upnpName in ht_upnpName.keys():
					ht_upnpName[rendererKey]=upnpName
				
			serialNumberList=doc.getElementsByTagName('serialNumber')
			if serialNumberList.length != 0:
				serialNumberStr=str(serialNumberList.item(0).firstChild.nodeValue)
				if not serialNumberStr in ht_SerialNumber.keys():
					ht_SerialNumber[rendererKey]=serialNumberStr
			
			deviceTypeList=doc.getElementsByTagName('deviceType')
			if deviceTypeList.length != 0:
				deviceTypeStr=str(deviceTypeList.item(0).firstChild.nodeValue)
				if rendererKey in ht_DeviceType.keys():
					if not deviceTypeStr in ht_DeviceType[rendererKey]:
						ht_DeviceType[rendererKey].append(deviceTypeStr)
				else:
					ht_DeviceType[rendererKey]=[]
					ht_DeviceType[rendererKey].append(deviceTypeStr)

	# afficher les infos
	DisplayInfo(ht_renderers.keys(),ht_upnpName,ht_SerialNumber,ht_DeviceType)

#------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------#
def DisplayInfo(IPs, upnpName, SerialNumber, DeviceType):
	for ip in IPs:
		print upnpName[ip].ljust(25) + (" ip:" + ip).ljust(20) + " sn:" + SerialNumber[ip].ljust(40) + " " + ConvertToHumanString(DeviceType[ip])

#------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------#
def ConvertToHumanString(devices):
	devStr="["
	for dev in devices:
		devArray=dev.split(':')
		if not devStr=="[":
			devStr+=" ; "
		devStr+=devArray[len(devArray)-2]
	devStr+="]"				
	return devStr
		

if __name__ == '__main__':
    main()
