#!/bin/bash
###############################################################################
#
# Die Variablen   $IMPORTANT_BENCHMARK_JSON,
#                 $bENCH_SRC   (=="bENCH.in")
#     müssen gesetzt sein.
#
# Erzeugt werden die Variablen
#                 $IMPORTANT_BENCHMARK_JSON_last_age_in_seconds
#     und jede Menge Assoziativer Arrays, die über
#     $algorithm   (==algo#miner_name#miner_version)
#     angesprochen werden können.
#

_read_IMPORTANT_BENCHMARK_JSON_in()
{
    unset bENCH       ; declare -Ag bENCH
    unset WATTS       ; declare -Ag WATTS
    unset EXTRA_PARAMS; declare -Ag EXTRA_PARAMS
    unset GRAFIK_CLOCK; declare -Ag GRAFIK_CLOCK
    unset MEMORY_CLOCK; declare -Ag MEMORY_CLOCK
    unset FAN_SPEED   ; declare -Ag FAN_SPEED
    unset POWER_LIMIT ; declare -Ag POWER_LIMIT
    unset LESS_THREADS; declare -Ag LESS_THREADS
    unset READARR

    # Dateialter zum Zeitpunkt des Array-Aufbaus festhalten
    IMPORTANT_BENCHMARK_JSON_last_age_in_seconds=$(date --utc --reference=$IMPORTANT_BENCHMARK_JSON +%s)

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
    #      "MinerBaseType": %i,
    #      "MinerName": "%s",
    #      "MinerVersion": "%s",
    #      "BenchmarkSpeed": %i,
    #      "ExtraLaunchParameters": "%s",
    #      "WATT": %i,
    #      "GPUGraphicsClockOffset[3]": %i,
    #      "GPUMemoryTransferRateOffset[3]": %i,
    #      "GPUTargetFanSpeed": %i,
    #      "PowerLimit": %i,
    #      "LessThreads": %i
    #
    #      ... werden zu den 3 Zeilen
    #
    #      neoscrypt#ccminer#2.2
    #      896513.0
    #      320
    #      
    #sed -e 's/\r//g' $IMPORTANT_BENCHMARK_JSON | \
    shopt -s lastpipe
    gawk -e '$1 ~ /"Name":/ \
                 { algo          = substr( tolower($2), 2, length($2)-3 ); \
                   getline;                                       # NiceHashID    \
                   getline;                                       # MinerBaseType \
                   getline;                                       # MinerName \
                   miner_name    = substr( $2, 2, length($2)-3 ); \
                   getline;                                       # MinerVersion \
                   miner_version = substr( $2, 2, length($2)-3 ); \
                   getline;                                       # BenchmarkSpeed \
                   benchspeed    = substr( $2, 1, length($2)-1 ); \
                   getline;                                       # ExtraLaunchParameters \
                   extra_params  = substr( $2, 2, length($2)-3 ); \
                   getline;                                       # WATT \
                   watt          = substr( $2, 1, length($2)-1 ); \
                   getline;                                       # GRAFIK_CLOCK \
                   grafik_clock  = substr( $2, 1, length($2)-1 ); \
                   getline;                                       # MEMORY_CLOCK \
                   memory_clock  = substr( $2, 1, length($2)-1 ); \
                   getline;                                       # FAN_SPEED \
                   fan_speed     = substr( $2, 1, length($2)-1 ); \
                   getline;                                       # POWER_LIMIT \
                   power_limit   = substr( $2, 1, length($2)-1 ); \
                   getline;                                       # LESS_THREADS \
                   less_threads  = substr( $2, 1, length($2)-0 ); \
                   print algo "#" miner_name "#" miner_version; \
                   print benchspeed;   \
                   print watt;         \
                   print extra_params; \
                   print grafik_clock; \
                   print memory_clock; \
                   print fan_speed;    \
                   print power_limit;  \
                   print less_threads; \
                   next \
                 }' ${IMPORTANT_BENCHMARK_JSON} \
        | tee $bENCH_SRC \
        | readarray -n 0 -O 0 -t READARR
    # Aus den MinerName:BenchmarkSpeed:WATT Paaren das assoziative Array bENCH erstellen
    for ((i=0; $i<${#READARR[@]}; i+=9)) ; do
        bENCH[${READARR[$i]}]=${READARR[$i+1]}
        declare -ig WATTS[${READARR[$i]}]=${READARR[$i+2]}
        if [[ ${#READARR[$i+1]} -gt 0 && (${#READARR[$i+2]} == 0 || ${READARR[$i+2]} == 0) ]]; then
           WATTS[${READARR[$i]}]=1000
           notify-send -t 10000 -u critical "### Fehler in Benchmarkdatei ###" \
                 "GPU-Dir: ${GPU_DIR} \n Algoname: ${READARR[$i]} \n KEINE WATT ANGEGEBEN. Verwende 1000"
        fi
        EXTRA_PARAMS[${READARR[$i]}]=${READARR[$i+3]}
        GRAFIK_CLOCK[${READARR[$i]}]=${READARR[$i+4]}
        MEMORY_CLOCK[${READARR[$i]}]=${READARR[$i+5]}
        FAN_SPEED[${READARR[$i]}]=${READARR[$i+6]}
        POWER_LIMIT[${READARR[$i]}]=${READARR[$i+7]}
        LESS_THREADS[${READARR[$i]}]=${READARR[$i+8]}
    done
}