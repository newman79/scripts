#!/bin/bash

count=`ps ax | grep node | grep xms-node-ewelink-devices-control-http-server.js | grep -v grep | wc -l`

if [ $count -eq 0 ]; then
	cd `dirname "$0"`
	node xms-node-ewelink-devices-control-http-server.js &	
fi