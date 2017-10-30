#!/bin/bash
INSTANZ="GPU-980TI Miner"
#GPU_DIR=/opt/gpu/980ti/miner
Pid_schleife=miner.sh.pid
Pid_miner=980ti.pid

# Startparameter des EQUIHASH Miners 
#./miner --server equihash.eu.nicehash.com \
#        --port 3357 \
#        --user 12X6Enpg5FBQ332Re3vjU5FAxxQWUioBMg.1060 \
#        --pass x \
#        --cuda_devices 1 \
#        --pec \
#        --solver 0 \
#        --intensity 64 

#pids einlesen in variablen
if [ -f $Pid_schleife ]
then
    Pids=$(< $Pid_schleife )
fi

if [ -f $Pid_miner ]
then
    Pidm=$(< $Pid_miner )
fi

case "$1" in
    'start')
        if [ -f $Pid_schleife ] ; then
            if test `ps -e | grep -c $Pids` = 1; then        #wenn keine pid datei da ist kommt fehler meldung
                echo "Der $INSTANZ - laeuft schon mit der PID: $Pids"
            else
                echo "Starte $INSTANZ"
                #cd $GPU_DIR
                ./miner_5.sh &
            fi
        else
            if test `ps -e | grep -c $Pidm` = 1; then        #wenn keine pid datei da ist kommt fehler meldung
                echo "Der $INSTANZ - laeuft schon mit der PID: $Pidm"
            else
                echo "Starte $INSTANZ"
                #cd $GPU_DIR
                ./miner_5.sh &
                #nohup ./bsp.sh &> /dev/null &         # dev/null schiebt die ausgabe in den müll vom prog
            fi
        fi
        ;;

    'stop')
        if [ -f $Pid_schleife ] ; then
            echo "Stoppe $INSTANZ"
            kill -15 $Pids
            kill -15 $Pidm
            rm $Pid_schleife ; rm $Pid_miner
        else
            echo "Kann nicht $INSTANZ gestoppt werden - keinen Prozess gefunden!"
        fi
        ;;

    'restart')
        $0 stop
        sleep 5
        $0 start
        ;;

    'status')
        if [ -f $Pid_schleife ] ; then
            if test `ps -e | gawk -e '{print $1}' | grep -c $Pids` = 0; then    #wenn keine pid datei da ist kommt fehler meldung
                echo "$INSTANZ laeuft nicht"
            else
                echo "$INSTANZ schleife laeuft mit PID: [$Pids]"
            fi
            if test `ps -e | grep -c $Pidm` = 0; then    #wenn keine pid datei da ist kommt fehler meldung
                echo "$INSTANZ laeuft nicht"
            else
                echo "$INSTANZ miner laeuft mit PID: [$Pidm]"
            fi
        else
            echo "$Pid_schleife und $Pid_miner existiert nicht! Kann keinen Prozess $INSTANZ status!"
            exit 1
        fi
        ;;

    *)
        echo "usage: $0 { start | stop | restart | status }"
        ;;

esac
exit 0
