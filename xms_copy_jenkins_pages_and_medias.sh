#!/bin/bash

echo "Warning : if not yet done, to make this script work, you need to add following lines in your /etc/ssh/ssh_config or /etc/ssh_config file"
echo "          StrictHostKeyChecking no"
echo "          UserKnownHostsFile /dev/null"
    



PwdForMount=`cat /home/pi/scripts/MountLoginPassword.cfg | grep "vps-e8fd6ad8" | awk '{print $3}' | /home/pi/xmsEncodeDecode -d`

#echo Password is : $PwdForMount

#echo `whoami`

# de mon raspberryPi vers le serveur ovh vps-e8fd6ad8.vps.ovh.net
# REMARQUE : si vous voulez vraiment juste voir ce qui va être copié et supprimé sur le remote, alors ajouter l'option --dry-run dans les commandes ci-dessous
# REMARQUE : -e 'ssh -4 -p 33333'   signifie pour faire le job, connecte toi en ssh avec l'IPv4 de vps-e8fd6ad8.vps.ovh.net, puis sert toi de cette connection ssh pour faire ton rsync
#            On comprend donc que là le remote écoute sur le port 33333 

sshpass -p"$PwdForMount" rsync -avz --no-o --no-g --no-p --delete-after --progress -e 'ssh -4 -p 33333' /var/www/dokuwiki/data/pages/ debian@vps-e8fd6ad8.vps.ovh.net:/var/www/html/dokuwiki/data/pages/
echo "Pages copy result : $?"

sshpass -p"$PwdForMount" rsync -avz --no-o --no-g --no-p --delete-after --progress -e 'ssh -4 -p 33333' /var/www/dokuwiki/data/media/ debian@vps-e8fd6ad8.vps.ovh.net:/var/www/html/dokuwiki/data/media/
echo "Media copy result : $?"



# de mon serveur ovh vps-e8fd6ad8.vps.ovh.net vers mon raspberryPi
# ATTENTION : --dry-run   permet de simuler, si vous voulez vraiment le faire, alors retirer l'option --dry-run dans les commandes ci-dessous

sshpass -p"$PwdForMount" rsync -avz --no-o --no-g --no-p --delete-after --progress -e 'ssh -4 -p 33333' --dry-run debian@vps-e8fd6ad8.vps.ovh.net:/var/www/html/dokuwiki/data/pages/ /var/www/dokuwiki/data/pages/
echo "Pages copy result : $?"

sshpass -p"$PwdForMount" rsync -avz --no-o --no-g --no-p --delete-after --progress -e 'ssh -4 -p 33333' --dry-run debian@vps-e8fd6ad8.vps.ovh.net:/var/www/html/dokuwiki/data/media/ /var/www/dokuwiki/data/media/
echo "Media copy result : $?"