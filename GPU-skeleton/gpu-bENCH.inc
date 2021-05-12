#!/bin/bash
###############################################################################
#
# Die Variablen   $IMPORTANT_BENCHMARK_JSON,
#                 $bENCH_SRC   (=="bENCH.in")
#                 $gpu_idx
#                 $LINUX_MULTI_MINING_ROOT
#     müssen gesetzt sein.
#
# Erzeugt werden die Variablen
#                 $IMPORTANT_BENCHMARK_JSON_last_age_in_seconds
#     und jede Menge Assoziativer Arrays, die über
#     $algorithm   (== algo#miner_name#miner_version)
#     angesprochen werden können.
#
# Die folgenden Funktionen werden hier drin definiert:
# function _expand_IMPORTANT_BENCHMARK_JSON ()
# function _read_IMPORTANT_BENCHMARK_JSON_in ()
# function _init_some_file_and_path_variables () {
# function _init_NH_continent_handling () {
# function _disable_algorithm () {
# function _disable_algo_for_5_minutes () {
# function _terminate_Logger_Terminal () {
# function _terminate_Miner () {

_GPU_BENCH_INCLUDED=1

[[ ${#_MINERFUNC_INCLUDED} -eq 0 ]] && source ${LINUX_MULTI_MINING_ROOT}/miner-func.inc

# Extrem wichtige Funktion zur Erweiterung der JSON, falls notwendig.
#
# Diese Funktion soll die Automatische Anpassung der eingestellten IMPORTANT_BENCHMARK_JSON
# oder der als Parameter übergebenen .JSON durchführen:
# 1. Backup Datei erstellen
# 2. Änderungslauf Erweiterung um Minerversion und Korrektur der Eigenschaft MinerName
# 3. Aufnahme der neuen Eigenschaften/Felder "MAX_WATT" bis "MinerFee"
#
# Folgende Varablen MÜSSEN eingestellt sein:
#     IMPORTANT_BENCHMARK_JSON 
#         ("../${gpu_uuid}/benchmark_${gpu_uuid}.json")
#         ("../GPU-skeleton/benchmark_skeleton.json")
# Der benchmark_skeleton.json kommt dabei eine besondere Rolle bei der Synchronisation der Verteilung zu:
#     Wenn sie verändert wurde und neuer oder wenigstens gleich alt ist wie die sie ändernde Datei (hier),
#     dann ist das das Zeichen, dass alles für die Verteilung vorbereitet ist:
#     - gpu-bench.sh
#     - gpu-bENCH.inc
#     - bench_30s_2.sh
#     - tweak_commands.sh
# Zweite Session:
#     - multi_mining_cals.sh muss zusammen mit gpu_gv-algo.sh die ALGO_WATTS_MINES.in abstimmen!
#     sind alle vorbereitet, dass jeder Prozess die neue Struktur vorfindet.

function _expand_IMPORTANT_BENCHMARK_JSON ()
{
    # echo ${IMPORTANT_BENCHMARK_JSON}
    #
    # Zu 1. Backup Datei erstellen
    #
    # IMPORTANT_BENCHMARK_JSON="../${gpu_uuid}/benchmark_${gpu_uuid}.json"
    cp -f ${IMPORTANT_BENCHMARK_JSON} ${IMPORTANT_BENCHMARK_JSON}.STRUCT_BAK

    #
    # 1. Erweiterung der Blockstruktur des benchmark_${gpu_uuid}.json um die Felder
    #    "HashCountPerSeconds" (als Quotient aus hashCount und HASH_DURATION, 4 Stellen hinter dem Komma)
    #    "BenchMode"           ( "l" für LIVE oder "o" für OFFLINE
    # 2. "NiceHashID     kann wieder raus. Interessiert eigentlich niemanden, weil die JSON nicht nur für NiceHash,
    #                    sondern für alle MiningAlgos da ist, die vom jeweiligen Pool unabhängig sind.
    #    "MinerBaseType" kann raus, bis wir wissen, was das soll.
    #    "ExtraLaunchParameters" raus, bis wir wissen, was das soll.
    #    "MinerFee"      kann wieder raus, weil die MinerFees in ../miners/all.miner.fees gepflegt werden
    #    
    # Kann wieder raus, wenn es keine "veralteten" benchmark_*.json Dateien mehr gibt.
    #
    grep -m1 -c "\"HashCountPerSeconds\": " ${IMPORTANT_BENCHMARK_JSON}.STRUCT_BAK &>/dev/null \
        || gawk -e 'BEGIN {FS=":"}
           match( $0, /"Name": / ) { print $0     # Name bzw. MiningAlgo
                           getline                # NiceHashID                      raus
                           getline                # MinerBaseType                   raus
                           getline;  print $0     # MinerName
                           getline;  print $0     # MinerVersion
                           getline;  print $0     # BenchmarkSpeed
                           getline                # ExtraLaunchParameters           raus
                           getline;  print $0     # WATT
                           getline;  print $0     # MAX_WATT
                           getline;  print $0     # HASHCOUNT
                           getline;  print $0     # HASH_DURATION
                           getline;  print $0     # BENCH_DATE
                           getline;  print $0     # BENCH_KIND
                           getline                # MinerFee                        raus
                           getline;  print $0     # GPUGraphicsClockOffset[3]
                           getline;  print $0     # GPUMemoryTransferRateOffset[3]
                           getline;  print $0     # GPUTargetFanSpeed
                           getline;  print $0     # PowerLimit
                           print "      \"HashCountPerSeconds\": 0,"
                           print "      \"BenchMode\": o,"
                           next }
           {print}' ${IMPORTANT_BENCHMARK_JSON}.STRUCT_BAK >${IMPORTANT_BENCHMARK_JSON}

}

function _read_IMPORTANT_BENCHMARK_JSON_in ()
{
    local w_o_miners=0
    if [ "$1" == "without_miners" ]; then w_o_miners=1; fi
    if [ ${w_o_miners} -eq 0 ]; then
        ################################################################################
        #
        # Feststellen der Menge an Algorithmen, die insgesamt im System möglich sind
        #    und nur diese Menge an $algorithm-Objekten einlesen.
        #
        #################################################################################

        # Einlesen aller $algorithm-Objekte (Algo#MinerName#MinerVersion) aus den ${miner_name}#${miner_version}.algos Dateien
        # in ALLE diese Arrays:
	# ALLE_MINER[ i ]   = ${miner_name}#${miner_version}
	# MINER_IS_AVAILABLE[ ${miner_name}#${miner_version} ] = 1
	# MINER_FEES[         ${miner_name}#${miner_version} ] = 1.25
	# -n "Mining_${miner_name//-/_}_${miner_version//\./_}_Algos"[ ${coin} ] = ${algo}
        # Das Verzeichnis, das alle diese Informationen bereit hält ist: ${LINUX_MULTI_MINING_ROOT}/miners
        _set_ALLE_MINER_from_path

    fi

    # Das sind die Werte zu jedem einzelnen "${algorithm}" == "${algo}#${miner_name}#${miner_version}"
    unset bENCH               ; declare -Ag bENCH
    unset WATTS               ; declare -Ag WATTS
    unset MAX_WATT            ; declare -Ag MAX_WATT
    unset HASHCOUNT           ; declare -Ag HASHCOUNT
    unset HASH_DURATION       ; declare -Ag HASH_DURATION
    unset BENCH_DATE          ; declare -Ag BENCH_DATE
    unset BENCH_KIND          ; declare -Ag BENCH_KIND
    unset GRAFIK_CLOCK        ; declare -Ag GRAFIK_CLOCK
    unset MEMORY_CLOCK        ; declare -Ag MEMORY_CLOCK
    unset FAN_SPEED           ; declare -Ag FAN_SPEED
    unset POWER_LIMIT         ; declare -Ag POWER_LIMIT
    unset HashCountPerSeconds ; declare -Ag HashCountPerSeconds
    unset BenchMode           ; declare -Ag BenchMode
    unset LESS_THREADS        ; declare -Ag LESS_THREADS
    unset READARR

    _reserve_and_lock_file ${IMPORTANT_BENCHMARK_JSON}    # Zum Lesen und Bearbeiten reservieren...

    # Dateialter zum Zeitpunkt des Array-Aufbaus festhalten
    IMPORTANT_BENCHMARK_JSON_last_age_in_seconds=$(date --reference=$IMPORTANT_BENCHMARK_JSON +%s)

    ################################################################################
    #
    # Einlesen aller Algorithmen aus der IMPORTANT_BENCHMARK_JSON in die Arrays
    #
    #################################################################################

    # Einlesen der Benchmarkdatei nach READARR
    #
    # 1. Datei benchmark_GPU-742cb121-baad-f7c4-0314-cfec63c6ec70.json erstellen
    # 2. IN DIESER .json DATEI SIND <CR> DRIN !!!!!!!!!!!!!!!!!!!!!!!
    # 3. Array $bENCH[] in Datei bENCH.in pipen
    # 4. Anschließend einlesen und Array mit Werten aufbauen
    # Die begehrten Zeilen...
    #      "Name":           "neoscrypt",
    #      "MinerName":      "ccminer",
    #      "MinerVersion":   "2.2",
    #      "BenchmarkSpeed": 896513.0,
    #      "WATT":           320,
    #
    #      "Name": "%s",
    #      "NiceHashID": %i,
    #      "MinerName": "%s",
    #      "MinerVersion": "%s",
    #      "BenchmarkSpeed": %i,
    #      "WATT": %i,
    #      "GPUGraphicsClockOffset[3]": %i,
    #      "GPUMemoryTransferRateOffset[3]": %i,
    #      "GPUTargetFanSpeed": %i,
    #      "PowerLimit": %i,
    #      "HashCountPerSeconds": %i,
    #      "BenchMode": %i,
    #      "LessThreads": %i
    #
    #      ... werden zu den 3 Zeilen
    #
    #      neoscrypt#ccminer#2.2
    #      896513.0
    #      320
    #      
    #sed -e 's/\r//g' $IMPORTANT_BENCHMARK_JSON | \
    [ ${#bENCH_SRC} -eq 0 ] && bENCH_SRC=${IMPORTANT_BENCHMARK_JSON}.tee_bENCH_SRC
    gawk -e '$1 ~ /"Name":/ \
       { mining_algo = substr( tolower($2), 2, length($2)-3 )
         if ( length( mining_algo ) > 0 ) {
            getline                                       # MinerName
            miner_name          = substr( $2, 2, length($2)-3 )
            getline                                       # MinerVersion
            miner_version       = substr( $2, 2, length($2)-3 )
            getline                                       # BenchmarkSpeed
            benchspeed          = substr( $2, 1, length($2)-1 )
            getline                                       # WATT
            watt                = substr( $2, 1, length($2)-1 )
            getline                                       # MAX_WATT
            MAX_WATT            = substr( $2, 1, length($2)-1 )
            getline                                       # HASHCOUNT
            HASHCOUNT           = substr( $2, 1, length($2)-1 )
            getline                                       # HASH_DURATION
            HASH_DURATION       = substr( $2, 1, length($2)-1 )
            getline                                       # BENCH_DATE
            BENCH_DATE          = substr( $2, 1, length($2)-1 )
            getline                                       # BENCH_KIND
            BENCH_KIND          = substr( $2, 1, length($2)-1 )
            getline                                       # GRAFIK_CLOCK
            grafik_clock        = substr( $2, 1, length($2)-1 )
            getline                                       # MEMORY_CLOCK
            memory_clock        = substr( $2, 1, length($2)-1 )
            getline                                       # FAN_SPEED
            fan_speed           = substr( $2, 1, length($2)-1 )
            getline                                       # POWER_LIMIT
            power_limit         = substr( $2, 1, length($2)-1 )
            getline                                       # HashCountPerSeconds
            HashCountPerSeconds = substr( $2, 1, length($2)-1 )
            getline                                       # BenchMode
            BenchMode           = substr( $2, 1, length($2)-1 )
            getline                                       # LESS_THREADS
            less_threads  = substr( $2, 1, length($2)-0 )
            algorithm = mining_algo "#" miner_name "#" miner_version
            if ( BENCH_KIND == 888 )
               { algorithm = algorithm "#888" }
            print algorithm
            print benchspeed
            print watt
            print MAX_WATT
            print HASHCOUNT
            print HASH_DURATION
            print BENCH_DATE
            print BENCH_KIND
            print grafik_clock
            print memory_clock
            print fan_speed
            print power_limit
            print HashCountPerSeconds
            print BenchMode
            print less_threads
            next
         }
       }' ${IMPORTANT_BENCHMARK_JSON} \
        | tee $bENCH_SRC \
        | readarray -n 0 -O 0 -t READARR
    _remove_lock                                     # ... und wieder freigeben

    constAnzahlParameter=15
    # Aus den MinerName:BenchmarkSpeed:WATT Paaren das assoziative Array bENCH erstellen
    for (( i=0; $i<${#READARR[@]}; i+=${constAnzahlParameter} )) ; do
        lfdAlgorithm=${READARR[$i]}

        # Nur diejenigen $algorithm-Objekte einlesen, die im System aktuell möglich sind 
        if [ ${w_o_miners} -eq 0 ]; then
            read lfdMiningAlgo m_name m_version <<<"${lfdAlgorithm//#/ }"
            [[ ! ${#MINER_IS_AVAILABLE[${m_name}#${m_version}]} -eq 1 ]] && continue
        fi

        bENCH[${lfdAlgorithm}]=${READARR[$i+1]}
        declare -ig WATTS[${lfdAlgorithm}]=${READARR[$i+2]}
        if [[ "${bENCH[${lfdAlgorithm}]}" != "0" && (${#WATTS[${lfdAlgorithm}]} == 0 || ${WATTS[${lfdAlgorithm}]} == 0) ]]; then
           WATTS[${lfdAlgorithm}]=1000
           notify-send -t 10000 -u critical "### Fehler in Benchmarkdatei ###" \
                 "GPU-Dir: ${GPU_DIR} \n MiningAlgoName: ${lfdAlgorithm} \n KEINE WATT ANGEGEBEN. Verwende 1000"
        fi
        # Die müssen alle in der richtigen Reihenfolge stehen!
        declare -i ofs=3
        MAX_WATT[${lfdAlgorithm}]=${READARR[$i+ofs++]}
        HASHCOUNT[${lfdAlgorithm}]=${READARR[$i+ofs++]}
        HASH_DURATION[${lfdAlgorithm}]=${READARR[$i+ofs++]}
        BENCH_DATE[${lfdAlgorithm}]=${READARR[$i+ofs++]}
        BENCH_KIND[${lfdAlgorithm}]=${READARR[$i+ofs++]}
        GRAFIK_CLOCK[${lfdAlgorithm}]=${READARR[$i+ofs++]}
        MEMORY_CLOCK[${lfdAlgorithm}]=${READARR[$i+ofs++]}
        FAN_SPEED[${lfdAlgorithm}]=${READARR[$i+ofs++]}
        local -i PL=${READARR[$i+ofs++]}
        [[ ${PL} -eq 0 ]] && PL=${defPowLim[${gpu_idx}]}
        POWER_LIMIT[${lfdAlgorithm}]=${PL}
        HashCountPerSeconds[${lfdAlgorithm}]=${READARR[$i+ofs++]}
        BenchMode[${lfdAlgorithm}]=${READARR[$i+ofs++]}
        LESS_THREADS[${lfdAlgorithm}]=${READARR[$i+ofs++]}
    done

#    if [ ${w_o_miners} -eq 0 ]; then
        ################################################################################
        #
        # Vergleich der eingelesenen Algorithmen mit der Menge an Algorithmen,
        # die insgesamt im System möglich sind und auf eventuell fehlende Hinweisen.
        #
        #################################################################################

        # Dann alle Minerversionen und die entsprechenden Algos durchgehen und schauen, ob diese
        # Algos gerade aus der IMPORTANT_BENCHMARK_JSON eingelesen wurden.
        # Wenn nicht, Ausgabe einer entsprechenden Meldung

        unset algo_checked pleaseBenchmarkAlgorithm
        declare -Ag algo_checked
	declare -ag pleaseBenchmarkAlgorithm
        for minerName in ${ALLE_MINER[@]}; do
            read m_name m_version <<<"${minerName//#/ }"
	    #$$$ Dieses Array hat als keys wenigstens 1x actMiningAlgos[${algo_coin}]="${mining_algo}"
	    # den ${algo_coin} und als Value den ${mining_algo}
	    # Irgendetwas stimmt hier nicht $$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$
            declare -n actMiningAlgos="Mining_${m_name//\-/_}_${m_version//\./_}_Algos"
            for lfdMiningAlgo in ${actMiningAlgos[@]}; do
                lfdAlgorithm="${lfdMiningAlgo}#${m_name}#${m_version}"
                if [ ${#algo_checked[${lfdAlgorithm}]} -eq 0 ]; then
                    if [ ${#bENCH[${lfdAlgorithm}]} -eq 0 ]; then
                        printf "GPU #%s:%40s <------- Bitte Benchmark durchführen\n" \
                               ${gpu_idx} ${lfdAlgorithm}
			pleaseBenchmarkAlgorithm[${#pleaseBenchmarkAlgorithm[@]}]=${lfdAlgorithm}
			algo_checked[${lfdAlgorithm}]=0
		    else
			algo_checked[${lfdAlgorithm}]=1
                    fi
                fi
            done
        done
#    fi
}

################################################################################
###
### Funktionen für die Benchmark-Auswertungen.
### Gleichzeitig von MinerShell und bench_30s verwendete Routinen
###
################################################################################

# Hier fehlt irgendwie noch das Overclocking !? $$$$$$$$$$$$$$$$$$$$
function _init_some_file_and_path_variables () {
    LOG_FATALERROR_ALL=${LINUX_MULTI_MINING_ROOT}/log_FATALERROR
    LOG_FATALERROR=${LINUX_MULTI_MINING_ROOT}/${gpu_uuid}/log_FATALERROR_${coin_algorithm}
    LOG_CONLOSS_ALL=${LINUX_MULTI_MINING_ROOT}/log_ConLoss
    LOG_CONLOSS=${LINUX_MULTI_MINING_ROOT}/${gpu_uuid}/log_ConLoss_${coin_algorithm}
    LOG_BOOOOOS_ALL=${LINUX_MULTI_MINING_ROOT}/log_Booooos
    LOG_BOOOOOS=${LINUX_MULTI_MINING_ROOT}/${gpu_uuid}/log_Booooos_${coin_algorithm}
    LOG_NO_HASH_ALL=${LINUX_MULTI_MINING_ROOT}/log_No_Hash
    LOG_NO_HASH=${LINUX_MULTI_MINING_ROOT}/${gpu_uuid}/log_No_Hash_${coin_algorithm}
}

################################################################################
###
###          Ganz schöne Ääction wegen der "continent"e Verwaltung
###
################################################################################
function _init_NH_continent_handling () {
    nowDate=$(date "+%Y-%m-%d %H:%M:%S" )
    declare -ig nowSecs=$(date +%s) timestamp
    if [ "${pool}" == "nh" ]; then
        CONTINENTFILE="${LINUX_MULTI_MINING_ROOT}/${gpu_uuid}/act_continent_${coin_algorithm}"
        while :; do
            declare -ig location_ptr=0                         # Index in das optimal aufgebaute LOCATION Array, beginnend mit "eu"
            if [[ "${continent}" == "SelbstWahl" ]]; then
                if [ -s ${CONTINENTFILE} ]; then
                    read _date_ _oclock_ timestamp location_ptr continent <<<$(tail -n 1 ${CONTINENTFILE})
                    if   [ ${location_ptr} -eq 0 ]; then
                        continent=${LOCATION[${location_ptr}]}
                    elif [ ${nowSecs} -gt $((${timestamp}+3600)) ]; then
                        # Let's try the best one again ...
                        location_ptr=0
                        continent=${LOCATION[${location_ptr}]}
                        echo "# Probieren wir es nach 1h wieder von vorne mit dem Besten..." >>${CONTINENTFILE}
                        echo ${nowDate} ${nowSecs} ${location_ptr} ${continent}              >>${CONTINENTFILE}
                    fi
                else
                    continent=${LOCATION[${location_ptr}]}
                    echo "# Beginnen wir neu mit dem Besten..."             >>${CONTINENTFILE}
                    echo ${nowDate} ${nowSecs} ${location_ptr} ${continent} >>${CONTINENTFILE}
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
                    echo "# Entscheidung wurde per Parameter übergeben..."  >>${CONTINENTFILE}
                    echo ${nowDate} ${nowSecs} ${location_ptr} ${continent} >>${CONTINENTFILE}
                    break
                fi
            fi
        done
        # Das brauchen wir, um bei einem Verbindungsabbruch einen Anhaltspunkt zu haben um zu wissen,
        # wann wir alle "continent"e durch sind und weitere Verbindungsversuche bleiben lassen können.
        declare -ig initial_location_ptr=$location_ptr
    fi
}

# Wenn es Probleme beim Benchmarking gibt, wegen zu weniger Werte oder wegen zu vieler boooos,
# dann soll der $algorithm (ein miningAlgo eines ganz bestimmten Minerversion) disabled werden,
# bis sich ein Mensch darum kümmert.
function _disable_algorithm () {
    # $1 - $algorithm
    # $2 - $reason
    # $3 - $gpu_idx
    nowDate=$(date "+%Y-%m-%d %H:%M:%S" )
    nowSecs=$(date +%s)
    _reserve_and_lock_file ../BENCH_ALGO_DISABLED
    printf "%s %s %02i %30s %s\n" "${nowDate}" "${nowSecs}" "$3" "$1" "$2" >>../BENCH_ALGO_DISABLED
    _remove_lock                                     # ... und wieder freigeben
    echo "Der Algorithm ${algorithm} wurde in die Datei BENCH_ALGO_DISABLED eingetragen."
}

function _disable_algo_for_5_minutes () {
    # Algo in die 5-Minuten-Disabled Datei UND in die HISTORY/CHRONIK Datei eintragen...
    _reserve_and_lock_file ../MINER_ALGO_DISABLED_HISTORY
    printf "disable " >>../MINER_ALGO_DISABLED_HISTORY
    printf "${nowDate} ${nowSecs} ${coin_algorithm}\n" \
        | tee -a ../MINER_ALGO_DISABLED \
              >>../MINER_ALGO_DISABLED_HISTORY
    _remove_lock                                     # ... und wieder freigeben
}

function _terminate_Logger_Terminal () {
    ### SCREEN ADDITIONS: ###
    # Wennn man mit Screen arbeitet, sollte man vorher oder nachher die Region "killen",
    # damit die Aufteilung am Bildschirm für den Logger wieder verschwindet.
    # In einer ersten Annäherung wird hier der focus als $1 übergeben
    [ ${#1} -gt 0 ] && screen -X eval focus $1 remove fit

    printf "Beenden des Logger-Terminals alias ${MINER} ... "
    REGEXPAT="${Bench_Log_PTY_Cmd//\//\\/}"
    REGEXPAT="${REGEXPAT//\+/\\+}"
    REGEXPAT="${REGEXPAT//\$/\\$}"
    if [ ${#REGEXPAT} -eq 0 ]; then
        printf "\nDas Logger-Terminal soll beendet werden, die Variable \${Bench_Log_PTY_Cmd} ist aber leer:\n–––>${Bench_Log_PTY_Cmd}<–––\n"
    else
        kill_pids=$(ps -ef \
                  | grep -E -e "${REGEXPAT}" \
                  | grep -v 'grep -E -e ' \
                  | gawk -e 'BEGIN {pids=""} {pids=pids $2 " "} END {print pids}')
        if [ -n "$kill_pids" ]; then
            kill $kill_pids # >/dev/null
            printf "done.\n"
        else
            printf "NOT FOUND!!!\n"
        fi
    fi
}

function _terminate_Miner () {
    if [ -s ${MINER}.pid ]; then
        MINER_pid=$(< ${MINER}.pid)
        if [ -n "${MINER_pid}" ]; then
            printf "Beenden des Miners alias ${coin_algorithm} mit PID ${MINER_pid} ... "
	    if [ ${ScreenTest} -eq 1 ]; then
		REGEXPAT="${find_and_kill_this_pseudo_miner_cmd}"
	    else
		REGEXPAT="${minerstart//\//\\/}"
		REGEXPAT="${REGEXPAT//\+/\\+}"
	    fi
            kill_pid=$(ps -ef | gawk -e '$2 == '${MINER_pid}' && /'"${REGEXPAT}"'/ {print $2; exit }')
            if [ -n "$kill_pid" ]; then
                kill $kill_pid
                if [[ $? -eq 0 ]]; then
                    printf "KILL SIGTERM SIGNAL SUCCESSFULLY SENT.\n"
                else
                    kill -9 $kill_pid
                    if [[ $? -eq 0 ]]; then
                        printf "KILL SIGKILL SIGNAL SUCCESSFULLY SENT, but had to be \"kill -9 $kill_pid\" !\n"
                    else
                        printf "\n–––> KILL_PANIC: KILL SIGKILL SIGNAL COULD NOT BE SENT SUCCESSFULLY, even not \"kill -9 $kill_pid\" !\n"
                    fi
                fi
                sleep $Erholung   # "Erholung" nach jedem kill und vor vor einem Neustart

                # Und nochmal suchen:
                printf "Check PID ${MINER_pid} again after $Erholung seconds ... "
                kill_pid=$(ps -ef | gawk -e '$2 == '${MINER_pid}' && /'"${REGEXPAT}"'/ {print $2; exit }')
                if [ -n "$kill_pid" ]; then
                    printf "\n–––> KILL_PANIC: GPU #${gpu_idx}: $(basename $0): PID ${MINER_pid} of Miner ${MINER} ...
nach $Erholung Sekunden Erholzeit nach kill 15 immer noch vorhanden.
Es folgt ein kill -9... "
                    kill -9 $kill_pid
                    if [[ $? -eq 0 ]]; then
                        printf "KILL -9 SIGNAL SUCCESSFULLY SENT.\n"
                    else
                        printf "\n–––> KILL_PANIC: KILL -9 SIGNAL COULD NOT BE SENT SUCCESSFULLY!\n"
                    fi
                else
                    printf "no longer there.\n"
                fi
            else
                printf "\n–––> KILL_PANIC: GPU #${gpu_idx}: $(basename $0):
PID ${MINER_pid} of Miner ${MINER} NOT FOUND IN PROCESS TABLE after the following search:
awk -e \"\$2 == \${MINER_pid} && /\${REGEXPAT}/ {print $2; exit }\"
awk -e \"\$2 == ${MINER_pid} && /${REGEXPAT}/ {print $2; exit }\"\n" | tee -a ${ERRLOG}
            fi
        else
            printf "–––> KILL_PANIC: Sehr komisch. Miner ${MINER} soll beendet werden, es gibt auch eine -s .pid Datei.
–––> KILL_PANIC: Nach dem Einlesen des Dateiinhalts in die Variable \${MINER_pid} ist die aber leer \"${MINER_pid}\".\n" | tee -a ${ERRLOG}
        fi
    else
	if [ ! ${ScreenTest} -eq 1 ]; then
            printf "–––> KILL_PANIC: Miner ${MINER} soll beendet werden, es gibt aber keine entsprechende .pid Datei.
–––> KILL_PANIC: Möglicherweise wurde er gar nicht gestartet?\n" | tee -a ${ERRLOG}
	fi
    fi
    rm -f ${MINER}.pid
}

# 2020-04-16:
#  9. Prüft hier, ob Algorithms zu benchmarken sind (pleaseBenchmarkAlgorithm[])...
#     zieht die GLOBAL_ALGO_DISABLED davon ab...
#     zieht die BENCH_ALGO_DISABLED davon ab...
#     [SOLL:] zieht die temporär disableten davon ab... $$$$$$$$$$$$$$$$$$$$
#
#     Die Definition dieser Funktion kann in eine .inc verlegt werden $$$$$$$$$$$$$$$$$$$$

# Voraussetzungen.
# - gpu_uuid
function _find_algorithms_to_benchmark {
    # local algo_GPU disabledAlgo GPUs lfdGPU lfdAlgorithm mName mVer muck888 

    unset WillBenchmarkAlgorithm
    declare -ag WillBenchmarkAlgorithm
    unset GLOBAL_ALGO_DISABLED_ARR

    # 1. Zuerst die GLOBAL_ALGO_DISABLED Algos
    _reserve_and_lock_file ${LINUX_MULTI_MINING_ROOT}/GLOBAL_ALGO_DISABLED
    if [ -s ${LINUX_MULTI_MINING_ROOT}/GLOBAL_ALGO_DISABLED ]; then
	cat ${LINUX_MULTI_MINING_ROOT}/GLOBAL_ALGO_DISABLED | grep -E -v -e '^#|^$' | readarray -n 0 -O 0 -t GLOBAL_ALGO_DISABLED_ARR
    fi
    _remove_lock

    unset MyDisabledAlgos
    declare -a MyDisabledAlgos
    for algo_GPU in ${GLOBAL_ALGO_DISABLED_ARR[@]}; do
	read disabledAlgo GPUs <<<"${algo_GPU//:/ }"
	if [ ${#GPUs} -gt 1 ]; then
	    for lfdGPU in ${GPUs}; do
		if [ "${lfdGPU}" == "${gpu_uuid}" ]; then
		    MyDisabledAlgos[${#MyDisabledAlgos[@]}]=${disabledAlgo}
		    break
		fi
	    done
	else
	    # Zeile gilt für ALLE GPUs
	    MyDisabledAlgos[${#MyDisabledAlgos[@]}]=${disabledAlgo}
	fi
    done
    #declare -p MyDisabledAlgos

    # 2. Dann die BENCH_ALGO_DISABLED Algos
    # ...
    unset MyDisabledAlgorithms MyDisabledAlgorithms_in
    declare -a MyDisabledAlgorithms
    _reserve_and_lock_file ${LINUX_MULTI_MINING_ROOT}/BENCH_ALGO_DISABLED
    if [ -s ${LINUX_MULTI_MINING_ROOT}/BENCH_ALGO_DISABLED ]; then
	cat ${LINUX_MULTI_MINING_ROOT}/BENCH_ALGO_DISABLED | grep -E -v -e '^#|^$' | readarray -n 0 -O 0 -t MyDisabledAlgorithms_in
    fi
    _remove_lock                                     # ... und wieder freigeben

    for actRow in "${MyDisabledAlgorithms_in[@]}"; do
	read _date_ _oclock_ timestamp gpuIdx lfdAlgorithm Reason <<<${actRow}
	[ ${gpuIdx#0} -eq ${gpu_idx} ] && MyDisabledAlgorithms[${#MyDisabledAlgorithms[@]}]=${lfdAlgorithm}
    done

    # 3. Dann die vorübergehend disabled ebenfalls feststellen und herausnehmen
    # Diese Untersuchung dazu zu benutzen, den algorithm vom benchmarking auszunehmen, ist ein bisschen hart.
    # Eiegntlich muss noch berücksichtigt werden, welcher POOL da beteiligt ist.
    # Denn vielleicht ist nur der Coin eines bestimmten Pools im Moment nicht verfügbar, der Algorithm aber bei anderen Pools durchaus problemlos laufen könnte.
    unset MINER_ALGO_DISABLED_ARR MINER_ALGO_DISABLED_DAT
    declare -Ag MINER_ALGO_DISABLED_ARR MINER_ALGO_DISABLED_DAT
    _reserve_and_lock_file ${LINUX_MULTI_MINING_ROOT}/MINER_ALGO_DISABLED_HISTORY
    nowDate=$(date "+%Y-%m-%d %H:%M:%S" )
    declare -i nowSecs=$(date +%s)
    if [ -s ${LINUX_MULTI_MINING_ROOT}/MINER_ALGO_DISABLED ]; then
	if [ $debug -eq 1 ]; then echo "Reading ${LINUX_MULTI_MINING_ROOT}/MINER_ALGO_DISABLED ..."; fi
	declare -i timestamp
	unset READARR
	readarray -n 0 -O 0 -t READARR <${LINUX_MULTI_MINING_ROOT}/MINER_ALGO_DISABLED
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
		printf "ENABLED ${nowDate} ${nowSecs} ${coin_algorithm}\n" | tee -a ${LINUX_MULTI_MINING_ROOT}/MINER_ALGO_DISABLED_HISTORY
            fi
	done
	# Weg mit dem bisherigen File...
	mv -f ${LINUX_MULTI_MINING_ROOT}/MINER_ALGO_DISABLED ${LINUX_MULTI_MINING_ROOT}/MINER_ALGO_DISABLED.BAK
	# ... und anlegen eines Neuen, wenn noch Algos im Array sind
	for coin_algorithm in "${!MINER_ALGO_DISABLED_ARR[@]}"; do
            # Die eingelesenen Werte wieder ausgeben
            printf "${MINER_ALGO_DISABLED_DAT[${coin_algorithm}]} ${MINER_ALGO_DISABLED_ARR[${coin_algorithm}]} ${coin_algorithm}\n" >>${LINUX_MULTI_MINING_ROOT}/MINER_ALGO_DISABLED
	done
    fi
    _remove_lock                                     # ... und wieder freigeben

    # 4. Die Erstellung des Arrays der zu benchmarkenden Algorithms
    for lfdAlgorithm in ${pleaseBenchmarkAlgorithm[@]}; do
	for disabledAlgo in ${MyDisabledAlgorithms[@]}; do
	    [ "${lfdAlgorithm}" == "${disabledAlgo}" ] && continue 2
	done
	read lfdAlgo mName mVer muck888 <<<${lfdAlgorithm//#/ }
	echo "checking $lfdAlgo..."
	for disabledAlgo in ${MyDisabledAlgos[@]}; do
	    [ "${lfdAlgo}" == "${disabledAlgo}" ] && continue 2
	done
	for coin_algorithm in ${!MINER_ALGO_DISABLED_ARR[@]}; do
	    read _coin_ _pool_ _algo_ _mNam_ _mVer_ <<<"${coin_algorithm//#/ }"
	    [ "${lfdAlgorithm}" == "${_algo_}#${_mNam_}#${_mVer_}" ] && continue 2
	done
	WillBenchmarkAlgorithm[${#WillBenchmarkAlgorithm[@]}]=${lfdAlgorithm}
    done
}

