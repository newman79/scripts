#!/usr/bin/python
# Developed by Shantanu Goel. http://tech.shantanugoel.com/

import socket
import argparse
import time

SEP = "\r\n"

#Defaults
DefaultPort = 52235
receiver_no = "1234567890"
sender_no   = "1234567890"
receiver    = "Receiver"
sender      = "Sender"
epochtime   = time.mktime(time.localtime())


# TV-HOME   Channel    ChType DTV   MajorCh 8		MinorCh 65534    PTC 25      ProgNum 513
# TV-HOME   Channel    ChType DTV   MajorCh 6		MinorCh 65534    PTC 30      ProgNum 1025
# TV-HOME   Channel    ChType DTV   MajorCh 32		MinorCh 65534    PTC 28      ProgNum 2051


def SendCommand_SendKeyCode(ip, port, serviceUuid,controlURL, KeyCode):
  
  httpBodyStart = "<?xml version=\"1.0\" encoding=\"utf-8\"?>" + "<s:Envelope xmlns:s=\"http://schemas.xmlsoap.org/soap/envelope/\" s:encodingStyle=\"http://schemas.xmlsoap.org/soap/encoding/\">" + "<s:Body>"   
  httpFunctionStart = "<u:SendKeyCode xmlns:u=\"urn:" + serviceUuid + "\">"
  httpFunctionArg1 		= "<KeyCode>" 			+ str(0) 	+ "</KeyCode>"
  httpFunctionArg2 		= "<KeyDescription>" 	+ KeyCode 	+ "</KeyDescription>"
  httpFunctionArg3 		= ""
  httpFunctionEnd 	= "</u:SendKeyCode>"
  httpBodyEnd 	= "   </s:Body>" + "</s:Envelope>"
  
  httpFunctionArgs = httpFunctionArg1 + httpFunctionArg2 + httpFunctionArg3
  httpFunction = httpFunctionStart + httpFunctionArgs + httpFunctionEnd
  httpbody = httpBodyStart + httpFunction + httpBodyEnd

  host = socket.gethostname()
  length = len(httpbody)

  # controlURL =  # Retrieved in <controlURL> tag of XML service description found at url associated with service urn:samsung.com:service:MessageBoxService:1  in gss-discovered output
  
  header = "POST " + controlURL + " HTTP/1.1" + SEP + "User-Agent: Coherence PageGetter" + SEP + "Accept: */*" + SEP + "Host: " + ip + ":" + str(port) + SEP + "connection: close" + SEP + "content-type: text/xml ;charset=\"utf-8\"" + SEP + "Content-Length: " + str(length) + SEP + "SOAPACTION: \"urn:" + serviceUuid + "#SendKeyCode\"" + SEP + SEP
  message = header + httpbody
  sendMessage(ip, port, message)


def SendCommand_SendKeyCode2(ip, port, serviceUuid,controlURL, KeyCode):
  
  httpBodyStart = "<?xml version=\"1.0\" encoding=\"utf-8\"?>" + "<s:Envelope xmlns:s=\"http://schemas.xmlsoap.org/soap/envelope/\" s:encodingStyle=\"http://schemas.xmlsoap.org/soap/encoding/\">" + "<s:Body>"   
  httpFunctionStart = "<u:SendKeyCode xmlns:u=\"urn:" + serviceUuid + "\">"
  httpFunctionArg1 		= "<KeyCode>" 			+ "%KEYCODE%" 	+ "</KeyCode>"
  httpFunctionArg2 		= "<KeyDescription>" 	+ KeyCode 	+ "</KeyDescription>"
  httpFunctionArg3 		= ""
  httpFunctionEnd 	= "</u:SendKeyCode>"
  httpBodyEnd 	= "   </s:Body>" + "</s:Envelope>"
  
  httpFunctionArgs = httpFunctionArg1 + httpFunctionArg2 + httpFunctionArg3
  httpFunction = httpFunctionStart + httpFunctionArgs + httpFunctionEnd
  httpbody = httpBodyStart + httpFunction + httpBodyEnd

  host = socket.gethostname()
  length = len(httpbody)

  # controlURL =  # Retrieved in <controlURL> tag of XML service description found at url associated with service urn:samsung.com:service:MessageBoxService:1  in gss-discovered output
  
  header = "POST " + controlURL + " HTTP/1.1" + SEP + "User-Agent: Coherence PageGetter" + SEP + "Accept: */*" + SEP + "Host: " + ip + ":" + str(port) + SEP + "connection: close" + SEP + "content-type: text/xml ;charset=\"utf-8\"" + SEP + "Content-Length: " + str(length) + SEP + "SOAPACTION: \"urn:" + serviceUuid + "#SendKeyCode\"" + SEP + SEP
  message = header + httpbody

  s = socket.socket(socket.AF_INET, socket.SOCK_STREAM, 0)
  s.connect((ip, port))
  message = message.replace("%KEYCODE%",str(s.fileno()))
  
  print "--------- Sending to server ---------->"
  print message
  sent = s.send(message)
  if (sent <= 0):
    print("Error Sending Message")
    s.close()
    return
  print "<--------- Received from server ----------"
  recv = s.recv(100000)
  print recv
  s.close()

  
#---------------------------------------------------------------------------------------------------------------------------------------#
def SendCommand_GetVolume(ip, port, serviceUuid,controlURL, InstanceID,Channel):
  
  httpBodyStart = "<?xml version=\"1.0\" encoding=\"utf-8\"?>" + "<s:Envelope xmlns:s=\"http://schemas.xmlsoap.org/soap/envelope/\" s:encodingStyle=\"http://schemas.xmlsoap.org/soap/encoding/\">" + "<s:Body>"   
  httpFunctionStart = "<u:GetVolume xmlns:u=\"urn:" + serviceUuid + "\">"
  httpFunctionArg1 		= "<InstanceID>" 	+ str(0) 	+ "</InstanceID>"
  httpFunctionArg2 		= "<Channel>" 		+ Channel 	+ "</Channel>"
  httpFunctionEnd 	= "</u:GetVolume>"
  httpBodyEnd 	= "</s:Body>" + "</s:Envelope>"
  
  httpFunctionArgs = httpFunctionArg1 + httpFunctionArg2
  httpFunction = httpFunctionStart + httpFunctionArgs + httpFunctionEnd
  httpbody = httpBodyStart + httpFunction + httpBodyEnd
  
  #httpbody =  "<?xml version=\"1.0\" encoding=\"utf-8\"?><s:Envelope xmlns:ns0=\"urn:schemas-upnp-org:service:RenderingControl:1\" s:encodingStyle=\"http://schemas.xmlsoap.org/soap/encoding/\" xmlns:s=\"http://schemas.xmlsoap.org/soap/envelope/\"><s:Body><ns0:GetVolume><InstanceID>0</InstanceID><Channel>Master</Channel></ns0:GetVolume></s:Body></s:Envelope>"
  
  host = socket.gethostname()
  length = len(httpbody)

  #controlURL =  # Retrieved in <controlURL> tag of XML service description found at url associated with service urn:samsung.com:service:MessageBoxService:1  in gss-discovered output
  
  header = "POST " + controlURL + " HTTP/1.1" + SEP + "User-Agent: Coherence PageGetter" + SEP + "Accept: */*" + SEP + "Host: " + ip + ":" + str(port) + SEP + "connection: close" + SEP + "content-type: text/xml ;charset=\"utf-8\"" + SEP + "Content-Length: " + str(length) + SEP + "SOAPACTION: \"urn:" + serviceUuid + "#GetVolume\"" + SEP + SEP
  message = header + httpbody
  print message
  sendMessage(ip, port, message)

#---------------------------------------------------------------------------------------------------------------------------------------#
def SendCommand_SetVolume(ip, port, serviceUuid,controlURL, InstanceID,Channel,DesiredVolume):
  
  httpBodyStart = "<?xml version=\"1.0\" encoding=\"utf-8\"?>" + "<s:Envelope xmlns:s=\"http://schemas.xmlsoap.org/soap/envelope/\" s:encodingStyle=\"http://schemas.xmlsoap.org/soap/encoding/\">" + "<s:Body>"   
  httpFunctionStart = "<u:SetVolume xmlns:u=\"urn:" + serviceUuid + "\">"
  httpFunctionArg1 		= "<InstanceID>" 	+ str(0) 	+ "</InstanceID>" + SEP
  httpFunctionArg2 		= "<Channel>" 		+ Channel 	+ "</Channel>" + SEP
  httpFunctionArg3 		= "<DesiredVolume>" + str(16) 	+ "</DesiredVolume>" + SEP
  httpFunctionEnd 	= "</u:SetVolume>"
  httpBodyEnd 	= "</s:Body>" + "</s:Envelope>"
  
  httpFunctionArgs = httpFunctionArg1 + httpFunctionArg2 + httpFunctionArg3
  httpFunction = httpFunctionStart + httpFunctionArgs + httpFunctionEnd
  httpbody = httpBodyStart + httpFunction + httpBodyEnd

  host = socket.gethostname()
  length = len(httpbody)
  header = "POST " + controlURL + " HTTP/1.1" + SEP + "User-Agent: Coherence PageGetter" + SEP + "Accept: */*" + SEP + "Host: " + ip + ":" + str(port) + SEP + "connection: close" + SEP + "content-type: text/xml ;charset=\"utf-8\"" + SEP + "Content-Length: " + str(length) + SEP + "SOAPACTION: \"urn:" + serviceUuid + "#SetVolume\"" + SEP + SEP
  
  message = header + httpbody
  sendMessage(ip, port, message)

#---------------------------------------------------------------------------------------------------------------------------------------#
def SendCommand_AddMessage(ip, port, serviceUuid, controlURL, args):

  httpBodyStart = "<?xml version=\"1.0\" encoding=\"utf-8\"?>" + "<s:Envelope xmlns:s=\"http://schemas.xmlsoap.org/soap/envelope/\" s:encodingStyle=\"http://schemas.xmlsoap.org/soap/encoding/\">" + "<s:Body>" 
  httpFunctionStart = "<u:AddMessage xmlns:u=\"urn:" + serviceUuid + "\">"
  httpFunctionArg1 		= "<MessageType>text/xml</MessageType>"
  httpFunctionArg2 		= "<MessageID>MessageId</MessageID>"
  httpFunctionArg3 		= "<Message>" + "&lt;Category&gt;SMS&lt;/Category&gt;" + "&lt;DisplayType&gt;Maximum&lt;/DisplayType&gt;" + "&lt;ReceiveTime&gt;" + "&lt;Date&gt;" + time.strftime('%Y-%m-%d', time.localtime(args.time)) + "&lt;/Date&gt;" + "&lt;Time&gt;" + time.strftime('%H:%M:%S', time.localtime(args.time)) + "&lt;/Time&gt;" + "&lt;/ReceiveTime&gt;" + "&lt;Receiver&gt;" + "&lt;Number&gt;" + args.receiver_no + "&lt;/Number&gt;" + "&lt;Name&gt;" + args.receiver + "&lt;/Name&gt;" + "&lt;/Receiver&gt;" + "&lt;Sender&gt;" + "&lt;Number&gt;" + args.sender_no + "&lt;/Number&gt;" + "&lt;Name&gt;" + args.sender + "&lt;/Name&gt;" + "&lt;/Sender&gt;" + "&lt;Body&gt;" + args.msg + "&lt;/Body&gt;" + "</Message>"
  httpFunctionEnd 	= "</u:AddMessage>"
  httpBodyEnd 	= "</s:Body>" + "</s:Envelope>"

  httpFunctionArgs = httpFunctionArg1 + httpFunctionArg2 + httpFunctionArg3
  httpFunction = httpFunctionStart + httpFunctionArgs + httpFunctionEnd
  httpbody = httpBodyStart + httpFunction + httpBodyEnd

  host = socket.gethostname()
  length = len(httpbody)

  #controlURL =  # Retrieved in <controlURL> tag of XML service description found at url associated with service urn:samsung.com:service:MessageBoxService:1  in gss-discovered output
  
  header = "POST " + controlURL + " HTTP/1.0\r\n" + "Content-Type: text/xml; charset=\"utf-8\"\r\n" + "HOST: " + host + "\r\n" + "Content-Length: " + str(length) + SEP + "SOAPACTION: \"uuid:" + serviceUuid + "#AddMessage\"" + SEP + "Connection: close"+ SEP + SEP
  message = header + httpbody
  sendMessage(ip, port, message)
  

#---------------------------------------------------------------------------------------------------------------------------------------#
def sendMessage(ip, port, message):
  s = socket.socket(socket.AF_INET, socket.SOCK_STREAM, 0)
  s.connect((ip, port))
  print "--------- Sending to server ---------->"
  print message
  sent = s.send(message)
  if (sent <= 0):
    print("Error Sending Message")
    s.close()
    return
  print "<--------- Received from server ----------"
  recv = s.recv(100000)
  print recv
  s.close()

  
#---------------------------------------------------------------------------------------------------------------------------------------#
#---------------------------------------------------------------------------------------------------------------------------------------#
def main():
  parser = argparse.ArgumentParser(description='Send an arbitrary text message to Samsung TVs which is displayed onscreen. Developed by Shantanu Goel (http://tech.shantanugoel.com/) version 1.0', add_help = False)
  flags = parser.add_argument_group('Arguments')
  flags.add_argument('-i', '--ip', dest = 'ip', default = None, help = 'Required. IP Address of the TV', required = True)
  flags.add_argument('-m', '--msg', dest = 'msg', default = None, help = 'Required. Message body text to be sent to TV', required = True)
  flags.add_argument('-p', '--port', dest = 'port', default = DefaultPort, type = int, help = 'Optional. Port on which message should be sent')
  flags.add_argument('-t', '--time', dest = 'time', default = epochtime, type = float, help = 'Optional. Receive date and time in epoch/unix format')
  flags.add_argument('-r', '--receiver', dest = 'receiver', default = receiver, help = 'Optional. Receiver Name')
  flags.add_argument('-x', '--receiverno', dest = 'receiver_no', default = receiver_no, help = 'Optional. Receiver Number')
  flags.add_argument('-s', '--sender', dest = 'sender', default = sender, help = 'Optional. Sender Name')
  flags.add_argument('-y', '--senderno', dest = 'sender_no', default = sender_no, help = 'Optional. Sender Number')
  flags.add_argument('-h', '--help', action='help')
  args = parser.parse_args()

  # SendCommand_AddMessage(	args.ip	, args.port		,"samsung.com:service:MessageBoxService:1","/PMR/control/MessageBoxService", args) 
  # SendCommand_SetVolume(	args.ip	, args.port    	,"schemas-upnp-org:service:RenderingControl:1","/upnp/control/RenderingControl1", 0,"Master",16)    
  # SendCommand_GetVolume(	args.ip	, args.port     ,"schemas-upnp-org:service:RenderingControl:1","/upnp/control/RenderingControl1", 0,"Master")  
  
  SendCommand_GetVolume("192.168.1.153", 7676 ,"schemas-upnp-org:service:RenderingControl:1","/smp_17_", 0,"Master")  

  # <s:Fault><faultcode>s:Client</faultcode><faultstring>UPnPError</faultstring><detail><UPnPError xmlns="urn:schemas-upnp-org:control-1-0"><errorCode>501</errorCode><errorDescription>Action Failed</errorDescription></UPnPError></detail></s:Fault>
  SendCommand_SetVolume("192.168.1.153", 7676 ,"schemas-upnp-org:service:RenderingControl:1","/smp_17_", 0,"Master", 6)  
  
  SendCommand_SendKeyCode2("192.168.1.153", 7676,"samsung.com:service:MultiScreenService:1","/smp_9_","KEY_1")
  SendCommand_SendKeyCode2("192.168.1.153", 7676,"samsung.com:service:MultiScreenService:1","/smp_9_","KEY_ENTER")
  
  #KO : SendCommand_SendKeyCode("192.168.1.153", 8001,"samsung.com:service:MultiScreenService:1","/smp_9_","KEY_1")  
  #KO : SendCommand_SendKeyCode("192.168.1.153", 8001,"samsung.com:device:RemoteControlReceiver:1","/smp_9_","KEY_1")  
  
  
  
#---------------------------------------------------------------------------------------------------------------------------------------#
main()