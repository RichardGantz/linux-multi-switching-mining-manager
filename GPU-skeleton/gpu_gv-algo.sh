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
# (21.11.2017)
# Wir wissen jetzt, dass alle relevanten Werte in der "simplemultialgo"-api Abfrage enthalten sind
#     und brauchen die ../ALGO_NAMES.in überhaupt nicht mehr.
#     Das folgende kann raus:
#  9. 
#
# (21.11.2017)
# Das machen wir ANDERS. Es gibt schon includable Funktionen zum Abruf, Auswertung und Einlesen der Webseite
# in die Arrays durch source ${LINUX_MULTI_MINING_ROOT}/algo_infos.inc
#        ALGOs[ $algo_ID ]
#        KURSE[ $algo ]
#        PORTs[ $algo ]
#     ALGO_IDs[ $algo ]
# 10. source ${LINUX_MULTI_MINING_ROOT}/algo_infos.inc
#
# 11. ###WARTET### jetzt, bis das SYNCFILE="../you_can_read_now.sync" vorhanden ist.
#                         und merkt sich dessen "Alter" in der Variable ${new_Data_available}
#
# (21.11.2017)
# Wir wissen jetzt, dass alle relevanten Werte in der "simplemultialgo"-api Abfrage enthalten sind
#     und brauchen die ../ALGO_NAMES.in überhaupt nicht mehr.
#     Das folgende kann raus:
# 12. 
# 13. 
#
# 14. EINTRITT IN DIE ENDLOSSCHLEIFE. Die folgenden Aktionen werden immer und immer wieder durchgeführt,
#                                     solange dieser Prozess läuft.
#  1. Ruft _update_SELF_if_necessary
#  2. Ruft _read_IMPORTANT_BENCHMARK_JSON_in falls die Quelldatei upgedated wurde.
#                                        => Aktuelle Arrays bENCH["AlgoName"] und WATTS["AlgoName"]
#  3. (weggefallen)
#  4. ###WARTET### jetzt, bis die Datei "../KURSE_PORTS.in" vorhanden und NICHT LEER ist.
#  5. Ruft _read_in_ALGO_PORTS_KURSE     => Array KURSE["AlgoName"] verfügbar
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
        exit 2
    fi
}
# Beim Neustart des Skripts gleich schauen, ob es eine aktuellere Version gibt
# und mit der neuen Version neu starten.
#  4. Ruft update_SELF_if_necessary()
_update_SELF_if_necessary

# ---> An dieser Stelle sollte wohl das Include "source" der GLOBALEN VARIABLEN stattfinden <---
# ---> An dieser Stelle sollte wohl das Include "source" der GLOBALEN VARIABLEN stattfinden <---
# ---> An dieser Stelle sollte wohl das Include "source" der GLOBALEN VARIABLEN stattfinden <---
##################################################################################################################
#                       GLOBALE VARIABLEN für spätere Implementierung
# Diese Variablen sind Kandidaten, um als Globale Variablen in einem "source" file überall integriert zu werden.
# Sie wird dann nicht mehr an dieser Stelle stehen, sondern über "source GLOBAL_VARIABLES.inc" eingelesen
#
# Diese Variable ist besonders wichtig für die über "source" includierten Dateien, die teilweise wissen müssen,
# wo sie aufegerufen wurden und wo ihr eigentliches "Home" ist.
# Gleich wird die
#     ../gpu-bENCH.inc gerufen,                               die ihrerseits eingangs sogar die
#     source ${LINUX_MULTI_MINING_ROOT}/miner-func.inc
# ruft und welche natürlich das ../miners Verzeichnis finden können muss, um Auskunft über Miner geben zu können.
#

GRID[0]="netz"
GRID[1]="solar"
GRID[2]="solar_akku"

declare -i k_base=1024          # CCminer scheint gemäß bench.cpp mit 1024 zu rechnen

LINUX_MULTI_MINING_ROOT=$(pwd | gawk -e 'BEGIN {FS="/"} { for ( i=1; i<NF; i++ ) {out = out "/" $i }; \
                   print substr(out,2) }')

# Mehr und mehr setzt sich die Systemweite Verwendung dieser Variablen durch:
gpu_idx=$(< gpu_index.in)
if [ ${#gpu_idx} -eq 0 ]; then
    declare -i i=0
    declare -i n=5
    for (( ; i<n; i++ )); do
        clear
        echo "---===###>>> MISSING IDENTITY:"
        echo "---===###>>> Ist gpu-abfrage.sh nicht gelaufen?"
        echo "---===###>>> Mir fehlt die Datei gpu_index.in, die mir sagt,"
        echo "---===###>>> welchen GPU-Index ich als UUID"
        echo "---===###>>> ${GPU_DIR}"
        echo "---===###>>> gerade habe."
        echo "---===###>>> Der Aufruf wird in $((n-i)) Sekunden gestoppt und beendet!"
        sleep 1
    done
    exit 1
fi    

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
    rm -f LINUX_MULTI_MINING_ROOT ALGO_WATTS_MINES.lock \
       $(basename $0 .sh).pid
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
    echo "---        FATAL ERROR GPU #${gpu_idx}           ---"
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
#     MAX_WATT["AlgoName"]
#     HASHCOUNT["AlgoName"]
#     HASH_DURATION["AlgoName"]
#     BENCH_DATE["AlgoName"]
#     BENCH_KIND["AlgoName"]
#     MinerFee["AlgoName"]
#     EXTRA_PARAMS["AlgoName"]
#     GRAFIK_CLOCK["AlgoName"]
#     MEMORY_CLOCK["AlgoName"]
#     FAN_SPEED["AlgoName"]
#     POWER_LIMIT["AlgoName"]
#     LESS_THREADS["AlgoName"]
#     aufnimmt
#
#     (09.11.2017)
#     Nach jedem Einlesen der Algorithmen aus der IMPORTANT_BENCHMARK_JSON prüft diese Funktion ebenfalls,
#     wie viele Miner in wieviel verschiedenen Versionen insgesamt im System bekannt sind
#         und welche Algorithmen sie können,
#     DAMIT bekannt ist, wie viele Algorithmen es insgesamt im System gibt, die alle miteinander verglichen werden können.
#
#     Algorithmen, die MÖGLICH, aber noch nicht in der IMPORTANT_BENCHMARK_JSON enthalten sind,
#         werden durch eine entsprechende Meldung "angemeckert".
#
#     ---> Natürlich muss noch überlegt werden,                                     <---
#     ---> an welcher Stelle eine routinemäßige Prüfung aller möglichen Algorithmen <---
#     ---> stattfinden soll, um keine Änderung im System zu verpassen.              <---
#     
bENCH_SRC="bENCH.in"
# Ein bisschen Hygiene bei Änderung von Dateinamen
bENCH_SRC_OLD=""; if [ -f "$bENCH_SRC_OLD" ]; then rm "$bENCH_SRC_OLD"; fi

# Damit readarray als letzter Prozess in einer Pipeline nicht in einer subshell
# ausgeführt wird und diese beim Austriit gleich wieder seine Variablen verwirft
shopt -s lastpipe
source gpu-bENCH.sh

# Auf jeden Fall beim Starten das Array bENCH[] und WATTS[] aufbauen
# Später prüfen, ob die Datei erneuert wurde und frisch eingelesen werden muss
#  8. Ruft _read_IMPORTANT_BENCHMARK_JSON_in() und hat jetzt die beiden Arrays zur Verfügung und kennt das "Alter"
#     der Benchmarkdatei zum Zeitpunkt des Einlesens in der Variablen ${IMPORTANT_BENCHMARK_JSON_last_age_in_seconds}
_read_IMPORTANT_BENCHMARK_JSON_in

###############################################################################
#
# Einlesen und verarbeiten der aktuellen Algos und Kurse
#
#
#
######################################

#                       GLOBALE VARIABLEN für spätere Implementierung
# Diese Variablen sind Kandidaten, um als Globale Variablen in einem "source" file überall integriert zu werden.
# Sie wird dann nicht mehr an dieser Stelle stehen, sondern über "source GLOBAL_VARIABLES.inc" eingelesen
algoID_KURSE_PORTS_WEB="KURSE.json"
algoID_KURSE_PORTS_ARR="KURSE_PORTS.in"

# Da manche Skripts in Unterverzeichnissen laufen, müssen diese Skripts die Globale Variable für sich intern anpassen
# ---> Wir könnten auch mit Symbolischen Links arbeiten, die in den Unterverzeichnissen angelegt werden und auf die
# ---> gleichnamigen Dateien darüber zeigen.
algoID_KURSE_PORTS_WEB="../${algoID_KURSE_PORTS_WEB}"
algoID_KURSE_PORTS_ARR="../${algoID_KURSE_PORTS_ARR}"

# 10. Definiert _read_in_ALGO_PORTS_KURSE(), welches die Datei "../KURSE_PORTS.in" in das Array KURSE["AlgoName"] aufnimmt.
#     Das Alter dieser Datei ist unwichtig, weil sie IMMER durch algo_multi_abfrage.sh aus dem Web aktualisiert wird.
#     Andere müssen dafür sorgen, dass die Daten in dieser Datei gültig sind!
source ${LINUX_MULTI_MINING_ROOT}/algo_infos.inc

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
    echo "GPU #${gpu_idx}: ###---> Waiting for ${SYNCFILE} to become available..."; sleep 1
done
new_Data_available=$(date --utc --reference=${SYNCFILE} +%s)

###############################################################################
#
#     ENDLOSSCHLEIFE START
#
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
        echo "GPU #${gpu_idx}: ###---> Updating Arrays bENCH[] and WATTs[] (and more) from $IMPORTANT_BENCHMARK_JSON"
        _read_IMPORTANT_BENCHMARK_JSON_in
    fi

    # Die Reihenfolge der Dateierstellungen durch ../algo_multi_abfrage.sh ist:
    # (21.11.2017)
    # Wir wissen jetzt, dass alle relevanten Werte in der "simplemultialgo"-api Abfrage enthalten sind
    #     und brauchen die ../ALGO_NAMES.in überhaupt nicht mehr.
    #     Das folgende kann raus und es ergibt sich eine neue Reihenfolge:
    #     (1.: $ALGO_NAMES entfällt)
    #     1.: $algoID_KURSE_PORTS_WEB und $algoID_KURSE_PORTS_ARR
    #     2.: ../BTC_EUR_kurs.in
    # Letzte: ${SYNCFILE}

    # Einlesen und verarbeiten der aktuellen Kurse, sobald die Datei vorhanden und nicht leer ist
    #  4. ###WARTET### jetzt, bis die Datei "../KURSE_PORTS.in" vorhanden und NICHT LEER ist.
    while [ ! -s ${algoID_KURSE_PORTS_ARR} ]; do
        echo "GPU #${gpu_idx}: ###---> Waiting for ${algoID_KURSE_PORTS_ARR} to become available..."
        sleep 1
    done
    #  5. Ruft _read_in_ALGO_PORTS_KURSE     => Array KURSE["AlgoName"] verfügbar
    _read_in_ALGO_PORTS_KURSE

    ###############################################################################
    #
    #    Berechnung und Ausgabe ALLER AlgoNames, Watts und Mines für die Multi_mining_calc.sh
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
                    && ${#KURSE[$algo]}      -gt 0   \
                    && ${WATTS[$algorithm]}  -lt 1000 \
            ]]; then
            # "Mines" in BTC berechnen
            algoMines=$(echo "scale=8;   ${bENCH[$algorithm]}  \
                                       * ${KURSE[$algo]}  \
                                       / ${k_base}^3  \
                             " | bc )
            printf "$algorithm\n${WATTS[$algorithm]}\n${algoMines}\n" >>ALGO_WATTS_MINES.in
        else
            # ---> MUSS VIELLEICHT AKTIVIERT WERDEN, WENN UNTEN DER BEST-OF TEIL WEGFÄLLT <---
            echo "GPU #${gpu_idx}: KEINE BTC \"Mines\" BERECHNUNG möglich bei $algorithm !!! \<---------------"
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
        echo "GPU #${gpu_idx}: ###---> Waiting for ${SYNCFILE} to become available..."
        sleep 1
    done
    echo "GPU #${gpu_idx}: Waiting for new actual Pricing Data from the Web..."
    while [ "${new_Data_available}" == "$(date --utc --reference=${SYNCFILE} +%s)" ] ; do
        sleep 1
    done
    #  8. Merkt sich das neue "Alter" von ${SYNCFILE} in der Variablen ${new_Data_available}
    new_Data_available=$(date --utc --reference=${SYNCFILE} +%s)
    
done
