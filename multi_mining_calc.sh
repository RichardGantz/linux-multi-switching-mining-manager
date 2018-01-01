#!/bin/bash
###############################################################################
#                           Multi-Mining-Sort und -Calc
# 
# Hier werden die GPU's Algorythmen jeder Karte Sortiert und zusammengefasst.
# 
# Welche Karte "sieger" ist und als erstes z.b. anfangen darf zu minen
#
#
#
#
###############################################################################

# GLOBALE VARIABLEN, nützliche Funktionen
[[ ${#_GLOBALS_INCLUDED}     -eq 0 ]] && source globals.inc
[[ ${#_MINERFUNC_INCLUDED}   -eq 0 ]] && source ${LINUX_MULTI_MINING_ROOT}/miner-func.inc

# Für die Ausgabe von mehr Zwischeninformationen auf 1 setzen.
# Null, Empty String, oder irgendetwas andere bedeutet AUS.
verbose=0

# Wenn debug=1 ist, werden die temporären Dateien beim Beenden nicht gelöscht.
debug=1

# Performance-Test-Werte und Bedeutung:
# 1: Sekundenzeitstempel an folgenden 8 signifikanten Stellen der Endlosschleife in Datei "perfmon.log"
#
# >1.< While Loop ENTRY"
# >2.< Startschuss: Neue Daten sind verfügbar"
# >3.< GPUs haben alle Daten geschrieben"
# >4.< Alle Algos aller GPUs sind eigelesen."
# >5.< Berechnungen beginnen mit Einzelberechnungen"
# >6.< Beginn mit der Gesamtsystemberechnung"
# >7.< Auswertung und Miner-Steuerungen"
# >8.< Eintritt in den WARTEZYKLUS..."
#
# 2: pstree-Dauerschleife vom Beginn bis zum Ende der Berechnungen (Punkte >5.< und >6.<) in Datei "pstree.log"
#    ACHTUNG: die pstree-Informationen haben keine neuen Erkenntnisse ergeben!
performanceTest=1
arrayRedeclareTest=0

# Sicherheitshalber alle .pid Dateien löschen.
# Das machen die Skripts zwar selbst bei SIGTERM, nicht aber bei SIGKILL und anderen.
# Sonst startet er die Prozesse nicht.
# Die .pid ist in der Endlosschleife der Hinweis, dass der Prozess läuft und NICHT gestartet werden muss.
#
find . -depth -name \*.pid  -delete
find . -depth -name \*.lock -delete

# Aktuelle PID der 'multi_mining-controll.sh' ENDLOSSCHLEIFE
echo $$ >$(basename $0 .sh).pid
export ERRLOG=${LINUX_MULTI_MINING_ROOT}/$(basename $0 .sh).err

function _delete_temporary_files () {
    rm -f ${ERRLOG} ${SYNCFILE} ${SYSTEM_STATE}.lock \
       I_n_t_e_r_n_e_t__C_o_n_n_e_c_t_i_o_n__L_o_s_t
}
_delete_temporary_files

#
# Aufräumarbeiten beim ordungsgemäßen kill -15 Signal (SIGTERM)
#
function _terminate_all_log_ptys () {
    for gpu_idx in ${!LOG_PTY_CMD[@]}; do
        broken_pipe_text+="Beenden des Logger-Terminals GPU #${gpu_idx} ... "
        REGEXPAT="${LOG_PTY_CMD[${gpu_idx}]//\//\\/}"
        REGEXPAT="${REGEXPAT//\+/\\+}"
        kill_pids=$(ps -ef \
          | grep -e "${REGEXPAT}" \
          | grep -v 'grep -e ' \
          | gawk -e 'BEGIN {pids=""} {pids=pids $2 " "} END {print pids}')
        if [ ! "$kill_pids" == "" ]; then
            kill $kill_pids >/dev/null
            broken_pipe_text+="done.\n"
        fi
    done
}

function _terminate_all_processes_of_script () {
    kill_pids=$(ps -ef \
       | grep -e "/bin/bash.*$1" \
       | grep -v 'grep -e ' \
       | gawk -e 'BEGIN {pids=""} {pids=pids $2 " "} END {print pids}')
    if [ ! "$kill_pids" == "" ]; then
        broken_pipe_text+="Killing all $1 processes... "
        kill $kill_pids
        broken_pipe_text+="done.\n"
    fi
}

function _On_Exit () {
    broken_pipe_text="MultiMiner: _On_Exit() ENTRY, CLEANING UP RESOURCES NOW...\n"
    _terminate_all_processes_of_script "gpu_gv-algo.sh"
    _terminate_all_processes_of_script "algo_multi_abfrage.sh"
    _terminate_all_log_ptys
    broken_pipe_text+="\n"
    echo ${broken_pipe_text}

    [[ ${#pstreePID} -gt 0 ]] && kill ${pstreePID}
    # Temporäre Dateien löschen
    [[ $debug -eq 0 ]] && _delete_temporary_files
    rm -f $(basename $0 .sh).pid
}
trap _On_Exit EXIT

FullPowerPattern="\#888$"    # Endet mit "#888"

# Funktionen Definitionen ausgelagert
source ./multi_mining_calc.inc

# Hier nun einige Vorarbeiten und dann der Einstig in die Endlosschleife
# Um die algo_multi_abfrage.sh zu stoppen, müssen wir in der Prozesstabelle nach
#        '/bin/bash.*algo_multi_abfrage.sh'
#        suchen und die Prozess-ID vielleicht mit der Datei vergleichen,
#        die algo_multi_abfrage.sh selbst geschrieben hat?
#
# Die gpu_gv-algo.sh können selbst die Miner stoppen und weitere Aufräumarbeiten durch führen
# kill $(ps -ef \
#      | grep gpu_gv-algo.sh \
#      | grep -v grep \
#      | grep -e '/bin/bash.*gpu_gv-algo.sh' \
#      | gawk -e 'BEGIN {pids=""} {pids=pids $2 " "} END {print pids}')

# Jetzt erst mal der einfachste Fall:
# Wenn multi_mining_calc.sh gestoppt wird, soll alles gestoppt werden.
# ALLE LAUFENDEN gpu_gv-algo.sh killen.
# ---> DAS MUSS NATÜRLICH AUCH DEN MINERN NOCH MITGETEILT WERDEN! <---
# ---> WIR BEFINDEN UNS HIER NOCH IN DER TROCKENÜBUNG             <---
_terminate_all_processes_of_script "gpu_gv-algo.sh"
_terminate_all_processes_of_script "algo_multi_abfrage.sh"
# ---> WIR MÜSSEN AUCH ÜBERLEGEN, WAS WIR MIT DEM RUNNING_STATE MACHEN !!! <---
# ---> WIE SINNVOLL IST ES, DEN AUFZUHEBEN?                                <---
rm -f ${RUNNING_STATE}

# Danach ist alles saubergeputzt, soweit wir das im Moment überblicken und es kann losgehen, die
# gpu_gv-algos's zu starten, die erst mal auf SYNCFILE warten
# und dann algo_multi_abfrage.sh

exec 2>>${ERRLOG}
# Error-Kanal in eigenes Terminal ausgeben
unset ii; declare -i ii=0
unset LOG_PTY_CMD; declare -ag LOG_PTY_CMD
LOG_PTY_CMD[999]="tail -f ${ERRLOG}"
ofsX=$((ii*60+50))
ofsY=$((ii*30+50))
let ii++
gnome-terminal --hide-menubar \
               --title="MultiMining Error Channel Output" \
               --geometry="100x24+${ofsX}+${ofsY}" \
               -e "${LOG_PTY_CMD[999]}"
#               -x bash -c "${LOG_PTY_CMD[999]}"

# Besteht nun hauptsächlich aus der Funktion _func_gpu_abfrage_sh
source ./gpu-abfrage.sh

# Zuletzt 15047 Sekunden gelaufen mit der Einstellung arrayRedeclareTest=1
# Deshalb brechen wir nach dieser zeit ab. Sind etwas über 4 Stunden...
# TestZeitEnde=$(($(date --utc +%s)+15047))

# Das gibt Informationen der gpu-abfrage.sh aus
ATTENTION_FOR_USER_INPUT=1
while : ; do
    printf "=========         Beginn neuer Zyklus um:     $(date "+%Y-%m-%d %H:%M:%S" )         =========\n"

    [[ ${performanceTest} -ge 1 ]] && echo "$(date --utc +%s): >1.< While Loop ENTRY" >>perfmon.log

    # Diese Abfrage erzeugt die beiden Dateien "gpu_system.out" und "GLOBAL_GPU_SYSTEM_STATE.in"
    # Daten von "GLOBAL_GPU_SYSTEM_STATE.in", WELCHES MANUELL BEARBEITET WERDEN KANN,
    #       werden berücksichtigt, vor allem sind das die Daten über den generellen Beachtungszustand
    #       von GPUs und Algorithmen.
    #       GPUs können als ENABLED (1) oder DISABLED (0) gesetzt werden
    _func_gpu_abfrage_sh

    #
    # Wir schalten jetzt die GPU-Abfragen ein, wenn sie nicht schon laufen...
    # ---> Müssen auch daran denken, sie zu stoppen, wenn die GPU DISABLED wird <---
    for lfdUuid in "${!uuidEnabledSOLL[@]}"; do
        if [ ${uuidEnabledSOLL[${lfdUuid}]} -eq 1 ]; then
            if [ ! -f ${lfdUuid}/gpu_gv-algo.pid ]; then
                workdir=$(pwd)

                # Ins GPU-Verzeichnis wechseln
                cd ${lfdUuid}
                lfd_gpu_idx=$(< gpu_index.in)
                GPU_GV_LOG="gpu_gv-algo_${lfdUuid}.log"
                rm -f ${GPU_GV_LOG}
                echo "GPU #${lfd_gpu_idx}: Starting process in the background..."
                ./gpu_gv-algo.sh >>${GPU_GV_LOG} &
                # gnome-terminal -x ./abc.sh
                #    Für die Logs in eigenem Terminalfenster, in dem verblieben wird, wenn tail abgebrochen wird:
                ofsX=$((ii*60+50))
                ofsY=$((ii*30+50))
                LOG_PTY_CMD[${lfd_gpu_idx}]="tail -f ${GPU_GV_LOG}"
                gnome-terminal --hide-menubar \
                               --title="GPU #${lfd_gpu_idx}  -  ${lfdUuid}" \
                               --geometry="100x24+${ofsX}+${ofsY}" \
                               -e "${LOG_PTY_CMD[${lfd_gpu_idx}]}"
                let ii++

                cd ${workdir} >/dev/null
            fi
        fi
    done

    #
    # Dann starten wir die algo_multi_abfrage.sh, wenn sie nicht schon läuft...
    #
    if [ ! -f algo_multi_abfrage.pid ]; then
        # Das lohnt sich erst, wenn wir den curl dazu gebracht haben, ebenfalls umzuleiten...
        # gnome-terminal -x ./abc.sh
        #    Für die Logs in eigenem Terminalfenster, in dem verblieben wird, wenn tail abgebrochen wird:
        ofsX=$((ii*60+50))
        ofsY=$((ii*30+50))
        rm -f algo_multi_abfrage.log
        echo "Starting algo_multi_abfrage.sh in the background..."
        ./algo_multi_abfrage.sh &>>algo_multi_abfrage.log &
        LOG_PTY_CMD[998]="tail -f algo_multi_abfrage.log"
        gnome-terminal --hide-menubar \
                       --title="\"RealTime\" Algos und Kurse aus dem Web" \
                       --geometry="100x24+${ofsX}+${ofsY}" \
                       -e "${LOG_PTY_CMD[998]}"
    fi

    ###############################################################################################
    #
    # Einlesen des bisherigen RUNNING Status
    #
    ###############################################################################################
    # Wer diese Datei schreiben oder lesen will, muss auf das Verschwinden von *.lock warten...
    _reserve_and_lock_file ${RUNNING_STATE}          # Zum Lesen reservieren...
    _read_in_actual_RUNNING_STATE                    # ... einlesen...
    rm -f ${RUNNING_STATE}.lock                      # ... und wieder freigeben

    # Folgende Arrays stehen uns jetzt zur Verfügung, die uns sagen, welche GPU seit den
    # vergangenen 31s mit welchem Algorithmus und welchem Watt-Konsum laufen sollte,
    # ob sie ENABLED WAR und mit welchem GPU-Index sie "damals" gestartet wurde.
    # Auf all diese Informationen haben wir über die UUID Zugriff.
    #      RunningGPUid[ $UUID ]=${RunningGPUidx}    GPU-Index
    #      WasItEnabled[ $UUID ]=${GenerallyEnabled} (0/1)
    #      RunningWatts[ $UUID ]=${Watt}             Watt
    #      WhatsRunning[ $UUID ]=${RunningAlgo}      AlgoName
    unset SUM_OF_RUNNING_WATTS; declare -i SUM_OF_RUNNING_WATTS=0

    unset lfdUUID
    if [[ ${#RunningGPUid[@]} -gt 0 ]]; then
        for lfdUUID in ${!RunningGPUid[@]}; do
            if [[ ${WasItEnabled[$lfdUUID]} == 1 ]]; then
                SUM_OF_RUNNING_WATTS+=${RunningWatts[$lfdUUID]}
            fi
        done
    fi

    ###############################################################################################
    ###############################################################################################
    ###
    ###              WARTEN und TESTEN AUF GÜLTIGE DATEN AUS DEM NETZ
    ###
    ###############################################################################################
    ###############################################################################################
    _progressbar='\r'
    while [ ! -f ${SYNCFILE} ]; do
        [[ "${_progressbar}" == "\r" ]] && echo "###---> Waiting for ${SYNCFILE} to become available..."
        _progressbar+='.'
        if [[ ${#_progressbar} -gt 75 ]]; then
            printf '\r                                                                            '
            _progressbar='\r.'
        fi
        printf ${_progressbar}
        sleep .5
    done
    [[ "${_progressbar}" != "\r" ]] && printf "\n"
    #  Das neue "Alter" von ${SYNCFILE} in der Variablen ${new_Data_available} merken für später.
    #  Die GPUs haben schon losgelegt, das heisst, dass SYNCFILE da ist und in etwa 31s neu getouched wird
    declare -i new_Data_available=$(stat -c %Y ${SYNCFILE})

    # Testabbruch nach etwa 4 Stunden mit der anderen Arraybehandlung
    # [[ ${performanceTest} -ge 2 ]] && [[ ${TestZeitEnde} -le ${new_Data_available} ]] && break
    [[ ${performanceTest} -ge 1 ]] && echo "$(date --utc +%s): >2.< Startschuss: Neue Daten sind verfügbar" >>perfmon.log

    ###############################################################################################
    # (26.10.2017)
    # Vor dem Einlesen der Werte aus dem SMARTMETER, um u.a. SolarWattAvailable berechnen zu können,
    # warten wir erst mal, bis alle ENABLED GPUs ihre Dateien ALGO_WATTS_MINES.in geschrieben haben.
    # Darin enthalten sind die Watt-Angaben und die BTC "Mines", die sie produzieren würden,
    # wenn sie laufen würden.
    # Wir warten darauf, dass das Modification Date der Datei ALGO_WATTS_MINES.in größer oder gleich
    # dem des SYNCFILE ist, weil die "alten" Dateien der letzten 31s noch rumliegen.
    #
    # Erst, wenn alle BTC "Mines" anhand der aktuellen Kurse berechnet wurden
    #       und wir die optimale Konfiguration durchrechnen können,
    #       bestimmen wir den momentanen "Strompreis" anhand der Daten aus dem SMARTMETER
    #
    # Zunächst also warten, bis die "Mines"-Berechnungen und die Wattangaben alle verfügbar sind.

    echo $(date "+%Y-%m-%d %H:%M:%S" ) $(date +%s) "Going to wait for all GPUs to calculate their ALGO_WATTS_MINES.in"
    if [ ${NumEnabledGPUs} -gt 0 ]; then
        declare -i msg_echoed=0
        while :; do
            declare -i AWMTime=new_Data_available+3600
            for UUID in ${!uuidEnabledSOLL[@]}; do
                if [ ${uuidEnabledSOLL[${UUID}]} -eq 1 ]; then
                    if [ ! -f ${UUID}/ALGO_WATTS_MINES.lock ]; then
                        if [ -f ${UUID}/ALGO_WATTS_MINES.in ]; then
                            declare -i gpuTime=$(stat -c %Y ${UUID}/ALGO_WATTS_MINES.in) 2>/dev/null
                            if [ $gpuTime -lt $AWMTime ]; then AWMTime=gpuTime; fi
                        fi
                    fi
                fi
            done
            if [ $AWMTime -lt $new_Data_available ]; then
                [[ msg_echoed++ -eq 0 ]] && echo "Waiting for all GPUs to calculate their ALGO_WATTS_MINES.in"
                sleep .5
            else
                break
            fi
        done
    else
        echo "Im Moment sind ALLE GPU's DISABLED..."
    fi

    echo $(date "+%Y-%m-%d %H:%M:%S" ) $(date +%s)
    [[ ${performanceTest} -ge 1 ]] && echo "$(date --utc +%s): >3.< GPUs haben alle Daten geschrieben" >>perfmon.log

    ###############################################################################################
    #
    #    Info über Algos, die DISABLED wurden und sind ausgeben
    #
    if [ -f GLOBAL_ALGO_DISABLED ]; then
        echo "-------------> Die folgenden Algos sind GENERELL DISABLED: <-------------"
        cat GLOBAL_ALGO_DISABLED | grep -E -v -e '^#|^$'
    fi
    if [ -f BENCH_ALGO_DISABLED ]; then
        echo "-------------> Die folgenden Algos sind aufgrund des Benchmarings DAUERHAFT DISABLED: <-------------"
        cat BENCH_ALGO_DISABLED | grep -E -v -e '^#|^$'
    fi
    if [ -f MINER_ALGO_DISABLED ]; then
        echo "-------------> Die folgenden Algos sind für 5 Minuten DISABLED: <-------------"
        cat MINER_ALGO_DISABLED | sort -k 3
    fi

    ###############################################################################################
    #
    #    EINLESEN ALLER ALGORITHMEN, WATTS und MINES, AUF DIE WIR GERADE GEWARTET HABEN
    #
    # m_m_calc.sh wird zwar das selbe auch tun, aber wir brauchen die Daten, wenn wir die Ergebnisse von m_m_calc.sh bekommen,
    # denn diese Ergebnisse sind nur exakte Pointer/Zeiger in diese Datenmenge hinein, die wir brauchen, um die Anweisungen
    # über ${RUNNING_STATE} an die GPUs weitergeben zu können. Wir können uns das Einlesen also nicht ersparen.
    _read_in_All_ALGO_WATTS_MINESin

    [[ ${performanceTest} -ge 1 ]] && echo "$(date --utc +%s): >4.< Alle Algos aller GPUs sind eigelesen." >>perfmon.log

    ###############################################################################################
    #
    #     EINLESEN der STROMPREISE in BTC
    #
    # In algo_multi_abfrage.sh, die vor Kurzem gelaufen sein muss,
    # werden die EUR-Strompreise in BTC-Preise umgewandelt.
    # Diese Preise brauchen wir in BTC, um die Kosten von den errechneten "Mines" abziehen zu können.
    #
    _read_in_kWhMin_kWhMax_kWhAkk

    ##################################################################################
    ##################################################################################
    #
    #     EINLESEN SMARTMETER und BERECHNEN VON SolarWattAvaiable
    #
    # Irgendwann brauchen wir irgendwoher den aktuellen Powerstand aus dem Smartmeter
    # w3m "http://192.168.6.170/solar_api/blabla..." > smartmeter
    #          "PowerReal_P_Sum" : 20.0,
    # kW=$( grep PowerReal_P_Sum smartmeter | gawk '{print substr($3,1,index($3,".")-1)}' ) ergibt Integer Wattzahl
    #
    # Jetzt können wir den aktuellen Verbrauch aller Karten von kW abziehen, um zu sehen, ob wir uns
    #     im "Einspeisemodus" befinden.
    #     (${kW} - ${ActuallyRunningWatts}) < 0 ? SolarWatt=$(expr ${ActuallyRunningWatts} - ${kW} )
    #
    ###                                                                            ###
    ### FALLS ES ALSO "solar" Power gibt, wird die Variable SolarWattAvailable > 0 ###
    ### Die Berechnungen stimmen so oder so. Auch für den Fall, dass es keine      ###
    ### "solar" Power gibt, was durch SolarWattAvailable=0 ausgedrückt wird.       ###
    ###                                                                            ###

    PHASE=PowerReal_P_Phase_1
    PHASE=PowerReal_P_Phase_2
    PHASE=PowerReal_P_Phase_3
    PHASE=PowerReal_P_Sum

    declare -i ACTUAL_SMARTMETER_KW
    declare -i SolarWattAvailable=0

    if [ ! $NoCards ]; then
        # Datei smartmeter holen
        w3m "http://192.168.6.170/solar_api/v1/GetMeterRealtimeData.cgi?Scope=Device&DeviceId=0&DataCollection=MeterRealtimeData" > smartmeter
    fi

    printf "         Sum of actually running WATTS: %5dW\n" ${SUM_OF_RUNNING_WATTS}

    # ABFRAGE PowerReal_P_Sum
    ACTUAL_SMARTMETER_KW=$(grep $PHASE smartmeter | gawk '{print substr($3,0,index($3,".")-1)}')
    printf "Aktueller Verbrauch aus dem Smartmeter: %5dW\n" ${ACTUAL_SMARTMETER_KW}

    if [[ $((${ACTUAL_SMARTMETER_KW} - ${SUM_OF_RUNNING_WATTS})) -lt 0 ]]; then
        SolarWattAvailable=$(expr ${SUM_OF_RUNNING_WATTS} - ${ACTUAL_SMARTMETER_KW})    
    fi
    printf "                 Verfügbare SolarPower: %5dW\n" ${SolarWattAvailable}

    ###############################################################################################
    #
    # Jetzt wollen wir die Arrays zur Berechnung des optimalen Algo pro Karte mit den Daten füllen,
    # die wir für diese Berechnung brauchen.
    #
    # Folgendes ist noch wichtig:
    #
    # 1. Der Fall "solar_akku" ist überhaupt noch nicht in diese Überlegungen einbezogen worden.
    #    Bis her brauchen wir nur aktiv zu werden, wenn "solar" ins Spiel kommt.
    #    Wie das dann zu berechnen ist, haben wir tief durchdacht.
    #    Nicht aber, wie "solar_akku" da hineinspielt.
    #    ---> DESHALB NEHMEN WIR DIE 3. SCHLEIFE EINFACH MAL WEG !!! <---
    #
    # 2. Beste Algorithmen, die nur etwas kosten (GV<0) lassen wir gleich weg.
    #    Das bedeutet, dass die GPU unverzüglich anzuhalten ist,
    #    wenn diese GPU nicht mehr durch einen anderen Algo im Array vertreten ist!
    #    Der entsprechende Array-Drilling hat dann keinerlei Members, was wir daran erkennen,
    #        dass die Anzahl Array-Members oder die "Länge" der Arrays
    #        ${#GPU{realer_gpu_index}Algos/Watts/Mines} gleich 0 ist.
    #             also z.B.  GPU3Algos[]
    #             also z.B.  GPU3Watts[]
    #             also z.B.  GPU3Mines[]
    #

    # Jetzt geht's los:
    # Jetzt brauchen wir ALLE möglichen Kombinationen aus GPU-Konstellationen:
    # Jede GPU und mit jedem möglichen Algo, den sie kann, wird mit allen anderen möglichen
    #      GPUs und deren Algos, und Kombinationen aus GPUs berechnet.
    # Wir errechnen die jeweilige max. BTC-Generierung pro Kombination
    #     und den entsprechenden Gesamtwattverbrauch.
    # Anhand des Gesamtwattverbrauchs der Kombination errechnen wir die Gesamtkosten dieser Kombination
    #     unter Berücksichtigung eines entsprechenden "solar" Anteils, wodurch die Kosten sinken.
    # Die Kombination mit dem besten GV-Verhältnis merken wir uns jeweils in MAX_PROFIT und MAX_PROFIT_GPU_Algo_Combination:
    
    if [[ ${performanceTest} -ge 1 ]]; then
        MessungsStart=$(date --utc +%s)
        echo "${MessungsStart}: >5.< Berechnungen beginnen mit Einzelberechnungen" >>perfmon.log
        if [[ ${performanceTest} -ge 2 ]]; then
            rm -f pstree.log; ./pstree_log.sh ${MessungsStart} &
            pstreePID=$!
        fi
    fi

    #####################################################################################################
    #
    #     DAS IST EIN EXTREM WICHTIGES VARIABLENPAAR:
    #     MAX_PROFIT und MAX_PROFIT_GPU_Algo_Combination
    #
    # Die Berechnungen schieben gleich den maximalen Gewinn immer höher und merken sich die Kombination.
    #     Bei jeder gültigen Berechnung lassen wir die Variable MAX_PROFIT von ".0" aus hochfahren
    #     und halten jedes mal die Kombination aus GPU's und Algo's fest in MAX_PROFIT_GPU_Algo_Combination
    #     in der Form '${gpu_idx}:${algoIdx},'. Bei mehreren GPUs wird der String länger.
    #
    # --> DAS IST FÜR SPÄTERES FEINTUNING: <--
    # Wir können das auch noch weiter verfeinern, wenn wir Kombinationen mit GLEICHEM Gewinn
    #     darauf hin untersuchen, welche "effektiver" ist, welche z.B. bei gleichem Gewinn den minimalsten Strom
    #     verbraucht und diesen dann vorziehen.

    #    MAX_PROFIT=".0"
    #    MAX_PROFIT_GPU_Algo_Combination=''
    #    MAX_FP_MINES=".0"
    #    MAX_FP_WATTS=0
    #    MAX_FP_GPU_Algo_Combination=''
    #    declare -ig GLOBAL_GPU_COMBINATION_LOOP_COUNTER=0
    #    declare -ig GLOBAL_MAX_PROFIT_CALL_COUNTER=0

    ################################################################################
    #
    #                Einzel- und Gesamtsystemberechnung extern
    #
    ################################################################################
    ./m_m_calc.sh ${SolarWattAvailable} "p${performanceTest}" "v${verbose}"

    ################################################################################
    #
    #                Einlesen des Endergebnisses Beste GPU/Algo-Kombination
    #
    ################################################################################
    unset MAX_PROFIT_DATA
    readarray -n 0 -O 0 -t MAX_PROFIT_DATA <MAX_PROFIT_DATA.out
    MAX_PROFIT_GPU_Algo_Combination=${MAX_PROFIT_DATA[0]}
    MAX_FP_GPU_Algo_Combination=${MAX_PROFIT_DATA[1]}
    unset PossibleCandidateGPUidx
    read -a PossibleCandidateGPUidx <<<"${MAX_PROFIT_DATA[2]}"
    unset SwitchOffGPUs
    read -a SwitchOffGPUs <<<"${MAX_PROFIT_DATA[3]}"
    GLOBAL_GPU_COMBINATION_LOOP_COUNTER=${MAX_PROFIT_DATA[4]}
    GLOBAL_MAX_PROFIT_CALL_COUNTER=${MAX_PROFIT_DATA[5]}
    MAX_FP_WATTS=${MAX_PROFIT_DATA[6]}

    ################################################################################
    #
    #                Die Auswertung der optimalen Kombination
    #
    ################################################################################

    [[ ${performanceTest} -ge 2 ]] && [[ ${#pstreePID} -gt 0 ]] && kill ${pstreePID}; unset pstreePID
    [[ ${performanceTest} -ge 1 ]] && echo "$(date --utc +%s): >7.< Auswertung und Miner-Steuerungen" >>perfmon.log

    printf "=========       Endergebnis        =========\n"
    echo "\$GLOBAL_GPU_COMBINATION_LOOP_COUNTER: $GLOBAL_GPU_COMBINATION_LOOP_COUNTER"
    echo "\$GLOBAL_MAX_PROFIT_CALL_COUNTER: $GLOBAL_MAX_PROFIT_CALL_COUNTER"

    # Wer diese Datei schreiben oder lesen will, muss auf das Verschwinden von *.lock warten...
    _reserve_and_lock_file ${RUNNING_STATE}          # Zum Schreiben reservieren...

    # Sichern der alten Datei. Vielleicht brauchen wir sie bei einem Abbruch zur Analyse
    [[ -f ${RUNNING_STATE} ]] && cp -f ${RUNNING_STATE} ${RUNNING_STATE}.BAK

    #####################################################
    # Ausgabe des neuen Status
    ####################################################

    printf 'UUID : GPU-Index : Enabled (1/0) : Watt : Running with AlgoName or Stopped if \"\"\n' >${RUNNING_STATE}
    printf '================================================================================\n'  >>${RUNNING_STATE}

    # Man könnte noch gegenchecken, dass die Summe aus laufenden und abgeschalteten
    #     GPU's die Anzahl GPU's ergeben muss, die im System sind.
    # Es gibt ja ${MAX_GOOD_GPUs}, ${SwitchOnCnt}, ${SwitchOffCnt} und ${GPUsCnt}
    # Es müsste gelten: ${MAX_GOOD_GPUs} + ${SwitchOffCnt} == ${GPUsCnt}
    #              und: ${MAX_GOOD_GPUs} >= ${SwitchOnCnt},
    #                   da möglicherweise die beste Kombination aus weniger als ${MAX_GOOD_GPUs} besteht.
    # Dann hätten wir diejenigen ${MAX_GOOD_GPUs} - ${SwitchOnCnt} noch zu überprüfen und zu stoppen !?!?

    _decode_MAX_PROFIT_GPU_Algo_Combination_to_GPUINDEXES

    declare -i SwitchOnCnt=${#GPUINDEXES[@]}
    declare -i GPUsCnt=${#index[@]}
    declare -i NewLoad=0

    if [[ ${verbose} == 1 ]]; then
        echo "Die optimale Konfiguration besteht aus diesen ${SwitchOnCnt} Karten:"
    fi
    ###                                                             ###
    #   Zuerst die am Gewinn beteiligten GPUs, die laufen sollen...   #
    ###                                                             ###
    for (( i=0; $i<${SwitchOnCnt}; i++ )); do
        # Split the "String" at ":" into the 2 variables "gpu_idx" and "algoidx"
        read gpu_idx algoidx <<<"${GPUINDEXES[$i]//:/ }"

        # Ausfiltern der Guten GPUs aus PossibleCandidateGPUidx.
        # PossibleCandidateGPUidx enthält dann zum Schluss nur noch ebenfalls abzuschaltende GPUs
        unset tmparray
        for p in ${!PossibleCandidateGPUidx[@]}; do
            [[ "${PossibleCandidateGPUidx[$p]}" != "${gpu_idx}" ]] && tmparray+=( ${PossibleCandidateGPUidx[$p]} )
        done
        PossibleCandidateGPUidx=( ${tmparray[@]} )

        declare -n actGPUalgoName="GPU${gpu_idx}Algos"
        declare -n actGPUalgoWatt="GPU${gpu_idx}Watts"
        gpu_uuid=${uuid[${gpu_idx}]}

        if [ ! ${#RunningGPUid[@]} -eq 0 ]; then
            #############################   CHAOS BEHADLUNG Anfang  #############################
            ### Schweres Thema: IST DER GPU-INDEX NOCH DER SELBE ??? <-----------------------
            #echo "\${gpu_idx}:${gpu_idx} == \${RunningGPUid[\${gpu_uuid}:${gpu_uuid}]}:${RunningGPUid[${gpu_uuid}]}"
            if [[ "${gpu_idx}" != "${RunningGPUid[${gpu_uuid}]}" ]]; then
                _notify_about_GPU_INDEX_CHANGED_WHILE_RUNNING "${name[${gpu_idx}]}" \
                                                              "${gpu_uuid}" \
                                                              "${RunningGPUid[${gpu_uuid}]}" \
                                                              "${gpu_idx}"
                exit
            fi
            #############################   CHAOS BEHADLUNG  Ende  #############################

            # Der Soll-Zustand kommt aus der manuell bearbeiteten Systemdatei ganz am Anfang
            # Wir schalten auf jeden Fall den gewünschten Soll-Zustand.
            # Eventuell müssen wir mit dem letzten Run-Zustand vergleichen, um etwas zu stoppen...
            printf "${gpu_uuid}:${gpu_idx}:${uuidEnabledSOLL[${gpu_uuid}]}:" >>${RUNNING_STATE}

            # Ist die GPU generell Enabled oder momentan nicht zu behandeln?
            if ((${WasItEnabled[${gpu_uuid}]} == 1)); then
                #
                # Die Karte WAR generell ENABLED
                #
                if [[ ${uuidEnabledSOLL[${gpu_uuid}]} == 1 ]]; then

                    #
                    # Die Karte BLEIBT generell ENABLED
                    #
                    ########################################################
                    ### START- STOP- SWITCHING- Skripte.
                    ### Hier ist die richtige Stelle, die Miner zu switchen
                    ########################################################

                    ### Lief die Karte mit dem selben Algorithmus?
                    if [[ "${WhatsRunning[${gpu_uuid}]}" != "${actGPUalgoName[${algoidx}]}" ]]; then
                        if [[ -z "${WhatsRunning[${gpu_uuid}]}" ]]; then
                            # MINER- Behandlung
                            echo "---> SWITCH-CMD: GPU#${gpu_idx} EINSCHALTEN mit Algo \"${actGPUalgoName[${algoidx}]}\""
                        else
                            # MINER- Behandlung
                            echo "---> SWITCH-CMD: GPU#${gpu_idx} Algo WECHSELN von \"${WhatsRunning[${gpu_uuid}]}\" auf \"${actGPUalgoName[${algoidx}]}\""
                        fi
                    else
                        # Alter und neuer Algo ist gleich, kann weiterlaufen
                        echo "---> SWITCH-NOT: GPU#${gpu_idx} BLEIBT weiterhin auf \"${actGPUalgoName[${algoidx}]}\""
                    fi
                    printf "${actGPUalgoWatt[${algoidx}]}:${actGPUalgoName[${algoidx}]}\n" >>${RUNNING_STATE}
                    if [ $NoCards ]; then
                        [ "${actGPUalgoWatt[${algoidx}]}" != "" ] && NewLoad=$(($NewLoad+${actGPUalgoWatt[${algoidx}]}))
                    fi
                else
                    #
                    # Die Karte ist NUN generell DISABLED!
                    #
                    # GERADE SEHEN WIR, DASS DIE TATSACHE, DASS DIESE KARTE MIT IN DIE BERECHNUNGEN
                    # EINBEZOGEN WURDE, SINNLOS WAR!
                    # Wir müssen im Anschluss überlegen, wo wir das abzuchecken haben, BEVOR
                    # wir mit den Berechnungen beginnen.
                    # Dann wird dieser Fall hier GAR NICHT MEHR VORKOMMEN <---   NOCH ZU IMPLEMENTIEREN
                    # MINER- Behandlung
                    echo "---> SWITCH-OFF: GPU#${gpu_idx} wurde generell DISABLED und ist abzustellen!"
                    echo "---> SWITCH-OFF: Sie läuft noch mit \"${WhatsRunning[${gpu_uuid}]}\""
                    printf "0:\n" >>${RUNNING_STATE}
                fi
            else
                #
                # Die Karte WAR generell DISABLED
                #
                if [[ "${uuidEnabledSOLL[${gpu_uuid}]}" == "1" ]]; then
                    #
                    # Die Karte IST NUN generell ENABLED
                    #
                    ########################################################
                    ### START- STOP- SWITCHING- Skripte.
                    ### Hier ist die richtige Stelle, die Miner zu switchen
                    ########################################################
                    # MINER- Behandlung
                    echo "---> SWITCH-CMD: GPU#${gpu_idx} EINSCHALTEN mit Algo \"${actGPUalgoName[${algoidx}]}\""
                    printf "${actGPUalgoWatt[${algoidx}]}:${actGPUalgoName[${algoidx}]}\n" >>${RUNNING_STATE}
                    if [ $NoCards ]; then
                        [ "${actGPUalgoWatt[${algoidx}]}" != "" ] && NewLoad=$(($NewLoad+${actGPUalgoWatt[${algoidx}]}))
                    fi
                else
                    #
                    # Die Karte BLEIBT generell DISABLED
                    #
                    # Zeile abschliessen
                    echo "---> SWITCH-NOT: GPU#${gpu_idx} BLEIBT weiterhin DISABLED"
                    printf "0:\n" >>${RUNNING_STATE}
                fi
            fi
        else
            ### IM ${RUNNING_STATE} WAREN KEINERLEI EINTRÄGE.
            ### Wahrscheinlich existierte sie noch nie. Jetzt kommen AUF JEDEN FALL Einträge hinein.
            ### Wir wisseen also nichts über den laufenden Zustand und schalten deshalb einfach alles nur ein,
            ###     falls nicht eine GPU Generell DISABLED ist.
            # Den SOLL-Zustand über Generell ENABLED/DISABLED haben wir am Anfang ja eingelesen.

            if [[ "${uuidEnabledSOLL[${gpu_uuid}]}" == "1" ]]; then
                #
                # Die Karte IST generell ENABLED
                #
                ########################################################
                ### START- STOP- SWITCHING- Skripte.
                ### Hier ist die richtige Stelle, die Miner zu switchen
                ########################################################

                # MINER- Behandlung
                echo "---> SWITCH-CMD: GPU#${gpu_idx} EINSCHALTEN mit Algo \"${actGPUalgoName[${algoidx}]}\""
                printf "${gpu_uuid}:${gpu_idx}:${uuidEnabledSOLL[${gpu_uuid}]}:${actGPUalgoWatt[${algoidx}]}:${actGPUalgoName[${algoidx}]}\n" >>${RUNNING_STATE}
                if [ $NoCards ]; then
                    [ "${actGPUalgoWatt[${algoidx}]}" != "" ] && NewLoad=$(($NewLoad+${actGPUalgoWatt[${algoidx}]}))
                fi
            else
                #
                # Die Karte IST generell DISABLED
                #
                # MINER- Behandlung
                echo "---> SWITCH-OFF: GPU#${gpu_idx} wurde generell DISABLED und ist abzustellen!"
                printf "${gpu_uuid}:${gpu_idx}:${uuidEnabledSOLL[${gpu_uuid}]}:0:\n" >>${RUNNING_STATE}
            fi
        fi

        if [[ ${verbose} == 1 ]]; then
            echo "GPU-Index        #${gpu_idx}"
            echo "GPU-Algo-Index   [${algoidx}]"
            echo "GPU-AlgoName     ${actGPUalgoName[${algoidx}]}"
            algoWatts=${actGPUalgoWatt[${algoidx}]}
            echo "GPU-AlgoWatt     ${algoWatts}"
            declare -n actGPUalgoMines="GPU${gpu_idx}Mines"
            algoMines=${actGPUalgoMines[${algoidx}]}
            echo "GPU-AlgoMines    ${algoMines}"
            _calculate_ACTUAL_REAL_PROFIT \
                ${SolarWattAvailable} ${algoWatts} ${algoMines}
            echo "RealGewinnSelbst ${ACTUAL_REAL_PROFIT} (wenn alleine laufen würde)"
        fi
    done

    # Die Guten GPUs sind raus aus PossibleCandidateGPUidx.
    # PossibleCandidateGPUidx enthält jetzt nur noch ebenfalls abzuschaltende GPUs,
    # die wir jetzt auf's SwitchOffGPUs Array packen
    SwitchOffGPUs=(${SwitchOffGPUs[@]} ${PossibleCandidateGPUidx[@]})

    ###                                                             ###
    #   ... dann die GPU's, die abgeschaltet werden sollen            #
    ###                                                             ###

    declare -i SwitchOffCnt=${#SwitchOffGPUs[@]}
    if [ $((${SwitchOffCnt} + ${SwitchOnCnt})) -ne ${GPUsCnt} ]; then
        echo "---> ??? Oh je, ich glaube fast, wir haben da ein paar GPU's vergessen abzuschalten ??? <---"
    fi

    # Auch hier kann es natürlich vorkommen, dass sich eine Indexnummer geändert hat
    #      und dass dann die CHAOS-BEHANDLUNG durchgeführt werden muss.
    if [ ${SwitchOffCnt} -gt 0 ]; then
        if [[ ${verbose} == 1 ]]; then
            echo "Die folgenden Karten müssen ausgeschaltet werden:"
        fi

        for (( i=0; $i<${SwitchOffCnt}; i++ )); do
            gpu_idx=${SwitchOffGPUs[$i]}
            gpu_uuid=${uuid[${gpu_idx}]}

            if [ ! ${#RunningGPUid[@]} -eq 0 ]; then
                #############################   CHAOS BEHADLUNG Anfang  #############################
                ### Schweres Thema: IST DER GPU-INDEX NOCH DER SELBE ??? <-----------------------
                if [[ "${gpu_idx}" != "${RunningGPUid[${gpu_uuid}]}" ]]; then
                    _notify_about_GPU_INDEX_CHANGED_WHILE_RUNNING "${name[${gpu_idx}]}" \
                                                                  "${gpu_uuid}" \
                                                                  "${RunningGPUid[${gpu_uuid}]}" \
                                                                  "${gpu_idx}"
                    exit
                fi
                #############################   CHAOS BEHADLUNG  Ende  #############################

                if ((${WasItEnabled[${gpu_uuid}]} == 1)); then
                    #
                    # Die Karte WAR generell ENABLED
                    #
                    if [[ -n "${WhatsRunning[${gpu_uuid}]}" ]]; then
                        # MINER- Behandlung
                        echo "---> SWITCH-OFF: GPU#${gpu_idx} ist ABZUSTELLEN!"
                        echo "---> SWITCH-OFF: GPU#${gpu_idx} läuft noch mit \"${WhatsRunning[${gpu_uuid}]}\""
                    fi
                else
                    echo "---> SWITCH-NOT: GPU#${gpu_idx} BLEIBT weiterhin DISABLED"
                fi
            fi
            printf "${gpu_uuid}:${gpu_idx}:${uuidEnabledSOLL[${gpu_uuid}]}:0:\n" >>${RUNNING_STATE}
        done
    fi
    if [[ ${verbose} == 1 ]]; then
        echo "-------------------------------------------------"
    fi

    # Zugriff auf die Globale Steuer- und Statusdatei wieder zulassen
    rm -f ${RUNNING_STATE}.lock                      # ... und wieder freigeben

    echo "Zugriff auf neues globales Switching Sollzustand Kommandofile ${RUNNING_STATE} freigegeben:"
    cat ${RUNNING_STATE}

    if [ $NoCards ]; then
        if [[ $NewLoad -gt 0 ]]; then
            echo "         \"PowerReal_P_Sum\" : $((${ACTUAL_SMARTMETER_KW}-${SUM_OF_RUNNING_WATTS}+${NewLoad})).6099354," \
                 >smartmeter
        fi
    fi

    [[ ${performanceTest} -ge 1 ]] && echo "$(date --utc +%s): >8.< Eintritt in den WARTEZYKLUS..." >>perfmon.log

    printf "=========         Ende des Zyklus um:         $(date "+%Y-%m-%d %H:%M:%S" )         =========\n\n"
    while [ "${new_Data_available}" == "$(date --utc --reference=${SYNCFILE} +%s)" ] ; do
        sleep 1
    done

done  ## while : 

