#! /usr/bin/python
# -*-coding:utf-8 -*
# Liste les renderers presents sur le reseau local a partir du fichier passe en parametre
import random, time, sys, copy
import pygame
import pygame.gfxdraw
import urllib2
import os
from sets import Set
import glob
import re
from threading import Thread,RLock
import signal
import subprocess
import argparse
import datetime
from xms.system import SystemUtils
from pygame.locals import *
import math

global verrou_log,progName
global fenetre,curveColor, baseColor, fenetre_largeur, fenetre_hauteur, intervalSize, NbCurveIntervals
global prevNow,theNow
global fond
global XOffsetStart,XOffsetEnd
global YOffsetStart, YOffsetEnd
global dimA, X
global time0,time1,time2,time3

# global queueTotalCpu
# global queueSelectedProcessesCpu
#queueTotalCpu 				= Queue()
#queueSelectedProcessesCpu 	= Queue()
global totalCpu
global selProcessesCpu
global selProcessesPid
	
progName 			= os.path.basename(__file__).split(".")[0]

XOffsetStart 		= 40
XOffsetEnd 			= -3
YOffsetStart 		= 3
YOffsetEnd 			= -3

curveColor		 	= [0,200,0]
baseColor 			= [240,240,240]
baseColor2 			= [100,100,100]
baseColor3 			= [150,150,150]
baseColor4 			= [150,0,0]
theNow 				= time.time()
prevNow 			= theNow
NbCurveIntervals 	= 60.0
CurveCpuTotOrds		= []
CurveSelProcOrds	= []
LastCPUTotal		= [0,0,0,0] # les 4 dernières mesures prises
LastCPUSelProc		= [0,0,0,0]

intervalSize 		= 6
dimA 				= 4 # vaut 4 pour un système 4*4
A 					= []

time0 				= 0.0
time1 				= intervalSize
time2 				= 2 * time1
time3 				= 3 * time1

totalCpu 			= 0
selProcessesCpu 	= 0

for i in range(0,dimA):
	A.append(0.0)
	
for i in range(0,2000):
	CurveCpuTotOrds.append(0)
	CurveSelProcOrds.append(0)
	

#-------------------------------------------------------------------------------------------------------------------------------------------------------------------#
# 																				IDLE  																				
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------#
def idle():
	global dimA, X
	
	global prevNow, theNow
	global fenetre
	global intervalSize, NbCurveIntervals
	global fenetre_largeur,	fenetre_hauteur
	global XOffsetStart, XOffsetEnd
	global YOffsetStart, YOffsetEnd	
	global time0,time1,time2,time3
	
	global totalCpu
	global selProcessesCpu
	global selProcessesPid	
		
	theNow 		= time.time()
	if theNow - prevNow > 1: # 1 second s'est écoulée ==> on raffraichit
		fenetre_largeur	= fenetre.get_width()
		fenetre_hauteur	= fenetre.get_height()
		xCurveStart = XOffsetStart
		xCurveEnd = fenetre_largeur + XOffsetEnd
		curveWidth = min(xCurveEnd - xCurveStart,2000)
		
		fenetre.fill((0,0,0))
		
		yBaseLow 		= fenetre_hauteur + YOffsetEnd
		yBaseHigh 		= YOffsetStart
		yDixIntervalle 	= (yBaseLow - yBaseHigh) / 10.0
		
		#------------ Trace de la base repere ------------#
		pygame.gfxdraw.line(fenetre,xCurveStart,yBaseLow,xCurveEnd,yBaseLow,baseColor)		
		pygame.gfxdraw.line(fenetre,xCurveStart,yBaseLow,xCurveStart,yBaseHigh,baseColor)		
		for i in range(1,10,1):
			yOffset=int(yBaseLow-i*yDixIntervalle)
			pygame.gfxdraw.line(fenetre,xCurveStart,yOffset,xCurveEnd,yOffset,baseColor2)		
		for i in range(xCurveStart+intervalSize,xCurveEnd,intervalSize*11):
			pygame.gfxdraw.line(fenetre,i,yBaseHigh,i,yBaseLow,baseColor2)		

		#------------ Calcul de la nouvelle courbe ------------#
		# Decalage courbe de intervalSize vers la droite
		for i in range(int(curveWidth-intervalSize),0,-1):		
			CurveCpuTotOrds[i+int(intervalSize)] = CurveCpuTotOrds[i]
			CurveSelProcOrds[i+int(intervalSize)] = CurveSelProcOrds[i]
			
		# Calcul du nouvel interval : identification du polynome de degre 4 qui passe par les 4 derniers points de mesure
		newTotalCpu = totalCpu / 100.0
		LastCPUTotal.insert(0, totalCpu )
		LastCPUTotal.pop()
		newSelProcCpu = selProcessesCpu / 100.0		
		LastCPUSelProc.insert(0, selProcessesCpu )
		LastCPUSelProc.pop()
		
		# Y = t(Y0,Y1,Y2,Y3) = LastCPUTotal 		--> A3.Xi^3 + A2.Xi^2 + A1.Xi + A0 = Yi   
		# A = t(A0,A1,A2,A3)
		# X = t(X0,X1,X2,X3) X0=0 Xi=X0 + i*int(intervalSize)   i=0,1,2,3  --> les Xi et les Yi sont connus
		# --> Objectif : - trouver les Ai ; c'est un système 4*4 ==> pivot de gauss
		#				 - une fois le polynome défini, prendre ses valeurs de X=0 à X=intervalSize
		#-------------------------------------------------------------- Calcul du polynome pour la courbe CPU total ------------------------------------------------------------------#
		mat = [[1, time0, math.pow(time0,2), math.pow(time0,3), LastCPUTotal[0]], [1, time1, math.pow(time1,2), math.pow(time1,3), LastCPUTotal[1]],[1, time2, math.pow(time2,2), math.pow(time2,3), LastCPUTotal[2]],[1, time3, math.pow(time3,2), math.pow(time3,3), LastCPUTotal[3]]]
		matP = pivot(mat)
		#------------ Resolution de type A.X=Y dans laquelle A est une matrice triangulaire supérieure ; ------------#
		# Ici A = matP(3 premières colonnes)      X = A     Y = matP(dernière colonne)
		for i in range(dimA-1 , -1 ,-1):		
			XiAi = matP[i][dimA]
			for k in range(i+1,dimA,1):
				XiAi = XiAi - matP[i][k] * A[k]
			A[i] = XiAi / matP[i][i]
		#------------ Dès lors, Ai = X[i]   on calcule les Yi (= A3.Xi^3 + A2.Xi^2 + A1.Xi + A0 = Yi), et ce pour les Xi de l'intervalle [0,intervalSize] ------------#
		for i in range(0,int(intervalSize)+1,1):
			NewY = 0 
			for k in range(0,4):
				NewY = NewY + A[k] * math.pow(i,k)				
			CurveCpuTotOrds[i] = int(NewY)

		#-------------------------------------------------------------- Calcul du polynome pour la courbe CPU des processus selectionnes ---------------------------------------------#
		mat = [[1, time0, math.pow(time0,2), math.pow(time0,3), LastCPUSelProc[0]], [1, time1, math.pow(time1,2), math.pow(time1,3), LastCPUSelProc[1]],[1, time2, math.pow(time2,2), math.pow(time2,3), LastCPUSelProc[2]],[1, time3, math.pow(time3,2), math.pow(time3,3), LastCPUSelProc[3]]]
		matP = pivot(mat)
		#------------ Resolution de type A.X=Y dans laquelle A est une matrice triangulaire supérieure ; ------------#
		# Ici A = matP(3 premières colonnes)      X = A     Y = matP(dernière colonne)
		for i in range(dimA-1 , -1 ,-1):		
			XiAi = matP[i][dimA]
			for k in range(i+1,dimA,1):
				XiAi = XiAi - matP[i][k] * A[k]
			A[i] = XiAi / matP[i][i]
		#------------ Dès lors, Ai = X[i]   on calcule les Yi (= A3.Xi^3 + A2.Xi^2 + A1.Xi + A0 = Yi), et ce pour les Xi de l'intervalle [0,intervalSize] ------------#
		for i in range(0,int(intervalSize)+1,1):
			NewY = 0 
			for k in range(0,4):
				NewY = NewY + A[k] * math.pow(i,k)				
			CurveSelProcOrds[i] = int(NewY)			
			
		#------------ Tracé des courbes (de xCurveStart à xCurveEnd) ------------#
		prevYCpuTot 	= int(yBaseLow-CurveCpuTotOrds[0]*(yBaseLow - yBaseHigh)/100.0)
		prevYCpuSelProc = int(yBaseLow-CurveSelProcOrds[0]*(yBaseLow - yBaseHigh)/100.0)
		pygame.gfxdraw.line(fenetre,xCurveStart,prevYCpuTot		,xCurveStart+1,prevYCpuTot		,curveColor)		
		pygame.gfxdraw.line(fenetre,xCurveStart,prevYCpuSelProc	,xCurveStart+1,prevYCpuSelProc	,curveColor)		
		for i in range(1,curveWidth+1,1):		
			xStart 		= xCurveStart + i
			
			newYCpuTot 	= int(yBaseLow-CurveCpuTotOrds[i]*(yBaseLow - yBaseHigh)/100.0)			
			pygame.gfxdraw.line(fenetre	,xStart	,prevYCpuTot		,xStart+1	,newYCpuTot		,curveColor)		 #pygame.gfxdraw.pixel(fenetre,xStart,newYCpuTot,curveColor)
			prevYCpuTot 	= newYCpuTot
			
			newYSelProc = int(yBaseLow-CurveSelProcOrds[i]*(yBaseLow - yBaseHigh)/100.0)			
			pygame.gfxdraw.line(fenetre	,xStart	,prevYCpuSelProc	,xStart+1	,newYSelProc	,baseColor4)
			prevYCpuSelProc = newYSelProc
			
		#------------ Trace du cpu ------------#
		PercentBaseLow = fenetre_hauteur + YOffsetEnd - 18
		PercentTotalHeight = PercentBaseLow - YOffsetStart
		PercentHeight = int(PercentTotalHeight * newTotalCpu)
		for y in range(PercentBaseLow,YOffsetStart+2,-2):
			pygame.gfxdraw.line(fenetre,3,y,37,y,baseColor2)			
		for y in range(PercentBaseLow,PercentBaseLow-PercentHeight,-2):
			pygame.gfxdraw.line(fenetre,3,y,37,y,curveColor)		
			
		font = pygame.font.Font(None, 16)
		cpuRenderStr = str(int(totalCpu)).rjust(3) + " %"
		text = font.render(cpuRenderStr, 1, curveColor)
		textpos = text.get_rect()
		textpos.left=3
		textpos.top=fenetre_hauteur + YOffsetEnd-16
		fenetre.blit(text, textpos)
			
		pygame.display.flip()

		prevNow = theNow

#-------------------------------------------------------------------------------------------------------------------------------------------------------------------#
# 																				MAIN  																				
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------#
def main():	

	global fenetre, fond
	global XOffsetStart, XOffsetEnd
	global YOffsetStart, YOffsetEnd
	global CurveCpuTotOrds
	
	psfile = None
	
	parser = argparse.ArgumentParser(description='Example with simples options')
	parser.add_argument('-pslist' 		, '--pslist'		,	action="store", 	help="Liste des pid pour lesquels cumuler la charge cpu")
	parser.add_argument('-psfile' 		, '--psfile'		,	action="store", 	help="Fichier contenant la liste des pid pour lesquels cumuler la charge cpu")
	parser.add_argument('-displayover' 	, '--displayover'	,	action="store", 	help="Charge CPU au dessus de laquelle chaque processus sera affiche")
	result = parser.parse_args()
	arguments = dict(result._get_kwargs())
	
	thepslist = []
	if arguments['pslist'] != None: 
		thepslist = arguments['pslist'].split(',')
		#thepslist.append("this")
	else:
		if arguments['psfile'] != None: 
			psfile = arguments['psfile'].rstrip()
	
	over = 4
	if arguments['displayover'] != None: 
		over = arguments['displayover']
	
	global thread_CpuGraber
	
	thread_CpuGraber = SystemUtils.CPUGraber(callbackCpuLoads, callbackInfo)
	
	if len(thepslist) != 0:
		for pid in thepslist:
			if pid != "this": thread_CpuGraber.addPid(pid)
			else			: thread_CpuGraber.addPid(str(os.getpid()))
	else:
		if psfile != None:
			thread_CpuGraber.setPidListFromFile(psfile)

	
	thread_CpuGraber.displayProcessesOver(over)
	thread_CpuGraber.start()	
		
	pygame.init()
	
	#---------- Création de la fenêtre ----------#
	fenetre 		= pygame.display.set_mode((300,100), RESIZABLE,NOFRAME)

	prevNow = time.time()	

	#---------- Icone ----------#
	#icone = pygame.image.load(image_icone)
	#pygame.display.set_icon(icone)
	#---------- Titre ----------#
	pygame.display.set_caption("XCPUGraber XMS-RBPI")
	
	#fond = pygame.image.load("/home/pi/scripts/python/background.gif").convert_alpha()
	#fenetre.blit(fond, (0,0))
	pygame.display.flip() # affiche le buffer graphique préparé
	
	#DISPLAY_REFRESH = USEREVENT
	#pygame.time.set_timer(DISPLAY_REFRESH, int(1000.0/30))
	
	#---------- Optimisation CPU ----------#
	pygame.event.set_blocked(MOUSEMOTION)
	# pygame.event.set_blocked(KEYDOWN)
	# pygame.event.set_blocked(KEYUP)

	pygame.event.set_blocked(JOYAXISMOTION)
	pygame.event.set_blocked(JOYBALLMOTION)
	pygame.event.set_blocked(JOYHATMOTION)
	pygame.event.set_blocked(JOYBUTTONUP)
	
	mustRun = True
	while mustRun:
		pygame.event.pump()
		idle()
		for event in pygame.event.get():   # liste de tous les événements reçus (event.type, event.key)
			if event.type == QUIT or event.type == KEYDOWN: 
				mustRun = False
				break
			elif event.type == KEYUP: 
				pygame.image.save(fenetre,'nomfichier.bmp')	
				break
			elif event.type == MOUSEBUTTONDOWN:
				print "MouseEvent btn=" + str(event.button) + " pos=" + repr(event.pos)
				break
			elif event.type == MOUSEMOTION:
				print "MouseMotionEvent btn=" + str(event.buttons) + " pos=" + repr(event.pos)
				break
			if event.type == pygame.VIDEORESIZE:
				fenetre_largeur, fenetre_hauteur = event.size
				fenetre_largeur = min(fenetre_largeur,800)
				fenetre_hauteur = min(fenetre_hauteur,200)
				fenetre 		= pygame.display.set_mode((fenetre_largeur,fenetre_hauteur), RESIZABLE,NOFRAME)
				break
			# elif event.type == DISPLAY_REFRESH:
				# 
				# break
					
		#pygame.time.Clock().tick(10)	
		pygame.time.wait(500)
					
	thread_CpuGraber.stop()
					
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------#
# 									Appelee par un thread
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------#
def callbackInfo(msg):
	theNow 	= datetime.datetime.utcnow()
	message = '[' + theNow.strftime('%Y%m%d_%H%M%S.%f') + '][' + progName + '][0] ' + msg 
	print  message
	sys.stdout.flush()

#-------------------------------------------------------------------------------------------------------------------------------------------------------------------#
# 									Appelee par un thread
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------#
def callbackCpuLoads(totalCpuLoad, selectedPids, selectedCpuLoad):
	global totalCpu
	global selProcessesCpu
	global selProcessesPid
	totalCpu 		= totalCpuLoad
	selProcessesPid = selectedPids
	selProcessesCpu = selectedCpuLoad
	
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------#
# 									Pivot de gauss
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------#
def pivot(tab):
	line, col = len(tab), len(tab[0]) ## on considere que tab a deux dimensions et est non vide
	i, j = 0, 0
	
	while j < col and i < line:
		## tri inverse de tab
		tab.sort(reverse=1)
		## Identification du meilleur pivot pour la j ieme colonne
		max = i 
		k = i+1
		while k < line:
			if ( abs( tab[k][j] ) > abs( tab[max][j] ) ):
				max = k
			k = k+1
				
		## mise à 0 de la colonne j des autres lignes que celles du pivot. Le pivot est sur la ligne max
		if tab[max][j] != 0: # --> sinon c est foutu, on ne pourra pas faire
			## reduction du coef pivot a 1 en divisant la ligne par le pivot
			k = j
			piv = tab[max][j]
			while k < col:
				tab[max][k] = tab[max][k] * 1. / piv
				k = k + 1
			## operations du pivot de Gauss : pour mettre des 0 sur les autres lignes que celles du pivot de gauss
			k = 0
			while k < line: # Iteration sur toutes les lignes
				if k != max: # sauf celle ci: n'est pas la ligne du pivot pour la colonne j ==> il faut mettre a 0 l element k
					t = 0
					ca = tab[k][j] ## coef de la colonne pivot j de la ligne k modifiee
					while t < col:
						tab[k][t] = tab[k][t] - ca * tab[max][t]
						t = t + 1
				k = k+1
			i = i+1
			
		j = j+1 # colonne suivante
		
	tab.sort(reverse=1) ## peu important et ajoute un peu de complexite
	return tab	
	
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------#
if __name__ == '__main__':
	main()
