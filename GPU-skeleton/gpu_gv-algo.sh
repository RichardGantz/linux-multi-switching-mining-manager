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
#        ALGOs[ ${coin_ID} ]
#        KURSE[ ${coin} ]
#        PORTs[ ${coin} ]
#     ALGO_IDs[ ${coin} ]
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
#     Und Füllt die Arrays, die für die Coin-Berechnung erforderlich sind.
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
#  8. Wenn multi_mining_calc.sh mit den Berechnungen fertig ist, schreibt sie die Datei ${RUNNING_STATE},
#     in der die neue Konfigurationdrin steht, WIE ES AB JETZT ZU SEIN HAT.
#     Aus dieser Datei entnimmt jede GPU nun die Information, die für sie bestimmt ist und stoppt und startet
#     die entsprechenden Miner.
#     Miner, die noch laufen, müssen beendet werden, wenn ein neuer Miner gestartet werden soll.
#     Nach jedem Minerstart merkt sich die GPU, 
#
#     ###WARTET### jetzt, bis das "Alter" der Datei ${SYNCFILE} aktueller ist als ${new_Data_available}
#                         mit der Meldung "Waiting for new actual Pricing Data from the Web..."
#  9. Merkt sich das neue "Alter" von ${SYNCFILE} in der Variablen ${new_Data_available}
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

# GLOBALE VARIABLEN, nützliche Funktionen
[[ ${#_GLOBALS_INCLUDED} -eq 0 ]] && source ../globals.inc
declare -i verbose=0
declare -i debug=1
rm -f ALGO_WATTS_MINES.in

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
This=$(basename $0 .sh)
echo $$ >${This}.pid
# Ermittlung der Process Group ID, die beim multi_mining_calc.sh seiner eigenen PID gleicht.
# Alles, was er aufruft, sollte die selbe Group-ID haben, also auch die gpu_gv-algos und algo_multi_abfrage.sh
# Interessant wird es bei den gpu_gv-algo.sh's, wenn die wiederum etwas rufen.
# Wie lautet dann die Group-ID?
# Die folgenden Teilen haben gezeigt, dass die gpu_gv-algi der selben Prozessgruppe angehört.
#  PID  PGID   SID TTY          TIME CMD
# 9462  9462  1903 pts/0    00:00:00 multi_mining_ca
#echo "GPU #${gpu_idx} gehört zu folgender Prozess-Gruppe:"
#ps -j --pid $$
#echo "Die Prozessgruppe, die der MULTI_MINER eröffnet hat, hat die PID == PGID == ${MULTI_MINERS_PID}"

#
# Aufräumarbeiten beim ordungsgemäßen kill -15 Signal
#
function _On_Exit () {
    if [ -n "${DoAutoBenchmark}" ] && [ ${DoAutoBenchmark} -eq 1 ]; then
        echo "Prozess wurde aus dem Auto-Benchmarking gerissen... GPU #${gpu_idx} wird wieder global Enabled."
        _enable_GPU_UUID_GLOBALLY ${gpu_uuid}
    fi

    # Die MinerShell muss beendet werden, wenn sie noch laufen sollte.
    unset MinerShell_pid
    [ -s ${MinerShell}.ppid -a -s ${MinerShell}.pid ] && MinerShell_pid=$(< ${MinerShell}.ppid)
    if [ -n "${MinerShell_pid}" ]; then
        printf "Beenden der MinerShell ${MinerShell}.sh mit PID ${MinerShell_pid} ... "
        minershell_REGEXPAT="${MinerShell//\./\\.}\.sh"
        kill_pid=$(ps -ef | gawk -e '$2 == '${MinerShell_pid}' && /'${minershell_REGEXPAT}'/ {print $2; exit }')
        if [ -n "$kill_pid" ]; then
            kill $kill_pid
            [[ $? -eq 0 ]] && printf "KILL SIGNAL SUCCESSFULLY SENT.\n" || printf "KILL SIGNAL COULD NOT BE SENT SUCCESSFULLY.\n"
        else
            printf "PID ${MinerShell_pid} NOT FOUND IN PROCESS TABLE!!!\n"
        fi
    elif [ -s ${MinerShell}.ppid ]; then
        MinerShell_pid=$(< ${MinerShell}.ppid)
        printf "MinerShell ${MinerShell}.sh mit PID ${MinerShell_pid} wurde bereits beendet. Nur noch Datei .ppid übrig geblieben."
    fi

    rm -f .DO_AUTO_BENCHMARK_FOR
    for algorithm in ${!DO_AUTO_BENCHMARK_FOR[@]}; do
        echo ${algorithm} >>.DO_AUTO_BENCHMARK_FOR
    done
    [ $debug -eq 1 ] && [ -s .DO_AUTO_BENCHMARK_FOR ] && cat .DO_AUTO_BENCHMARK_FOR
    
    rm -f ${MinerShell}.ppid ${MinerShell}.sh .now_$$ *.lock \
       ${This}.pid

}
trap _On_Exit EXIT # == SIGTERM == TERM == -15

# Die Quelldaten Miner- bzw. AlgoName, BenchmarkSpeed und WATT für diese GraKa
#  6. Prüft, ob die Benchmarkdatei jemals bearbeitet wurde und bricht ab, wenn nicht.
#     Dann gibt es nämlich keine Benchmark- und Wattangaben zu den einzelnen Algorithmen.
# (25.12.2017) Das wird wohl hinfällig, weil wir das System so planen, dass es auch ohne Objekte in der JSON Datei
#     hochfährt und selbst das Benchmarking startet, um Werte hineinzubekommen.
# Kann irgendwann ganz rausgelöscht werden, wenn die Erfahrung zeigt, dass auch so alles funktioniert.
if [ 1 -eq 0 ]; then
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
        exit 1
    fi
fi
gpu_uuid="${GPU_DIR}"
IMPORTANT_BENCHMARK_JSON="benchmark_${gpu_uuid}.json"

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
_read_IMPORTANT_BENCHMARK_JSON_in  # without_miners Muss AUF JEDEN FALL die Miner beachten.

###############################################################################
#
# Die Funktionen zum Einlesen und Verarbeiten der aktuellen Algos und Kurse
#
#
#
######################################

# 10. Definiert _read_in_ALGO_PORTS_KURSE(), welches die Datei "../KURSE_PORTS.in" in das Array KURSE["AlgoName"] aufnimmt.
#     Das Alter dieser Datei ist unwichtig, weil sie IMMER durch algo_multi_abfrage.sh aus dem Web aktualisiert wird.
#     Andere müssen dafür sorgen, dass die Daten in dieser Datei gültig sind!
[[ ${#_ALGOINFOS_INCLUDED} -eq 0 ]]   && source ${LINUX_MULTI_MINING_ROOT}/algo_infos.inc
[[ ${#_NVIDIACMD_INCLUDED} -eq 0 ]]   && source ${LINUX_MULTI_MINING_ROOT}/benchmarking/nvidia-befehle/nvidia-query.inc
[[ ${#_GPU_ABFRAGE_INCLUDED} -eq 0 ]] && source ${LINUX_MULTI_MINING_ROOT}/gpu-abfrage.inc

if [ -z "${defPowLim[${gpu_idx}]}" ]; then
    _reserve_and_lock_file ${SYSTEM_STATE}                   # Zum Lesen reservieren
    _read_in_SYSTEM_FILE_and_SYSTEM_STATEin
    _remove_lock                                             # ... und wieder freigeben
fi

# 10.1. GANZ WICHTIG immer nach der GPU-Abfrage und nach dem Setzen von ALLE_MINER (um letzteres kümmert sich die Funktion selbst):
#       Seit Ende 2017 die Trennung von gpu_idx und miner_dev. In einem Assoziativen Array vorgehalten,
#       das bei jedem Start und dann bei jeder Änderung wieder upgedatet werden muss
_set_Miner_Device_to_Nvidia_GpuIdx_maps
_set_ALLE_LIVE_MINER

# 10.2. Alle Miner-Arrays setzen wie ALLE_MINER[i], MINER_FEES[ miningAlgo ], Miner_${MINER}_Algos[ ${coin} ] etc.
#       Im Moment begnügen wir uns damit, VOR der Endlosschleife alle Arrays zu setzen.
# ---> Muss in die Endlosschleife verlegt werden, wenn die Coins im laufenden Betrieb hinzugefügt werden             <---
# ---> Wir müssen einen Trigger entwickeln, der uns in der Endlosschleife sagt, dass die Arrays neu einzulesen sind. <---
# Ab hier sind jedenfalls die Coin/miningAlgo-Informationen MinerFees gültig
_read_in_ALL_Mining_Available_and_Missing_Miner_Algo_Arrays

# 10.3. Alle fehlenden Pool-Infos setzen wie Coin, ServerName und Port
# Ab hier sind die folgenden Informationen in den Arrays verfügbar
#    actCoinsOfPool="CoinsOfPool_${pool}"
#    actServerNameOfPool="ServerNameOfPool_${pool}"
#    actPortsOfPool="PortsOfPool_${pool}"
_read_in_static_COIN_MININGALGO_SERVERNAME_PORT_from_Pool_Info_Array

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
#     Es hat sich gezeigt, dass es Fälle gibt, in denen das SYNCFILE überholt hat...
#     oder wenn die GPU im Laufenden Betrieb beendet werden musste und vom MultiMiner deswegen neu gestartet wird,
#     wenn dieser seinerseits vom Anfang seiner Endlosschleife losgeht und in Richtung ALGO_WATTS_MINES.in läuft
#     Auch dieser kann "überholt" worden sein und seinerseits selbst checken, was das für seine eigene Rolle bedeutet
#     und was für Auswirkungen das auf die anderen Prozesse hat.
_progressbar='\r'
while [ ! -f ${SYNCFILE} ]; do
    [[ "${_progressbar}" == "\r" ]] && echo "GPU #${gpu_idx}: ###---> Waiting for ${SYNCFILE} to become available..."
    _progressbar+='.'
    if [[ ${#_progressbar} -gt 75 ]]; then
        printf '\r                                                                            '
        _progressbar='\r.'
    fi
    printf ${_progressbar}
    sleep .5
done
[[ "${_progressbar}" != "\r" ]] && printf "\n"

# Neu:
read new_Data_available SynFrac <<<$(_get_file_modified_time_ ${SYNCFILE})

###############################################################################
#
#     ENDLOSSCHLEIFE START
#
#
# 14. EINTRITT IN DIE ENDLOSSCHLEIFE. Die folgenden Aktionen werden immer und immer wieder durchgeführt,
#                                     solange dieser Prozess läuft.
while :; do
    
    echo ""
    echo $(date "+%Y-%m-%d %H:%M:%S" ) $(date +%s)
    echo "GPU #${gpu_idx}: ###########################---> Anfang der Endlosschleife <---###########################"

    # If there is a newer version of this script, update it before the next run
    #  1. Ruft _update_SELF_if_necessary
    _update_SELF_if_necessary

    # new_Data_available wurde direkt vor der Endlosschleife gesetzt oder gleich nach dem Herausfallen ganz unten
    # Wie alt das SYNCFILE maximal sein darf steht in der Variablen ${GPU_alive_delay}, in globals.inc gesetzt.
    SynSecs=$((${new_Data_available}+${GPU_alive_delay}))
    touch .now_$$
    read NOWSECS nowFrac <<<$(_get_file_modified_time_ .now_$$)
    rm -f .now_$$ ..now_$$.lock
    if [[ ${NOWSECS} -le ${SynSecs} || (${NOWSECS} -eq ${SynSecs} && ${nowFrac} -le ${SynFrac}) ]]; then

        # (2018-01-23) Bisher konnten wir darauf verzichten.
        #_reserve_and_lock_file ${_WORKDIR_}/${GPU_ALIVE_FLAG}
        #echo "GPU #${gpu_idx}: ${NOWSECS}.${nowFrac} I recognized a newly written SYNCFILE and am willing to deliver data." \
        #    | tee ${_WORKDIR_}/${GPU_ALIVE_FLAG}
        #_remove_lock

        # Ist die Benchmarkdatei mit einer aktuellen Version überschrieben worden?
        #  2. Ruft _read_IMPORTANT_BENCHMARK_JSON_in falls die Quelldatei upgedated wurde.
        #                             => Aktuelle Arrays bENCH["AlgoName"] und WATTS["AlgoName"]
        if [[ $IMPORTANT_BENCHMARK_JSON_last_age_in_seconds < $(date --utc --reference=$IMPORTANT_BENCHMARK_JSON +%s) ]]; then
            echo "GPU #${gpu_idx}: ###---> Updating Arrays bENCH[] and WATTs[] (and more) from $IMPORTANT_BENCHMARK_JSON"
            _read_IMPORTANT_BENCHMARK_JSON_in # without_miners
        fi

        # Die Reihenfolge der Dateierstellungen durch ../algo_multi_abfrage.sh ist:
        # (21.11.2017)
        # Wir wissen jetzt, dass alle relevanten Werte in der "simplemultialgo"-api Abfrage enthalten sind
        #     und brauchen die ../ALGO_NAMES.in überhaupt nicht mehr.
        #     Das folgende kann raus und es ergibt sich eine neue Reihenfolge:
        #     1.: $algoID_KURSE_PORTS_WEB und $algoID_KURSE_PORTS_ARR
        #     2.: ../BTC_EUR_kurs.in
        # Letzte: ${SYNCFILE}

        # Wenn es noch keine ${RUNNING_STATE} gibt, wurde das Gesamtsystem vor Kurzem gestartet und multi_mining_calc wartet erst mal auf die
        #      Ergnisse aller gpu_gv-algo.sh's, welche ihrerseits erst mal auf gültige Daten von algo_multi_abfrage.sh warten.
        # Nachdem die Ergebnisse aller gpu_gv-algo.sh's geschrieben sind, führt multi_mining_calc.sh die neue Systemberechnung
        #      durch und schreibt die Anweisungen in die Datei ${RUNNING_STATE}.
        # Wir warten weiter unten auf genau diesen Augenblick, in dem die ${RUNNING_STATE} neu geschrieben ist und lesen sie ein.
        # Daraus folgt, dass:
        #      Wenn an dieser Stelle eine ${RUNNING_STATE} vorhanden ist, haben wir die Werte bereits im letzten Schleifendurchgang
        #      in den Arbeitspeicher geladen und eine MinerShell gestartet.
        # Die wichtigsten Variablen dieses Einlesevorgangs weiter unten veralten bald und müssen deshalb hier festgehalten werden,
        #      damit wir eine eventuell laufende MinerShell auch stoppen können, falls es nötig sein sollte.
        #
        # Es ist also eigentlich nicht nötig, die ${RUNNING_STATE} nochmal einzulesen.
        # ES SEI DENN... Was, wenn ein paar Schleifen ausgelassen wurden wegen GPU disabled, z.B.?
        #                Oder wenn kein neuer Algo angegeben war und deshalb keine MinerShell zu starten war?
        #                Wir lassen es also im Moment dabei und warten darauf, dass wir alles tiefer durchblicken.
        #                Es kann gut sein, dass mathematisch nachgewiesen werden kann, dass die Variablen (auch ${MinerShell}) ihre Gültigkeit
        #                behalten und die ${RUNNING_STATE} tatsächlich nicht neu eingelesen werden muss.
        # 
        # Da die Datei ${RUNNING_STATE} erst wieder geschrieben wird, nachdem die ALG_WATTS_MINES.in Berechnungen hier abgeliefert worden sind,
        # sperren wir sie mal NICHT zum Lesen, weil gleichzeitiges Lesen kein Problem verursachen sollte.
        unset IamEnabled MyActWatts RuningAlgo
        _reserve_and_lock_file ${RUNNING_STATE}  # Zum Lesen reservieren...
        _read_in_actual_RUNNING_STATE            # ... einlesen...
        _remove_lock                             # ... und wieder freigeben

        if [ ${#RunningGPUid[${gpu_uuid}]} -gt 0 ]; then
            echo "GPU #${gpu_idx}: Alter bzw. bisheriger RUNNING_STATE eingelesen."
            [[ "${RunningGPUid[${gpu_uuid}]}" != "${gpu_idx}" ]] \
                && echo "Konsistenzcheck FEHLGESCHLAGEN!!! GPU-Idx aus RUNNING_STATE anders als er sein soll !!!"
            IamEnabled=${WasItEnabled[${gpu_uuid}]}
            MyActWatts=${RunningWatts[${gpu_uuid}]}
            RuningAlgo=${WhatsRunning[${gpu_uuid}]}
        fi

        if [ $debug -eq 1 ]; then
            echo $(date "+%Y-%m-%d %H:%M:%S" ) $(date +%s)
            echo "GPU #${gpu_idx}: Einlesen und verarbeiten der aktuellen Kurse, sobald die Datei vorhanden und nicht leer ist"
        fi

        #  4. ###WARTET### jetzt, bis die Dateien zur Berechnung der Kurse vorhanden und NICHT LEER SIND und
        #  5. Ruft die entsprechenden Funktionen zum Füllen der Arrays, die für die Berechnungen benötigt werden
        unset wasThere
        for pool in ${!POOLS[@]}; do
            case ${pool} in

                "nh")
                    if [ ${PoolActive[${pool}]} -eq 1 ]; then
                        #  4. ###WARTET### jetzt, bis die Datei "../KURSE_PORTS.in" vorhanden und NICHT LEER ist.
                        until [ -s ${algoID_KURSE_PORTS_ARR} ]; do
                            echo "GPU #${gpu_idx}: ###---> Waiting for ${algoID_KURSE_PORTS_ARR} to become available..."
                            sleep .5
                        done
                        #  5. Ruft _read_in_ALGO_PORTS_KURSE
                        #      => Array KURSE["AlgoName"] verfügbar
                        #      => Array PORTS["AlgoName"] verfügbar
                        #      => Array ALGOs["Algo_IDs"] verfügbar
                        #      => Array ALGO_IDs["AlgoName"] verfügbar
                        _read_in_ALGO_PORTS_KURSE
                    fi
                    ;;

                "mh"|"sn")
                    if [ ${PoolActive[${pool}]} -eq 1 ]; then
                        if [ ${#wasThere} -gt 0 ]; then
                            until [ -s "${COIN_PRICING_ARR}" -a -s "${COIN_TO_BTC_EXCHANGE_ARR}" ]; do
                                echo "GPU #${gpu_idx}: ###---> Waiting for ${COIN_PRICING_ARR} and ${COIN_TO_BTC_EXCHANGE_ARR} to become available..."
                                sleep .5
                            done
                            # 5. Füllt die Arrays, die für die Coin-Berechnung erforderlich sind.
                            #      => Array CoinNames
                            #      => Array COINS
                            #      => Array COIN_IDs
                            #      => Array CoinAlgo
                            #      => Array BlockTime
                            #      => Array BlockReward
                            #      => Array CoinHash
                            _read_in_COIN_PRICING
                            #      => Array Coin2BTC_factor[$coin]
                            _read_in_COIN_TO_BTC_EXCHANGE_FACTOR
                        else wasThere=1; fi
                    fi
                    ;;
            esac
        done

        ###############################################################################
        #
        #    Ermittlung aller Algos, die zu Enablen sind und die Algos, die Disabled sind.
        #
        ######################################

        unset MINER_ALGO_DISABLED_ARR MINER_ALGO_DISABLED_DAT
        declare -Ag MINER_ALGO_DISABLED_ARR MINER_ALGO_DISABLED_DAT
        _reserve_and_lock_file ../MINER_ALGO_DISABLED_HISTORY
        nowDate=$(date "+%Y-%m-%d %H:%M:%S" )
        declare -i nowSecs=$(date +%s)
        if [ -s ../MINER_ALGO_DISABLED ]; then
            if [ $debug -eq 1 ]; then echo "Reading ../MINER_ALGO_DISABLED ..."; fi
            declare -i timestamp
            unset READARR
            readarray -n 0 -O 0 -t READARR <../MINER_ALGO_DISABLED
            for ((i=0; $i<${#READARR[@]}; i++)) ; do
                read _date_ _oclock_ timestamp coin_algorithm <<<${READARR[$i]}
                MINER_ALGO_DISABLED_ARR[${coin_algorithm}]=${timestamp}
                MINER_ALGO_DISABLED_DAT[${coin_algorithm}]="${_date_} ${_oclock_}"
            done
            # Jetzt sind die Algorithm's unique und wir prüfen nun, ob welche dabei sind,
            # die wieder zu ENABLEN sind, bzw. die aus dem Disabled_ARR verschwinden müssen,
            # bevor wir die Datei neu schreiben.
            for coin_algorithm in "${!MINER_ALGO_DISABLED_ARR[@]}"; do
                if [ ${nowSecs} -gt $(( ${MINER_ALGO_DISABLED_ARR[${coin_algorithm}]} + 300 )) ]; then
                    # Der Algo ist wieder einzuschalten
                    unset MINER_ALGO_DISABLED_ARR[${coin_algorithm}]
                    unset MINER_ALGO_DISABLED_DAT[${coin_algorithm}]
                    printf "ENABLED ${nowDate} ${nowSecs} ${coin_algorithm}\n" | tee -a ../MINER_ALGO_DISABLED_HISTORY
                fi
            done
            # Weg mit dem bisherigen File...
            mv -f ../MINER_ALGO_DISABLED ../MINER_ALGO_DISABLED.BAK
            # ... und anlegen eines Neuen, wenn noch Algos im Array sind
            for coin_algorithm in "${!MINER_ALGO_DISABLED_ARR[@]}"; do
                # Die eingelesenen Werte wieder ausgeben
                printf "${MINER_ALGO_DISABLED_DAT[${coin_algorithm}]} ${MINER_ALGO_DISABLED_ARR[${coin_algorithm}]} ${coin_algorithm}\n" >>../MINER_ALGO_DISABLED
            done
        fi
        _remove_lock                                     # ... und wieder freigeben

        #    Zusätzlich die über BENCH_ALGO_DISABLED Algos rausnehmen...
        unset BENCH_ALGO_DISABLED_ARR BENCH_ALGO_DISABLED_ARR_in
        declare -a BENCH_ALGO_DISABLED_ARR
        _reserve_and_lock_file ../BENCH_ALGO_DISABLED
        if [ -s ../BENCH_ALGO_DISABLED ]; then
            cat ../BENCH_ALGO_DISABLED | grep -E -v -e '^#|^$' | readarray -n 0 -O 0 -t BENCH_ALGO_DISABLED_ARR_in

            # Erwartet werden weiter unten nur die $algorithm's in diesem Array, das wir jetzt neu erstellen
            for actRow in "${BENCH_ALGO_DISABLED_ARR_in[@]}"; do
                read _date_ _oclock_ timestamp gpuIdx lfdAlgorithm Reason <<<${actRow}
                [ ${gpuIdx#0} -eq ${gpu_idx} ] && BENCH_ALGO_DISABLED_ARR+=( ${lfdAlgorithm} )
            done
        fi
        _remove_lock                                     # ... und wieder freigeben
        [ $debug -eq 1 -a ${#BENCH_ALGO_DISABLED_ARR[@]} -gt 0 ] && declare -p BENCH_ALGO_DISABLED_ARR

        #    Zusätzlich die über GLOBAL_ALGO_DISABLED Algos rausnehmen...
        unset GLOBAL_ALGO_DISABLED_ARR
        _reserve_and_lock_file ../GLOBAL_ALGO_DISABLED
        if [ -s ../GLOBAL_ALGO_DISABLED ]; then
            cat ../GLOBAL_ALGO_DISABLED | grep -E -v -e '^#|^$' | readarray -n 0 -O 0 -t GLOBAL_ALGO_DISABLED_ARR

            if [ $debug -eq 1 ]; then
                echo "GPU #${gpu_idx}: Vor  der Prüfung: GLOBAL_ALGO_DISABLED_ARRAY hat ${#GLOBAL_ALGO_DISABLED_ARR[@]} Einträge"
                declare -p GLOBAL_ALGO_DISABLED_ARR
            fi
            for ((i=0; $i<${#GLOBAL_ALGO_DISABLED_ARR[@]}; i++)) ; do
                unset disabled_algos_GPUs
                read -a disabled_algos_GPUs <<<${GLOBAL_ALGO_DISABLED_ARR[$i]//:/ }
                if [ ${#disabled_algos_GPUs[@]} -gt 1 ]; then
                    # Nur für bestimmte GPUs disabled. Wenn die eigene GPU nicht aufgeführt ist, übergehen
                    REGEXPAT="^.*:${gpu_uuid}\b"
                    if [[ ${GLOBAL_ALGO_DISABLED_ARR[$i]} =~ ${REGEXPAT} ]]; then
                        GLOBAL_ALGO_DISABLED_ARR[$i]=${disabled_algos_GPUs[0]}
                    else
                        unset GLOBAL_ALGO_DISABLED_ARR[$i]
                    fi
                fi
            done
            if [ $debug -eq 1 ]; then
                echo "GPU #${gpu_idx}: Nach der Prüfung: GLOBAL_ALGO_DISABLED_ARRAY hat ${#GLOBAL_ALGO_DISABLED_ARR[@]} Einträge"
                declare -p GLOBAL_ALGO_DISABLED_ARR
            fi
        fi
        _remove_lock                                     # ... und wieder freigeben

        # Mal sehen, ob es überhaupt schon Benchmarkwerte gibt oder ob Benchmarks nachzuholen sind.
        # Erst mal alle MiningAlgos ermitteln, die möglich sind und gegen die vorhandenen JSON Einträge checken.
        _set_Miner_Device_to_Nvidia_GpuIdx_maps
        _set_ALLE_LIVE_MINER
        _read_in_ALL_Mining_Available_and_Missing_Miner_Algo_Arrays
        _read_in_static_COIN_MININGALGO_SERVERNAME_PORT_from_Pool_Info_Array

        # Gibt es MissingAlgos, ziehen wir die Disabled Algos noch davon ab
        unset ALL_MISSING_ALGORITHMs I_want_to_Disable_myself_for_AutoBenchmarking
        declare -a ALL_MISSING_ALGORITHMs
        for minerName in "${ALLE_MINER[@]}"; do
            read m_name m_version <<<"${minerName//#/ }"
            declare -n   actMissingAlgos="Missing_${m_name}_${m_version//\./_}_Algos"
            #echo ${!actMissingAlgos}

            for actAlgo in ${!actMissingAlgos[@]}; do
                miningAlgo=${actMissingAlgos[$actAlgo]}
                algorithm="${miningAlgo}#${m_name}#${m_version}"
                if [[ "${#GLOBAL_ALGO_DISABLED_ARR[@]}" -gt 0 ]]; then
                    REGEXPAT="\b${miningAlgo}\b"
                    [[ "${GLOBAL_ALGO_DISABLED_ARR[@]}" =~ ${REGEXPAT}  ]] && continue
                fi
                if [[ "${#BENCH_ALGO_DISABLED_ARR[@]}" -gt 0 ]]; then
                    REGEXPAT="\b${algorithm}\b"
                    [[ "${BENCH_ALGO_DISABLED_ARR[@]}"  =~ ${REGEXPAT} ]] && continue
                fi
                ALL_MISSING_ALGORITHMs+=( ${algorithm} )
            done
        done

        if [ ${#ALL_MISSING_ALGORITHMs[@]} -gt 0 ]; then
            I_want_to_Disable_myself_for_AutoBenchmarking=1
            if [ ${debug} -eq 1 ]; then
                echo "GPU #${gpu_idx}: Anzahl vermisster Algos: ${#ALL_MISSING_ALGORITHMs[@]} DisableMyself: ->$I_want_to_Disable_myself_for_AutoBenchmarking<-"
                declare -p ALL_MISSING_ALGORITHMs
            fi
        fi

        ###############################################################################
        #
        #    Berechnung und Ausgabe ALLER (Enabled und bezahlten) AlgoNames, Watts und Mines für die Multi_mining_calc.sh
        #
        ######################################

        # Zur sichereren Synchronisation, dass der multi_mining_calc.sh erst dann die Datei ALGO_WATTS_MINES
        # einliest, wenn sie auch komplett ist und geschlossen wurde.

        #  6. Berechnet jetzt die "Mines" in BTC und schreibt die folgenden Angaben in die Datei ALGO_WATTS_MINES.in :
        #               AlgoName
        #               Watt
        #               BTC "Mines"
        #     sofern diese Daten tatsächlich vorhanden sind.
        #     Algorithmen mit fehlenden Benchmark- oder Wattangaben, etc. werden NICHT beachtet.
        #

        rm -f .ALGO_WATTS_MINES.in
        for algorithm in "${!bENCH[@]}"; do

            # Manche Algos kommen erst gar nicht in die Datei rein, z.B. wenn sie DISABLED wurden
            # oder wenn gerade nichts dafür bezahlt wird.

            # Wenn der Algo durch BENCHMARKING PERMANENT Disabled ist, übergehen:
            for lfdAlgorithm in ${BENCH_ALGO_DISABLED_ARR[@]}; do
                [[ "${algorithm%#888}" == "${lfdAlgorithm}" ]] && continue 2
            done
            # Wenn der Algo GLOBAL Disabled ist, übergehen:
            for lfdAlgorithm in ${GLOBAL_ALGO_DISABLED_ARR[@]}; do
                [[ ${algorithm} =~ ^${lfdAlgorithm} ]] && continue 2
            done

            read miningAlgo miner_name miner_version muck888 <<<${algorithm//#/ }
            MINER=${miner_name}#${miner_version}
            [ ${#ALLE_LIVE_MINER[${MINER}]} -eq 0 ] && continue

            declare -n actCoinsPoolsOfMiningAlgo="CoinsPoolsOfMiningAlgo_${miningAlgo//-/_}"
            [ $debug -eq 1 ] && (echo ${actCoinsPoolsOfMiningAlgo[@]} | tr ' ' '\n' >.${!actCoinsPoolsOfMiningAlgo})

            unset      coin_algorithm_Calculated
            declare -A coin_algorithm_Calculated
            for c_p_sn_p in ${actCoinsPoolsOfMiningAlgo[@]}; do

                read coin pool server_name algo_port <<<${c_p_sn_p//#/ }
                coin_pool="${coin}#${pool}"
                coin_algorithm="${coin_pool}#${miningAlgo}#${MINER}"

                # Wenn der coin#pool#miningAlgo#miner_name#miner_version für 5 Minuten Disabled ist, übergehen:
                [[ ${#MINER_ALGO_DISABLED_ARR[${coin_algorithm%#888}]} -ne 0 ]] && continue 2

                coin_algorithm+=$( [[ -n "${muck888}" ]] && echo "#${muck888}" )
                # Da ${coin_pool} nicht unique ist wg. evtl. mehrerer Server-Ports, beachten wir jeweils nur das erste Vorkommen.
                [ -z "${coin_algorithm_Calculated[${coin_pool}]}" ] && coin_algorithm_Calculated[${coin_pool}]=1 || continue

                REGEXPAT="\b${coin}\b"
                case "${pool}" in

                    "nh")
                        if [ ${PoolActive[${pool}]} -eq 1 ]; then
                            if [[ "${ALGOs[@]}" =~ ${REGEXPAT} ]]; then
                                # Wenn gerade nichts für den Algo bezahlt wird, übergehen:
                                [[ "${KURSE[${coin}]}" == "0" ]] && continue

                                if [[          ${#bENCH[${algorithm}]}  -gt    0 \
                                            && ${#KURSE[${coin}]}       -gt    0 \
                                            && ${#PoolFee[${pool}]}     -gt    0 \
                                            && ${#MINER_FEES[${MINER}]} -gt    0 \
                                            && ${WATTS[${algorithm}]}   -lt 1000 \
                                    ]]; then
                                    # "Mines" in BTC berechnen
                                    algoMines=$(echo "scale=8;   ${bENCH[${algorithm}]}  \
                                                           * ${KURSE[${coin}]}  \
                                                           / ${k_base}^3  \
                                                           * ( 100 - "${PoolFee[${pool}]}" )     \
                                                           * ( 100 - "${MINER_FEES[${MINER}]}" ) \
                                                           / 10000
                                             " \
                                                       | bc )
                                    # Wenn gerade nichts für den Algo bezahlt wird, übergehen:
                                    _octal_=${algoMines//\.}
                                    _octal_=${_octal_//0}
                                    [[ ${#_octal_} -gt 0 ]] \
                                        && printf "${coin_algorithm} ${WATTS[${algorithm}]} ${algoMines}\n" >>.ALGO_WATTS_MINES.in
                                else
                                    echo "GPU #${gpu_idx}: KEINE BTC \"Mines\" BERECHNUNG möglich bei \"nh\" ${coin_algorithm} !!! \<---------------"
                                    DO_AUTO_BENCHMARK_FOR["${algorithm}"]=1
                                fi
                            fi
                        fi
                        ;;

                    "mh"|"sn")
                        if [ ${PoolActive[${pool}]} -eq 1 ]; then
                            if [[ "${COINS[@]}" =~ ${REGEXPAT} ]]; then
                                if [[          ${#bENCH[${algorithm}]}      -gt    0 \
                                            && ${#BlockReward[${coin}]}     -gt    0 \
                                            && ${#BlockTime[${coin}]}       -gt    0 \
                                            && ${#CoinHash[${coin}]}        -gt    0 \
                                            && ${#Coin2BTC_factor[${coin}]} -gt    0 \
                                            && ${#PoolFee[${pool}]}         -gt    0 \
                                            && ${#MINER_FEES[${MINER}]}     -gt    0 \
                                            && ${WATTS[${algorithm}]}       -lt 1000 \
                                    ]]; then
                                    # "Mines" in BTC berechnen
                                    algoMines=$(echo "scale=8;   86400 * ${BlockReward[${coin}]} * ${Coin2BTC_factor[${coin}]}   \
                                                           / ( ${BlockTime[${coin}]} * (1 + ${CoinHash[${coin}]} / ${bENCH[${algorithm}]}) ) \
                                                           * ( 100 - "${PoolFee[${pool}]}" )     \
                                                           * ( 100 - "${MINER_FEES[${MINER}]}" ) \
                                                           / 10000
                                             " \
                                                       | bc )
                                    # Wenn gerade nichts für den Algo bezahlt wird, übergehen:
                                    _octal_=${algoMines//\.}
                                    _octal_=${_octal_//0}
                                    [[ ${#_octal_} -gt 0 ]] \
                                        && printf "${coin_algorithm} ${WATTS[${algorithm}]} ${algoMines}\n" >>.ALGO_WATTS_MINES.in
                                else
                                    echo "GPU #${gpu_idx}: KEINE BTC \"Mines\" BERECHNUNG möglich bei \"sn\" ${coin_algorithm} !!! \<---------------"
                                    DO_AUTO_BENCHMARK_FOR["${algorithm}"]=1
                                fi
                            fi
                        fi
                        ;;
                esac
            done
        done

        DataWorth="Valid Data"
        if [ -s .ALGO_WATTS_MINES.in ]; then
            sort -n -r -k3 .ALGO_WATTS_MINES.in >.ALGO_WATTS_MINES.out
            cat .ALGO_WATTS_MINES.out \
                | tr ' ' '\n' \
                     >ALGO_WATTS_MINES.in
        else
            touch ALGO_WATTS_MINES.in
            DataWorth="EMPTY DATA"
        fi
        _reserve_and_lock_file ${_WORKDIR_}/${GPU_VALID_FLAG}
        touch ${_WORKDIR_}/${GPU_VALID_FLAG}
        _remove_lock
        read ValSecs ValFrac <<<$(_get_file_modified_time_ ${_WORKDIR_}/${GPU_VALID_FLAG})
        echo "GPU #${gpu_idx}: ${ValSecs}.${ValFrac} ${DataWorth} are now UNLOCKED in ALGO_WATTS_MINES.in"

        #############################################################################
        #############################################################################
        #
        #  7. Die Daten für multi_mining_calc.sh sind nun vollständig verfügbar.
        #     Es ist jetzt erst mal die Berechnung durch multi_mining_calc.sh abzuwarten, um wissen zu können,
        #     ob diese GPU ein- oder ausgeschaltet werden soll.
        #     Vielleicht können wir das sogar hier drin tun, nachdem das Ergebnis für diese GPU feststeht ???
        #
        #############################################################################
        #############################################################################


        # multi_mining_calc.sh rechnet...


        #############################################################################
        #############################################################################
        #
        #  8. Wenn multi_mining_calc.sh mit den Berechnungen fertig ist, schreibt sie die Datei ${RUNNING_STATE},
        #     in der die neue Konfigurationdrin steht, WIE ES AB JETZT ZU SEIN HAT.
        #     Aus dieser Datei entnimmt jede GPU nun die Information, die für sie bestimmt ist und stoppt und startet
        #     die entsprechenden MinerShells.
        #
        #     Eine MinerShell ist nicht der Miner selbst, sondern ein .sh Script, das den übergebenen Miner
        #          sowie ein Terminalfenster mit seiner Logdatei startet.
        #     Die MinerShell hat jetzt die alleinige Verantwortung, diesen Miner so lange wie möglich laufen zu lassen.
        #          Ein Abbruch erfolgt von hier aus, von "aussen", sozusagen, es sei denn...
        #
        #     Die MinerShell überwacht dabei selbst das Miner-Logfile, um Unregelmäßigkeiten zu entdecken
        #          und entsprechend darauf zu reagieren, z.B.:
        #          - Verbindungsaufbau oder -abbruch zu NiceHash Server bedeutet: "continent" wechseln
        #            und beobachten, ob dann was geht (beim Aufbau innerhalb der ersten 5 Sekunden)
        #            ODER ob der Miner abzubrechen ist und weitere Maßnahmen ergriffen werden müssen,
        #            wie z.B. den Algo für diesen Miner vorübergehend DISABLEN ???   <--------------------------------
        #          - 90s ohne einen Hashwert bedeutet auch, dass etwas mit dem Algo nicht stimmt.
        #          - zu viele booooos und rejects (10 Aufeinanderfolgende) zeigen auch, dass mit dem Algo was nicht stimmt.
        #          - to be continued...
        #
        #     Miner, die noch laufen, müssen beendet werden, wenn ein neuer Miner gestartet werden soll.
        #     Nach jedem Minerstart merkt sich die GPU in dem File ${MinerShell}.ppid die gestartete MinerShell
        #          und kann sie so beenden.
        #     Ein Abbruch der MinerShell beendet ihrerseits die zwei von ihr gestarteten Prozesse Miner und Log-Terminal
        #
        #############################################################################
        #############################################################################
        echo "GPU #${gpu_idx}: Waiting for new RUNNING_STATE to get orders..."
        # Das haben wir weiter oben gemacht, nachdem wir die Valid-Datei geschrieben haben.
        #read ValSecs ValFrac <<<$(_get_file_modified_time_ ${_WORKDIR_}/${GPU_VALID_FLAG})
        # RUNNING_STATE muss nun älter sein als diese unsere Datei, die den MM veranlasst haben, auszuwerten und RUNNING_STATE zu schreiben.
        read RunSecs  RunFrac  <<<$(_get_file_modified_time_ ${RUNNING_STATE})
        until [[ ${ValSecs} -le ${RunSecs} || (${ValSecs} -eq ${RunSecs} && ${ValFrac} -le ${RunFrac}) ]]; do
            # Eine Hundertstel Sekunde länger warten, je höher der GPU-Index ist,
            # damit nicht alle gleichzeitig losrennen, wenn die Ergebnisse da sind
            sleep .$(( 50 + ${gpu_idx} ))
            read RunSecs  RunFrac  <<<$(_get_file_modified_time_ ${RUNNING_STATE})
        done

        #
        # ... multi_mining_calc.sh ist mit den Berechnungen fertig, das Ergebnis ist in ${RUNNING_STATE}
        #
        if [ $verbose -eq 1 -o $debug -eq 1 ]; then
            echo $(date "+%Y-%m-%d %H:%M:%S" ) $(date +%s)
            echo "GPU #${gpu_idx}: Einlesen des NEUEN nun einzustellenden ${RUNNING_STATE} und erfahren, was GPU #${gpu_idx} zu tun hat..."
        fi
        echo $(date "+%Y-%m-%d %H:%M:%S" ) $(date +%s) "RUNNING_STATE there now, going to fetch orders..."
        # Da NUR die multi_mining_calc.sh diese Datei schreibt und da die Datei länger nicht mehr geschrieben wird,
        # brauchen wir sie hier auch nicht zum Lesen reservieren.
        # GLEICHZEITIGES LESEN SOLLTE KEIN PROBLEM DARSTELLEN.
        _reserve_and_lock_file ${RUNNING_STATE}  # Zum Lesen reservieren...
        _read_in_actual_RUNNING_STATE            # ... einlesen...
        _remove_lock                             # ... und wieder freigeben

        # Wir löschen die ausgewerteten Daten, nachdem wir die Auswertung eingelesen haben
        # und heben sie uns für debug-Zwecke als BAK-Datei auf
        mv -f ALGO_WATTS_MINES.in ALGO_WATTS_MINES.in.BAK

        unset Ja_der_Miner_laeuft_und_soll_auch_weiterlaufen
        StartMiner=0
        [ $debug -eq 1 ] && echo "\${RunningGPUid[${gpu_uuid}]}: --->${RunningGPUid[${gpu_uuid}]}<---"
        [[ "${RunningGPUid[${gpu_uuid}]}" != "${gpu_idx}" ]] \
            && exit $(echo "---> RUNTIME-PANIC: Konsistenzcheck FEHLGESCHLAGEN!!! GPU-Idx aus RUNNING_STATE anders als er sein soll !!!")
        if [ -n "${IamEnabled}" ]; then
            echo "GPU #${gpu_idx}: Have to look whether to stop a miner and start another or let him run..."
            if [ ${IamEnabled} -eq 1 ]; then
                # echo "GPU #${gpu_idx}: Maybe something to stop first..."
                if [ "${WasItEnabled[${gpu_uuid}]}" == "1" ]; then
                    if [ -n "${RuningAlgo}" ]; then

                        read coin pool miningAlgo miner_name miner_version muck888 <<<${RuningAlgo//#/ }
                        MINER=${miner_name}#${miner_version}
                        coin_pool="${coin}#${pool}"
                        coin_algorithm="${coin_pool}#${miningAlgo}#${MINER}"

                        if [ "${RuningAlgo}" != "${WhatsRunning[${gpu_uuid}]}" ]; then

                            StopShell=${miner_name}_${miner_version}_${coin}_${pool}_${miningAlgo}$( [[ ${#muck888} -gt 0 ]] && echo _${muck888} )
                            printf "GPU #${gpu_idx}: STOPPING MinerShell ${StopShell}.sh with Coin/Algo ${RuningAlgo}..."

                            if [ -f ${StopShell}.ppid ]; then
                                if [ -f ${StopShell}.pid ]; then
                                    kill $(< ${StopShell}.ppid)
                                    sleep $Erholung                                           # Damit sich die Karte "erholen" kann.
                                    printf "done.\n"
                                else
                                    printf "\nGPU #${gpu_idx}: OOOooops... Process ${StopShell}.sh ist weg. "
                                    printf "Möglicherweise hat er den Algo ${coin_algorithm} DISABLED.\n"
                                fi
                            else
                                printf "\n\n"
                                echo "OOOooops... MinerShell File ${StopShell}.ppid already gone. Das darf eigentlich nicht passieren!"
                                echo "In dieser Datei hat die ${This}.sh die Process-ID der MinerShell ${StopShell}.sh gespeichert,"
                                echo "unmittelbar nachdem die Minershell ${StopShell}.sh in den Hintergrund geschickt wurde."
                                echo "Ja, es ist wahr, die MinerShell speichert die selbe Prozess-ID ebenfalls und es gibt also zwei Dateien"
                                echo "mit dem selben Inhalt und den Endungen .ppid bzw. .pid"
                                echo "Trotzdem darf die .ppid nicht so einfach verschwinden, BEVOR ${This}.sh den Prozess killt."
                                echo ""
                            fi
                            rm -f ${StopShell}.ppid ${StopShell}.sh

                            if [ -n "${WhatsRunning[${gpu_uuid}]}" ]; then
                                StartMiner=1
                            fi
                        else
                            if [ -f ${MinerShell}.ppid -a -f ${MinerShell}.pid ]; then
                                echo "Beide Dateien ${MinerShell}.p?id sind noch vorhanden, Miner müsste noch laufen."
                                if [ "$(< ${MinerShell}.ppid)" != "$(< ${MinerShell}.pid)" ]; then
                                    echo "--->INKONSISTENZ ENTDECKT: Alles deutet darauf, dass die MinerShell ${MinerShell}.sh noch läuft."
                                    echo "--->Die Datei ${MinerShell}.ppid sowie ${MinerShell}.pid enthalten aber UNTERSCHIEDLICHE PIDs ???"
                                    echo "--->Dem sollte bei Gelegenheit nachgegangen werden, weil das eigentlich nicht sein darf."
                                fi
                            fi
                            unset MinerShell_pid
                            if [ -f ${MinerShell}.ppid ]; then
                                MinerShell_pid=$(< ${MinerShell}.ppid)
                            elif [ -f ${MinerShell}.pid ]; then
                                MinerShell_pid=$(< ${MinerShell}.pid)
                                # Keine Datei ${MinerShell}.ppid mehr, sonst wäre er in diese Abfrage nicht rein gekommen
                                echo ""
                                echo "--->INKONSISTENZ ENTDECKT: Alles deutet darauf, dass die MinerShell ${MinerShell}.sh noch laufen sollte."
                                echo "--->Trotzdem erklärt das nicht das Verschwinden der Datei ${MinerShell}.ppid und sollte erforscht werden."
                                echo ""
                            fi
                            if [ -n "${MinerShell_pid}" ]; then
                                # Check, ob der Prozess tatsächlich noch existiert.
                                run_pid=$(ps -ef | gawk -e '$2 == '${MinerShell_pid}' && /'${gpu_uuid}'/ {print $2; exit }')
                                if [[ "${run_pid}" == "${MinerShell_pid}" ]]; then
                                    # Keinen Neustart fordern, denn die Shell läuft ja noch.
                                    # Das haben wir eben auf Herz und Nieren überprüft.
                                    # Und da der Prozess noch läuft, hat er sich auch den Algo noch nicht disabled und deshalb
                                    # brauchen wir auch nicht die MINER_ALGO_DISABLED zu checken.
                                    echo "GPU #${gpu_idx}: Miner ${miner_name} ${miner_version} with Coin/Algo ${coin} STILL RUNNING"
                                    Ja_der_Miner_laeuft_und_soll_auch_weiterlaufen=1
                                else
                                    if [ -f ${MinerShell}.pid ]; then
                                        echo ""
                                        echo "--->INKONSISTENZ ENTDECKT: Alles deutet darauf, dass die MinerShell ${MinerShell}.sh noch laufen sollte."
                                        echo "--->Datei ${MinerShell}.pid ist auch noch da ($MinerShell_pid), aber der Prozess ist nicht mehr vorhanden ($run_pid)."
                                        echo "--->Möglicherweise hat sich der Prozess wegen eines AlgoDisable oder fehlendem Internet selbst beendet."
                                        echo "--->Sollte er in dem \"Disabled-GAP\" disabled worden sein, wird weiter unten der Start verhindert,"
                                        echo "--->weil nochmal vor dem Start nachgesehen wird. Wir fordern hier also einfach einen Neustart."
                                        echo ""
                                        # Wie das mit der abgebrochenen Internetverbindung ist, müssen wir später nochmal durchdenken.
                                        # An dieser Stelle können wir sicher sagen, dass sich die MinerShell kurz nach dem Start selbst beendet
                                        # OHNE den Miner zu starten, weil sie vor dem Miner-Start das Internet checkt.
                                        # Und die ${MinerShell}.ppid müssen wir hier nicht löschen, da sie unten einfach überschrieben wird.
                                        StartMiner=1
                                    else
                                        echo ""
                                        echo "--->Die MinerShell ${MinerShell}.sh wurde im letzten Zyklus gestartet, hat sich aber beendet."
                                        echo "--->Datei ${MinerShell}.pid ist konsequenterweise auch nicht mehr vorhanden."
                                        echo "--->Und konsequenterweise wird jetzt auch die Datei ${MinerShell}.ppid gelöscht."
                                        echo ""
                                        rm -f ${MinerShell}.ppid
                                    fi
                                fi
                            else
                                echo ""
                                echo "--->      !!!      K R I T I S C H      !!!      <---"
                                echo "--->INKONSISTENZ ENTDECKT: Alles deutet darauf, dass die MinerShell ${MinerShell}.sh noch laufen sollte."
                                echo "--->Es gibt aber weder die Datei ${MinerShell}.ppid noch die Datei ${MinerShell}.pid mehr mit der PID."
                                echo "--->Möglicherweise hat sich der Prozess wegen eines AlgoDisable oder fehlendem Internet selbst beendet."
                                echo "--->Sollte er in dem \"Disabled-GAP\" disabled worden sein, wird weiter unten der Start verhindert,"
                                echo "--->weil nochmal vor dem Start nachgesehen wird. Wir fordern hier also einfach einen Neustart."
                                echo "--->WIR GEHEN ALSO FEST DAVON AUS, DASS ER NICHT MEHR LÄUFT! SONST MÜSSEN WIR IHN ÜBER SEIN STARTKOMMANDE SUCHEN."
                                echo "--->Trotzdem erklärt das nicht das Verschwinden der Datei ${MinerShell}.ppid und sollte erforscht werden."
                                echo ""
                                StartMiner=1
                            fi
                        fi
                    else
                        echo "GPU #${gpu_idx}: Nothing ran, so nothing to stop, maybe something to start"
                        # Evtl. ist eine neue MinerShell zu starten.
                        if [ ${#WhatsRunning[${gpu_uuid}]} -gt 0 ]; then
                            StartMiner=1
                        fi
                    fi
                else
                    # GPU Vorher ENABLED, JETZT DISABLED - NEUER ZUSTAND: DISABLED!
                    if [ -n "${RuningAlgo}" ]; then
                        read coin pool miningAlgo miner_name miner_version muck888 <<<${RuningAlgo//#/ }
                        MINER=${miner_name}#${miner_version}
                        coin_pool="${coin}#${pool}"
                        coin_algorithm="${coin_pool}#${miningAlgo}#${MINER}"

                        StopShell=${miner_name}_${miner_version}_${coin}_${pool}_${miningAlgo}$( [[ ${#muck888} -gt 0 ]] && echo _${muck888} )
                        printf "GPU #${gpu_idx}: STOPPING MinerShell ${StopShell}.sh with Coin/Algo ${RuningAlgo}, then GPU DISABLED... "
                        if [ -f ${StopShell}.ppid ]; then
                            StopShell_pid=$(< ${StopShell}.ppid)
                            kill ${StopShell_pid}
                            # 1. sleep $Erholung wegen Erholung ist hier nicht nötig, weil nichts neues unmittelbar gestartet wird ???
                            # 2. Wir könnten hier auf das Ende des Prozesses warten und seinen Exit-Status auswerten. Wir könnten uns zurückgeben lasen,
                            #    ob es Probleme beim Beenden des Binär-Miners gab. Die GPU ist sehr eng mit dem Miner verbunden.
                            #    Sie sollte keinesfalls zulassen, dass ein 2ter Miner gestartet wird, solange ein 1ster noch läuft!
                            #    Das gibt hier natürlich eine gewisse Verzögerung, weil die beendende MinerShell die $Erholung abwartet,
                            #    aber es ist sicherer
                            
                            # Wir probieren das also hier mal.
                            # wait ${StopShell_pid}
                            # RC=$?

                            printf "done.\n"
                        elif [ -f ${StopShell}.pid ]; then
                            kill $(< ${StopShell}.pid)
                            # sleep $Erholung wegen Erholung ist hier nicht nötig, weil nichts neues unmittelbar gestartet wird
                            printf "done.\n"
                        else
                            printf "\n\n"
                            echo "OOOooops... MinerShell Files ${StopShell}.ppid and ${StopShell}.pid already gone."
                            echo "---> DON't KNOW HOW TO STOP PROCESS WITHOUT KNOWING PID"
                            echo "---> Das ist nicht wahr. Wir müssen das Startkommando in der Prozesstabelle suchen, dann haben wir ihn"
                            echo "--->     und können darüber die PID herausfinden. BITTE IMPLEMTIEREN! SONST LÄUFT MINER WEITER!!! <---"
                            echo ""
                        fi
                        rm -f ${StopShell}.ppid ${StopShell}.sh

                    else
                        # Das ist ein guter Zustand, um Autozubenchmarken, aber der könnte zusätzlich genutzt werden.
                        # Das ist nicht selbst provoziert, denn wenn sich die GPU nachher selbst aktiv herausnehmen sollte, geschieht folgendes:
                        # Ein eventuell vorhandener Auftrag wird aus der Running_State gelöscht.
                        # Die GPU disabled sich global, was auch auf die kommenden Running_States Einfluss hat.
                        #     Aber sie bekommt davon gar nichts mit, denn:
                        #     Wenn sie sich selbst herausnimmt, dann arbeitet sie alle Benchmarks ab, bis es keine mehr gibt
                        #     und ENABLED sich dann wieder, ebenfalls global.
                        # Das heisst, sie bekommt diesen Zustand des DISABLED, den sie selbst ausgelöst hat, niemals mit, weil sie danach immer
                        # wieder enabled ist und nicht hier rein kommt.
                        # Noch anders ausgedrückt: Dieser Disabled Zustand hier, weswegen wir in diesem Codeabschnitt sind, kam ganz sicher von aussen.
                        # Verursacht durch einen manuellen Eintrag in der Datei GLOBAL_GPU_SYSTEM_STATE.in und ist daher unbedingt zu bevolgen.
                        echo "GPU #${gpu_idx}: Nothing ran, so nothing to stop AND nothing to start because now GPU DISABLED."
                    fi
                fi
            else
                # GPU war im letzten Zyklus DISABLED
                if [ "${WasItEnabled[${gpu_uuid}]}" == "1" ]; then
                    printf "GPU #${gpu_idx}: Was DISABLED, so nothing to stop, but now ENABLED "
                    if [ ${#WhatsRunning[${gpu_uuid}]} -gt 0 ]; then
                        printf "and there is ${WhatsRunning[${gpu_uuid}]} to start..."
                        StartMiner=1
                    else
                        printf "and there is still nothing to start."
                    fi
                    printf "\n"
                else
                    # Hier gehört eigentlich der #EXIT# rein, es sei denn. der Disable ist die Folge von
                    # I_want_to_Disable_myself_for_AutoBenchmarking=1
                    # Aber wie lange wäre der Prozess weg?
                    # Nach dem nächsten Sync würde er automatisch vom MM neu gestartet werden.
                    # Wir können das in Erwägung ziehen, wenn wir merken, dass die GPUs bei zu langer Laufzeit wieder langsamer werden.
                    # Aber wir müssen dann auch das Problem lösen, dass der MM die zu beendende GPU-Prouess-ID aus seiner Liste laufender PIDs entfernen kann,
                    #      bevor er den neuen Prozess aufnimmt.
                    echo "GPU #${gpu_idx}: Was DISABLED, so nothing to stop AND nothing to start because STILL DISABLED."
                fi
            fi
        else
            # Noch kein RUNNING_STATE da gewesen oder nicht enthalten gewesen
            # Bedeutet, dass kein Miner von hier gestartet gewesen sein sollte.
            # Müssen also auch auf nichts weiter achten als eventuell einen zu starten.
            if [ "${WasItEnabled[${gpu_uuid}]}" == "1" ]; then
                if [ -n "${WhatsRunning[${gpu_uuid}]}" ]; then
                    StartMiner=1
                fi
            fi
        fi

        if [ ${#I_want_to_Disable_myself_for_AutoBenchmarking} -gt 0 ]; then

            # 1. Bei einem Wechsel des coin_algorithm ist der bisherige Miner gestoppt und StartMiner=1.
            #    Um den Stop eines Miners müssen wir uns also nicht kümmern.
            #    Aber wir müssen die RUNNING_STATE bearbeiten, damit dem System "vorgetäuscht" wird, dass niemals geplant war,
            #    diese GPU mit dem Start eines Miners zu beauftragen.
            DoAutoBenchmark=0
            if [ ${StartMiner} -eq 1 ]; then

                _reserve_and_lock_file ${RUNNING_STATE}                      # Zum Lesen reservieren...
                touch -r ${RUNNING_STATE} .RUNNING_STATE_modification_date

                REGEXPAT='s/\('${gpu_uuid}':'${gpu_idx}'\):.*$/\1:0:0:/g'
                sed -i -e "${REGEXPAT}" ${RUNNING_STATE}

                touch -r .RUNNING_STATE_modification_date ${RUNNING_STATE}
                rm -f .RUNNING_STATE_modification_date
                _remove_lock                                                 # ... und wieder freigeben

                DoAutoBenchmark=1
            else
                ##################################################################
                # 2. Jetzt ist noch die Frage zu klären, ob noch ein Miner läuft, was der Fall sein könnte, wenn StartMiner -eq 0 ist!
                #    In diesem Fall wollten wir das Ende des Miners durch Wechsel des coin_algorithm abwarten,
                #    weil das in der bisherigen und momentanen Mechanik so oder so der Fall ist.
                #
                # Wir müssen auf jeden Fall im Fall StartMiner=0 prüfen, ob der Miner noch läuft UND IHN DANN WEITERLAUFEN LASSEN.
                # Und es ist nichts weiter zu schreiben.
                # Wir müssen das nur überleben und wieder hier rein kommen... oder eben nicht mehr. Dann hat es sich von selbst erledigt,
                # weil keine Elemente in der Liste/Array ALL_MISSING_ALGORITHMs[@] mehr drin sind.
                #
                # Wenn kein Miner läuft, war keiner gestartet oder wurde gestoppt und es ist kein Neuer zu starten.
                # Das ist der Fall, in dem wir die GPU rausnehmen und das Benchmarking machen.
                #

                if [ "${Ja_der_Miner_laeuft_und_soll_auch_weiterlaufen}" == "1" ]; then
                    unset Ja_der_Miner_laeuft_und_soll_auch_weiterlaufen
                else
                    DoAutoBenchmark=1
                fi
            fi

            # Jetzt sind alle Fragen geklärt, alle Voraussetzungen erfüllt, um sich auszuklinken, ohne dass irgendetwas vermisst würde.
            # Die RUNNING_STATE wurde berbeitet und wird erst beim nächsten SYNCFILE touch wieder inspiziert.
            # Nachdem auch die SYSTEM_STATE.in bearbeitet wird, ist die GPU endgültig offiziell aus dem System verschwunden und niemand
            # wartet mehr auf ihre Daten für die Mining-Berechnungen.
            if [ ${DoAutoBenchmark} -eq 1 ]; then

                printf "GPU #${gpu_idx}: ###---> Going to take me out of the system, recognized as \"DISABLED\"..."

                # Eigene gpu_uuid disablen.
                # Kann sehr gefahrlos gemacht werden, weil der multi_miner die Datei erst nach dem nächsten SYNCFILE einliest
                # und dann die GPU als disabled vorfindet und sie rausnimmt und in keiner Weise sie berücksichtigt.
                # Sogar die ${RUNNING_STATE} passt jetzt, da im Fall StartMIner=0 lediglich ein Miner abzustellen war
                # und deshalb auch kein coin_algorithm im ${RUNNING_STATE} eingetragen war.
                _disable_GPU_UUID_GLOBALLY ${gpu_uuid}
                printf " done\n"


                # ALL_MISSING_ALGORITHMs abarbeiten
                cd ../benchmarking
                mkdir -p autobenchlogs
                for algorithm in ${ALL_MISSING_ALGORITHMs[@]}; do

                    echo "GPU #${gpu_idx}: ###---> Going to Auto-Benchmark Algorithm/Miner ${algorithm}, trying to produce some Coins on the fly..."
                    parameters="-d"
                    [ ${NoCards} ] && parameters="-d -w 5 -m 5"
                    [ -n "${parameters}" ] && echo "        ###---> HardCoded additional Parameters for bench_30s_2.sh: \"${parameters}\""
                    ./bench_30s_2.sh -a ${gpu_idx} ${algorithm} ${parameters} | tee autobenchlogs/bench_${gpu_idx}_${algorithm}.log

                done
                cd ${_WORKDIR_}
                


                echo $(date "+%Y-%m-%d %H:%M:%S" ) $(date +%s)
                printf "GPU #${gpu_idx}: ###---> Going to take me back into the system, recognized as \"Enabled\"..."

                # Zum geordneten Wiedereintritt in den Gesamtprozess warten wir erst auf einen sicheren Zeitpunkt zum Schreiben
                #     der Datei ${SYSTEM_STATE}.in, wodurch wir wieder als ENABLED wahrgenommen werden.
                # Warten, bis multi_mining_calc.sh für längere Zeit "schlafen" geht und kein Interesse mehr an der Datei SYSTEM_STATE hat,
                # Das ist der Fall nachdem multi_mining_calc.sh die Datei ${RUNNING_STATE} mit den Anweisungen für die GPUs geschrieben hat.
                # Zuerst brauchen wir die Zeit von RUNNING_STATE, dan bekommen wir mit, wenn sich unmittelbar danach SYNCFILE aktualisiert.
                # Und es sollte garantiert werden, dass immer eine gewisse Mindestzeit, z.B. 31s vergehen, NACHDEM die RUNIING_STATE geschrieben wurde,
                #     bis SYNCFILE wieder geschrieben wird.
                #     Diese Problematik versuchen wir daduch in den Griff zu bekommen, dass algo_multi_abfrage das Schreiben der Datei
                #     RUNNING_STATE irgendwie mit berücksichtigt, bevor er einen neuen Abruf macht.
                read RunSecs            RunFrac <<<$(_get_file_modified_time_ ${RUNNING_STATE})
                read new_Data_available SynFrac <<<$(_get_file_modified_time_ ${SYNCFILE})
                until (( ${RunSecs} > ${new_Data_available} )); do
                    sleep 5
                    read RunSecs            RunFrac <<<$(_get_file_modified_time_ ${RUNNING_STATE})
                    read new_Data_available SynFrac <<<$(_get_file_modified_time_ ${SYNCFILE})
                done

                _enable_GPU_UUID_GLOBALLY ${gpu_uuid}
                printf " done\n"

                # Das Kennzeichen für die Auto-Benchmarking-Periode.
                # Wenn beim Programmende diese Datei noch existiert, muss sich die GPU wieder enablen.
                unset DoAutoBenchmark

            fi
        else        # oder auch möglich:         elif [ ${StartMiner} -eq 1 ]; then
            #############################################################################
            #############################################################################
            #
            #     Starten der MinerShell und Übergabe aller relevanten Parameter.
            #     Eine vorhandene Datei ${MinerShell}.ppid bedeutet:
            #          Laufende MinerShell und laufender Miner.
            #
            #############################################################################
            #############################################################################
            # Es mus sichergestellt sein, dass kein Miner mehr läuft, wenn StartMiner == 1 ist !!!
            # Bei einem noch laufenden Miner DARF StartMiner NICHT 1 sein!!!
            # Das hat uns komplette Rechnerabstürze beschert.
            # Also bitte oben sicherstellen, dass StartMiner == 0 bleibt, wenn noch ein Miner läuft!!!
            if [ ${StartMiner} -eq 1 ]; then
                coin_algorithm=${WhatsRunning[${gpu_uuid}]}
                read coin pool miningAlgo miner_name miner_version muck888 <<<${coin_algorithm//#/ }
                algorithm="${miningAlgo}#${miner_name}#${miner_version}"$( [[ ${#muck888} -gt 0 ]] && echo "#${muck888}" )
                MinerShell=${miner_name}_${miner_version}_${coin}_${pool}_${miningAlgo}$( [[ ${#muck888} -gt 0 ]] && echo _${muck888} )

                # Ein letzter Blick in die MINER_ALGO_DISABLED Datei, weil der Algo während der Wartezeit von einem
                # laufenden Miner disabled geworden sein könnte und deshalb nicht mehr laufen darf.
                declare -i suddenly_disabled=0
                [[ -f ../MINER_ALGO_DISABLED ]] \
                    && suddenly_disabled=$(grep -E -c -m1 -e "\b${coin_algorithm%#888}([^.\W]|$)" ../MINER_ALGO_DISABLED)
                if [ ${suddenly_disabled} -gt 0 ]; then
                    echo ""
                    echo "GPU #${gpu_idx}: MinerShell ${MinerShell}.sh sollte gestartet werden, IST ABER MITTLERWEILE DISABLED."
                    echo "                 Dieses Disable kann nur in der Zeit geschehen sein, in der multi_mining_calc.sh gerechnet hat."
                    echo "                 Bitte diese Tatsache überprüfen. Dazu wird hier die Differenz aus dem Disabled.Zeitpunkt"
                    echo "                 zum jetzigen Moment ausgerechnet:"

                    unset       MINER_ALGO_DISABLED_ARR MINER_ALGO_DISABLED_DAT
                    declare -Ag MINER_ALGO_DISABLED_ARR MINER_ALGO_DISABLED_DAT
                    declare -i  nowSecs=$(date +%s) timestamp
                    unset READARR
                    readarray -n 0 -O 0 -t READARR <../MINER_ALGO_DISABLED
                    for ((i=0; $i<${#READARR[@]}; i++)) ; do
                        read _date_ _oclock_ timestamp disd_coin_algorithm <<<${READARR[$i]}
                        MINER_ALGO_DISABLED_ARR[${disd_coin_algorithm}]=${timestamp}
                        MINER_ALGO_DISABLED_DAT[${disd_coin_algorithm}]="${_date_} ${_oclock_}"
                    done

                    if [ -n "${MINER_ALGO_DISABLED_ARR[${coin_algorithm%#888}]}" ]; then
                        echo "             Zeitpunkt des DISABLE: ${MINER_ALGO_DISABLED_DAT[${coin_algorithm%#888}]}"
                        echo "             Zeitpunkt der Prüfung: $(( ${nowSecs} - ${timestamp} ))s später."
                    else
                        echo "OOOooops...  PROGRAMMIERFEHLER oder schwerer Denkfehler !"
                        echo "             Irgendetwas stimmt mit der grep-Abfrage nicht, denn die hat signalisiert, dass ${coin_algorithm%#888}"
                        echo "             in der Datei ../MINER_ALGO_DISABLED enthalten sein müsste."
                        echo "             Nach dem Einlesen der Datei ist aber nichts da."
                        echo "             Es könnte sein, dass eine andere GPU den Algo in dieser kurzen Zeit zwischen der grep-Abfrage"
                        echo "             und dem Einlesen der Datei wieder enabled und herausgenommen hat."
                        echo "             In diesem Fall würde etwas anderes nicht stimmen, denn dann hätte der ${coin_algorithm} vor 31s"
                        echo "             GAR NICHT BERECHNET UND WEITERGEGEBEN WERDEN DÜRFEN !!! BITTE ÜBERPRÜFEN !!!"
                        echo ""
                        echo "             --->         DER MINER WIRD SICHERHEITSHALBER NICHT GESTARTET!         <---"
                        echo ""
                    fi
                    echo "                 DAS DARF NICHT ZU OFT VORKOMMEN, SONST MUSS DAS NÄHER UTERSUCHT WERDEN!!!"
                    echo ""
                    # Nur um sicherzustellen, dass wirklich keine solche Datei existiert.
                    # Er dürfte hier nämlich gar nicht reinkommen, wenn diese Datei existiert.
                    # Denn das würde bedeuten, dass die Anweisung gegeben wurde, einen Miner zu starten, obwohl noch einer läuft!
                    rm -f ${MinerShell}.ppid
                else
                    # EINSCHALTEN

                    read coin pool miningAlgo miner_name miner_version muck888 <<<${coin_algorithm//#/ }

                    REGEXPAT="^${coin}#${pool}#"
                    declare -n actCoinsPoolsOfMiningAlgo="CoinsPoolsOfMiningAlgo_${miningAlgo//-/_}"
                    for c_p_sn_p in ${actCoinsPoolsOfMiningAlgo[@]}; do
                        if [[ "${c_p_sn_p}" =~ ${REGEXPAT} ]]; then
                            read ccoin ppool server_name algo_port <<<${c_p_sn_p//#/ }
                            break
                        fi
                    done
                    domain=${POOLS[${pool}]}

                    REGEXPAT="\b${coin}\b"
                    case ${pool} in

                        "nh")
                            if [ ${PoolActive[${pool}]} -eq 1 ]; then
                                if [[ "${ALGOs[@]}" =~ ${REGEXPAT} ]]; then
                                    algo_port=${PORTs[${coin}]}
                                fi
                            fi
                            ;;

                        #                "sn")
                        #                    if [ ${PoolActive[${pool}]} -eq 1 ]; then
                        #                        if [[ "${COINS[@]}" =~ ${REGEXPAT} ]]; then
                        #                            # Seit 24.12.2017 gibt es die Funktion
                        #                            # _read_in_static_COIN_MININGALGO_SERVERNAME_PORT_from_Pool_Info_Array, die die Dateien all.*
                        #                            # komplett auswertet und die Informationen in allen Kombinationen zur Verfügung stellt.
                        #                            #algo_port=$(cat ../all.suprnova \
                        #                            #           | grep -v -e '^#' \
                        #                            #           | grep -m 1 -e "^${coin}:" \
                        #                            #           | cut -d ':' -f 4 )
                        #                        fi
                        #                    fi
                        #                    ;;
                    esac

                    continent="SelbstWahl"
                    [[ "${miner_name}" == "zm" ]] && continent="br"

                    printf -v worker "%02i${gpu_uuid:4:6}" ${gpu_idx}

                    _setup_Nvidia_Default_Tuning_CmdStack
                    cmdParameterString=""
                    for cmd in "${CmdStack[@]}"; do
                        cmdParameterString+="${cmd// /;} "
                    done
                    
                    echo "GPU #${gpu_idx}: STARTE Miner Shell ${MinerShell}.sh und übergebe Algorithm ${coin_algorithm} und mehr..."
                    cp -f ../GPU-skeleton/MinerShell.sh ${MinerShell}.sh
                    ./${MinerShell}.sh    \
                      ${coin_algorithm}   \
                      ${gpu_idx}          \
                      ${continent}        \
                      ${algo_port}        \
                      ${worker}           \
                      ${gpu_uuid}         \
                      ${domain}           \
                      ${server_name}      \
                      ${miner_gpu_idx["${miner_name}#${miner_version}#${gpu_idx}"]} \
                      $cmdParameterString \
                      >>${MinerShell}.log &
                    echo $! >${MinerShell}.ppid
                fi
            fi
        fi
    else
        echo "GPU #${gpu_idx}: Was too late. SYNCFILE older than ${GPU_alive_delay} seconds"
    fi

    #############################################################################
    #
    #
    # Warten auf neue aktuelle Daten aus dem Web, die durch
    #        algo_multi_abfrage.sh
    # beschafft werden müssen und deren Gültigkeit sichergestellt werden muss!
    #
    #
    #
    #     ###WARTET### jetzt, bis das "Alter" der Datei ${SYNCFILE} aktueller ist als ${new_Data_available}
    #                         mit der Meldung "Waiting for new actual Pricing Data from the Web..."
    echo $(date "+%Y-%m-%d %H:%M:%S" ) $(date +%s)
    echo "GPU #${gpu_idx}: Waiting for SYNCFILE and therefore for new actual Pricing Data from the Web..."
    while (( ${new_Data_available} == $(stat -c "%Y" ${SYNCFILE}) )) ; do
        sleep 1
    done
    #  9. Merkt sich das neue "Alter" von ${SYNCFILE} in der Variablen ${new_Data_available}
    read new_Data_available SynFrac <<<$(_get_file_modified_time_ ${SYNCFILE})
    
done
