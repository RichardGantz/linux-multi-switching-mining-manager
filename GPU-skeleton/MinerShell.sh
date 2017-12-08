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
#    "gpu_idx"
#    "algo"
#    "continent"
#    "NH_DOMAIN"
#    "algo_port"
#    "worker"
#    "LIVE_LOGFILE" : "InternalAlgos[${algo}]"
#)

# GLOBALE VARIABLEN, nützliche Funktionen
[[ ${#_GLOBALS_INCLUDED} -eq 0 ]]     && source ../globals.inc
[[ ${#_LOGANALYSIS_INCLUDED} -eq 0 ]] && source ../logfile_analysis.inc

# Wenn debug=1 ist, werden die temporären Dateien beim Beenden nicht gelöscht.
debug=1

####################################################################################
################################################################################
###
###                        1. Parameter entgegen nehmen
###
################################################################################
####################################################################################
algorithm=$1
read algo miner_name miner_version muck888 <<<${algorithm//#/ }
gpu_idx=$2
continent=$3
algo_port=$4
worker=$5
declare -A InternalAlgos[$algo]=$6
gpu_uuid=$7
# Rest ist Nvidia GPU Default Tuning CmdStack
shift 7
command_string=$*
read -a CmdStack <<<"${command_string}"
declare -i i
for (( i=0; $i<${#CmdStack[@]}; i++ )); do
    CmdStack[$i]=${CmdStack[$i]//;/ }
done
MINER=${miner_name}#${miner_version}
# ACHTUNG: Die #888 - falls vorhanden - wird hier drin nicht benötigt!
#          Wir haben alle Daten inclusive der GPU-Einstellungen in den Parametern übergeben bekommen
algorithm=${algo}#${MINER}

################################################################################
###
###          Ganz schöne Ääction wegen der "continent"e Verwaltung
###
################################################################################
nowDate=$(date "+%Y-%m-%d %H:%M:%S" )
declare -i nowSecs=$(date +%s) timestamp
while :; do
    declare -i location_ptr=0                         # Index in das optimal aufgebaute LOCATION Array, beginnend mit "eu"
    if [[ "${continent}" == "SelbstWahl" ]]; then
        if [ -s act_continent_${algorithm} ]; then
            read _date_ _oclock_ timestamp location_ptr continent <<<$(tail -n 1 act_continent_${algorithm})
            if   [ ${location_ptr} -eq 0 ]; then
                continent=${LOCATION[${location_ptr}]}
            elif [ ${nowSecs} -gt $((${timestamp}+3600)) ]; then
                # Let's try the best one again ...
                location_ptr=0
                continent=${LOCATION[${location_ptr}]}
                echo "# Probieren wir es nach 1h wieder von vorne mit dem Besten..." >>act_continent_${algorithm}
                echo ${nowDate} ${nowSecs} ${location_ptr} ${continent}              >>act_continent_${algorithm}
            fi
        else
            continent=${LOCATION[${location_ptr}]}
            echo "# Beginnen wir neu mit dem Besten..."             >>act_continent_${algorithm}
            echo ${nowDate} ${nowSecs} ${location_ptr} ${continent} >>act_continent_${algorithm}
        fi
        break
    else
        for (( location_ptr=0; $location_ptr<${#LOCATION[@]}; location_ptr++ )); do
            [[ "${LOCATION[$location_ptr]}" == "${continent}" ]] && break
        done
        # Eventuell nicht vorhandenen continent übergeben, dann umstellen auf SelbstWahl
        if [[ $location_ptr -eq ${#LOCATION[@]} ]]; then
            continent="SelbstWahl"
        else
            echo "# Entscheidung wurde per Parameter übergeben..."  >>act_continent_${algorithm}
            echo ${nowDate} ${nowSecs} ${location_ptr} ${continent} >>act_continent_${algorithm}
            break
        fi
    fi
done
# Das brauchen wir, um bei einem Verbindungsabbruch einen Anhaltspunkt zu haben um zu wissen,
# wann wir alle "continent"e durch sind und weitere Verbindungsversuche bleiben lassen können.
declare -i initial_location_ptr=$location_ptr

# Dieser Aufruf zieht die entsprechenden Variablen rein, die für den Miner
# definiert sind, damit die Aufrufmechanik für alle gleich ist.
source ../miners/${MINER}.starts

# Ein paar Standardverzeichnisse im GPU-UUID Verzeichnis zur Verbesserung der Übersicht:
[[ ! -d live ]]                  && mkdir live
[[ ! -d live/${algo} ]]          && mkdir live/${algo}
[[ ! -d live/${algo}/${MINER} ]] && mkdir live/${algo}/${MINER}

LOGPATH="live/${algo}/${MINER}"
BENCHLOGFILE="live/mining_${algo}_${gpu_uuid}.log"
# Einer der letzten zu setzenden Parameter für den Parameterstack des equihash "miner"
LIVE_LOGFILE=${BENCHLOGFILE}

function _build_minerstart_commandline () {
    # ---> Die folgenden Variablen müssen noch vollständig implementiert werden! <---
    # "LOCATION eu, usa, hk, jp, in, br"  <--- von der Webseite https://www.nicehash.com/algorithm
    # Wird übergeben, aber:# Noch nicht vollständig implementiert!      <--------------------------------------
    #continent="eu"        # Noch nicht vollständig implementiert!      <--------------------------------------
    #worker="1060"         # Noch nicht vollständig implementiert!      <--------------------------------------

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

function _disable_algo () {
    # Algo in die 5-Minuten-Disabled Datei UND in die HISTORY/CHRONIK Datei eintragen...
    _reserve_and_lock_file ../MINER_ALGO_DISABLED_HISTORY
    printf "disable " >>../MINER_ALGO_DISABLED_HISTORY
    printf "${nowDate} ${nowSecs} ${algorithm}\n" \
        | tee -a ../MINER_ALGO_DISABLED \
              >>../MINER_ALGO_DISABLED_HISTORY
    rm -f ../MINER_ALGO_DISABLED_HISTORY.lock
}

####################################################################################
################################################################################
###
###                        2. Prozesse sauber (beginnen) und beenden
###
################################################################################
####################################################################################
function _terminate_Logger_Terminal () {
    printf "Beenden des Logger-Terminals alias ${MINER} ... "
    kill_pids=$(ps -ef \
          | grep -e "${Bench_Log_PTY_Cmd}" \
          | grep -v 'grep -e ' \
          | gawk -e 'BEGIN {pids=""} {pids=pids $2 " "} END {print pids}')
    if [ -n "$kill_pids" ]; then
        kill $kill_pids # >/dev/null
        printf "done.\n"
    else
        printf "NOT FOUND!!!\n"
    fi
}

function _terminate_Miner () {
    printf "Beenden des Miners           alias ${algorithm} ... "
    MINER_pid=$(< ${MINER}.pid)
    if [ -n "${MINER_pid}" ]; then
        printf "Beenden des Miners           alias ${algorithm} mit PID ${MINER_pid} ... "
        kill_pid=$(ps -ef | gawk -e '$2 == '${MINER_pid}' && /'${minerstart}'/ {print $2; exit }')
        if [ -n "$kill_pid" ]; then
            kill $kill_pid
            if [[ $? -eq 0 ]]; then
                printf "KILL SIGNAL SUCCESSFULLY SENT.\n"
                sleep $Erholung                               # "Erholung" vor einem Neustart
            else
                kill -9 $kill_pid
                if [[ $? -eq 0 ]]; then
                    printf "KILL SIGNAL SUCCESSFULLY SENT, but had to be \"kill -9 $kill_pid\" !\n"
                    sleep $Erholung                           # "Erholung" vor einem Neustart
                else
                    printf "KILL SIGNAL COULD NOT BE SENT SUCCESSFULLY, even not \"kill -9 $kill_pid\" !\n"
                fi
            fi
        else
            printf "PID ${MINER_pid} NOT FOUND IN PROCESS TABLE!!!\n"
            printf "GPU #${gpu_idx}: $(basename $0): PID ${MINER_pid} of Miner ${MINER} NOT FOUND IN PROCESS TABLE!!!\n" \
                | tee -a ${ERRLOG}
        fi
    fi
    rm -f ${MINER}.pid
}

function _delete_temporary_files () {
    [[ -n "${MINER}" ]] && rm -f ${MINER}.retry ${MINER}.booos
}
_delete_temporary_files
rm -f ${BENCHLOGFILE}

function _On_Exit () {

    _terminate_Logger_Terminal

    _terminate_Miner

    # Auf jeden Fall das LOGFILE aufheben... nach möglichen anderen Abgebrochenen als ULTIMATIVES dieses Zyklus
    cp -f ${BENCHLOGFILE} ${LOGPATH}/mining_$(date "+%Y%m%d_%H%M%S").log

    if [ $debug -eq 0 ]; then
        _delete_temporary_files
    fi
    rm -f $(basename $0 .sh).pid
}
trap _On_Exit EXIT

# Aktuelle eigene PID merken
echo $$ >$(basename $0 .sh).pid


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
echo   "Das ist der Miner,      der ausgewählt ist : ${miner_name} ${miner_version}"
echo   "das ist der NH-Algo,    der ausgewählt ist : ${algo}"
printf "das ist der \$algorithm, der ausgewählt ist : ${algorithm}"
[[ ${#muck888} -gt 0 ]] && printf "#${muck888}"
printf "\n"
[ "${InternalAlgos[$algo]}" != "${algo}" ] && echo "Das ist der Miner-Interne Algoname: ${InternalAlgos[$algo]}"
echo   ""
echo   "DIE FOLGENDEN NVIDIA GPU KOMMANDOS WERDEN ABGESETZT:"
for (( i=0; $i<${#CmdStack[@]}; i++ )); do
    echo "---> ${CmdStack[$i]} <---"
done

# GPU-Kommandos absetzen...
for (( i=0; $i<${#CmdStack[@]}; i++ )); do
    ${CmdStack[$i]}
done

if [ $NoCards ]; then
    if [ ! -f "${BENCHLOGFILE}" ]; then
        if [[ "${miner_name}" == "miner" ]]; then
            #sed -e 's/\x1B[[][[:digit:]]*m//g' equihash.log >${BENCHLOGFILE}
            cp -f ../benchmarking/equihash.log ${BENCHLOGFILE}
        else
            # cp ../benchmarking/test/benchmark_blake256r8vnl_GPU-742cb121-baad-f7c4-0314-cfec63c6ec70.fake ${BENCHLOGFILE}
            cp ../benchmarking/test/bnch_retry_catch_fake.log ${BENCHLOGFILE}
            # cp ../booos ${BENCHLOGFILE}
        fi
    fi
fi  ## $NoCards


####################################################################################
################################################################################
###
###                        4. Eintritt in die Endlosschleife
###
################################################################################
####################################################################################

declare -i inetLost_detected=0
while :; do
    if [[ -f I_n_t_e_r_n_e_t__C_o_n_n_e_c_t_i_o_n__L_o_s_t ]]; then
        echo $(date "+%Y-%m-%d %H:%M:%S" ) $(date +%s) \
             "GPU #${gpu_idx}: $(basename $0): Abbruch des Miners alias ${algorithm} wegen NO INTERNET..." \
            | tee -a ../log_ConLoss log_ConLoss_${algorithm} ${ERRLOG} \
                  >>${BENCHLOGFILE}
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
        echo "GPU #${gpu_idx}: Starting Miner alias ${algorithm} with the following command line:"
        echo ${minerstart}
        ${minerstart} >>${BENCHLOGFILE} &
        echo $! > ${MINER}.pid
        Bench_Log_PTY_Cmd="tail -f ${BENCHLOGFILE}"
        gnome-terminal --hide-menubar \
                       --title="GPU #${gpu_idx}  -  Mining ${algorithm}" \
                       -e "${Bench_Log_PTY_Cmd}"
    fi

    ################################################################################
    ###
    ###          Logfile auf Abbruchbedingungen hin überwachen,
    ###          Hashwerte nachsehen und zählen
    ###
    ################################################################################

    hashCount=$(cat ${BENCHLOGFILE} \
                  | tee >(grep -c -m1 -e "${CONEXPR//[|]/\\|}" >${MINER}.retry) \
                        >(gawk -v YES="${YESEXPR}" -v BOO="${BOOEXPR}" -e '
                               BEGIN { yeses=0; booos=0; seq_booos=0 }
                               $0 ~ BOO { booos++; seq_booos++; next }
                               $0 ~ YES { yeses++; seq_booos=0 }
                               END { print seq_booos " " booos " " yeses }' >${MINER}.booos) \
                  | sed -e 's/ *(yes!)$//g' \
                  | grep -c "/s$")

    ################################################################################
    ###
    ###          1. ABBRUCHBEDINGUNG:       "VERBINDUNG ZUM SERVER VERLOREN"
    ###          Ist vor dem endgültigen Abbruch der "continent" zu wechseln?
    ###
    ################################################################################

    if [[ $(< ${MINER}.retry) -eq 1 ]]; then
        echo "GPU #${gpu_idx}: Connection loss detected..."
        if [[ -f I_n_t_e_r_n_e_t__C_o_n_n_e_c_t_i_o_n__L_o_s_t ]]; then
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
            cat ${BENCHLOGFILE} >>${LOGPATH}/mining_$(date "+%Y%m%d_%H%M%S")_ABORTED.log

            # BENCHLOGFILE neu beginnen...
            echo ${nowDate} ${nowSecs} \
                 "GPU #${gpu_idx}: Neustart des Miners alias ${algorithm} nach Internet-Verbindungsfehler..." \
                | tee -a ../log_ConLoss log_ConLoss_${algorithm} \
                      >${BENCHLOGFILE}
            inetLost_detected=0
            continue
        else
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
                    echo "# Keiner war erreichbar, deshalb nextes mal von vorne mit dem Besten..." >>act_continent_${algorithm}
                    echo ${nowDate} ${nowSecs} ${location_ptr} ${continent}                        >>act_continent_${algorithm}
                fi

                # Algo in die 5-Minuten-Disabled Datei UND in die HISTORY/CHRONIK Datei eintragen...
                _disable_algo

                # Miner-Abbrüche protokollieren nach bisher 3 Themen getrennt
                echo ${nowDate} ${nowSecs} \
                     "GPU #${gpu_idx}: BEENDEN des Miners alias ${algorithm} wegen NiceHash Servers WORLDWIDE unavailable." \
                    | tee -a ../log_ConLoss log_ConLoss_${algorithm} \
                          >>${BENCHLOGFILE}
                break

            else
                ################################################################################
                ###
                ###          Abbruch des nicht mehr funktioierenden "continent"
                ###
                ################################################################################
                echo ${nowDate} ${nowSecs} "GPU #${gpu_idx}: Abbruch des Miners alias ${algorithm}..." \
                    | tee -a ../log_ConLoss log_ConLoss_${algorithm} \
                          >>${BENCHLOGFILE}
                _terminate_Logger_Terminal
                _terminate_Miner
                # Vielleicht noch das ${BENCHLOGFILE} sichern vor dem Überschreiben zur "Beweissicherung"
                cat ${BENCHLOGFILE} >>${LOGPATH}/mining_$(date "+%Y%m%d_%H%M%S")_ABORTED_BEFORE_RESTART.log

                ################################################################################
                ###
                ###          Neuer "continent"
                ###
                ################################################################################

                continent=${LOCATION[${location_ptr}]}

                nowDate=$(date "+%Y-%m-%d %H:%M:%S" )
                nowSecs=$(date +%s)
                echo "# Neuer Continent \"$continent\" nach Verbindungsabbruch des ${algorithm}" >>act_continent_${algorithm}
                echo ${nowDate} ${nowSecs} ${location_ptr} ${continent}                          >>act_continent_${algorithm}

                # BENCHLOGFILE neu beginnen...
                echo ${nowDate} ${nowSecs} \
                     "GPU #${gpu_idx}: ... und Neustart des Miners alias ${algorithm} nach Continent-Wechsel zu \"${continent}\"..." \
                    | tee -a ../log_ConLoss log_ConLoss_${algorithm} \
                          >${BENCHLOGFILE}
                if [ $NoCards ]; then
                    cat ../benchmarking/test/bnch_retry_catch_fake.log >>${BENCHLOGFILE}
                fi  ## $NoCards
                continue
            fi
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
        _disable_algo

        # Miner-Abbrüche protokollieren nach bisher 3 Themen getrennt
        echo ${nowDate} ${nowSecs} \
             "GPU #${gpu_idx}: Abbruch des Miners alias ${algorithm} wegen zu vieler 'booooos'..." \
            | tee -a ../log_Booooos log_Booooos_${algorithm} \
                  >>${BENCHLOGFILE}
        break
    elif [[ ${booos} -ge 5 ]]; then
        echo "GPU #${gpu_idx}: Miner alias ${algorithm} gibt bereits ${booos} 'booooos' hintereinander von sich..."
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
        _disable_algo

        # Miner-Abbrüche protokollieren nach bisher 3 Themen getrennt
        echo ${nowDate} ${nowSecs} \
             "GPU #${gpu_idx}: Abbruch des Miners alias ${algorithm} wegen 320s ohne Hashwerte." \
            | tee -a ../log_No_Hash log_No_Hash_${algorithm} \
                  >>${BENCHLOGFILE}
        break
    fi

    # Eine Sekunde pausieren vor dem nächsten Logfile-Check.
    sleep 1
    let secs++

done  ##  while :
