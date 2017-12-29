#
#  
#     Heure derniere fermeture de porte + Absence d activite(PC, tele, onde radio, telephone) + Détecteur présence humaine (IR) pendant 1h ==> activation
# 
# Toute presence d activite ==> désactivation jusqu a 08h00
# 

import time
import pigpio

MAX_MESSAGE_BYTES=77


