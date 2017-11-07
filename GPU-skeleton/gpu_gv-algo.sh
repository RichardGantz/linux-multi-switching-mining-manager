#!/bin/bash
###############################################################################
#
#  GPU - Algorithmus - Berechnung - BTC "Mines" anhand aktueller Kurse
#
#  1. Neustart des Skripts bekommt eine PID, die nur in der Prozesstabelle vorhanden ist
#  2. Merkt sich die eigene UUID in ${GPU_DIR}
#  3. Definiert _update_SELF_if_necessary()
#  4. Ruft update_SELF_if_necessary()
#  5. Schreibt seine PID in eine gleichnamige Datei mit der Endung .pid
#  6. Prüft, ob die Benchmarkdatei jemals bearbeitet wurde und bricht ab, wenn nicht.
#     Dann gibt es nämlich keine Benchmark- und Wattangaben zu den einzelnen Algorithmen.
#  7. Definiert _read_IMPORTANT_BENCHMARK_JSON_in(), welches Benchmark- und Wattangaben pro Algorithmus
#     aus der Datei benchmark_${GPU_DIR}.json
#     in die Assoziativen Arrays bENCH["AlgoName"] und WATTS["AlgoName"] aufnimmt
#  8. Ruft _read_IMPORTANT_BENCHMARK_JSON_in() und hat jetzt die beiden Arrays zur Verfügung und kennt das "Alter"
#     der Benchmarkdatei zum Zeitpunkt des Einlesens in der Variablen ${IMPORTANT_BENCHMARK_JSON_last_age_in_seconds}
#  9. Definiert _read_ALGOs_in(), welches nur dann etwas im Arbeitsspeicher ändert, wenn die Datei
#     ../ALGO_NAMES.in existiert und nicht leer ist:
#     Dann liest sie die Datei in die Arrays kMGTP["AlgoName"] und ALGOs["algoID"] ein
#     und merkt sich das "Alter" der eingelesenen Datei in der Variablen ${ALGO_NAMES_last_age_in_seconds}
# 10. Definiert _read_KURSE_in(), welches die Datei "../KURSE.in" in das Array KURSE["AlgoName"] aufnimmt.
#     Das Alter dieser Datei ist unwichtig, weil sie IMMER durch algo_multi_abfrage.sh aus dem Web aktualisiert wird.
#     Andere müssen dafür sorgen, dass die Daten in dieser Datei gültig sind!
# 11. ###WARTET### jetzt, bis das SYNCFILE="../you_can_read_now.sync" vorhanden ist.
#                         und merkt sich dessen "Alter" in der Variable ${new_Data_available}
# 12. ###WARTET### jetzt, bis die Datei ALGO_NAMES="../ALGO_NAMES.in" vorhanden und NICHT LEER ist.
# 13. Ruft _read_ALGOs_in und hat jetzt die Arrays kMGTP["AlgoName"] und ALGOs["algoID"] zur Verfügung,
#     FALLS die Datei ../ALGO_NAMES.in existiert und nicht leer ist!
#     ---> Ansonsten sind die beiden Arrays NICHT DEFINIERT! <--- (was kein guter Zustand ist und wir nochmal
#                                                                  die Konsequenzen untersuchen müssen!!!)
#          Wenn diese Arrays nicht da sind, kann nichts berechnet werde.
#          Alle weiteren Schritte sind SINNLOS und das Skript sollte NICHTS WEITER UNTERNEHMEN!
#          Wir müssen also später zu dieser Stelle zurückkehren und WISSEN, ob algo_multi_abfrage.sh
#          WIRKLICH SICHERSTELLT, DASS DIESE DATEI DA IST UND GÜLTIGEN INHALT HAT, WENN "this" an dieser
#          Stelle vorbeikommt und die Datei einlesen will.
#
# 14. EINTRITT IN DIE ENDLOSSCHLEIFE. Die folgenden Aktionen werden immer und immer wieder durchgeführt,
#                                     solange dieser Prozess läuft.
#  1. Ruft _update_SELF_if_necessary
#  2. Ruft _read_IMPORTANT_BENCHMARK_JSON_in falls die Quelldatei upgedated wurde.
#                             => Aktuelle Arrays bENCH["AlgoName"] und WATTS["AlgoName"]
#  3. Ruft _read_ALGOs_in     falls die Quelldatei upgedated wurde.
#                             => Aktuelle Arrays kMGTP["AlgoName"] und ALGOs["algoID"]
#  4. ###WARTET### jetzt, bis die Datei "../KURSE.in" vorhanden und NICHT LEER ist.
#  5. Ruft _read_KURSE_in     => Array KURSE["AlgoName"] verfügbar
#  6. Berechnet jetzt die "Mines" in BTC und schreibt die folgenden Angaben in die Datei ALGO_WATTS_MINES.in :
#               AlgoName
#               Watt
#               BTC "Mines"
#     sofern diese Daten tatsächlich vorhanden sind.
#     Algorithmen mit fehlenden Benchmark- oder Wattangaben, etc. werden NICHT beachtet.
#
#     Das "Alter" der Datei ALGO_WATTS_MINES.in Sekunden ist Hinweis für multi_mining_calc.sh,
#     ob mit der Gesamtsystem-Gewinn-Verlust-Berechnung begonnen werden kann.
#
#  7. Die Daten für multi_mining_calc.sh sind nun vollständig verfügbar.
#     Es ist jetzt erst mal die Berechnung durch multi_mining_calc.sh abzuwarten, um wissen zu können,
#     ob diese GPU ein- oder ausgeschaltet werden soll.
#     Vielleicht können wir das sogar hier drin tun, nachdem das Ergebnis für diese GPU feststeht ???
#
#     ###WARTET### jetzt, bis das "Alter" der Datei ${SYNCFILE} aktueller ist als ${new_Data_available}
#                         mit der Meldung "Waiting for new actual Pricing Data from the Web..."
#  8. Merkt sich das neue "Alter" von ${SYNCFILE} in der Variablen ${new_Data_available}
#
# 15. VORLÄUFIGES ENDE DER ENDLOSSCHLEIFE
#
###############################################################################
#  1. Neustart des Skripts bekommt eine PID, die nur in der Prozesstabelle vorhanden ist
#  2. Merkt sich die eigene UUID in ${GPU_DIR}
SRC_DIR=GPU-skeleton
GPU_DIR=$(pwd | gawk -e 'BEGIN { FS="/" }{print $NF}')
#  3. Definiert _update_SELF_if_necessary()
_update_SELF_if_necessary()
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
            echo "GPU #$(< gpu_index.in): ###---> Updating the GPU-UUID-directory from $SRC_DIR"
            exec ./$UPD_FILE
        fi
    else
        echo "Exiting in the not-to-be-run $SRC_DIR directory"
        echo "This directory doesn't represent a valid GPU"
        exit
    fi
}
# Beim Neustart des Skripts gleich schauen, ob es eine aktuellere Version gibt
# und mit der neuen Version neu starten.
#  4. Ruft update_SELF_if_necessary()
_update_SELF_if_necessary

# Diese Prozess-ID ändert sich durch den Selbst-Update NICHT!!!
# Sie ist auch nach dem Selbst-Update noch die Selbe.
# Es ist immer noch der selbe Prozess.
# Diese Datei sollte aber auch immer zusammen mit dem Prozess verschwinden, was wir noch konstruieren müssen.
#  5. Schreibt seine PID in eine gleichnamige Datei mit der Endung .pid
echo $$ >$(basename $0 .sh).pid

#
# Aufräumarbeiten beim ordungsgemäßen kill -15 Signal
#
function _On_Exit () {
    rm -f $(basename $0 .sh).pid
}
trap _On_Exit EXIT

# Die Quelldaten Miner- bzw. AlgoName, BenchmarkSpeed und WATT für diese GraKa
#  6. Prüft, ob die Benchmarkdatei jemals bearbeitet wurde und bricht ab, wenn nicht.
#     Dann gibt es nämlich keine Benchmark- und Wattangaben zu den einzelnen Algorithmen.
IMPORTANT_BENCHMARK_JSON_SRC=../${SRC_DIR}/benchmark_skeleton.json
IMPORTANT_BENCHMARK_JSON="benchmark_${GPU_DIR}.json"
diff -q $IMPORTANT_BENCHMARK_JSON $IMPORTANT_BENCHMARK_JSON_SRC &>/dev/null
if [ $? == 0 ]; then
    echo "-------------------------------------------"
    echo "---        FATAL ERROR GPU #$(< gpu_index.in)           ---"
    echo "-------------------------------------------"
    echo "File '$IMPORTANT_BENCHMARK_JSON' not yet edited!!!"
    echo "Please edit and fill in valid data!"
    echo "Execution stopped."
    echo "-------------------------------------------"
    exit
fi

###############################################################################
#
# Einlesen und verarbeiten der Benchmarkdatei
#
######################################

#  7. Definiert _read_IMPORTANT_BENCHMARK_JSON_in(), welches Benchmark- und Wattangaben
#     und überhaupt alle Daten pro Algorithmus
#     aus der Datei benchmark_${GPU_DIR}.json
#     in die Assoziativen Arrays bENCH["AlgoName"] und WATTS["AlgoName"] und
#     EXTRA_PARAMS["AlgoName"]
#     GRAFIK_CLOCK["AlgoName"]
#     MEMORY_CLOCK["AlgoName"]
#     FAN_SPEED["AlgoName"]
#     POWER_LIMIT["AlgoName"]
#     LESS_THREADS["AlgoName"]
#     aufnimmt
bENCH_SRC="bENCH.in"
# Ein bisschen Hygiene bei Änderung von Dateinamen
bENCH_SRC_OLD=""; if [ -f "$bENCH_SRC_OLD" ]; then rm "$bENCH_SRC_OLD"; fi

# Damit readarray als letzter Prozess in einer Pipeline nicht in einer subshell
# ausgeführt wird und diese beim Austriit gleich wieder seine Variablen verwirft
shopt -s lastpipe
source ../gpu-bENCH.inc

# Auf jeden Fall beim Starten das Array bENCH[] und WATTS[] aufbauen
# Später prüfen, ob die Datei erneuert wurde und frisch eingelesen werden muss
#  8. Ruft _read_IMPORTANT_BENCHMARK_JSON_in() und hat jetzt die beiden Arrays zur Verfügung und kennt das "Alter"
#     der Benchmarkdatei zum Zeitpunkt des Einlesens in der Variablen ${IMPORTANT_BENCHMARK_JSON_last_age_in_seconds}
_read_IMPORTANT_BENCHMARK_JSON_in

###############################################################################
#
# WELCHE ALGOS DA
#
# Abfrage welche Algorithmen gibt es  
#
######################################

#  9. Definiert _read_ALGOs_in(), welches nur dann etwas im Arbeitsspeicher ändert, wenn die Datei
#     ../ALGO_NAMES.in existiert und nicht leer ist:
#     Dann liest sie die Datei in die Arrays kMGTP["AlgoName"] und ALGOs["algoID"] ein
#     und merkt sich das "Alter" der eingelesenen Datei in der Variablen ${ALGO_NAMES_last_age_in_seconds}
ALGO_NAMES="../ALGO_NAMES.in"
# Ein bisschen Hygiene bei Änderung von Dateinamen
ALGO_NAMES_OLD=""; if [ -f "$ALGO_NAMES_OLD" ]; then rm "$ALGO_NAMES_OLD"; fi

_read_ALGOs_in()
{
    # Eigentlich sollte algo_multi_abfrage.sh schon dafür gesorgt haben, dass diese
    # Datei nicht leer ist.
    # Nur zur Sicherheit lesen wir sie nur dann ein, wenn sie nicht leer ist.
    if [ -s ${ALGO_NAMES} ]; then
        # Aus den Name:kMGTP:Algo Drillingen
        #     die assoziativen Arrays ALGOs und kMGTP erstellen
        # 
        unset kMGTP; declare -Ag kMGTP
        unset ALGOs
        unset READARR

        # Die Zeit merken, um aussen entscheiden zu können,
        # ob das Array durch Aufruf von _read_ALGOs_in neu erstellt werden muss
        # Wichtig dabei ist, die Zeit VOR dem tatsächlichen Einlesen der Datei festzuhalten !!!
        #    Ansonsten kann der Fall eintreten, dass bis zum nächsten erforderlichen Update
        #    - und das kann ein ganzer Tag sein - mit den alten Daten gearbeitet wird.
        #    Ist SEEEHR unwahrscheinlich, aber möglich
        ALGO_NAMES_last_age_in_seconds=$(date --utc --reference=$ALGO_NAMES +%s)

        # $ALGO_NAMES einlesen in das indexed Array READARR
        readarray -n 0 -O 0 -t READARR <$ALGO_NAMES
        for ((i=0; $i<${#READARR[@]}; i+=3)) ; do
            #echo ${READARR[$i]}
            kMGTP[${READARR[$i]}]=${READARR[$i+1]}
            ALGOs[${READARR[$i+2]}]=${READARR[$i]}
        done
    fi
}

###############################################################################
#
# Einlesen und verarbeiten der aktuellen Kurse
#
# Unbedingte Voraussetzung: Das Array ALGOs[] mit den Algorithmennamen
#
######################################

# 10. Definiert _read_KURSE_in(), welches die Datei "../KURSE.in" in das Array KURSE["AlgoName"] aufnimmt.
#     Das Alter dieser Datei ist unwichtig, weil sie IMMER durch algo_multi_abfrage.sh aus dem Web aktualisiert wird.
#     Andere müssen dafür sorgen, dass die Daten in dieser Datei gültig sind!
KURSE_in="../KURSE.in"
# Ein bisschen Hygiene bei Änderung von Dateinamen
KURSE_in_OLD=""; if [ -f "$KURSE_in_OLD" ]; then rm "$KURSE_in_OLD"; fi

_read_KURSE_in()
{
    unset KURSE; declare -Ag KURSE
    unset READARR

    # Aus den ALGORITHMUS:PREIS Paaren das assoziative Array KURSE erstellen
    readarray -n 0 -O 0 -t READARR <$KURSE_in
    for ((i=0; $i<${#READARR[@]}; i+=2)) ; do
        #echo ${READARR[$i]}
        #echo ${ALGOs[${READARR[$i]}]}
        KURSE[${ALGOs[${READARR[$i]}]}]=${READARR[$i+1]}
    done
}

###############################################################################
#
# Gibt es überhaupt schon etwas zu tun?
#
######################################

# Diese Datei wird alle 31s erstelt, nachdem die Daten aus dem Internet aktualisiert wurden
# Sollte diese Datei nicht da sein, weil z.B. die algo_multi_abfrage.sh
# noch nicht gelaufen ist, warten wir das einfach ab und sehen sekündlich nach,
# ob die Datei nun da ist und die Daten zur Verfügung stehen.

# 11. ###WARTET### jetzt, bis das SYNCFILE="../you_can_read_now.sync" vorhanden ist.
#                         und merkt sich dessen "Alter" in der Variable ${new_Data_available}
SYNCFILE="../you_can_read_now.sync"
while [ ! -f ${SYNCFILE} ]; do
    echo "GPU #$(< gpu_index.in): ###---> Waiting for ${SYNCFILE} to become available..."; sleep 1
done
new_Data_available=$(date --utc --reference=${SYNCFILE} +%s)

# Auf jeden Fall beim Starten die zwei Arrays aufbauen.
# Später prüfen, ob die Datei erneuert wurde und frisch eingelesen werden muss
# 12. ###WARTET### jetzt, bis die Datei ALGO_NAMES="../ALGO_NAMES.in" vorhanden und NICHT LEER ist.
while [ ! -s $ALGO_NAMES ]; do
    echo "GPU #$(< gpu_index.in): ###---> Waiting for $ALGO_NAMES to become available..."; sleep 1
done
# 13. Ruft _read_ALGOs_in und hat jetzt die Arrays kMGTP["AlgoName"] und ALGOs["algoID"] zur Verfügung,
#     FALLS die Datei ../ALGO_NAMES.in existiert und nicht leer ist!
#     ---> Ansonsten sind die beiden Arrays NICHT DEFINIERT! <--- (was kein guter Zustand ist und wir nochmal
#                                                                  die Konsequenzen untersuchen müssen!!!)
#          Wenn diese Arrays nicht da sind, kann nichts berechnet werde.
#          Alle weiteren Schritte sind SINNLOS und das Skript sollte NICHTS WEITER UNTERNEHMEN!
#          Wir müssen also später zu dieser Stelle zurückkehren und WISSEN, ob algo_multi_abfrage.sh
#          WIRKLICH SICHERSTELLT, DASS DIESE DATEI DA IST UND GÜLTIGEN INHALT HAT, WENN "this" an dieser
#          Stelle vorbeikommt und die Datei einlesen will.
_read_ALGOs_in

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

GRID[0]="netz"
GRID[1]="solar"
GRID[2]="solar_akku"

#
# 14. EINTRITT IN DIE ENDLOSSCHLEIFE. Die folgenden Aktionen werden immer und immer wieder durchgeführt,
#                                     solange dieser Prozess läuft.
while [ 1 -eq 1 ] ; do
    
    # If there is a newer version of this script, update it before the next run
    #  1. Ruft _update_SELF_if_necessary
    _update_SELF_if_necessary

    # Ist die Benchmarkdatei mit einer aktuellen Version überschrieben worden?
    #  2. Ruft _read_IMPORTANT_BENCHMARK_JSON_in falls die Quelldatei upgedated wurde.
    #                             => Aktuelle Arrays bENCH["AlgoName"] und WATTS["AlgoName"]
    if [[ $IMPORTANT_BENCHMARK_JSON_last_age_in_seconds < $(date --utc --reference=$IMPORTANT_BENCHMARK_JSON +%s) ]]; then
        echo "GPU #$(< gpu_index.in): ###---> Updating Arrays bENCH[] und WATTs[] from $IMPORTANT_BENCHMARK_JSON"
        _read_IMPORTANT_BENCHMARK_JSON_in
    fi

    # Die Reihenfolge der Dateierstellungen durch ../algo_multi_abfrage.sh ist:
    #     1.: $ALGO_NAMES
    #     2.: $KURSE_in
    #     3.: ../BTC_EUR_kurs.in
    # Letzte: ${SYNCFILE}

    # Ist die Datei ALGO_NAMES mit einer aktuellen Version überschrieben worden?
    #  3. Ruft _read_ALGOs_in     falls die Quelldatei upgedated wurde.
    #                             => Aktuelle Arrays kMGTP["AlgoName"] und ALGOs["algoID"]
    if [[ $ALGO_NAMES_last_age_in_seconds < $(date --utc --reference=$ALGO_NAMES +%s) ]]; then
        echo "GPU #$(< gpu_index.in): ###---> Updating Arrays ALGOs[] und kMGTP[] from $ALGO_NAMES"
        _read_ALGOs_in
    fi

    # Einlesen und verarbeiten der aktuellen Kurse, sobald die Datei vorhanden und nicht leer ist
    #  4. ###WARTET### jetzt, bis die Datei "../KURSE.in" vorhanden und NICHT LEER ist.
    while [ ! -s $KURSE_in ]; do
        echo "GPU #$(< gpu_index.in): ###---> Waiting for $KURSE_in to become available..."
        sleep 1
    done
    #  5. Ruft _read_KURSE_in     => Array KURSE["AlgoName"] verfügbar
    _read_KURSE_in

    ###############################################################################
    #
    #    Festhalten ALLER   AlgoNames, Watts und Mines für die Multi_mining_calc.sh
    #
    ######################################
    # Zur sichereren Synchronisation, dass der multi_mining_calc.sh erst dann die Datei ALGO_WATTS_MINES
    # einliest, wenn sie auch komplett ist und geschlossen wurde.
    # -----------------> IST NOCH ZU IMPLEMENTIEREN IN multi_mining_calc.sh <-----------------
    date --utc +%s >ALGO_WATTS_MINES.lock
    #  6. Berechnet jetzt die "Mines" in BTC und schreibt die folgenden Angaben in die Datei ALGO_WATTS_MINES.in :
    #               AlgoName
    #               Watt
    #               BTC "Mines"
    #     sofern diese Daten tatsächlich vorhanden sind.
    #     Algorithmen mit fehlenden Benchmark- oder Wattangaben, etc. werden NICHT beachtet.
    #
    #     Das "Alter" der Datei ALGO_WATTS_MINES.in Sekunden ist Hinweis für multi_mining_calc.sh,
    #     ob mit der Gesamtsystem-Gewinn-Verlust-Berechnung begonnen werden kann.
    rm -f ALGO_WATTS_MINES.in
    for algorithm in "${!bENCH[@]}"; do
        read algo miner_name miner_version <<<${algorithm//#/ }
        if [[          ${#bENCH[$algorithm]} -gt 0   \
                    && ${#kMGTP[$algo]}      -gt 0   \
                    && ${#KURSE[$algo]}      -gt 0   \
                    && ${WATTS[$algorithm]}  -lt 1000 \
            ]]; then
            # "Mines" in BTC berechnen
            algoMines=$(echo "scale=8;   ${bENCH[$algorithm]}  \
                                       * ${KURSE[$algo]}  \
                                       / ${kMGTP[$algo]}  \
                             " | bc )
            printf "$algorithm\n${WATTS[$algorithm]}\n${algoMines}\n" >>ALGO_WATTS_MINES.in
        else
            # ---> MUSS VIELLEICHT AKTIVIERT WERDEN, WENN UNTEN DER BEST-OF TEIL WEGFÄLLT <---
            echo "GPU #$(< gpu_index.in): KEIN Hash WERT bei $algorithm !!! \<------------------------"
        fi
    done
    rm -f ALGO_WATTS_MINES.lock
    
    #############################################################################
    #
    #
    # Warten auf neue aktuelle Daten aus dem Web, die durch
    #        algo_multi_abfrage.sh
    # beschafft werden müssen und deren Gültigkeit sichergestellt werden muss!
    #
    #
    #
    #  7. Die Daten für multi_mining_calc.sh sind nun vollständig verfügbar.
    #     Es ist jetzt erst mal die Berechnung durch multi_mining_calc.sh abzuwarten, um wissen zu können,
    #     ob diese GPU ein- oder ausgeschaltet werden soll.
    #     Vielleicht können wir das sogar hier drin tun, nachdem das Ergebnis für diese GPU feststeht ???
    #
    #     ###WARTET### jetzt, bis das "Alter" der Datei ${SYNCFILE} aktueller ist als ${new_Data_available}
    #                         mit der Meldung "Waiting for new actual Pricing Data from the Web..."
    while [ ! -f ${SYNCFILE} ]; do
        echo "GPU #$(< gpu_index.in): ###---> Waiting for ${SYNCFILE} to become available..."
        sleep 1
    done
    echo "GPU #$(< gpu_index.in): Waiting for new actual Pricing Data from the Web..."
    while [ "${new_Data_available}" == "$(date --utc --reference=${SYNCFILE} +%s)" ] ; do
        sleep 1
    done
    #  8. Merkt sich das neue "Alter" von ${SYNCFILE} in der Variablen ${new_Data_available}
    new_Data_available=$(date --utc --reference=${SYNCFILE} +%s)
    
done
