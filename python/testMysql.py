from __future__ import print_function
import datetime
import mysql.connector

cnx = mysql.connector.connect(user='xavier', database='Evenements', password='free1979')
cursor = cnx.cursor()

# insert into Evenements.EventLanDevice(id,date,state,ip,measure1,measure2) values (6,'2017-12-30 21:39:32',6,'192.168.1.133','15.7','98');

cursor.execute("select id from TR_DeviceName where nomDNS='xms-rbpi'")
result = cursor.fetchone()
deviceId = result[0]
deviceIdStr = str(deviceId)
request_insert_measure_event = ("INSERT INTO EventLanDevice(id,date,state,ip,measure1,measure2) VALUES(%s,%s,%s,%s,%s,%s)")


theNow 	= datetime.datetime.utcnow()
measureDateStr = theNow.strftime('%Y-%m-%d %H:%M:%S')

#data_measure_event = (deviceId, "2017-12-30 21:39:34", 6, "192.168.1.133", "15.7","95")
data_measure_event = (deviceId, measureDateStr, 6, "192.168.1.133", "15.7","95")

# Insert 
cursor.execute(request_insert_measure_event, data_measure_event)
#insertedEventRowId = cursor.lastrowid

# Make sure data is committed to the database
cnx.commit()

cursor.close()
cnx.close()