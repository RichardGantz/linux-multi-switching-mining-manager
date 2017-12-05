#!/bin/bash
###############################################################################
#
#
_GLOBALS_INCLUDED=1

# Eigenes Arbeitsverzeichnis, in das jederzeit über "cd ${_WORKDIR_}" zurückgewechselt werden können sollte.
_WORKDIR_=$(pwd)
# Auffinden und setzen der ${LINUX_MULTI_MINING_ROOT} zur absoluten Adressierung, wenn man sichergehen möchte
until [ -d benchmarking ] && [ -d miners ] && [ -d GPU-skeleton ]; do cd ..; done
LINUX_MULTI_MINING_ROOT=$(pwd)
cd ${_WORKDIR_} >/dev/null

# Die SLEEP Zeit nach dem Abbruch eines Miners in Sekunden. Experimentell, .5 bis 3 ???
Erholung=.001

# Das wäre die zu bevorzugende Reihenfolge, wenn man die losses ("usa") als ungünstigst ansieht.
LOCATION=( "eu" "br" "in" "jp" "hk" "usa" )

InetPingStack=(
    62.138.238.100   # t-online.de          antwortet als Schnellster
    8.8.8.8          # google DNS-Server    antwortet als 2.Schnellster
    172.217.22.227   # google.de
    216.58.207.174   # google.com
)

export LD_LIBRARY_PATH=/usr/local/cuda-8.0/lib64/:$LD_LIBRARY_PATH
NH_DOMAIN="nicehash.com"

### gpu-abfrage.sh spezifische Variablen
SYSTEM_FILE="${LINUX_MULTI_MINING_ROOT}/gpu_system.out"
SYSTEM_STATE="${LINUX_MULTI_MINING_ROOT}/GLOBAL_GPU_SYSTEM_STATE"

# Hier drin halten wir den aktuellen GLOBALEN Status des Gesamtsystems fest
RUNNING_STATE="${LINUX_MULTI_MINING_ROOT}/GLOBAL_GPU_ALGO_RUNNING_STATE"

### algo_multi_abfrage.sh spezifische Variablen
algoID_KURSE_PORTS_WEB="${LINUX_MULTI_MINING_ROOT}/KURSE.json"
algoID_KURSE_PORTS_ARR="${LINUX_MULTI_MINING_ROOT}/KURSE_PORTS.in"

SYNCFILE="${LINUX_MULTI_MINING_ROOT}/you_can_read_now.sync"

# Wie rechnet NiceHash und die Miner, wenn sie sagen GH/s?
# Mit 1000 oder mit 1024 als Basis?
declare -i k_base=1024          # CCminer scheint gemäß bench.cpp mit 1024 zu rechnen

GRID[0]="netz"
GRID[1]="solar"
GRID[2]="solar_akku"

declare -Ag DO_AUTO_BENCHMARK_FOR

# Wenn keine Karten da sind, dürfen verschiedene Befehle nicht ausgeführt werden
# und müssen sich auf den Inhalt fixer Dateien beziehen.
if [ $HOME == "/home/richard" ]; then
    NoCards=true
    PATH=${PATH}:${LINUX_MULTI_MINING_ROOT}/benchmarking/nvidia-befehle
fi

# Diese Funktion ist bequem, aber langsamer als die Member eines Arrays in einer for-Schleife zu verbinden.
# Für große Datenmengen, große Arrays, daher besser in einem Array zusammen-joinen.
# UND: Wenn die Funktion OFT gerufen wird, dann ebenfalls lieber eine for-Schleife schreiben.
function join { local IFS="$1"; shift; echo "$*"; }

#
# $1 - Dateiname der für andere zu sperrenden bzw. für Schreiben/Lesen zu reservierenden Datei
#      z.B.: ${IMPORTANT_BENCHMARK_JSON}, ${RUNNING_STATE}, etc.
#
function _reserve_and_lock_file () {
    declare -i locked_loop_counter=0
    while [ -f ${1}.lock ]; do let locked_loop_counter++; done
    touch ${1}.lock
    [[ ${locked_loop_counter} -gt 0 ]] \
        && echo $(date "+%Y-%m-%d %H:%M:%S") " : " ${locked_loop_counter} >>.$(basename ${1}).loop_counter
}

#####################################################
# Einlesen des bisherigen Status laufender GPUs
####################################################
function _read_in_actual_RUNNING_STATE () {
    if [ -f ${RUNNING_STATE} ]; then
        shopt_cmd_before=$(shopt -p lastpipe)
        shopt -s lastpipe

        unset RUNNING_STATE_CONTENT
        #unset AlgoDisabled; declare -Ag AlgoDisabled
        unset RunningGPUid; declare -Ag RunningGPUid
        unset WasItEnabled; declare -Ag WasItEnabled
        unset RunningWatts; declare -Ag RunningWatts
        unset WhatsRunning; declare -Ag WhatsRunning
        cat ${RUNNING_STATE} \
            | grep -e "^GPU-\|^AlgoDisabled" \
            | readarray -n 0 -O 0 -t RUNNING_STATE_CONTENT

        for (( i=0; $i<${#RUNNING_STATE_CONTENT[@]}; i++ )); do
            if [[ "${RUNNING_STATE_CONTENT[$i]:0:4}" == "GPU-" ]]; then
                read RunningUUID RunningGPUidx GenerallyEnabled Watt RunningAlgo <<<"${RUNNING_STATE_CONTENT[$i]//:/ }"
                RunningGPUid[${RunningUUID}]=${RunningGPUidx}
                WasItEnabled[${RunningUUID}]=${GenerallyEnabled}
                RunningWatts[${RunningUUID}]=${Watt}
                WhatsRunning[${RunningUUID}]=${RunningAlgo}
            elif [ "${RUNNING_STATE_CONTENT[$i]:0:12}" == "AlgoDisabled" ]; then
                unset AlgoName sortThem allDisabled
                read -a AlgoName <<<"${RUNNING_STATE_CONTENT[$i]//:/ }"
                read -a sortThem <<<${AlgoDisabled[${AlgoName[1]}]//:/ }
                sortThem=("${sortThem[@]:2}" "${AlgoName[@]:2}")
                rm -f sortThem;        for sortIt in "${sortThem[@]}"; do echo "$sortIt" >>sortThem; done
                rest=$(cat sortThem | sort -u )
                rm -f sortThem
                readarray -t allDisabled <<<${rest//\n/ }
                AlgoDisabled[${AlgoName[1]}]="AlgoDisabled:${AlgoName[1]}:${allDisabled// /:}"
            fi
        done

        ${shopt_cmd_before}

        if [[ ${verbose} == 1 ]]; then
            if [[ ${#RunningGPUid[@]} -gt 0 ]]; then
                echo "---> Alledgedly Running GPUs/Algos"
                unset lfdUUID
                for lfdUUID in ${!RunningGPUid[@]}; do
                    echo "GPU-Index      : ${RunningGPUid[$lfdUUID]}, UUID=$lfdUUID"
                    echo "War sie Enabled? $((${WasItEnabled[$lfdUUID]} == 1))"
                    echo "Wieviel Watt   : ${RunningWatts[$lfdUUID]}"
                    echo "Running Algo   : ${WhatsRunning[$lfdUUID]}"
                done
            fi
            if [[ ${#AlgoDisabled[@]} -gt 0 ]]; then
                echo "---> Temporarily Disabled Algos"
                for algoName in ${!AlgoDisabled[@]}; do
                    unset AlgoName
                    read -a AlgoName <<<"${AlgoDisabled[$algoName]//:/ }"
                    echo "$algoName:"
                    for (( lfdAlgo=2; $lfdAlgo<${#AlgoName[@]}; lfdAlgo++ )); do
                        echo "    ${AlgoName[$lfdAlgo]}"
                    done
                done
            fi
        fi
    fi  ### if [ -f ${RUNNING_STATE} ]; then
}
