#!/bin/bash
###############################################################################
#
#  GPU - Gewinn - Verlust - Alogirthmus - Berechnung - Auswahl
#  Schleife alle 10 sekunden in ausgabe :
# gv_netz.out ; gv_solar_akku.out ; gv_solar.out
# 
# die Outs geben den zu berechnenden Algo aus
#
#
#
#
###############################################################################

echo $$ >gpu_gv-algo.pid

# Die Quelldaten Miner- bzw. AlgoName, BenchmarkSpeed und WATT für diese GraKa
BENCHFILE="benchmark_GPU-742cb121-baad-f7c4-0314-cfec63c6ec70.json"

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
while [ 1 -eq 1 ] ; do

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

    kwh_netz_EUR=$(< ../kwh_netz_kosten.in)
    kwh_solar_EUR=$(< ../kwh_solar_kosten.in)
    kwh_solar_akku_EUR=$(< ../kwh_solar_akku_kosten.in)
    
    # Netz-Strom-Berechnung
    kwh_N_BTC=$(echo "scale=8; $kwh_netz_EUR/$btcEUR" | bc)
    
    # Solar-Strom-Berechnung
    kwh_S_BTC=$(echo "scale=8; $kwh_solar_EUR/$btcEUR" | bc)

    # Solar-Akku-Berechnung
    kwh_SA_BTC=$(echo "scale=8; $kwh_solar_akku_EUR/$btcEUR" | bc)

###############################################################################
#
# Einlesen und verarbeiten der Benchmarkdatei
#
#Einlesen der Benchmarkdatei nach bench.in  
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
        sed -e 's/\r//g' $BENCHFILE  \
        | gawk -e ' \
            $1 ~ /MinerName/      { print substr( tolower($2), 2, length($2)-3 ); next } \
            $1 ~ /BenchmarkSpeed/ { print substr( $2, 1, length($2)-1 ); next } \
            $1 ~ /WATT/           { print substr( $2, 1, length($2)-1 ) }' \
        >$bENCH_SRC
	# Diese assoziativen Arrays werden immer im ersten Lauf der Endlosschleife erstellt
	# und danach immer dann, wenn $BENCHFILE erneuert wurde.
	unset READARR
	readarray -n 0 -O 0 -t READARR <$bENCH_SRC
	# Aus den MinerName:BenchmarkSpeed Paaren das assoziative Array bENCH erstellen
	declare -A bENCH
	declare -A WATTS
	for ((i=0; $i<${#READARR[@]}; i+=3)) ; do
            bENCH[${READARR[$i]}]=${READARR[$i+1]}
            WATTS[${READARR[$i]}]=${READARR[$i+2]}
            #echo ${READARR[$i]} : ${bENCH[${READARR[$i]}]}
            #echo ${READARR[$i]} : ${WATTS[${READARR[$i]}]}
	done
    fi
    
###############################################################################
#
# Berechnung mit Netz Strom
#
#gv_netz.out <-- ist dann endprodukt welches algo berechnet werden soll 
#
######################################
    
    for algo in ${!ALGOs[@]}; do
        algorithm=${ALGOs[$algo]}
        if [[ ${#bENCH[$algorithm]}>0 && ${#kMGTP[$algorithm]}>0 && ${#KURSE[$algorithm]}>0 ]]; then
            # 1. Werte berechnen
            actual_gv=$(echo "scale=8; ${bENCH[$algorithm]} \
                                     / ${kMGTP[$algorithm]} \
                                     * ${KURSE[$algorithm]} \
                                     - ${WATTS[$algorithm]}*24*$kwh_N_BTC/1000" | bc )
                                   
            echo $algorithm : BTC/D Gewinn/Verlust : $actual_gv
            # Ausgabe in Datei zum sortieren mit externen prog (vielleicht im ram sorteiren ohne datei schreiben)
            echo $actual_gv $algorithm ${WATTS[$algorithm]} >> gv_netz.out
        else
            echo KEIN Hash WERT bei $algorithm bei GPU-xyz fehlt !!! \<------------------------
            # abfrage wegen watt wert ... dann wenn keiner da ist einfach keinen wert eintragen
            #fehler wie kein HASH oder WATT wert --> log datei der GPU 
        fi
    done
    
    cat gv_netz.out | sort -rn -o gv_netz_sort.out
    #> gv_netz_sort.out
    sed -n '1p' gv_netz_sort.out > best_algo_netz.out 
    rm gv_netz.out
    
###############################################################################
#
# Berechnung mit Solar Strom
#
# gv_netz.out <-- ist dann entprodukt welches algo berechnet werden soll 
#
######################################
    
     for algo in ${!ALGOs[@]}; do
         algorithm=${ALGOs[$algo]}
         if [[ ${#bENCH[$algorithm]}>0 && ${#kMGTP[$algorithm]}>0 && ${#KURSE[$algorithm]}>0 ]]; then
             # 1. Werte berechnen
             actual_gv=$(echo "scale=8; ${bENCH[$algorithm]} \
                                      / ${kMGTP[$algorithm]} \
                                      * ${KURSE[$algorithm]} \
                                      - ${WATTS[$algorithm]}*24*$kwh_S_BTC/1000" | bc )
                                   
             echo $algorithm : BTC/D gewinn/verlust : $actual_gv
             #ausgabe in datei zum sorteiren mit externen prog (vielleicht im ram sorteiren ohne datei schreiben)
             echo $actual_gv $algorithm ${WATTS[$algorithm]} >> gv_solar.out
        else
            echo KEIN Hash WERT bei $algorithm bei GPU-xyz fehlt !!! \<------------------------
            # abfrage wegen watt wert ... dann wenn keiner da ist einfach keinen wert eintragen
            #fehler wie kein HASH oder WATT wert --> log datei der GPU 
        fi
    done
    
    cat gv_solar.out | sort -rn -o gv_solar_sort.out
    #> gv_netz_sort.out
    sed -n '1p' gv_solar_sort.out > best_algo_solar.out 
    rm gv_solar.out
    
###############################################################################
#
# Berechnung mit Solar-Akku Strom
#
# gv_netz.out <-- ist dann entprodukt welches algo berechnet werden soll 
#
######################################
    
    for algo in ${!ALGOs[@]}; do
        algorithm=${ALGOs[$algo]}
        if [[ ${#bENCH[$algorithm]}>0 && ${#kMGTP[$algorithm]}>0 && ${#KURSE[$algorithm]}>0 ]]; then
            # 1. Werte berechnen
            actual_gv=$(echo "scale=8; ${bENCH[$algorithm]} \
                                     / ${kMGTP[$algorithm]} \
                                     * ${KURSE[$algorithm]} \
                                     - ${WATTS[$algorithm]}*24*$kwh_SA_BTC/1000" | bc )
                                   
            echo $algorithm : BTC/D gewinn/verlust : $actual_gv
            #ausgabe in datei zum sorteiren mit externen prog (vielleicht im ram sorteiren ohne datei schreiben)
            echo $actual_gv $algorithm ${WATTS[$algorithm]} >> gv_solar_akku.out
        else
            echo KEIN Hash WERT bei $algorithm bei GPU-xyz fehlt !!! \<------------------------
            # abfrage wegen watt wert ... dann wenn keiner da ist einfach keinen wert eintragen
            #fehler wie kein HASH oder WATT wert --> log datei der GPU 
        fi
    done
    
    cat gv_solar_akku.out | sort -rn -o gv_solar_akku_sort.out
    #> gv_netz_sort.out
    sed -n '1p' gv_solar_akku_sort.out > best_algo_solar_akku.out 
    rm gv_solar_akku.out
    
#############################################################################
#
#
# Ausgabe 
#
#
    echo --------------------------------------------------------------------
    echo --------Der Beste Algo zur zeit ist mit NETZ Strom ----------------- 
    cat best_algo_netz.out
    echo --------------------------------------------------------------------
    echo --------------------------------------------------------------------
    echo --------Der Beste Algo zur zeit ist mit Solar Strom ----------------- 
    cat best_algo_solar.out
    echo --------------------------------------------------------------------
    echo --------------------------------------------------------------------
    echo -----Der Beste Algo zur zeit ist mit Solar-Akku Strom -------------- 
    cat best_algo_solar_akku.out
    echo --------------------------------------------------------------------

    while [ $btcSec == $(date --utc --reference=$SYNCFILE +%s) ] ; do
	echo HAAAAAAAAALOOOOOO... Ist da Wer\? >/dev/null
    done
    
done
