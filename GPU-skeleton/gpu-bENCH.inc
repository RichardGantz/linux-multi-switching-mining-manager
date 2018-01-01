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
#     sind ale vorbereitet, dass jeder Prozess die neue Struktur vorfindet.

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

_read_IMPORTANT_BENCHMARK_JSON_in()
{
    local w_o_miners=0
    if [ "$1" == "without_miners" ]; then w_o_miners=1; fi

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

    _reserve_and_lock_file ${IMPORTANT_BENCHMARK_JSON}

    # Dateialter zum Zeitpunkt des Array-Aufbaus festhalten
    IMPORTANT_BENCHMARK_JSON_last_age_in_seconds=$(date --utc --reference=$IMPORTANT_BENCHMARK_JSON +%s)

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
    shopt -s lastpipe
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
    constAnzahlParameter=15
    # Aus den MinerName:BenchmarkSpeed:WATT Paaren das assoziative Array bENCH erstellen
    for (( i=0; $i<${#READARR[@]}; i+=${constAnzahlParameter} )) ; do
        bENCH[${READARR[$i]}]=${READARR[$i+1]}
        declare -ig WATTS[${READARR[$i]}]=${READARR[$i+2]}
        if [[ ${#READARR[$i+1]} -gt 0 && (${#READARR[$i+2]} == 0 || ${READARR[$i+2]} == 0) ]]; then
           WATTS[${READARR[$i]}]=1000
           notify-send -t 10000 -u critical "### Fehler in Benchmarkdatei ###" \
                 "GPU-Dir: ${GPU_DIR} \n MiningAlgoName: ${READARR[$i]} \n KEINE WATT ANGEGEBEN. Verwende 1000"
        fi
        # Die müssen alle in der richtigen Reihenfolge stehen!
        declare -i ofs=3
        MAX_WATT[${READARR[$i]}]=${READARR[$i+ofs++]}
        HASHCOUNT[${READARR[$i]}]=${READARR[$i+ofs++]}
        HASH_DURATION[${READARR[$i]}]=${READARR[$i+ofs++]}
        BENCH_DATE[${READARR[$i]}]=${READARR[$i+ofs++]}
        BENCH_KIND[${READARR[$i]}]=${READARR[$i+ofs++]}
        GRAFIK_CLOCK[${READARR[$i]}]=${READARR[$i+ofs++]}
        MEMORY_CLOCK[${READARR[$i]}]=${READARR[$i+ofs++]}
        FAN_SPEED[${READARR[$i]}]=${READARR[$i+ofs++]}
        local -i P=${READARR[$i+ofs++]}
        [[ ${P} -eq 0 ]] && P=${defPowLim[${gpu_idx}]}
        POWER_LIMIT[${READARR[$i]}]=${P}
        HashCountPerSeconds[${READARR[$i]}]=${READARR[$i+ofs++]}
        BenchMode[${READARR[$i]}]=${READARR[$i+ofs++]}
        LESS_THREADS[${READARR[$i]}]=${READARR[$i+ofs++]}
    done
    rm -f ${IMPORTANT_BENCHMARK_JSON}.lock

    if [ ${w_o_miners} -eq 0 ]; then
        ################################################################################
        #
        # Vergleich der eingelesenen Algorithmen mit der Menge an Algorithmen,
        # die insgesamt im System möglich sind und auf eventuell fehlende Hinweisen.
        #
        #################################################################################

        # Einlesen aller Dateien ${miner_name}#Coin2Algo.names, die die Zuordnung der NH-Namen (Algo/Coin) zu den CC-Namen (Algorithmus) enthält
        # Dann Einlesen der restlichen Algos aus den ${miner_name}#${miner_version}.algos Dateien
        # in ALLE die Arrays "Mining_${miner_name}_${miner_version//\./_}_Algos"
        #
        # Das Verzeichnis, das alle diese Informationen bereit hält ist:
        # ${LINUX_MULTI_MINING_ROOT}/miners

        _set_ALLE_MINER_from_path ${LINUX_MULTI_MINING_ROOT}/miners

        # Dann alle Minerversionen und die entsprechenden Algos durchgehen und schauen, ob diese
        # Algos gerade aus der IMPORTANT_BENCHMARK_JSON eingelesen wurden.
        # Wenn nicht, Ausgabe einer entsprechenden Meldung

        for minerName in ${ALLE_MINER[@]}; do
            read m_name m_version <<<"${minerName//#/ }"
            declare -n actMiningAlgos="Mining_${m_name}_${m_version//\./_}_Algos"
            for lfdMiningAlgo in ${actMiningAlgos[@]}; do
                if [ ${#bENCH["${lfdMiningAlgo}#${m_name}#${m_version}"]} -eq 0 ]; then
                    printf "GPU #%s:%40s <------- Bitte Benchmark durchführen\n" \
                           ${gpu_idx} "${lfdMiningAlgo}#${m_name}#${m_version}"
                fi
            done
        done
    fi
}
