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

# Wir verwenden oft "readarray" am Ende einer Pipe. Deshalb wollen wir, dass diese Option global verfügbar ist.
# An jeder Stelle im Source-Code, wo diese Zeile gefunden wird, kann sie also entfernt werden.
shopt -s lastpipe

# Die Anzahl der besten Algos, die bei der globalen Berechnung pro GPU berücksichtigt werden sollen
BEST_ALGO_CNT=5

# Die SLEEP Zeit nach dem Abbruch eines Miners in Sekunden. Experimentell, .5 bis 3 ???
Erholung=.9

# Das wäre die zu bevorzugende Reihenfolge, wenn man die losses ("usa") als ungünstigst ansieht.
LOCATION=( "eu" "br" "in" "jp" "hk" "usa" )

InetPingStack=(
    62.138.238.100   # t-online.de          antwortet als Schnellster
    8.8.8.8          # google DNS-Server    antwortet als 2.Schnellster
    172.217.22.227   # google.de
    216.58.207.174   # google.com
)

export LD_LIBRARY_PATH=/usr/local/cuda-9.1/lib64/:$LD_LIBRARY_PATH

# Die Pools, bzw. Abgabestellen, die wir am besten an einem Kürzel erkennen
#     und die in verschiedenen Domains zu Hause sind.
# Assoziative Arrays, die durch das Pool-Kürzel $pool indexiert werden
# 0 bedeutet: Disabled
# 1 bedeutet: Enabled, wird abgefragt und berechnet und ge-MinerShelld
declare -Ag OfflineInfo POOLS PoolFee PoolActive BOERSE
OfflineInfo["nh"]="all.nicehash"
OfflineInfo["sn"]="all.suprnova"
OfflineInfo["mh"]="all.miningpoolhub"
BOERSE["bittrex"]=0.25
BOERSE["cryptopia"]=0.2
POOLS["nh"]="nicehash.com";             PoolFee["nh"]=3.5      PoolActive["nh"]=1
#      sn = 0 + BOERSE["bittrex"]  0,25 oder BOERSE["cryptopia"] 0.2
POOLS["sn"]="suprnova.cc";              PoolFee["sn"]=0.25     PoolActive["sn"]=0
#      mh= 0,9 + BOERSE["bittrex"] 0,25 oder BOERSE["cryptopia"] 0.2
POOLS["mh"]="hub.miningpoolhub.com";    PoolFee["mh"]=1.15     PoolActive["mh"]=0

declare pool="sn"
declare domain=${POOLS["sn"]}

### gpu-abfrage.sh spezifische Variablen
SYSTEM_FILE="${LINUX_MULTI_MINING_ROOT}/gpu_system.out"
SYSTEM_STATE="${LINUX_MULTI_MINING_ROOT}/GLOBAL_GPU_SYSTEM_STATE"
FATAL_ERRORS="${LINUX_MULTI_MINING_ROOT}/FATAL_ERRORS.log"
# Wieviele Zeilen der gpu_system.out gehören zu jeweils einer GPU
declare -ig num_gpu_rows=6

# Hier drin halten wir den aktuellen GLOBALEN Status des Gesamtsystems fest
RUNNING_STATE="${LINUX_MULTI_MINING_ROOT}/GLOBAL_GPU_ALGO_RUNNING_STATE"

### algo_multi_abfrage.sh spezifische Variablen
algoID_KURSE_PORTS_WEB="${LINUX_MULTI_MINING_ROOT}/KURSE.json"
algoID_KURSE_PORTS_ARR="${LINUX_MULTI_MINING_ROOT}/KURSE_PORTS.in"
rm -f "${LINUX_MULTI_MINING_ROOT}/BTCEURkurs"
BTC_EUR_KURS_WEB="${LINUX_MULTI_MINING_ROOT}/BTC_EUR_kurs.http"
COIN_PRICING_WEB="${LINUX_MULTI_MINING_ROOT}/WhatToMine.json"
COIN_PRICING_ARR="${LINUX_MULTI_MINING_ROOT}/WhatToMine.in"
COIN_TO_BTC_EXCHANGE_WEB="${LINUX_MULTI_MINING_ROOT}/BittrexSummaries.json"
COIN_TO_BTC_EXCHANGE_ARR="${LINUX_MULTI_MINING_ROOT}/BittrexSummaries.in"

MINER_FEES="${LINUX_MULTI_MINING_ROOT}/miners/all.miner.fees"

SYNCFILE="${LINUX_MULTI_MINING_ROOT}/you_can_read_now.sync"

# Wie rechnet NiceHash und die Miner, wenn sie sagen GH/s?
# Mit 1000 oder mit 1024 als Basis?
declare -i k_base=1024          # CCminer scheint gemäß bench.cpp mit 1024 zu rechnen

GRID[0]="netz"
GRID[1]="solar"
GRID[2]="solar_akku"

declare -Ag DO_AUTO_BENCHMARK_FOR
TWEAK_CMD_START_PARAMS="${LINUX_MULTI_MINING_ROOT}/benchmarking/.start_params_for_tweak_commands_sh"

# Für die bech_30s_2.sh und MinerShell.sh zum Zählen der hashCount's
# Der Output des "zm" Equihash Miners sieht so aus:
#2017-11-28 17:20:15|>  GPU0  68C  Sol/s: 493.9  Sol/W: 1.87  Avg: 493.9  I/s: 267.3  Sh: 0.00   . .   
#2017-11-28 17:20:55|   GPU0  70C  Sol/s: 496.0  Sol/W: 1.86  Avg: 494.1  I/s: 265.3  Sh: 0.00   . .   
#2017-11-28 17:21:15|>  GPU0  69C  Sol/s: 497.5  Sol/W: 1.86  Avg: 495.0  I/s: 264.5  Sh: 0.75   1.00 52  +
#2017-11-28 17:21:35|   GPU0  69C  Sol/s: 498.9  Sol/W: 1.87  Avg: 495.8  I/s: 264.9  Sh: 1.19   1.00 53  +
#2017-11-28 17:21:55|   GPU0  69C  Sol/s: 496.7  Sol/W: 1.87  Avg: 495.9  I/s: 264.4  Sh: 1.49   1.00 49  +
#
#$1         $2          $3    $4   $5     $6     $7     $8    $9   $10    $11  $12    $13 $14    $15  $16 $NF
#
# Und dieser Filter macht aus den o.g. Zeilen die folgenden:
#493.9 Sol/s
#494.1 Sol/s
#495.0 Sol/s
#495.8 Sol/s
#495.9 Sol/s
#
detect_zm_hash_count='BEGIN { hash=10 }
/GPU[[:digit:]] +[[:digit:]]+C +Sol\/s: [[:digit:].]+ +Sol\/W: [[:digit:].]+ +Avg: [[:digit:].]+ +I\/s: [[:digit:].]+ +Sh: [[:digit:].]+/ \
    { print $hash " Sol/s"; next }
{ print }
'

# Wenn keine Karten da sind, dürfen verschiedene Befehle nicht ausgeführt werden
# und müssen sich auf den Inhalt fixer Dateien beziehen.
if [ $HOME == "/home/richard" ]; then
    NoCards=true
    PATH=${PATH}:${LINUX_MULTI_MINING_ROOT}/benchmarking/nvidia-befehle
    Erholung=.001
    PoolActive["sn"]=1
    PoolActive["mh"]=1
fi

GPU_alive_delay=2
GPU_ALIVE_FLAG=.willing_to_deliver_data
GPU_VALID_FLAG=.valid_data_delivered
MM_validating_delay=5
RUN_SYNC_delay=5

# Diese Funktion ist bequem, aber langsamer als die Member eines Arrays in einer for-Schleife zu verbinden.
# Für große Datenmengen, große Arrays, daher besser in einem Array zusammen-joinen.
# UND: Wenn die Funktion OFT gerufen wird, dann ebenfalls lieber eine for-Schleife schreiben.
pos_join () { local IFS="$1"; shift; echo "$*"; }

_remove_lock () {
    flock -u 999                                     # ... und wieder freigeben
    [[ "$1" != "--do_not_log" ]] && \
	echo $(date "+%Y-%m-%d %H:%M:%S") $(basename $0) "PID ${own_PID} Released the exclusive Lock now" \
             >>${LINUX_MULTI_MINING_ROOT}/._reserve_and_lock_counter.${LockBase}
}

_reserve_and_lock_file () {

    LockBase=$(basename ${1})
    LockFile="${1%${LockBase}}.${LockBase}.lock"

    # 6-stellige PID-Nummern (eigentlich gehen sie nur bis 32k) mit führenden Nullen
    own_PID="00000"$$
    own_PID=${own_PID:$(( ${#own_PID} - 6 ))}

    exec 999>${LockFile}
    flock -x 999
    [[ "$2" != "--do_not_log" ]] && \
	echo $(date "+%Y-%m-%d %H:%M:%S") $(basename $0) "PID ${own_PID} Got the exclusive Lock now" \
             >>${LINUX_MULTI_MINING_ROOT}/._reserve_and_lock_counter.${LockBase}
}

_get_file_modified_time_ () {
    # 0.1 deshalb, weil führende Nullen bei Dezimalzahlen als Oktalzahlen interpretiert werden, die dann zu gross für die "aktuelle Basis" sind.
    # Bei den Ziffern hinter dem Komma müssen wir also immer die führenden Nullen wegnehmen.
    # Und wenn hier "0.0" stehen würde, würde die Fraction hinter dem Komma komplett entfernt und die entsprechende Variable wäre leer,
    # was zu einem Fehler "Operand erwartet" führen würde.
    # Aus diesem Grund prüfen wir die Fraction gleich und lassen führende Nullen hier schon weg
    declare _modified_time_="0" _fraction_="1"

    _reserve_and_lock_file "$1" "--do_not_log"
    if [ -f ${1} ]; then
	_modified_time_=$(stat -c "%Y" ${1}) #.${_fraction_}
	_fraction_=$(find ${1} -printf "%TS" )
	_fraction_=${_fraction_#*\.}
	REGEXPAT="^0+([[:digit:]]*)"
	[[ "${_fraction_}" =~ ${REGEXPAT} ]] && _fraction_=${BASH_REMATCH[1]}
	[[ "${_fraction_}" == ""          ]] && _fraction_="1"
    fi
    _remove_lock "--do_not_log"
    echo "${_modified_time_} ${_fraction_}"
}

#####################################################
# Einlesen des bisherigen Status laufender GPUs
####################################################
_read_in_actual_RUNNING_STATE () {
    if [ -f ${RUNNING_STATE} ]; then
        unset RUNNING_STATE_CONTENT
        unset RunningGPUid; declare -Ag RunningGPUid
        unset WasItEnabled; declare -Ag WasItEnabled
        unset RunningWatts; declare -Ag RunningWatts
        unset WhatsRunning; declare -Ag WhatsRunning
        cat ${RUNNING_STATE} \
            | grep -e "^GPU-" \
            | readarray -n 0 -O 0 -t RUNNING_STATE_CONTENT

        for (( i=0; $i<${#RUNNING_STATE_CONTENT[@]}; i++ )); do
            if [[ "${RUNNING_STATE_CONTENT[$i]:0:4}" == "GPU-" ]]; then
                read RunningUUID RunningGPUidx GenerallyEnabled Watt RunningAlgo <<<"${RUNNING_STATE_CONTENT[$i]//:/ }"
                RunningGPUid[${RunningUUID}]=${RunningGPUidx}
                WasItEnabled[${RunningUUID}]=${GenerallyEnabled}
                RunningWatts[${RunningUUID}]=${Watt}
                WhatsRunning[${RunningUUID}]=${RunningAlgo}
            fi
        done

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
        fi
    fi  ### if [ -f ${RUNNING_STATE} ]; then
}
