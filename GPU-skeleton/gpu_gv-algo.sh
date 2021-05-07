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
#  -  Definition der _On_Exit() Austrittsroutine
#  - Definition von gpu_uuid und IMPORTANT_BENCHMARK_JSON

#  6. 2021-04-16: Nach dem Einlesen der IMPORTANT_BENCHMARK_JSON stehen nun auch die noch fehlenden
#     Algorithms in dem Array pleaseBenchmarkAlgorithm[]
#     Diese Benchmarks werden nach jedem Neustart des gpu_gv-algo.sh vor dem Eintritt in die Endlosschleife gebenchmarked.

#  6. sourced über gpu-bENCH.inc die _read_IMPORTANT_BENCHMARK_JSON_in(), welches durch Aufruf
#     die Benchmark- und Wattangaben pro Algorithmus aus der Datei benchmark_${GPU_DIR}.json
#     in die Assoziativen Arrays bENCH["AlgoName"] und WATTS["AlgoName"] aufnimmt
#     Und ALLE_MINER[], alle MINER_FEES[miner:algo], alle Arrays Mining_$minername_$minerversion_Algos[ $coin ]=4algo,
#         alle MINER_IS_AVAILABLE[ $algorithm ]=1, alle algo_checked[ $algorithm ]=0/1
#         und das Array pleaseBenchmarkAlgorithm[]=$algorithm
#  7. Ruft _read_IMPORTANT_BENCHMARK_JSON_in() und hat jetzt alle oben erähnten Arrays zur Verfügung und kennt das "Alter"
#     der Benchmarkdatei zum Zeitpunkt des Einlesens in der Variablen ${IMPORTANT_BENCHMARK_JSON_last_age_in_seconds}
# (21.11.2017)
# Wir wissen jetzt, dass alle relevanten Werte in der "simplemultialgo"-api Abfrage enthalten sind
#     und brauchen die ../ALGO_NAMES.in überhaupt nicht mehr.
#     Das folgende kann raus:
#  x. 
#
# (21.11.2017)
# Das machen wir ANDERS. Es gibt schon includable Funktionen zum Abruf, Auswertung und Einlesen der Webseite
# in die Arrays durch source ${LINUX_MULTI_MINING_ROOT}/algo_infos.inc
#        ALGOs[ ${coin_ID} ]
#        KURSE[ ${coin} ]
#        PORTs[ ${coin} ]
#     ALGO_IDs[ ${coin} ]
#  8.  source ${LINUX_MULTI_MINING_ROOT}/algo_infos.inc, nvidia-Befehle und gpu-abfrage.inc
#  8.1
#  8.2
#  8.3
#
# 2020-04-16:
#  9. Prüft hier, ob Algorithms zu benchmarken sind (pleaseBenchmarkAlgorithm[])...
#     zieht die GLOBAL_ALGO_DISABLED davon ab...
#     [SOLL:] zieht die temporär disableten davon ab... $$$$$$$$$$$$$$$$$$$$
#     und nimmt sich bei Bedarf aus dem System, die Benchmarks durchzuführen
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
#  4. ###WARTET### jetzt, bis die Datei "../NH_KURSE_PORTS.in" vorhanden und NICHT LEER ist.
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
GPU_DIR=$(pwd)
GPU_DIR=${GPU_DIR##*/}

#  3. Definiert _update_SELF_if_necessary()
#     Das exec hier drin veranlasst das Script NICHT durch die _On_Exit Routine zu laufen!
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
        dst_secs=$(date --utc --reference=${SRC_FILE} +%s)
        if [[ $dst_secs < $src_secs ]]; then
            # create update command file
            echo "cp -f ../${SRC_DIR}/${SRC_FILE} .; \
                  exec ./${SRC_FILE}" \
                 >$UPD_FILE
            chmod +x $UPD_FILE
            echo "GPU #$(< gpu_index.in): ###---> Updating the GPU-UUID-directory from $SRC_DIR" # | tee .going-to-exec
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
        #clear
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

# Das Prioritätenkürzel für die MinerShell's
# Kann hier global gesetzt werden, weil nur die MinerShell aus diesem Skript gestartet wird
ProC="ms"

### SCREEN ADDITIONS: ###
# Die folgende Variable wird auch in der globals.inc gesetzt (0 bis zum Ende der Tests) und kann hier überschrieben werden.
# 0 ist der frühere Betrieb an einem graphischen Desktop mit mehreren hochpoppenden Terminals
# 1 ist der Betrieb unter GNU screen
#UseScreen=1
[[ ${#GPU_gv_Title} -eq 0 ]] && GPU_gv_Title="GPU#${gpu_idx}_GV"
[[ ${#BencherTitle} -eq 0 ]] && BencherTitle="GPU#${gpu_idx}_BENCH_RUN"
export MinerShell_RUN_title MinerShell_LOG_title

# Bei einem Update dieses Scripts in der Endlosschleife des produktiven Betriebes
# werden alle Speichervariablen gelöscht und müssen neu aufgebaut werden.
# Vor allem die Information über gestartete und noch laufende MinerShells...
# Hier sollte alles Wesentliche erneut aufgebaut werden:
# 1. Variable "MinerShell" <--- muss noch verifiziert werden, wie lange die überhaupt gültig ist
#    Gibt es immer eine MinerShell und ab und an eine StopShell ?
if [ -f MinerShell_STARTS_HISTORY ]; then
    read _epoch_ msh_pid _bash_ MinerShell Parameters <<<$(tail -1 MinerShell_STARTS_HISTORY)
    MinerShell=$(basename ${MinerShell} .sh)
    if [ ${msh_pid} -eq $(< ${MinerShell}.ppid) ]; then
	echo "Ran MinerShell \"${MinerShell}\" before _update_SELF_if_necessary() with PID ${msh_pid}"
    else
        echo "--->INKONSISTENZ ENTDECKT: Alles deutet darauf, dass die MinerShell ${MinerShell}.sh noch läuft."
        echo "--->Die PID aus der Datei Datei ${MinerShell}.ppid ($(< ${MinerShell}.ppid)) sowie die PID aus der Datei MinerShell_STARTS_HISTORY (${msh_pid}) sind aber UNTERSCHIEDLICH???"
        echo "--->Dem muss DRINGEND nachgegangen werden, weil das nicht passieren darf!!!"
    fi
fi

function _get_running_MinerShell_pid_from_ptable {
    run_pid=0
    if [ ${#1} -eq 0 ]; then
	read _epoch_ filed_pid _bash_ MinerShell_CMD <<<$(tail -1 MinerShell_STARTS_HISTORY)
	CMD="${MinerShell_CMD//[/\\[}"
	CMD="${CMD//]/\\]}"
    else
	# MinerShell LOG process
	read _epoch_ filed_pid LOG_PTY_CMD <<<$(tail -1 MinerShell_LOG_PTY_CMD)
	CMD="${LOG_PTY_CMD}"
    fi
    pgrep_pids=( $(pgrep -f "${CMD}") )
    for pgrep_pid in ${pgrep_pids[@]}; do
	[ $pgrep_pid -eq $filed_pid ] && { run_pid=$pgrep_pid; break; }
    done
}

function _terminate_screen_logger_terminal {
    # Beenden des Logger-Terminals, das eventuell im Screen-Modus gestartet wurde
    if [ -s MinerShell_LOG_PTY_CMD ]; then
	printf "Beenden des MinerShell Logger-Terminals ... "
	_get_running_MinerShell_pid_from_ptable LOG
	if [ ${run_pid} -gt 0 ]; then
            kill ${run_pid} >/dev/null
            printf "done.\n"
	else
            printf "\n–––> KILL_PANIC: Logger-Terminal \"${LOG_PTY_CMD}\"\n"
            printf "     Konnte nicht mehr gefunden werden. PID der Startdatei: ${filed_pid}, PID in Prozesstabelle: ${run_pid}\n"
	fi
	mv -f MinerShell_LOG_PTY_CMD MinerShell_LOG_PTY_CMD.BAK &>/dev/null
    fi
}

function _terminate_MinerShell_and_logger_terminal {
    if [ -s MinerShell_STARTS_HISTORY ]; then
	printf "\nBeenden der MinerShell ${MinerShell}.sh mit PID ${MinerShell_pid} ... "
	_get_running_MinerShell_pid_from_ptable
	if [ ${run_pid} -gt 0 ]; then
            kill ${run_pid} >/dev/null
            printf "done.\n"
	else
            printf "\n–––> KILL_PANIC: MinerShell \"${MinerShell_CMD}\"\n"
            printf "     Konnte nicht mehr gefunden werden. PID der Startdatei: ${filed_pid}, PID in Prozesstabelle: ${run_pid}\n"
	fi
	mv -f MinerShell_STARTS_HISTORY MinerShell_STARTS_HISTORY.BAK &>/dev/null

	read StopShell Paremeters <<<"${MinerShell_CMD}"
	StopShell=$(basename ${StopShell} .sh)
	rm -f ${StopShell}.ppid &>/dev/null
	while [ -f ${StopShell}.pid ]; do { echo "${StopShell}.pid still there..."; sleep 1; }; done
	echo "${StopShell}.pid gone. Good!"
    fi

    # Beenden des Logger-Terminals, das im Screen-Modus gestartet wurde
    _terminate_screen_logger_terminal
}

#
# Aufräumarbeiten beim ordungsgemäßen kill -15 Signal
#
function _On_Exit () {
    [ ${debug} -eq 1 ] && echo "_On_Exit() entered..."

    if [ -n "${DoAutoBenchmark}" ] && [ ${DoAutoBenchmark} -eq 1 ]; then
        echo "Prozess wurde aus dem Auto-Benchmarking gerissen... GPU #${gpu_idx} wird wieder global Enabled."
        _enable_GPU_UUID_GLOBALLY ${gpu_uuid}
	# Im ScreenTest Modus kann der Benchmarker problemlos beendet werden,
	#    während es im Normalbetrieb sinnvoll ist, den Benchmarking-Lauf beenden zu lassen, damit das Benchmarking nicht umsonst war.
	if [ ${ScreenTest} -eq 1 ]; then
	    [ ${#benchPID} -gt 0 ] && kill ${benchPID}
	fi
    fi

    # Die MinerShell muss beendet werden, wenn sie noch laufen sollte.
    if [ ${UseScreen} -eq 1 ]; then
	_terminate_MinerShell_and_logger_terminal
    else   # Diese Methode kann und sollte komplett entfernt werden, wenn das mit der Befehls-Historie klappt
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
    fi

    rm -f .DO_AUTO_BENCHMARK_FOR
    for algorithm in ${!DO_AUTO_BENCHMARK_FOR[@]}; do
        echo ${algorithm} >>.DO_AUTO_BENCHMARK_FOR
    done
    [ $debug -eq 1 -a -s .DO_AUTO_BENCHMARK_FOR ] && cat .DO_AUTO_BENCHMARK_FOR

    # Diese beiden Dateien müssen unbedingt weg bei einem geordneten Abbruch, da sie Informationen über laufende Prozesse enthalten,
    #       die benötigt werden, falls gpu_gv-algo.sh "zwischendurch" neu reinkommt (_update_SELF_if_necessary)
    rm -f ${MinerShell}.ppid ${MinerShell}.sh .now_[0-9]* *.lock \
       ${This}.pid &>/dev/null
    [ ${debug} -eq 1 ] && echo "... leaving _On_Exit()"
}
trap _On_Exit EXIT # == SIGTERM == TERM == -15

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

gpu_uuid="${GPU_DIR}"
IMPORTANT_BENCHMARK_JSON="benchmark_${gpu_uuid}.json"

###############################################################################
#
# Einlesen und verarbeiten der Benchmarkdatei
#
######################################

#  6. Definiert _read_IMPORTANT_BENCHMARK_JSON_in(), welches Benchmark- und Wattangaben
#     und überhaupt alle Daten pro Algorithmus
#     aus der Datei benchmark_${GPU_DIR}.json
#     in die Assoziativen Arrays bENCH["AlgoName"] und WATTS["AlgoName"] und
#     MAX_WATT["AlgoName"]
#     HASHCOUNT["AlgoName"]
#     HASH_DURATION["AlgoName"]
#     BENCH_DATE["AlgoName"]
#     BENCH_KIND["AlgoName"]
#     GRAFIK_CLOCK["AlgoName"] - heisst in der .json: "GPUGraphicsClockOffset[3]"
#     MEMORY_CLOCK["AlgoName"] - heisst in der .json: "GPUMemoryTransferRateOffset[3]"
#     FAN_SPEED["AlgoName"]    - heisst in der .json: "GPUTargetFanSpeed"
#     POWER_LIMIT["AlgoName"]
#      "HashCountPerSeconds": 0,
#      "BenchMode": o,
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

# Damit readarray als letzter Prozess in einer Pipeline nicht in einer subshell
# ausgeführt wird und diese beim Austriit gleich wieder seine Variablen verwirft
shopt -s lastpipe

# Die Datei macht einiges, was das Format der benchmark.json betrifft, wobei die entsprechenden Funktionen dafür
# in der Datei gpu-bENCH.inc definiert sind.
# Eine Strukturänderung der benchmark.json wird nur durchgeführt, wenn zwei Dateien im GPU-skeleton Verzeichnis
#      denselben Zeitstempel haben.
# Muss mal sauber dokumentiert werden!!!
#
# Diese Datei macht einen
#   source gpu-bENCH.inc      und die wiederum macht einen
#      source miner-func.inc
source gpu-bENCH.sh

# Auf jeden Fall beim Starten das Array bENCH[] und WATTS[] aufbauen
# Später prüfen, ob die Datei erneuert wurde und frisch eingelesen werden muss
#  7. Ruft _read_IMPORTANT_BENCHMARK_JSON_in() und hat jetzt alle Arrays zur Verfügung und kennt das "Alter"
#     der Benchmarkdatei zum Zeitpunkt des Einlesens in der Variablen ${IMPORTANT_BENCHMARK_JSON_last_age_in_seconds}
# Da die Arrays ALLE_MINER, ALLE_MINER_FEES und ALLE_LIVE_MINER durch den Aufruf von _set_ALLE_MINER_from_path_bereits hier
#    eingelesen werden, wird der Aufruf von _set_ALLE_MINER_from_path aus der nachfolgenden Funktion entfernt:
#    _read_in_ALL_Mining_Available_and_Missing_Miner_Algo_Arrays
_read_IMPORTANT_BENCHMARK_JSON_in  # without_miners Muss AUF JEDEN FALL die Miner beachten.

###############################################################################
#
# Die Funktionen zum Einlesen und Verarbeiten der aktuellen Algos und Kurse
#
#
#
######################################

#  8. Definiert _read_in_ALGO_PORTS_KURSE(), welches die Datei "../NH_KURSE_PORTS.in" in das Array KURSE["AlgoName"] aufnimmt.
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

#  8.1. GANZ WICHTIG immer nach der GPU-Abfrage und nach dem Setzen von ALLE_MINER (um letzteres kümmert sich die Funktion selbst):
#       Seit Ende 2017 die Trennung von gpu_idx und miner_dev. In einem Assoziativen Array vorgehalten,
#       das bei jedem Start und dann bei jeder Änderung wieder upgedatet werden muss
#       2021-4-16:
#       Diese Funktion ruft die selbe Funktion _set_ALLE_MINER_from_path(), wie es auch schon die _read_IMPORTANT_BENCHMARK_JSON_in() getan hat
#       BITTE PRÜFEN, DASS DA KEIN DOPPELTER AUFWAND GETRIEBEN WIRD $$$$$$$$$$$$$$$$$$$$
_set_Miner_Device_to_Nvidia_GpuIdx_maps ${_ALL_MINERS_DATA_CHANGED_ON_DISK_}

#  8.2. Alle Miner-Arrays setzen wie ALLE_MINER[i], MINER_FEES[ miningAlgo ], Miner_${MINER}_Algos[ ${coin} ] etc.
#       Im Moment begnügen wir uns damit, VOR der Endlosschleife alle Arrays zu setzen.
# ---> Muss in die Endlosschleife verlegt werden, wenn die Coins im laufenden Betrieb hinzugefügt werden             <---
# ---> Wir müssen einen Trigger entwickeln, der uns in der Endlosschleife sagt, dass die Arrays neu einzulesen sind. <---
# Ab hier sind jedenfalls die Coin/miningAlgo-Informationen MinerFees gültig
_read_in_ALL_Mining_Available_and_Missing_Miner_Algo_Arrays

#  8.3. Alle fehlenden Pool-Infos setzen wie Coin, ServerName und Port
# Ab hier sind die folgenden Informationen in den Arrays verfügbar
#    actCoinsOfPool      ="CoinsOfPool_${pool}"
#    actMiningAlgosOfPool="MiningAlgosOfPool_${pool}"
#    # actServerNameOfPool="ServerNameOfPool_${pool}"
#    # actPortsOfPool="PortsOfPool_${pool}"
#    # Coin_MiningAlgo_ServerName_Port[i] = zwar global, aber Inhalt der letzten all.${pool}-Datei
#    UniqueMiningAlgoArray[${miningAlgo}]+="${coin}#${pool}#${server_name}#${algo_port} "
#    CoinsPoolsOfMiningAlgo_${mining_Algo}[i] = UniqueMiningAlgoArray[${miningAlgo}]
_read_in_static_COIN_MININGALGO_SERVERNAME_PORT_from_Pool_Info_Array

function _do_all_auto_benchmarks {
    # Eigene gpu_uuid disablen.
    # Kann sehr gefahrlos gemacht werden, weil der multi_miner diesen Prozess gerade erst gestartet hat oder gar nicht läuft.
    # Oder weil er im laufenden Betrieb vor Kurzem erst die ${RUNNING_STATE} geschrieben hat und schlafen gegangen ist:
    #   Kann sehr gefahrlos gemacht werden, weil der multi_miner die Datei erst nach dem nächsten SYNCFILE einliest
    #   und dann die GPU als disabled vorfindet und sie rausnimmt und in keiner Weise sie berücksichtigt.
    #   Sogar die ${RUNNING_STATE} passt jetzt, da im Fall StartMIner=0 lediglich ein Miner abzustellen war
    #   und deshalb auch kein coin_algorithm im ${RUNNING_STATE} eingetragen war.
    printf "GPU #${gpu_idx}: ###---> Going to take me out of the system, recognized as \"DISABLED\"..."
    _disable_GPU_UUID_GLOBALLY ${gpu_uuid}
    printf " done\n"

    # WillBenchmarkAlgorithm abarbeiten
    cd ${LINUX_MULTI_MINING_ROOT}/benchmarking
    mkdir -p autobenchlogs

    for algorithm in ${WillBenchmarkAlgorithm[@]}; do
	echo "GPU #${gpu_idx}: ###---> Going to Auto-Benchmark Algorithm/Miner ${algorithm}, trying to produce some Coins on the fly..."

	parameters="--gpu_called -d"
	[ -n "${parameters}" ] && echo "        ###---> HardCoded additional Parameters for bench_30s_2.sh: \"${parameters}\""
	cmd="./bench_30s_2.sh -a ${gpu_idx} ${algorithm} ${parameters} | tee autobenchlogs/bench_GPU#${gpu_idx}_${algorithm}.log"

	### SCREEN ADDITIONS: ###
	if [ ${UseScreen} -eq 1 ]; then
	    cmd="export BencherTitle=${BencherTitle}; ${cmd}"
	    cmd="cd ${LINUX_MULTI_MINING_ROOT}/benchmarking; ${cmd}"
	    # Vom mm aus gerufen befinden wir uns hier in der ${BG_SESS}!
	    # Deshalb hier die Umleitung in das eigene Logfile, damit die Aktivitäten vorne gesehen werden können.
            cmd+=" >>../${gpu_uuid}/gpu_gv-algo_${gpu_uuid}.log"
	    cmd+='\nexit\n'
	    # Vom mm aus gerufen befinden wir uns hier in der ${BG_SESS}!
	    # Merkmal: ${STY} == ${BG_SESS} - aber wir brauchen wahrscheinlich andere Kriterien, um das sicher zu erkennen.
	    screen -X screen -t ${BencherTitle}
	    screen -p ${BencherTitle} -X stuff "${cmd}"
	    # Warten, bis der Benchmarker gestartet ist...
	    benchPIDfile=.bench_30s_2_GPU#${gpu_idx}.pid
	    until [ -s ${benchPIDfile} ]; do sleep .01; done
	    # Warten, solange der Benchmarker läuft...
	    benchPID=$(< ${benchPIDfile})
	    #while [ -f ${benchPIDfile} -o $(ps -q ${benchPID} &>/dev/null; echo $?) -eq 0 ]; do sleep 1; done
	    while [ $(ps -q ${benchPID} &>/dev/null; echo $?) -eq 0 ]; do sleep 1; done
	    unset benchPID
	    screen -X eval only
	else
	    "${cmd}"
	fi
	echo "GPU #${gpu_idx}: ###---> Vom Auto-Benchmarking Algorithm/Miner ${algorithm} wieder zurück..."

	### $$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$
	### Die RÜCKGABEN UNTER SCREEN MÜSSEN ANDERS AUSGEWERTET WERDEN!!!
	### $$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$
	case $? in
	    94) # Internet Connection lost detected
		# Wenn das immer noch ist, sollte kein neuer Benchmarkversuch mehr gestartet werden
		if [[ -f ../I_n_t_e_r_n_e_t__C_o_n_n_e_c_t_i_o_n__L_o_s_t ]]; then
		    break
		fi
		;;
	esac
    done

    cd ${_WORKDIR_}
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

# Nach dem Aufruf dieser Funktion steht das Array WillBenchmarkAlgorithm mit den zu benchmarkenden Algorithms
# Diese Funktion wurde in die gpu-bENCH.inc verlegt, damit sie auch vom Benchmarker gerufen werden kann.
_find_algorithms_to_benchmark

### SCREEN ADDITIONS: ###
#if [ ${ScreenTest} -eq 0 ]; then
    #     ... und nimmt sich bei Bedarf aus dem System, um die Benchmarks durchzuführen
    if [ ${#WillBenchmarkAlgorithm[@]} -gt 0 ]; then
        DoAutoBenchmark=1

	_do_all_auto_benchmarks

        printf "GPU #${gpu_idx}: ###---> Going to take me back into the system, recognized as \"Enabled\"..."
        _enable_GPU_UUID_GLOBALLY ${gpu_uuid}
        printf " done\n"
        unset DoAutoBenchmark

	# Sicherheitshalber nach den Benchmarks beenden.
	# Automatische Benchmarks abgeschlossen.
	# Die GPU ist wieder enabled und wird beim nächsten multi_miner-Zyklus berücksichtigt.
	# Da es keine Datei gpu_gv-algo.pid mehr in diesem Verzeichnis gibt, startet der multi_miner das Script also wieder automatisch.
	exit 99
    fi
#fi

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

    #if [ ${#rtprio_set} -eq 0 ]; then
    #    ${LINUX_MULTI_MINING_ROOT}/.#rtprio# -f -p $(( ${RTPRIO_GPUgv} + ${gpu_idx} )) $$
    #    rtprio_set=1
    #fi

    # new_Data_available wurde direkt vor der Endlosschleife gesetzt oder gleich nach dem Herausfallen ganz unten
    # Wie alt das SYNCFILE maximal sein darf steht in der Variablen ${GPU_alive_delay}, in globals.inc gesetzt.
    SynSecs=$((${new_Data_available}+${GPU_alive_delay}))
    touch .now_$$
    read NOWSECS nowFrac <<<$(_get_file_modified_time_ .now_$$)
    rm -f .now_$$ ..now_$$.lock .ALGO_WATTS_MINES.in
    if [[ ${NOWSECS} -lt ${SynSecs} || (${NOWSECS} -eq ${SynSecs} && ${nowFrac} -le ${SynFrac}) ]]; then

        # (2018-01-23) Bisher konnten wir darauf verzichten.
        #_reserve_and_lock_file ${_WORKDIR_}/${GPU_ALIVE_FLAG}
        #echo "GPU #${gpu_idx}: ${NOWSECS}.${nowFrac} I recognized a newly written SYNCFILE and am willing to deliver data." \
        #    | tee ${_WORKDIR_}/${GPU_ALIVE_FLAG}
        #_remove_lock

        # Ist die Benchmarkdatei mit einer aktuellen Version überschrieben worden?
        #  2. Ruft _read_IMPORTANT_BENCHMARK_JSON_in falls die Quelldatei upgedated wurde.
        #                             => Aktuelle Arrays bENCH["AlgoName"] und WATTS["AlgoName"]
	#  2021-04-19:                => Array pleaseBenchmarkAlgorithm[]
        if [[ $IMPORTANT_BENCHMARK_JSON_last_age_in_seconds < $(date --utc --reference=$IMPORTANT_BENCHMARK_JSON +%s) ]]; then
            echo "GPU #${gpu_idx}: ###---> Updating Arrays bENCH[] and WATTs[] (and more) from $IMPORTANT_BENCHMARK_JSON"
            _read_IMPORTANT_BENCHMARK_JSON_in # without_miners
        fi

        # Die Reihenfolge der Dateierstellungen durch ../algo_multi_abfrage.sh ist:
        # (31.03.2021)
	#     1.: $algoID_KURSE__PAY__WEB="NH_PAYINGS.json"
	#     2.: $algoID_KURSE_PORTS_WEB="NH_PORTS.json"
	#     3.: $algoID_KURSE_PORTS_PAY="NH_PAYINGS.in"
        #     4.: $algoID_KURSE_PORTS_ARR="NH_PORTS.in"
        #     5.: ../BTC_EUR_kurs.in
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
	# 2021-05-01 - DOCH! Ist nötig! Denn:
	#              Nach dem Aufruf von _update_SELF_if_necessary und einem erzwungenen Update des Scripts sind alle im RAM befindlichen Variablen weg
	#              und müssen neu aufgebaut werden.
	#              Dazu dient vor allem auch die Datei MinerShell_STARTS_HISTORY sowie natürlich die Datei ${RUNNING_STATE}
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
                        #  4. ###WARTET### jetzt, bis die Datei "../NH_KURSE_PORTS.in" vorhanden und NICHT LEER ist.
                        until [ -s ${algoID_KURSE_PORTS_PAY} ]; do
                            echo "GPU #${gpu_idx}: ###---> Waiting for ${algoID_KURSE_PORTS_PAY} to become available..."
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
        ###############################################################################
	# Diese Funktion prüft die über die Dateien GLOBAL_, BENCH_ und MINER_ALGO_DISABLED disabled Coins/Algos/Algorithms
	# gegen das Array pleaseBenchmarkAlgorithm[], woars das Array WillBenchmarkAlgorithm[] hervorgeht.
	# Und das Array MINER_ALGO_DISABLED_ARR[${coin_algorithm}]} für temporär in den Berechnungen nicht zu beachtende coin_algorithm's
	_find_algorithms_to_benchmark

	#[ ${debug} -ge 1 ] && echo "\${#WillBenchmarkAlgorithm[@]} == ${#WillBenchmarkAlgorithm[@]}: ${WillBenchmarkAlgorithm[@]}"
        if [ ${#WillBenchmarkAlgorithm[@]} -gt 0 ]; then
            I_want_to_Disable_myself_for_AutoBenchmarking=1
            if [ ${debug} -eq 1 ]; then
                echo "GPU #${gpu_idx}: Anzahl vermisster Algos: ${#WillBenchmarkAlgorithm[@]} DisableMyself: ->$I_want_to_Disable_myself_for_AutoBenchmarking<-"
                declare -p WillBenchmarkAlgorithm
            fi
        fi

        # Mal sehen, ob es überhaupt schon Benchmarkwerte gibt oder ob Benchmarks nachzuholen sind.
        # Erst mal alle MiningAlgos ermitteln, die möglich sind und gegen die vorhandenen JSON Einträge checken.
        _set_Miner_Device_to_Nvidia_GpuIdx_maps
        _read_in_ALL_Mining_Available_and_Missing_Miner_Algo_Arrays
        _read_in_static_COIN_MININGALGO_SERVERNAME_PORT_from_Pool_Info_Array

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

	    # 2021-04-12: Implementierung der vom miningAlgo abhängigen Fees
	    miner_fee=0
	    [ ${#MINER_FEES[${MINER}]}               -gt 0 ] && miner_fee=${MINER_FEES[${MINER}]}
	    [ ${#MINER_FEES[${MINER}:${miningAlgo}]} -gt 0 ] && miner_fee=${MINER_FEES[${MINER}:${miningAlgo}]}

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
                                            && ${#SPEED[${coin}]}       -gt    0 \
                                            && ${#KURSE[${coin}]}       -gt    0 \
                                            && ${#PoolFee[${pool}]}     -gt    0 \
                                            && ${WATTS[${algorithm}]}   -lt 1000 \
                                    ]]; then

                                    # "Mines" in BTC berechnen
				    # Diese Zahl 100000000, durch die hier geteilt wird oder mit dessen Kehrwert 0.00000001 multipliert werden muss...
				    # ... diese Zahl ist dem Sourcecode eines Windows-Switscher entnommen UND ANGEPASST WORDEN.
				    # Denn die Zahl im Windows-Switcher-Sourcecode ist um eine 10er-Potenz höher, also 1000000000 bzw. 0.000000001
				    # Das liegt möglicherweise daran, dass der Switcher dseine Daten von einer ANDEREN Nicehash-Seite abruft.
				    # Mehr Details dazu in der README_GER.md
				    algoMines=$(echo "scale=20;   ${bENCH[${algorithm}]}  \
                                                           * ${KURSE[${coin}]}  \
                                                           / 100000000  \
                                                           * ( 100 - "${PoolFee[${pool}]}" )     \
                                                           * ( 100 - "${miner_fee}" ) \
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

				    if [ ${debug} -eq 1 ]; then
					echo "\${bENCH[${algorithm}]}: ${bENCH[${algorithm}]}"
					echo "\${coin}: ${coin}"
					echo "\${SPEED[${coin}]}: ${SPEED[${coin}]}"
					echo "\${KURSE[${coin}]}: ${KURSE[${coin}]}"
                                        echo "\${PoolFee[${pool}]}: ${PoolFee[${pool}]}"
                                        echo "\${miner_fee}: ${miner_fee}"
				    fi

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
                                            && ${WATTS[${algorithm}]}       -lt 1000 \
                                    ]]; then
                                    # "Mines" in BTC berechnen
                                    algoMines=$(echo "scale=20;   86400 * ${BlockReward[${coin}]} * ${Coin2BTC_factor[${coin}]}   \
                                                           / ( ${BlockTime[${coin}]} * (1 + ${CoinHash[${coin}]} / ${bENCH[${algorithm}]}) ) \
                                                           * ( 100 - "${PoolFee[${pool}]}" )     \
                                                           * ( 100 - "${miner_fee}" ) \
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
    else
        echo "GPU #${gpu_idx}: Was too late. SYNCFILE older than ${GPU_alive_delay} seconds"
    fi

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
				if [ ${UseScreen} -eq 1 ]; then
				    _terminate_MinerShell_and_logger_terminal
				else   # Diese Methode kann und sollte komplett entfernt werden, wenn das mit der Befehls-Historie klappt
                                    kill $(< ${StopShell}.ppid)
				fi
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
			#################################################################################
			### ${IamEnabled} -eq 1
			### "${WasItEnabled[${gpu_uuid}]}" == "1"
			### -n "${RuningAlgo}"
			### "${RuningAlgo}" == "${WhatsRunning[${gpu_uuid}]}"
			### => Nichts muss geändert werden. Miner läuft und soll weiterlaufen.
			#################################################################################
                        if [ -f ${MinerShell}.ppid -a -f ${MinerShell}.pid ]; then
                            echo "Nichts muss geändert werden. Minershell läuft (beide .p?id's vorhanden) und SOLL weiterlaufen. Es folgen Konsistenzchecks..."
                            if [ "$(< ${MinerShell}.ppid)" != "$(< ${MinerShell}.pid)" ]; then
                                echo "--->INKONSISTENZ ENTDECKT: Alles deutet darauf, dass die MinerShell ${MinerShell}.sh noch läuft."
                                echo "--->Die Datei ${MinerShell}.ppid ($(< ${MinerShell}.ppid)) sowie ${MinerShell}.pid ($(< ${MinerShell}.pid)) enthalten aber UNTERSCHIEDLICHE PIDs ???"
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
			    if [ ${UseScreen} -eq 1 ]; then
				run_pid=0
				if [ -s MinerShell_STARTS_HISTORY ]; then
				    # Setzt run_pid, filed_pd, MinerShell_CMD
				    _get_running_MinerShell_pid_from_ptable
				fi
			    else   # Diese Methode kann und sollte komplett entfernt werden, wenn das mit der Befehls-Historie klappt
				run_pid=$(ps -ef | gawk -e '$2 == '${MinerShell_pid}' && /'${gpu_uuid}'/ {print $2; exit }')
			    fi
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
				    mv -f MinerShell_STARTS_HISTORY MinerShell_STARTS_HISTORY.BAK &>/dev/null
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
			if [ ${UseScreen} -eq 1 ]; then
			    _terminate_MinerShell_and_logger_terminal
			else   # Diese Methode kann und sollte komplett entfernt werden, wenn das mit der Befehls-Historie klappt
                            kill ${StopShell_pid}
			fi
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
			if [ ${UseScreen} -eq 1 ]; then
			    _terminate_MinerShell_and_logger_terminal
			else   # Diese Methode kann und sollte komplett entfernt werden, wenn das mit der Befehls-Historie klappt
                            kill $(< ${StopShell}.pid)
			fi
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
		    mv -f MinerShell_STARTS_HISTORY MinerShell_STARTS_HISTORY.BAK &>/dev/null

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
                    printf "and there is still NOTHING to start."
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
            # weil keine Elemente in der Liste/Array WillBenchmarkAlgorithm[@] mehr drin sind.
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

	    _do_all_auto_benchmarks

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
            [[ -f ${LINUX_MULTI_MINING_ROOT}/MINER_ALGO_DISABLED ]] \
                && suddenly_disabled=$(grep -E -c -m1 -e "\b${coin_algorithm%#888}([^.\W]|$)" ${LINUX_MULTI_MINING_ROOT}/MINER_ALGO_DISABLED)
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
                readarray -n 0 -O 0 -t READARR <${LINUX_MULTI_MINING_ROOT}/MINER_ALGO_DISABLED
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
		mv -f MinerShell_STARTS_HISTORY MinerShell_STARTS_HISTORY.BAK &>/dev/null
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
                #[[ "${miner_name}" == "zm" && $((gpu_idx%2)) -eq 0 ]] && continent="br"

                printf -v worker "%02i${gpu_uuid:4:6}" ${gpu_idx}

                _setup_Nvidia_Default_Tuning_CmdStack
                cmdParameterString=""
                for ((cmd=0; cmd<${#CmdStack[@]}; cmd++)); do
                    cmdParameterString+="${CmdStack[${cmd}]// /°} "
                done
		shopt -s extglob
		cmdParameterString="${cmdParameterString%%*( )}"
                
                echo "GPU #${gpu_idx}: STARTE Miner Shell ${MinerShell}.sh und übergebe Algorithm ${coin_algorithm} und mehr..."
                cp -f ../GPU-skeleton/MinerShell.sh ${MinerShell}.sh


		# Die Umleitungen sind NICHT Bestandteil des Kommandos in der Prozesstabelle
		p_cmd="./${MinerShell}.sh \
${coin_algorithm} \
${gpu_idx} \
${continent} \
${algo_port} \
${worker} \
${gpu_uuid} \
${domain} \
${server_name} \
${miner_gpu_idx["${miner_name}#${miner_version}#${gpu_idx}"]} \
$cmdParameterString"
		p_cmd="${p_cmd%%*( )}"
		shopt -u extglob

		m_cmd="${p_cmd} >>${MinerShell}.log"

		# Das Kommando p_cmd, wie es in der Prozesstabelle stehen wird, muss hier festgehalten werden, damit wir es mit pgrep finden können.
		#     Leider wird es, bis in der Prozesstabelle landet, noch ein bisschen durch die Shell verändert.
		#     Das muss hier vorhergesehen werden, damit der String p_cmd als Regexp-Pattern für das Kommando pgrep dienen kann.
		# Die "[]" kommen in den nvidia-commands vor und müssen in einem Regex-Pattern escaped werden
		p_cmd="${p_cmd//[/\\[}"
		p_cmd="${p_cmd//]/\\]}"
		# Beschissene Ausnahme wegen des "nh" Pools, in dem $continent drin steht, obwohl es nicht gebraucht wird,
		# da der server_name durch die Funktion PREP_LIVE_PARAMETERSTACK ()
		p_cmd="${p_cmd//\$continent/}"

		if [ ${RT_PRIORITY[${ProC}]} -gt 0 ]; then
		    cmd="${LINUX_MULTI_MINING_ROOT}/.#rtprio# ${RT_POLICY[${ProC}]} ${RT_PRIORITY[${ProC}]}"
		else
		    echo "Starting soon ${MinerShell}.sh with Nice-Value" ${NICE[${ProC}]}
		    cmd="${LINUX_MULTI_MINING_ROOT}/.#nice# --adjustment=${NICE[${ProC}]}"
		fi

		### SCREEN ADDITIONS: ###
		if [ ${UseScreen} -eq 1 ]; then
		    cmd="${cmd} ${m_cmd}"'\nexit\n'
		    echo "cmd == ${cmd}"

		    MinerShell_RUN_title="MSh#${gpu_idx}"
		    screen -drx ${BG_SESS} -X screen -t ${MinerShell_RUN_title}
		    screen -drx ${BG_SESS} -p ${MinerShell_RUN_title} -X stuff "cd ${LINUX_MULTI_MINING_ROOT}/${gpu_uuid}\n"
		    screen -drx ${BG_SESS} -p ${MinerShell_RUN_title} -X stuff "${cmd}"
		    until [ -s ${MinerShell}.pid ]; do sleep .02; done
		    read _ppid_ _p_cmd_ <<<$(pgrep -f -a "${p_cmd}")
		    if [ ${_ppid_} -eq $(< ${MinerShell}.pid) ]; then
			_epoch_=$(date --utc +%s)
			printf -v to_cmd_history "%s %5d %s" ${_epoch_} ${_ppid_} "${_p_cmd_}"
			echo ${_ppid_} >${MinerShell}.ppid
			echo "${to_cmd_history}" >>MinerShell_STARTS_HISTORY
			cat MinerShell_STARTS_HISTORY
		    else
                        echo "--->      !!!      K R I T I S C H      !!!      <---"
                        echo "--->Probleme mit Prozessstart unter GNU screen:"
                        echo "--->Das in der BG-SESS ${BG_SESS} und oben ausgegebene abgesetzte Kommando hat seine .pid Datei mit folgendem Inhalt erstellt: \"${MinerShell}.pid\""
                        echo "--->Ds wurde abgewartet und per pgrep eine Bestätigung gesucht mit folgendem Kommando:"
			echo "--->pgrep -f -a "${p_cmd}
                        echo "--->Folgendes ist dabei herausgekommen: \$_ppid_ == \"$_ppid_\""
                        echo "--->Und \$_p_cmd_ == \"$_p_cmd_\""
                        echo "--->Es erfolgt jetzt ein Abbruch, bis dieses Probem gelöst ist."
                        echo ""
			exit
		    fi

		    # Jetzt noch das Logfile im Vordergrund anzeigen
		    LOG_PTY_CMD="tail -f ${LINUX_MULTI_MINING_ROOT}/${gpu_uuid}/${MinerShell}.log"
		    cmd="${LOG_PTY_CMD}"'\nexit\n'
		    MinerShell_LOG_title="MShLOG#${gpu_idx}"
		    screen -X screen -t ${MinerShell_LOG_title}
		    screen -p ${MinerShell_LOG_title} -X stuff "cd ${LINUX_MULTI_MINING_ROOT}/${gpu_uuid}\n"
		    screen -p ${MinerShell_LOG_title} -X stuff "${cmd}"
		    screen -X other
		    #echo "${LOG_PTY_CMD}" >.pgrep.pattern
		    #pgrep -f -a "${LOG_PTY_CMD}" | tee .pgrep.out
		    log_pid=$(pgrep -f "${LOG_PTY_CMD}")
		    until [[ -n "${log_pid}" && ${log_pid} > 1 ]]; do sleep .02; log_pid=$(pgrep -f "${LOG_PTY_CMD}"); done
		    printf -v to_pty_log "%s %5d %s" ${_epoch_} ${log_pid} "${LOG_PTY_CMD}"
		    echo "${to_pty_log}" >>MinerShell_LOG_PTY_CMD
		    cat MinerShell_LOG_PTY_CMD

		else
		    "${cmd} ${m_cmd}" &
                    echo $! >${MinerShell}.ppid
		fi
            fi
        fi
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
    while (( ${new_Data_available} == $(date --utc --reference=${SYNCFILE} +%s) )) ; do
        sleep 1
    done
    #  9. Merkt sich das neue "Alter" von ${SYNCFILE} in der Variablen ${new_Data_available}
    read new_Data_available SynFrac <<<$(_get_file_modified_time_ ${SYNCFILE})
    
done
