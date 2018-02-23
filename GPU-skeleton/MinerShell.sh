#!/bin/bash
###############################################################################
# 
# Wir wollen einen ganz bestimmten, übergebenen Miner starten und sein Logfile prüfen,
#     um ihn bei Bedarf selbst wieder abzustellen
# Dieses Skript geht davon aus, dass es von gpu_gv-algo.sh in einem GPU-UUID Verzeichnis gestartet wurde.
# Dieses Skript läuft - sofern keine Abbruchbedingung festgestellt wird -
#     BIS ES DURCH DEN INITIIERENDEN gpu_gv-algo.sh WIEDER GESTOPPT WIRD!
# 
# Die folgenden Variablen müssen alle bekannt sein, wenn wir ALLE Miner erfolgreich starten wollen,
#     denn manche haben unterschiedliche Parameternamen.
#     WIR MÜSSEN DIESE VARIABLENNAMEN ALLE KENNEN UND ZUR VERFÜGUNG STELLEN!
#
#LIVE_PARAMETERSTACK=(
#    "minerfolder"
#    "miner_name"
#    "server_name"
#    "algo_port"
#    "user_name"
#    "worker"
#    "password"
#    "gpu_idx"
#    "miningAlgo"
#    "miner_device"
#    "LIVE_LOGFILE"
#)

# GLOBALE VARIABLEN, nützliche Funktionen
[[ ${#_GLOBALS_INCLUDED}     -eq 0 ]] && source ../globals.inc
[[ ${#_LOGANALYSIS_INCLUDED} -eq 0 ]] && source ../logfile_analysis.inc

# Das Prioritätenkürzel für die MINER.
# Kann hier global gesetzt werden, weil nur der Miner aus diesem Skript gestartet wird
ProC="mi"

# Wenn debug=1 ist, werden die temporären Dateien beim Beenden nicht gelöscht.
debug=1

# Auch diese Messung hat ergeben, dass die MinerShell, gerufen von gpu_gv-algo.sh, gerufen von multi_mining_calc.sh
# zu der selben Prozessgruppe gehört wie der Multi_Miner !
#  PID  PGID   SID TTY          TIME CMD
# 9462  9462  1903 pts/0    00:00:00 multi_mining_ca
#echo "MinerShell $(basename $0) gehört zu folgender Prozess-Gruppe:"
#ps -j --pid $$
#echo "Die Prozessgruppe, die der MULTI_MINER eröffnet hat, hat die PID == PGID == ${MULTI_MINERS_PID}"

####################################################################################
################################################################################
###
###                        1. Parameter entgegen nehmen
###
################################################################################
####################################################################################
coin_algorithm=$1
read coin pool miningAlgo miner_name miner_version muck888 <<<${coin_algorithm//#/ }
gpu_idx=$2
continent=$3
algo_port=$4
worker=$5
gpu_uuid=$6
domain=$7
server_name=$8
miner_device=$9
# Rest ist Nvidia GPU Default Tuning CmdStack
shift 9
# So funktioniert das vielleicht nicht, weil Spaces im Command-String sind.
#command_string=$*
command_string="$*"
read -a CmdStack <<<"${command_string}"
declare -i i
for (( i=0; $i<${#CmdStack[@]}; i++ )); do
    CmdStack[$i]=${CmdStack[$i]//;/ }
done

[[ ${#_GPU_BENCH_INCLUDED}   -eq 0 ]] && source ${LINUX_MULTI_MINING_ROOT}/${gpu_uuid}/gpu-bENCH.inc

# ACHTUNG: Die #888 - falls vorhanden - wird hier drin nicht benötigt!
#          Wir haben alle Daten inclusive der GPU-Einstellungen in den Parametern übergeben bekommen
# Das bedeutet ausserdem, dass in der ../MINER_ALGO_DISABLED auch KEINE #888 entahlten sind!!!
#
MINER=${miner_name}#${miner_version}
algorithm=${miningAlgo}#${MINER}
coin_algorithm=${coin}#${pool}#${algorithm}

_init_some_file_and_path_variables
_init_NH_continent_handling

# Dieser Aufruf zieht die entsprechenden Variablen rein, die für den Miner
# definiert sind, damit die Aufrufmechanik für alle gleich ist.
source ../miners/${MINER}.starts

# Ein paar Standardverzeichnisse im GPU-UUID Verzeichnis zur Verbesserung der Übersicht:
[[ ! -d live ]]                        && mkdir live
[[ ! -d live/${MINER} ]]               && mkdir live/${MINER}
[[ ! -d live/${MINER}/${miningAlgo} ]] && mkdir live/${MINER}/${miningAlgo}

LOGPATH="live/${MINER}/${miningAlgo}"
BENCHLOGFILE="${LINUX_MULTI_MINING_ROOT}/${gpu_uuid}/live/${MINER}_${miningAlgo}_mining.log"
# Einer der letzten zu setzenden Parameter für den Parameterstack des equihash "miner"
LIVE_LOGFILE=${BENCHLOGFILE}
if [ ${NoCards} ]; then
    # Der equihash "miner" arbeitet nur auf test-Systemen ohne Karten auch im Benchmark-Modus
    BENCH_LOGFILE=${BENCHLOGFILE}
fi


_build_minerstart_commandline () {
    # ---> Die folgenden Variablen müssen noch vollständig implementiert werden! <---
    # "LOCATION eu, usa, hk, jp, in, br"  <--- von der Webseite https://www.nicehash.com/algorithm
    # Wird übergeben, aber:# Noch nicht vollständig implementiert!      <--------------------------------------
    #continent="eu"        # Noch nicht vollständig implementiert!      <------- NiceHash ONLY ----------------
    #worker="%02i${gpu_uuid:4:6}" ${gpu_idx}

    # Diese Funktion musste leider erfunden werden wegen der internen anderen Algonamen,
    # die NiceHash willkürlich anders benannt hat.
    # So rufen wir eine Funktion, wenn sie definiert wurde.
    declare -f PREP_LIVE_PARAMETERSTACK &>/dev/null && PREP_LIVE_PARAMETERSTACK
    PARAMETERSTACK=""
    for (( i=0; $i<${#LIVE_PARAMETERSTACK[@]}; i++ )); do
        declare -n param="${LIVE_PARAMETERSTACK[$i]}"
        PARAMETERSTACK+="${param} "
    done

    # JETZT KOMMT DAS KOMPLETTE KOMMANDO ZUM STARTEN DES MINERS IN DIE VARIABLE ${minerstart}
    printf -v minerstart "${LIVE_START_CMD}" ${PARAMETERSTACK}
}


####################################################################################
################################################################################
###
###                        2. Prozesse sauber (beginnen) und beenden
###
################################################################################
####################################################################################



_delete_temporary_files () {
    [[ -n "${MINER}" ]] && rm -f ${MINER}.retry ${MINER}.booos
}
_delete_temporary_files
rm -f ${BENCHLOGFILE}


_On_Exit () {
    echo $(date "+%Y-%m-%d %H:%M:%S" ) $(date +%s) "MinerShell ${This}: _On_Exit() ENTRY, CLEANING UP RESOURCES NOW..."

    _terminate_Logger_Terminal

    _terminate_Miner

    # Auf jeden Fall das LOGFILE aufheben... nach möglichen anderen Abgebrochenen als ULTIMATIVES dieses Zyklus
    cp -f ${BENCHLOGFILE} ${LOGPATH}/$(date "+%Y%m%d_%H%M%S")_mining.log

    if [ $debug -eq 0 ]; then
        _delete_temporary_files
    fi
    rm -f ${This}.pid
}
trap _On_Exit EXIT

# Aktuelle eigene PID merken
This=$(basename $0 .sh)
echo $$ >${This}.pid


declare -i secs=0
declare -i hashCount=0


####################################################################################
################################################################################
###
###                        3. GPU-Kommandos anzeigen und absetzen...
###
################################################################################
####################################################################################

echo   ""
echo   ${nowDate} ${nowSecs}
echo   "Kurze Zusammenfassung:"
echo   "GPU #${gpu_idx} mit UUID ${gpu_uuid} soll gestartet werden."
echo   "Das ist der Miner,           der ausgewählt ist : ${miner_name} ${miner_version}"
echo   "das ist der Coin,            der ausgewählt ist : ${coin}"
printf "das ist der \$coin_algorithm, der ausgewählt ist : ${coin_algorithm}"
[[ ${#muck888} -gt 0 ]] && printf "#${muck888}"
printf "\n"
[ "${miningAlgo}" != "${coin}" ] && echo "Das ist der Miner-Berechnungs Algorithmus...... : ${miningAlgo}"
echo   ""
echo   "DIE FOLGENDEN NVIDIA GPU KOMMANDOS WERDEN ABGESETZT:"
for (( i=0; $i<${#CmdStack[@]}; i++ )); do
    echo "---> ${CmdStack[$i]} <---"
done

# GPU-Kommandos absetzen...
touch .now_$$
read NOWSECS nowFrac <<<$(_get_file_modified_time_ .now_$$)
#rm -f .now_$$ ..now_$$.lock
printFrac="0000000000"${nowFrac}
zeitstempel_t0=${NOWSECS}.${printFrac:$((${#printFrac}-10))}
echo $(date -d "@${NOWSECS}" "+%Y-%m-%d %H:%M:%S" ) ${zeitstempel_t0} \
     "GPU #${gpu_idx}: ZEITMARKE t0: Absetzen der NVIDIA-Commands" | tee -a ${ERRLOG} ${BENCHLOGFILE}
for (( i=0; $i<${#CmdStack[@]}; i++ )); do
    ${CmdStack[$i]} | tee -a ${BENCHLOGFILE}
done

#if [ $NoCards ]; then
#    if [ ! -f "${BENCHLOGFILE}" ]; then
#        # cp ../benchmarking/test/benchmark_blake256r8vnl_GPU-742cb121-baad-f7c4-0314-cfec63c6ec70.fake ${BENCHLOGFILE}
#        cp ../benchmarking/test/bnch_retry_catch_fake.log ${BENCHLOGFILE}
#        # cp ../booos ${BENCHLOGFILE}
#    fi
#fi  ## $NoCards


####################################################################################
################################################################################
###
###                        4. Eintritt in die Endlosschleife
###
################################################################################
####################################################################################

declare -i inetLost_detected=0
while :; do
    if [[ -f ../I_n_t_e_r_n_e_t__C_o_n_n_e_c_t_i_o_n__L_o_s_t ]]; then
        echo $(date "+%Y-%m-%d %H:%M:%S" ) $(date +%s) \
             "GPU #${gpu_idx}: ${This}.sh: Abbruch des Miners PID ${MINER_pid} alias ${coin_algorithm} wegen NO INTERNET..." \
            | tee -a ${LOG_CONLOSS_ALL} ${LOG_CONLOSS} ${ERRLOG} ${BENCHLOGFILE}
        break
    fi

    ################################################################################
    ###
    ###          Miner Starten und Logausgabe in eigenes Terminal umleiten
    ###
    ###
    ################################################################################

    if [ ! -f ${MINER}.pid ]; then
        _build_minerstart_commandline

        touch .now_$$
        read NOWSECS nowFrac <<<$(_get_file_modified_time_ .now_$$)
        rm -f .now_$$ ..now_$$.lock
        printFrac="0000000000"${nowFrac}
        zeitstempel_t1=${NOWSECS}.${printFrac:$((${#printFrac}-10))}
        echo $(date -d "@${NOWSECS}" "+%Y-%m-%d %H:%M:%S" ) ${zeitstempel_t1} \
             "GPU #${gpu_idx}: ZEITMARKE t1: Starting Miner alias ${coin_algorithm} with the following command line:" \
            | tee -a ${ERRLOG} ${BENCHLOGFILE}
        echo ${minerstart}

        if [ ${RT_PRIORITY[${ProC}]} -gt 0 ]; then
            ${LINUX_MULTI_MINING_ROOT}/.#rtprio# ${RT_POLICY[${ProC}]} ${RT_PRIORITY[${ProC}]} \
                                      ${minerstart} > >(tee -a ${BENCHLOGFILE}) 2> >(tee -a ${BENCHLOGFILE} >&2) &
        else
            ${LINUX_MULTI_MINING_ROOT}/.#nice# -n ${NICE[${ProC}]} \
                                      ${minerstart} > >(tee -a ${BENCHLOGFILE}) 2> >(tee -a ${BENCHLOGFILE} >&2) &
        fi
        echo $! | tee ${MINER}.pid
        MINER_pid=$(< ${MINER}.pid)
        Bench_Log_PTY_Cmd="tail -f ${BENCHLOGFILE}"
        gnome-terminal --hide-menubar \
                       --title="GPU #${gpu_idx}  -  Mining ${coin_algorithm}" \
                       -e "${Bench_Log_PTY_Cmd}"
        echo $(date "+%Y-%m-%d %H:%M:%S" ) $(date +%s) "Miner and Logging gnome-terminal are running since here."
        if [ $debug -eq 1 ]; then
            REGEXPAT="${Bench_Log_PTY_Cmd//\//\\/}"
            REGEXPAT="${REGEXPAT//\+/\\+}"
            kill_pids=$(ps -ef \
                       | grep -E -e "${REGEXPAT}" \
                       | grep -v 'grep -E -e ' \
                       | gawk -e 'BEGIN {pids=""} {pids=pids $2 " "} END {print pids}')
            echo "Terminal PID: $kill_pids"
        fi
    fi

    ################################################################################
    ###
    ###          Logfile auf Abbruchbedingungen hin überwachen,
    ###          Hashwerte nachsehen und zählen
    ###
    ################################################################################

    # ---> Noch zu implementieren:
    #      Hash/Sol/s messen (einige Werte oder eine besimmte Zeit lang) und mit dem Wert in der benchmark_JSON vergleichen.
    #      x% Abweichung sind erlaubt.
    # ---> Noch zu implementieren:
    
    touch ${MINER}.retry.lock ${MINER}.booos.lock ${MINER}.overclock.lock
    hashCount=$(cat ${BENCHLOGFILE} \
                       | tee >(grep -c -m1 -e "${CONEXPR//[|]/\\|}" >${MINER}.retry; \
                               rm -f ${MINER}.retry.lock) \
                             >(gawk -v YES="${YESEXPR}" -v BOO="${BOOEXPR}" -e '
                                   BEGIN { yeses=0; booos=0; seq_booos=0 }
                                   $0 ~ BOO { booos++; seq_booos++; next }
                                   $0 ~ YES { yeses++; seq_booos=0;
                                               if (match( $NF, /[+*]+/ ) > 0)
                                                  { yeses+=(RLENGTH-1) }
                                            }
                                   END { print seq_booos " " booos " " yeses }' >${MINER}.booos; \
                               rm -f ${MINER}.booos.lock) \
                             >(grep -c -m1 -e "${OVREXPR//[|]/\\|}" >${MINER}.overclock; \
                               rm -f ${MINER}.overclock.lock) \
                  | sed -e 's/ *(yes!)$//g' \
                  | gawk -e "${detect_zm_hash_count}" \
                  | grep -E -c "/s *$")
    while [[ -f ${MINER}.retry.lock || -f ${MINER}.booos.lock || -f ${MINER}.overclock.lock ]]; do sleep .01; done

    ################################################################################
    ###
    ###          1. ABBRUCHBEDINGUNG:       "VERBINDUNG ZUM SERVER VERLOREN"
    ###          Ist vor dem endgültigen Abbruch der "continent" zu wechseln?
    ###
    ################################################################################

    # Check Overclocking
    if [[ $(< ${MINER}.overclock) -eq 1 ]]; then
        # Overclockings zählen ?
        # Miner abbrechen und neu starten?
        # Algo für 5 Minuten deaktivieren für diese Karte
        :
    fi

    if [[ $(< ${MINER}.retry) -eq 1 ]]; then
        echo "GPU #${gpu_idx}: Connection loss detected..."
        if [[ -f ../I_n_t_e_r_n_e_t__C_o_n_n_e_c_t_i_o_n__L_o_s_t ]]; then
            let inetLost_detected++
            continue
        fi
        nowDate=$(date "+%Y-%m-%d %H:%M:%S" )
        nowSecs=$(date +%s)
        if [ $inetLost_detected -gt 0 ]; then
            # Das Internet war mal kurzzeitig weg und vermutlich die Ursache für den Server-Abbruch.
            # In diesem Fall brauchen wir den Server nicht zu wechseln, sondern können den Miner mit denselben
            # Einstellungen einfach neu starten, um die von ihm selbst gewählte Wartezeit von 30s abzukürzen.
            _terminate_Logger_Terminal
            _terminate_Miner

            ################################################################################
            ###
            ###          Neustart mit selbem "continent"
            ###
            ################################################################################

            # Vielleicht noch das ${BENCHLOGFILE} sichern vor dem Überschreiben zur "Beweissicherung"
            # In diesem Fall können wir nicht weiter anhängen, weil sonst immer noch der "RETRY" im Logfile steht,
            # was wiederum zum sofortigen Abbruchsversuch führen würde.
            cat ${BENCHLOGFILE} >>${LOGPATH}/$(date "+%Y%m%d_%H%M%S")_mining_ABORTED.log

            # BENCHLOGFILE neu beginnen...
            echo ${nowDate} ${nowSecs} \
                 "GPU #${gpu_idx}: Neustart des Miners alias ${coin_algorithm} nach Internet-Verbindungsfehler..." \
                | tee -a ${LOG_CONLOSS_ALL} ${LOG_CONLOSS} ${ERRLOG} \
                      >${BENCHLOGFILE}
            inetLost_detected=0
            continue
        else
            case "${pool}" in

                "nh")
                    # Wechsel des "continent" bzw. der LOCATION und Neustart des Miners sind ERFORDERLICH
                    #   ODER Abbruch, wenn ALLE Verbindungs-Wechsel nicht funktioniert haben.

                    # Erst mal: Einstellung des Zeigers auf die vermeintlich nächste Location ohne Gewähr...
                    let location_ptr=$((++location_ptr%${#LOCATION[@]}))

                    # Abbruchbedingung
                    # Also: Sind wir schon alle "continents" durchgegangen und stehen wir daher - nach der Erhöhung -
                    #       auf dem selben $location_ptr, von dem wir ursprüngöich (initial) ausgegangen sind?
                    if [ $location_ptr -eq $initial_location_ptr ]; then

                        ################################################################################
                        ###
                        ###          ENDGÜLTIGER Abbruch, alle "continent"e durchgegangen ohne Erfolg
                        ###
                        ################################################################################

                        # Ausserdem wollen wir, wenn wir in diesem Lebenszyklus ALLE durchgegangen sind
                        # wieder mit dem Besten beginnen, denn dann war ganz grob was faul
                        if [ $location_ptr -ne 1 ]; then   # Ist location_ptr jetzt auf 1, dann steht die 0 schon in der Datei.
                            # In allen anderen Fällen setzen wir ihn auf 0 == "eu"
                            location_ptr=0
                            continent=${LOCATION[${location_ptr}]}
                            echo "# Keiner war erreichbar, deshalb nextes mal von vorne mit dem Besten..." >>${CONTINENTFILE}
                            echo ${nowDate} ${nowSecs} ${location_ptr} ${continent}                        >>${CONTINENTFILE}
                        fi

                        # Algo in die 5-Minuten-Disabled Datei UND in die HISTORY/CHRONIK Datei eintragen...
                        _disable_algo_for_5_minutes

                        # Miner-Abbrüche protokollieren nach bisher 3 Themen getrennt
                        echo ${nowDate} ${nowSecs} \
                             "GPU #${gpu_idx}: BEENDEN des Miners alias ${coin_algorithm} wegen NiceHash Servers WORLDWIDE unavailable." \
                            | tee -a ${LOG_CONLOSS_ALL} ${LOG_CONLOSS} ${ERRLOG} ${BENCHLOGFILE}
                        break

                    else
                        ################################################################################
                        ###
                        ###          Abbruch des nicht mehr funktioierenden "continent"
                        ###
                        ################################################################################
                        echo ${nowDate} ${nowSecs} "GPU #${gpu_idx}: Abbruch des Miners PID ${MINER_pid} alias ${coin_algorithm}..." \
                            | tee -a ${LOG_CONLOSS_ALL} ${LOG_CONLOSS} ${ERRLOG} ${BENCHLOGFILE}
                        _terminate_Logger_Terminal
                        _terminate_Miner
                        # Vielleicht noch das ${BENCHLOGFILE} sichern vor dem Überschreiben zur "Beweissicherung"
                        cat ${BENCHLOGFILE} >>${LOGPATH}/$(date "+%Y%m%d_%H%M%S")_mining_ABORTED_BEFORE_RESTART.log

                        ################################################################################
                        ###
                        ###          Neuer "continent"
                        ###
                        ################################################################################

                        continent=${LOCATION[${location_ptr}]}

                        nowDate=$(date "+%Y-%m-%d %H:%M:%S" )
                        nowSecs=$(date +%s)
                        echo "# Neuer Continent \"$continent\" nach Verbindungsabbruch des ${coin_algorithm}" >>${CONTINENTFILE}
                        echo ${nowDate} ${nowSecs} ${location_ptr} ${continent}                               >>${CONTINENTFILE}

                        # BENCHLOGFILE neu beginnen...
                        echo ${nowDate} ${nowSecs} \
                             "GPU #${gpu_idx}: ... und Neustart des Miners alias ${coin_algorithm} nach Continent-Wechsel zu \"${continent}\"..." \
                            | tee -a ${LOG_CONLOSS_ALL} ${LOG_CONLOSS} ${ERRLOG} \
                                  >${BENCHLOGFILE}
                        if [ $NoCards ]; then
                            cat ../benchmarking/test/bnch_retry_catch_fake.log >>${BENCHLOGFILE}
                        fi  ## $NoCards
                        continue
                    fi
                    ;;

                "mh"|"sn")
                    # Abbruch des Miners nach disablen des Algos
                    # Algo in die 5-Minuten-Disabled Datei UND in die HISTORY/CHRONIK Datei eintragen...
                    _disable_algo_for_5_minutes

                    # Miner-Abbrüche protokollieren nach bisher 3 Themen getrennt
                    echo ${nowDate} ${nowSecs} \
                         "GPU #${gpu_idx}: BEENDEN des Miners alias ${coin_algorithm} wegen dem Verlust der Server-Connection." \
                        | tee -a ${LOG_CONLOSS_ALL} ${LOG_CONLOSS} ${ERRLOG} ${BENCHLOGFILE}
                    break
                    ;;
            esac
        fi
    fi

    ################################################################################
    ###
    ###          2. ABBRUCHBEDINGUNG:       "ZU VIELE BOOOOS"
    ###          Ist vor dem endgültigen Abbruch der "continent" zu wechseln?
    ###
    ################################################################################

    read booos sum_booos sum_yeses <<<$(< ${MINER}.booos)
    if [[ ${booos} -ge 10 ]]; then
        nowDate=$(date "+%Y-%m-%d %H:%M:%S" )
        nowSecs=$(date +%s)

        # Algo in die 5-Minuten-Disabled Datei UND in die HISTORY/CHRONIK Datei eintragen...
        _disable_algo_for_5_minutes

        # Miner-Abbrüche protokollieren nach bisher 3 Themen getrennt
        echo ${nowDate} ${nowSecs} \
             "GPU #${gpu_idx}: Abbruch des Miners PID ${MINER_pid} alias ${coin_algorithm} wegen zu vieler 'booooos'..." \
            | tee -a ${LOG_BOOOOOS} ${LOG_BOOOOOS_ALL} ${ERRLOG} ${BENCHLOGFILE}
        break
    elif [[ ${booos} -ge 5 ]]; then
        echo "GPU #${gpu_idx}: Miner alias ${coin_algorithm} gibt bereits ${booos} 'booooos' hintereinander von sich..."
        if [ $NoCards ]; then
            [[ $(($secs%3)) -gt 0 ]] && \
                echo "#[2017-11-20 18:00:37] accepted: 0/12 (diff 9.171), 1648.05 MH/s (booooo)" >>${BENCHLOGFILE}
        fi
    else
        if [ $NoCards ]; then
            [[ $(($secs%3)) -gt 0 ]] && \
                echo "#[2017-11-20 18:00:37] accepted: 0/12 (diff 9.171), 1648.05 MH/s (booooo)" >>${BENCHLOGFILE}
        fi
    fi


    ################################################################################
    ###
    ###          3. ABBRUCHBEDINGUNG:       "KEINE HASHWERTE NACH 90 SEKUNDEN"
    ###          Ist vor dem endgültigen Abbruch der "continent" zu wechseln?
    ###
    ################################################################################

    if [[ ${hashCount} -eq 0 ]] && [[ ${secs} -ge 320 ]]; then
        nowDate=$(date "+%Y-%m-%d %H:%M:%S" )
        nowSecs=$(date +%s)

        # Algo in die 5-Minuten-Disabled Datei UND in die HISTORY/CHRONIK Datei eintragen...
        _disable_algo_for_5_minutes

        # Miner-Abbrüche protokollieren nach bisher 3 Themen getrennt
        echo ${nowDate} ${nowSecs} \
             "GPU #${gpu_idx}: Abbruch des Miners PID ${MINER_pid} alias ${coin_algorithm} wegen 320s ohne Hashwerte." \
            | tee -a ../log_No_Hash log_No_Hash_${coin_algorithm} ${ERRLOG} ${BENCHLOGFILE}
        break
    fi

    # Eine Sekunde pausieren vor dem nächsten Logfile-Check.
    sleep 1
    let secs++

done  ##  while :
