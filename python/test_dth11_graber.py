#! /usr/bin/python
# -*-coding:utf-8 -*

import RPi.GPIO as GPIO
import time
from xms.capteurs import dth11_szazo

def bin2dec(string_num):
    return str(int(string_num, 2))

# for GPIO numbering, 	choose BCM  GPIO.setmode(GPIO.BCM)  
# for pin numbering, 	choose BOARD  GPIO.setmode(GPIO.BOARD) 
GPIO.setmode(GPIO.BCM)


instance = dth11_szazo.DHT11(pin = 21)
result = instance.read()
print result.is_valid()
if result.is_valid():
	print result.temperature
	print result.humidity

result = instance.read()
print result.is_valid()
if result.is_valid():
	print result.temperature
	print result.humidity

result = instance.read()
print result.is_valid()
if result.is_valid():
	print result.temperature
	print result.humidity

exit(0)

data = []

pin=21

GPIO.setup(pin,GPIO.OUT)
GPIO.output(pin,GPIO.HIGH) 	# valeur haute (pull up)
time.sleep(0.025)
GPIO.output(pin,GPIO.LOW) 	# valeur haute (pull down)
time.sleep(0.02)

GPIO.setup(pin, GPIO.IN, pull_up_down=GPIO.PUD_UP) # Mettre le GPIO en mode lecture, en le pullant préalable à UP

time.sleep(0.001)

# Graber la reponse du DTH11
for i in range(0,500):
	data.append(GPIO.input(pin))

print data


bit_count 		= 0
tmp 			= 0
count 			= 0
HumidityBit 	= ""
TemperatureBit 	= ""
crc 			= ""

# La réponse du DTH11 est dans data
try:
	if data[count] == 0:
		while data[count] == 0:
			count = count + 1

	# aller au premier element a 0 (entete de la reponse du DTH11)
	while data[count] == 1:
		count = count + 1

	for i in range(0, 32): # 32 valeurs (de 8 bits ?) a decoder 
		# --> 1ere a 8eme valeur (0 a 7) 	==> humidity
		# --> 9eme a 16eme valeur (8 a 15) 	==> rien ?
		# --> 17re a 24eme valeur (16 a 23) ==> temperature
		# --> 25eme a 32eme valeur (24 a 31)==> rien ?
		bit_count = 0

		while data[count] == 0: # aller au premier element a 1
			count = count + 1

		while data[count] == 1: # aller au premier element a 0; à partir d'ici, on compte le nombre de bit envoyé par le DTH11
			bit_count = bit_count + 1
			count = count + 1

		if bit_count > 3:  # au moins 4 data a 1 ==> cas possibles : 00001111, 00011111, 00111111, 01111111, 11111111
			if i>=0 and i<8:
				HumidityBit 	= HumidityBit    + "1"
			if i>=16 and i<24:
				TemperatureBit 	= TemperatureBit + "1"
		else:				# au plus 3 data a 1 ==> cas possibles : 00000111, 00000011, 00000001, 00000000
			if i>=0 and i<8:
				HumidityBit 	= HumidityBit    + "0"
			if i>=16 and i<24:
				TemperatureBit = TemperatureBit  + "0"

except:
	print "ERR_RANGE WHEN ANALYZING DATA"
	exit(0)

# construction du crc
try:
	for i in range(0, 8):
		bit_count = 0

		while data[count] == 0:
			tmp = 1
			count = count + 1

		while data[count] == 1:
			bit_count = bit_count + 1
			count = count + 1

		if bit_count > 3:
			crc = crc + "1"
		else:
			crc = crc + "0"
except:
	print "ERR_RANGE CRC"
	Humidity 	= bin2dec(HumidityBit)
	Temperature = bin2dec(TemperatureBit)
	print Humidity
	print Temperature
	exit(0)


if int(Humidity) + int(Temperature) - int(bin2dec(crc)) == 0:
	print Humidity
	print Temperature
else:
	print "ERR_CRC"
