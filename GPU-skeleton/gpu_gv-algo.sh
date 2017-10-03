#!/bin/bash
###############################################################################
#
#  GPU - Gewinn - Verlust - Alogirthmus - Berechnung - Auswahl
#  Schleife alle 31 Sekunden, sobald neue Kurse eingelesen wurden
#  
# gv_GRID.out ; gv_solar_akku.out ; gv_solar.out
# 
# die Outs geben den zu berechnenden Algo aus
#
#
#
#
###############################################################################
SRC_DIR=GPU-skeleton
GPU_DIR=$(pwd | gawk -e 'BEGIN { FS="/" }{print $NF}')
_update_SELF()
{
    ###
    ### DO NOT TOUCH THIS FUNCTION! IT UPDATES ITSELF FROM DIR "GPU-skeleton"
    ###
    SRC_FILE=$(basename $0)
    UPD_FILE="update_${SRC_FILE}"
    rm -f $UPD_FILE
    if [ ! "$GPU_DIR" == "$SRC_DIR" ]; then
        src_secs=$(date --utc --reference=../${SRC_DIR}/${SRC_FILE} +%s)
        dst_secs=$(date --utc --reference=$SRC_FILE +%s)
        if [[ $dst_secs < $src_secs ]]; then
            # create update command file
            echo "cp -f ../${SRC_DIR}/${SRC_FILE} .; \
                  exec ./${SRC_FILE}" \
                 >$UPD_FILE
            chmod +x $UPD_FILE
            echo "Updating the GPU-UUID-directory from $SRC_DIR"
            exec ./$UPD_FILE
        fi
    else
        echo "Exiting in the not-to-be-run $SRC_DIR directory"
        echo "This directory doesn't represent a valid GPU"
        exit
    fi
}
_update_SELF

echo $$ >gpu_gv-algo.pid

# Die Quelldaten Miner- bzw. AlgoName, BenchmarkSpeed und WATT für diese GraKa
BENCHFILE_SRC=../${SRC_DIR}/benchmark_skeleton.json
BENCHFILE="benchmark_${GPU_DIR}.json"
diff -q $BENCHFILE $BENCHFILE_SRC &>/dev/null
if [ $? == 0 ]; then
    echo "-------------------------------------------"
    echo "---           FATAL ERROR               ---"
    echo "-------------------------------------------"
    echo "File '$BENCHFILE' not yet edited!!!"
    echo "Please edit and fill in valid data!"
    echo "Execution stopped."
    echo "-------------------------------------------"
fi

# Aufbereitet zum Einlesen mittels readarray und anschließendem Aufbau
# der assoziativen Arrays bENCH[algoname] und WATTS[algoname]
bENCH_SRC=bENCH.in

# Diese Datei wird in der Endlosschleife immer erstellt, wenn
# a) sie nicht vorhanden ist und
# b) sie älter ist als $BENCHFILE oben
rm -f $bENCH_SRC

# Diese Datei wird alle 31s erstelt, wen die Daten aus dem Internet aktualisiert wurden
# Sollte diese Datei nicht da sein, weil z.B. die algo_multi_abfrage.sh
# noch nicht gelaufen ist, warten wir das einfach ab und sehen sekündlich nach,
# ob die Datei nun da ist und die Daten zur Verfügung stehen.
SYNCFILE=../you_can_read_now.sync
while [ ! -f $SYNCFILE ]; do sleep 1; done

###############################################################################
#
# WELCHE ALGOS DA
#
# Abfrage welche Algorithmen gibt es  
#
######################################

ALGO_NAMES="../ALGO_NAMES.in"

# Aus den Name:kMGTP:Algo Drillingen
#     die assoziativen Arrays ALGOs und kMGTP erstellen
declare -A kMGTP
declare -a ALGOs
# KURSe extrahieren in das Standard indexed Array MAPFILE

readarray -n 0 -O 0 -t <$ALGO_NAMES
for ((i=0; $i<${#MAPFILE[@]}; i+=3)) ; do
    #echo ${MAPFILE[$i]}
    kMGTP[${MAPFILE[$i]}]=${MAPFILE[$i+1]}
    ALGOs[${MAPFILE[$i+2]}]=${MAPFILE[$i]}
done

###############################################################################
# 1. curl "https://api.nicehash.com/api?method=stats.global.current&location=0"
# 2. Die eine .json-Zeile bei "},{" in einzelne Zeilen aufspalten
# 3. Zuerst /"algo":[0-9*]/ suchen und alles nach dem ":" ausgeben
# 4. Dann   /
#    So sieht der Anfang der Datei aus, wenn RS angewendet wurde:
#{"result":{"stats"
#"profitability_above_ltc":"44.99","price":"0.0122","profitability_ltc":"0.0084","algo":0,"speed":"3913.40252248"
#"price":"0.2632","profitability_btc":"0.2279","profitability_above_btc":"15.48","algo":1,"speed":"58787556.32539999"
#...
#"price":"0.0124","algo":20,"speed":"3137.82488726","profitability_eth":"0.0072","profitability_above_eth":"71.20"
#
# 5. Ausgabe von ALGO-index und PREIS in Datei KURSE.in, die dann so aussieht:
#0
#0.0107
#1
#0.2821
#2
# ...
# ---
#28
#0.0724
#29
#0.0108
#
# 6. Einlesen der Datei KURSE.in in das Array READARR
# 7. READARR durchgehen und das assoziative Array KURSE aufbauen:
#    Der erste Wert [$i=0,2,4,6,etc.] ist der ALGO-index,
#        der als Index für Array ALGOs[] dient und den NAMEN auswirft.
#    Der NAME wiederum dient als Index für das Array KURSE[algoname],
#        der den PREIS aus der nächsten Zeile [$i+1 =1,3,5,7,etc.] aufnimmt.



###############################################################################
#
#     ENDLOSSCHLEIFE START
#

# Damit readarray als letzter Prozess in einer Pipeline nicht in einer subshell
# ausgeführt wird und diese beim Austriit gleich wieder seine Variablen verwirft
shopt -s lastpipe
while [ 1 -eq 1 ] ; do
    # If there is a newer version of this script, update it before the next run
    _update_SELF

    ###############################################################################
    #
    # Einlesen und verarbeiten der Benchmarkdatei
    #
    # Einlesen der Benchmarkdatei nach bench.in  
    #
    # 1. Datei benchmark_GPU-742cb121-baad-f7c4-0314-cfec63c6ec70.json erstellen
    # 2. IN DIESER .json DATEI SIND CR DRIN !!!!!!!!!!!!!!!!!!!!!!!
    # 3. Array $bENCH[] in Datei bENCH.in pipen
    # 4. Anschließend einlesen und Array mit Werten aufbauen
    # Die begehrten Zeilen:
    #      "MinerName":      "neoscrypt",
    #      "BenchmarkSpeed": 896513.0,
    #      "WATT":           320,
    ######################################

    # Ist die Benchmarkdatei mit einer aktuellen Version überschrieben worden?
    src_secs=$(date --utc --reference=$BENCHFILE +%s); dst_secs=0
    if [ -f $bENCH_SRC ]; then
        #echo $bENCH_SRC availlable
        dst_secs=$(date --utc --reference=$bENCH_SRC +%s)
    fi
    if [[ $src_secs > $dst_secs ]]; then
        #echo Creating new $bENCH_SRC
        unset READARR
        sed -e 's/\r//g' $BENCHFILE  \
            | gawk -e ' \
            $1 ~ /MinerName/      { print substr( tolower($2), 2, length($2)-3 ); next } \
            $1 ~ /BenchmarkSpeed/ { print substr( $2, 1, length($2)-1 ); next } \
            $1 ~ /WATT/           { print substr( $2, 1, length($2)-1 ) }' \
            | tee $bENCH_SRC \
            | readarray -n 0 -O 0 -t READARR
        # Diese assoziativen Arrays werden immer im ersten Lauf der Endlosschleife erstellt
        # und danach immer dann, wenn $BENCHFILE erneuert wurde.
        # Aus den MinerName:BenchmarkSpeed:WATT Paaren das assoziative Array bENCH erstellen
        unset bENCH; declare -A bENCH
        unset WATTS; declare -A WATTS
        for ((i=0; $i<${#READARR[@]}; i+=3)) ; do
            bENCH[${READARR[$i]}]=${READARR[$i+1]}
            WATTS[${READARR[$i]}]=${READARR[$i+2]}
            #echo ${READARR[$i]} : ${bENCH[${READARR[$i]}]}
            #echo ${READARR[$i]} : ${WATTS[${READARR[$i]}]}
        done
    fi

    ###############################################################################
    #
    # Einlesen und verarbeiten der aktuellen Kurse
    #
    unset READARR
    unset KURSE
    declare -A KURSE

    # Aus den ALGORITHMUS:PREIS Paaren das assoziative Array KURSE erstellen
    readarray -n 0 -O 0 -t READARR < ../KURSE.in
    #echo ${#READARR[@]}
    for ((i=0; $i<${#READARR[@]}; i+=2)) ; do
        #echo ${READARR[$i]}
        #echo ${ALGOs[${READARR[$i]}]}
        KURSE[${ALGOs[${READARR[$i]}]}]=${READARR[$i+1]}
    done
#    for algo in ${!ALGOs[@]}; do
#        echo ${ALGOs[$algo]}
#    done

###############################################################################
#
# BTC - EUR - Kurs
#
# Einlesen  
#
######################################    

    btcEUR=$(< ../BTC_EUR_kurs.in)
    btcSec=$(date --utc --reference=$SYNCFILE +%s)
    
###############################################################################
#
#                                                Berechnung der Stromkosten
#
# Berechnung der verschieden Strom bezugsarten Netz ; Solar ; Solar-Akku 
#
######################################
    GRID[0]="netz"
    GRID[1]="solar"
    GRID[2]="solar_akku"

    unset kwh_EUR; declare -A kwh_EUR
    unset kwh_BTC; declare -A kwh_BTC
    # Damit diese Datei auf gar keinen Fall schon da ist beim Eintritt in die Schleife
    rm -f gv_GRID.out
    for ((grid=0; $grid<${#GRID[@]}; grid+=1)) ; do

        # Kosten in EUR
        kwh_EUR[${GRID[$grid]}]=$(< ../kwh_${GRID[$grid]}_kosten.in)
    
        # Kosten Umrechnung in BTC
        kwh_BTC[${GRID[$grid]}]=$(echo "scale=8; ${kwh_EUR[${GRID[$grid]}]}/$btcEUR" | bc)
    
###############################################################################
#
# Berechnung mit Netz Strom
#
# gv_GRID.out <-- ist dann endprodukt welches algo berechnet werden soll 
#
######################################
    
        for algo in ${!ALGOs[@]}; do
            algorithm=${ALGOs[$algo]}
            if [[ ${#bENCH[$algorithm]}>0 && ${#kMGTP[$algorithm]}>0 && ${#KURSE[$algorithm]}>0 ]]; then
                # 1. Werte berechnen
                actual_gv=$(echo "scale=8; ${bENCH[$algorithm]} \
                                         / ${kMGTP[$algorithm]} \
                                         * ${KURSE[$algorithm]} \
                                         - ${WATTS[$algorithm]}*24*${kwh_BTC[${GRID[$grid]}]}/1000" | bc )
                                   
                echo $algorithm : BTC/D Gewinn/Verlust : $actual_gv
                # Ausgabe in Datei zum sortieren mit externen prog (vielleicht im RAM sortieren ohne datei schreiben)
                echo $actual_gv $algorithm ${WATTS[$algorithm]} >> gv_GRID.out
            else
                echo KEIN Hash WERT bei $algorithm bei GPU-xyz fehlt !!! \<------------------------
                # abfrage wegen watt wert ... dann wenn keiner da ist einfach keinen wert eintragen
                #fehler wie kein HASH oder WATT wert --> log datei der GPU 
            fi
        done
    
        cat gv_GRID.out | sort -rn | sed -n '1p' \
            > best_algo_${GRID[$grid]}.out
        rm gv_GRID.out

    done # for ((grid=0; $grid<${#GRID[@]}; grid+=1)) ; do

#############################################################################
#
#
# Ausgabe 
#
#
    for ((grid=0; $grid<${#GRID[@]}; grid+=1)) ; do
        echo --------------------------------------------------------------------
        echo --------Der Beste Algo zur zeit ist mit ${GRID[$grid]^^} Strom ----------------- 
        cat best_algo_${GRID[$grid]}.out
        echo --------------------------------------------------------------------
    done

    while [ $btcSec == $(date --utc --reference=$SYNCFILE +%s) ] ; do
        sleep 1
    done
    
done
