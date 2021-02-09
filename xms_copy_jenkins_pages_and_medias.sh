#!/bin/bash

echo "Warning : if not yet done, to make this script work, you need to add following lines in your /etc/ssh/ssh_config or /etc/ssh_config file"
echo "          StrictHostKeyChecking no"
echo "          UserKnownHostsFile /dev/null"
    



PwdForMount=`cat /home/pi/scripts/MountLoginPassword.cfg | grep "ovhvps1" | awk '{print $3}' | /home/pi/xmsEncodeDecode -d`

#echo Password is : $PwdForMount

#echo `whoami`

sshpass -p$PwdForMount rsync -avz --delete-after --progress /var/www/dokuwiki/data/pages/ root@qcmonline.ovhvps.net:/var/www/html/dokuwiki/data/pages
echo "Pages copy result : $?"

sshpass -p$PwdForMount rsync -avz --delete-after --progress /var/www/dokuwiki/data/media/ root@qcmonline.ovhvps.net:/var/www/html/dokuwiki/data/media
echo "Media copy result : $?"