#!/bin/bash
###############################################################################
#
#  Hier wird die GPU Watt abgefragt
#  
#  
# 
# 
# 
#
#
#
#
###############################################################################

#löschen einer bestehenden WATT.out datei
rm WATT_bensh_1.out

COUNTER=0
id=$(cat "watt_bensh_1.id")       #später indexnummer aus gpu folder einfügen !!!
time=100000000    #wieviel mal soll die schleife laufen ein durchlauf 1 sekunde

#### für so und so viele Sekunden den Watt wert in eine Datei schreiben
while [  $COUNTER -lt $time ]; do
    nvidia-smi --id=$id --query-gpu=power.draw --format=csv,noheader |gawk -e 'BEGIN {FS=" "} {print $1}'  >> WATT_bensh_1.out
    let COUNTER=COUNTER+1
    echo $COUNTER > COUNTER
    sleep 1
done


sort WATT_bensh_1.out |tail -1 > WATT_bensh_1_max.out

###############################################################################
#
#Berechnung der Durchschnittlichen Verbrauches
#

sort WATT_bensh_1.out |tail -1 > WATT_bensh_1_max.out

WATT=$(cat "WATT_bensh_1.out")
MWATT=$(cat "WATT_bensh_1_max.out")
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

