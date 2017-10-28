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


COUNTER=0
id=$(cat "bensh_gpu_30s_.index")       #später indexnummer aus gpu folder einfügen !!!
time=30    #wieviel mal soll die schleife laufen ein durchlauf 1 sekunde

#### für so und so viele Sekunden den Watt wert in eine Datei schreiben
while [  $COUNTER -lt $time ]; do
    nvidia-smi --id=$id --query-gpu=power.draw --format=csv,noheader |gawk -e 'BEGIN {FS=" "} {print $1}'  >> watt_bensh_30s.out
    let COUNTER=COUNTER+1
    echo $COUNTER > COUNTER
    sleep 1
done




###############################################################################
#
# Hinzufügung der avg variable in die bench datei zu dem zugörigem Algorythmus
# + den maximal wert welche erreicht wird (peak wert) wegen Solar steuerung

