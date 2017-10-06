#!/bin/bash

_reset_COUNTER()
{
    COUNTER=0
    echo $COUNTER>COUNTER
}

_get_COUNTER()
{
    if test -e COUNTER; then
	COUNTER=$(< COUNTER )
    else _reset_COUNTER
    fi
}

_inc_COUNTER()
{
    COUNTER=$(< COUNTER )
    let COUNTER=COUNTER+1
    echo $COUNTER>COUNTER
}

# ALTE DATEI LÖSCHEN, damit nur EINE 'miner.sh' ENDLOSSCHLEIFE läuft
#if test -e miner.sh.pid; then kill -9 $(< miner.sh.pid ); fi #im start stop script abgefragt

# Aktuelle PID der 'miner.sh' ENDLOSSCHLEIFE
echo $$ >miner.sh.pid

PHASE=PowerReal_P_Phase_1
PHASE=PowerReal_P_Phase_2
PHASE=PowerReal_P_Phase_3
PHASE=PowerReal_P_Sum

SCHWELLE=-260


# Falls das Programm 'miner' läuft, einfach weiterlaufen lassen und den aktuellen COUNTER holen.
# Wenn die Datei noch nicht existiert, wie bei ersten Aufruf, wird sie mit 0 initialisiert.
_get_COUNTER

run980tiwatt=0
if test -e 980ti.pid ; then
	 run980tiwatt=270
fi
	
while [ 1 -eq 1 ]; do

    # Datei smartmeter holen
    w3m "http://192.168.6.170/solar_api/v1/GetMeterRealtimeData.cgi?Scope=Device&DeviceId=0&DataCollection=MeterRealtimeData" > smartmeter
    
    # ABFRAGE $k
    k=`grep $PHASE smartmeter|gawk '{print substr($3,0,index($3,".")-1)}'`

    if  [ $k -gt $(( $SCHWELLE + $run980tiwatt)) ]
    then
	if test -e 980ti.pid
	then
	    if [ $COUNTER -ge 3 ]; then
		echo $k
		echo `date` "miner beenden bei COUNTER =" $COUNTER $k >> 980ti.log
		kill $(< 980ti.pid )
		# RUNTIME-Beweis für laufenden 'miner' löschen
		rm 980ti.pid
		run980tiwatt=0
	    fi
	fi
    else
	if test -e 980ti.pid
	then
	    	Pidm=$(< 980ti.pid )

		#pid ueberpruefen ob auf dieser wirklich "etwas"(vielleicht noch verfeinern ob prozess 'miner' auf der pid) laeuft
		if test `ps -e | grep -c $Pidm` = 0	#wenn keine pid datei da ist kommt fehler meldung
		then
			#neu starten des miners
	    		echo  `date` "RESET NEU start miner" $k >> 980ti.log
	    		./miner --config miner.cfg &
	    		echo $! > 980ti.pid
	    		run980tiwatt=270
	    		_reset_COUNTER
		fi
	    echo "programm laeuft seid $COUNTER durchgaengen a 10 sekunden!!!!!"
#	    exit
	else
	    echo  `date` "programm start miner" $k >> 980ti.log
	    ./miner --config miner.cfg &
	    echo $! > 980ti.pid
	    run980tiwatt=270
	    _reset_COUNTER
	fi
    fi
    sleep 10s
    _inc_COUNTER
done
