import time
import socket
import base64

src     = '192.168.1.253'       # ip of remote
mac     = 'B8-27-EB-AB-B5-99' # mac of remote b8:27:eb:ab:b5:99
remote  = 'pythonRemote'     # remote name
dst     = '192.168.1.153'       # ip of tv
app     = 'python'            # iphone..iapp.samsung
#tv      = 'iphone.UE40H6400.iapp.samsung'          # iphone.LE32C650.iapp.samsung
#tv      = 'iphone.TV-32C630.iapp.samsung'          # iphone.LE32C650.iapp.samsung
tv 		 =  'UE40H6400'

def push(key):
  new = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
  new.connect((dst, 8000))  # 55000, 7676, 52235, 8001, 8000,80, 15600,1900, 9900, 9090, 8443,52396,5601,15600
  #------------------- Authentification -------------------#
  msg = chr(0x64) + chr(0x00) +\
        chr(len(base64.b64encode(src)))    + chr(0x00) + base64.b64encode(src) +\
        chr(len(base64.b64encode(mac)))    + chr(0x00) + base64.b64encode(mac) +\
        chr(len(base64.b64encode(remote))) + chr(0x00) + base64.b64encode(remote)
  pkt = chr(0x00) +\
        chr(len(app)) + chr(0x00) + app +\
        chr(len(msg)) + chr(0x00) + msg
  new.send(pkt)
  
  #------------------- Envoie d'une commande -------------------#
  msg = chr(0x00) + chr(0x00) + chr(0x00) +\
        chr(len(base64.b64encode(key))) + chr(0x00) + base64.b64encode(key)
  pkt = chr(0x00) +\
        chr(len(tv))  + chr(0x00) + tv +\
        chr(len(msg)) + chr(0x00) + msg
  new.send(pkt)
  new.close()
  time.sleep(0.1)
  
while True:
  # switch to tv
  print "push1"
  push("KEY_TV")
  push("KEY_1")
  print "fait"
  
  # switch to channel one
  print "push2"
  push("KEY_1")
  push("KEY_ENTER")
  
  time.sleep(1)
  
  # switch to channel 15
  print "push3"
  push("KEY_1")
  push("KEY_5")
  push("KEY_ENTER")
  
  time.sleep(1)
  
  # switch to HDMI
  print "push4"
  push("KEY_HDMI")
  
  time.sleep(5)
  

# KEY_0
# KEY_1
# KEY_2
# KEY_3
# KEY_4
# KEY_5
# KEY_6
# KEY_7
# KEY_8
# KEY_9
# KEY_UP
# KEY_DOWN
# KEY_LEFT
# KEY_RIGHT
# KEY_MENU
# KEY_PRECH
# KEY_GUIDE
# KEY_INFO
# KEY_RETURN
# KEY_CH_LIST
# KEY_EXIT
# KEY_ENTER
# KEY_SOURCE
# KEY_AD
# KEY_PLAY
# KEY_PAUSE
# KEY_MUTE
# KEY_PICTURE_SIZE
# KEY_VOLUP
# KEY_VOLDOWN
# KEY_TOOLS
# KEY_POWEROFF
# KEY_CHUP
# KEY_CHDOWN
# KEY_CONTENTS
# KEY_W_LINK (=Media P)
# KEY_RSS (=Internet)
# KEY_MTS (=Dual)
# KEY_CAPTION (=Subt)
# KEY_REWIND
# KEY_FF
# KEY_REC
# KEY_STOP
# KEY_SLEEP
# KEY_TV  
  