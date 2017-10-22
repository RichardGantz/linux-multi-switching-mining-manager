#!/bin/bash
###############################################################################
#
#  Hier wird die GPU Watt abgefragt
#  
#  
# 
# 
# 
#FSP AURUM PT SERIES
#
#
#
###############################################################################

#löschen einer bestehenden WATT.out datei
rm WATT.out

COUNTER=0
id=0        #später indexnummer aus gpu folder einfügen !!!
time=14    #wieviel mal soll die schleife laufen ein durchlauf 1 sekunde

#### für so und so viele Sekunden den Watt wert in eine Datei schreiben
while [  $COUNTER -lt $time ]; do
    nvidia-smi --id=$id --query-gpu=power.draw --format=csv,noheader |gawk -e 'BEGIN {FS=" "} {print $1}'  >> WATT.out
    let COUNTER=COUNTER+1
    sleep 1
done

### MAX WATT zur berechnung für Solarstrom  ... muss in die bench hinzugefügt werden
sort WATT.out |tail -1 > WATT_max.out

###############################################################################
#
#Berechnung der Durchschnittlichen Verbrauches
#

WATT=$(cat "WATT.out")
MWATT=$(cat "WATT_max.out")
sum=0

for i in $WATT ; do 

	sum=$(echo "$sum + $i" | bc)
done

avg=$(echo "$sum / $time" | bc)
echo " Summe: $sum "
echo " Durchschnitt: $avg "
echo " Max WATT wert: $MWATT "

###############################################################################
#
# Hinzufügung der avg variable in die bench datei zu dem zugörigem Algorythmus
# + den maximal wert welche erreicht wird (peak wert) wegen Solar steuerung

