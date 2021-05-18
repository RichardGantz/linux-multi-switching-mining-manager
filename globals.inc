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

# Das zu verwendende Terminal für die Loggings, z.B.: "gnome-terminal"
_TERMINAL_="mate-terminal"

### SCREEN ADDITIONS: ###
# 0 ist der frühere Betrieb an einem graphischen Desktop mit mehreren hochpoppenden Terminals unter Verwendung von ${_TERMINAL_}
# 1 ist der Betrieb unter GNU screen
#  2021-04-08: Wir lassen das hier erst mal aus, bis alle Tests unter GNU screen abgeschlossen sind,
#              was NICHT heisst, dass der "alte" Betrieb schon getestet ist!!!
#              Tatsächlich ist er bis zum o.g. Zeitpunkt NOCH NICHT GETESTET WORDEN !!!
#[[ ${#UseScreen} -eq 0 ]] && UseScreen=0
export UseScreen=1
export ScreenTest=1
if [ ${UseScreen} -eq 1 ]; then
    export MAINSCREEN=LMMS
    [ ${#FG_SESS} -eq 0 ] && export FG_SESS=${STY}
    [ ${#BG_SESS} -eq 0 ] && export BG_SESS=BACKGROUND.$$
fi

# Das Kommando nvidia-settings zum Tweaken verschiedener Einstellungen funktioniert nicht ohne weiteres.
# Da ist einiges zu erledigen, was in der README_GER.md nachzulesen ist.
# Sobald das Problem gelöst ist, kann die Variable nvidia_settings_unsolved auf 0 gesetzt werden
nvidia_settings_unsolved=1

# Wir verwenden oft "readarray" am Ende einer Pipe. Deshalb wollen wir, dass diese Option global verfügbar ist.
# An jeder Stelle im Source-Code, wo diese Zeile gefunden wird, kann sie also entfernt werden.
shopt -s lastpipe
shopt -s extglob

# Die Anzahl der besten Algos, die bei der globalen Berechnung pro GPU berücksichtigt werden sollen
BEST_ALGO_CNT=5 # 2021-05-02 Mehr als 60 Mio Berechnungen bei 10 GPU's, 210 Sekunden Berechnungsdauer
BEST_ALGO_CNT=4 # 2021-05-02 Fast     10 Mio Berechnungen bei 10 GPU's,  36 Sekunden Berechnungsdauer
BEST_ALGO_CNT=3 # 2021-05-02 Gut       1 Mio Berechnungen bei 10 GPU's,   9 Sekunden Berechnungsdauer
declare -Ag cycle_counter

# Die SLEEP Zeit nach dem Abbruch eines Miners in Sekunden. Experimentell, .5 bis 3 ???
Erholung=1.9

# Das wäre die zu bevorzugende Reihenfolge, wenn man die losses ("usa") als ungünstigst ansieht.
LOCATION=( "eu-west" "eu-north" "usa-east" "usa-west" )

InetPingStack=(
    62.138.238.100   # t-online.de          antwortet als Schnellster
    8.8.8.8          # google DNS-Server    antwortet als 2.Schnellster
    172.217.22.227   # google.de
    216.58.207.174   # google.com
)

#export LD_LIBRARY_PATH=/usr/local/cuda-9.1/lib64/:$LD_LIBRARY_PATH

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
POOLS["nh"]="nicehash.com";             PoolFee["nh"]=2        PoolActive["nh"]=1
#      sn = 0 + BOERSE["bittrex"]  0,25 oder BOERSE["cryptopia"] 0.2
POOLS["sn"]="suprnova.cc";              PoolFee["sn"]=0.25     PoolActive["sn"]=0
#      mh= 0,9 + BOERSE["bittrex"] 0,25 oder BOERSE["cryptopia"] 0.2
POOLS["mh"]="hub.miningpoolhub.com";    PoolFee["mh"]=1.15     PoolActive["mh"]=0

declare pool="nh"
declare domain=${POOLS[${pool}]}

### gpu-abfrage.sh spezifische Variablen
SYSTEM_FILE="${LINUX_MULTI_MINING_ROOT}/gpu_system.out"
SYSTEM_STATE="${LINUX_MULTI_MINING_ROOT}/GLOBAL_GPU_SYSTEM_STATE"
FATAL_ERRORS="${LINUX_MULTI_MINING_ROOT}/FATAL_ERRORS.log"
# Wieviele Zeilen der gpu_system.out gehören zu jeweils einer GPU
declare -ig num_gpu_rows=7

#declare -g NVIDIA_SMI_PM_LAUNCHED_string
#[ -z "${NVIDIA_SMI_PM_LAUNCHED_string}" ] && export NVIDIA_SMI_PM_LAUNCHED_string
#export NVIDIA_SMI_PM_LAUNCHED_string

# Der zm miner muss etwas anders behandelt werden und ist nur vorhanden, bzw. wird nur berücksichtigt,
# wenn die folgende Variable in der nächsten Zeile (zm_list_devices_cmd) NICHT leer ist.
# (Vorhanden sein sollte sie aber schon, damit die Abfragen keine Fehlermeldungen auslösen.
#  Deshalb am besten in einer ZWEITEN Zeile definieren, falls ein ZM miner vorhanden ist
#  und die Leerdefinition immer stehen lassen.)
zm_list_devices_cmd="/home/avalon/miner/zmminer/zm-0.6.2/zm --list-devices"
#[ "${LOGNAME}" == "avalon" ] && zm_list_devices_cmd="/media/avalon/dea6f367-2865-4032-8c39-d2ca4c26f5ce/zm_0.5.6 --list-devices"
ZM_FILE="${LINUX_MULTI_MINING_ROOT}/zm_system.out"

# Hier drin halten wir den aktuellen GLOBALEN Status des Gesamtsystems fest
RUNNING_STATE="${LINUX_MULTI_MINING_ROOT}/GLOBAL_GPU_ALGO_RUNNING_STATE"

SYSTEM_MALFUNCTIONS_REPORT="${LINUX_MULTI_MINING_ROOT}/.SYSTEM_MALFUNCTIONS_REPORT"

### algo_multi_abfrage.sh spezifische Variablen
algoID_KURSE_PORTS_WEB="${LINUX_MULTI_MINING_ROOT}/NH_PORTS.json"
algoID_KURSE__PAY__WEB="${LINUX_MULTI_MINING_ROOT}/NH_PAYINGS.json"
algoID_KURSE_PORTS_ARR="${LINUX_MULTI_MINING_ROOT}/NH_PORTS.in"
algoID_KURSE_PORTS_PAY="${LINUX_MULTI_MINING_ROOT}/NH_PAYINGS.in"
BTC_EUR_KURS_WEB="${LINUX_MULTI_MINING_ROOT}/BTC_EUR_kurs.http"
COIN_PRICING_WEB="${LINUX_MULTI_MINING_ROOT}/WhatToMine.json"
COIN_PRICING_ARR="${LINUX_MULTI_MINING_ROOT}/WhatToMine.in"
COIN_TO_BTC_EXCHANGE_WEB="${LINUX_MULTI_MINING_ROOT}/BittrexSummaries.json"
COIN_TO_BTC_EXCHANGE_ARR="${LINUX_MULTI_MINING_ROOT}/BittrexSummaries.in"

ALL_MINER_FEES_FILE="${LINUX_MULTI_MINING_ROOT}/miners/all.miner.fees"

SYNCFILE="${LINUX_MULTI_MINING_ROOT}/you_can_read_now.sync"

# Wie rechnet NiceHash und die Miner, wenn sie sagen GH/s?
# Mit 1000 oder mit 1024 als Basis?
declare -i k_base=1024          # CCminer scheint gemäß bench.cpp mit 1024 zu rechnen
#declare -i k_base=1000

# Welche Strompreis... -Kategorien/-Arten mag es geben?
GRID[0]="netz"
GRID[1]="solar"
GRID[2]="solar_akku"

declare -Ag DO_AUTO_BENCHMARK_FOR
TWEAK_CMD_START_PARAMS="${LINUX_MULTI_MINING_ROOT}/benchmarking/.start_params_for_tweak_commands_sh"

GPU_alive_delay=6
GPU_ALIVE_FLAG=.willing_to_deliver_data     # Not used since 2021-04-24 and beyond. Remove comment, if used again.
GPU_VALID_FLAG=.valid_data_delivered
MM_validating_delay=15
RUN_SYNC_delay=5

RTPRIO_Miner=31   # Angezeigt wird -( RTPRIO_GPUgv + 1 ), verwendet  in  MinerShell.sh
RTPOLICY_Miner=-r # -r für round-robin, -f für FIFO
RTPRIO_MM=0       # 0 ist niedrigste Priorität, Policy SCHED_OTHER, verwendet  in  multi_mining_calc.sh / bc
RTPOLICY_MM=-r
RTPRIO_GPUgv=1    # Angezeigt wird -( RTPRIO_GPUgv + 1 )
RTPOLICY_GPUgv=-r #            -r für round-robin, -f für FIFO

declare -A RT_PRIORITY RT_POLICY NICE
RT_PRIORITY["mi"]=31   # Angezeigt wird -( RT_PRIORITY[] + 1 ), verwendet  in  MinerShell.sh
RT_POLICY["mi"]=-r     # -r für round-robin, -f für FIFO
NICE["mi"]=-20
RT_PRIORITY["ms"]=0    # Angezeigt wird -( RT_PRIORITY[] + 1 ), verwendet  in  gpu_gv-algo.sh
RT_POLICY["ms"]=-r     # -r für round-robin, -f für FIFO
NICE["ms"]=-10
RT_PRIORITY["gpu"]=0   # Angezeigt wird -( RT_PRIORITY[] + 1 ), verwendet  in  multi_mining_calc.sh / bc
RT_POLICY["gpu"]=-r    # -r für round-robin, -f für FIFO
NICE["gpu"]=-20
RT_PRIORITY["mm"]=0    # Angezeigt wird -( RT_PRIORITY[] + 1 ), verwendet  in  multi_mining_calc.sh / bc
RT_POLICY["mm"]=-r     # -r für round-robin, -f für FIFO
NICE["mm"]=-20

# Für große Datenmengen, große Arrays, daher besser in einem Array zusammen-joinen.
# UND: Wenn die Funktion OFT gerufen wird, dann ebenfalls lieber eine for-Schleife schreiben.
# Der "echo" macht aus mehrfachen Spaces ein einzelnes!
#pos_join () { local IFS="$1"; shift; echo "$*"; }
function pos_join () {
    local SEP="$1"; shift
    local OUT=""
    for STR in "$@"; do
	OUT+="${STR}${SEP}"
    done
    OUT="${OUT%${SEP}}"
    printf "${OUT}"
}

function _remove_lock () {
    flock -u 999                                     # ... und wieder freigeben
    [[ "$1" != "--do_not_log" ]] && \
        echo $(date "+%Y-%m-%d %H:%M:%S %s.%N") $(basename $0) "PID ${own_PID} Released the exclusive Lock now" \
             >>${LINUX_MULTI_MINING_ROOT}/._reserve_and_lock_counter.${LockBase}
}

function _reserve_and_lock_file () {

    LockBase=$(basename ${1})
    LockFile="${1%${LockBase}}.${LockBase}.lock"

    # 6-stellige PID-Nummern (eigentlich gehen sie nur bis 32k) mit führenden Nullen
    own_PID="00000"$$
    own_PID=${own_PID:$(( ${#own_PID} - 6 ))}

    exec 999>${LockFile}
    flock -x 999
    [[ "$2" != "--do_not_log" ]] && \
        echo $(date "+%Y-%m-%d %H:%M:%S %s.%N") $(basename $0) "PID ${own_PID} Got the exclusive Lock now" \
             >>${LINUX_MULTI_MINING_ROOT}/._reserve_and_lock_counter.${LockBase}
}

function _get_file_modified_time_ () {
    # 0.1 deshalb, weil führende Nullen bei Dezimalzahlen als Oktalzahlen interpretiert werden, die dann zu gross für die "aktuelle Basis" sind.
    # Bei den Ziffern hinter dem Komma müssen wir also immer die führenden Nullen wegnehmen.
    # Und wenn hier "0.0" stehen würde, würde die Fraction hinter dem Komma komplett entfernt und die entsprechende Variable wäre leer,
    # was zu einem Fehler "Operand erwartet" führen würde.
    # Aus diesem Grund prüfen wir die Fraction gleich und lassen führende Nullen hier schon weg
    declare _modified_time_="0" _fraction_="1"

    if [ -f ${1} ]; then
	_reserve_and_lock_file "$1" "--do_not_log"
	read _modified_time_ _fraction_ <<<$(date -r "${1}" "+%s %N")
	_fraction_=${_fraction_##*(0)}
	_fraction_=${_fraction_:-1}
	_remove_lock "--do_not_log"
    fi
    echo "${_modified_time_} ${_fraction_}"
}

#####################################################
# Einlesen des bisherigen Status laufender GPUs
####################################################
function _read_in_actual_RUNNING_STATE () {
    if [ -f ${RUNNING_STATE} ]; then
        unset RUNNING_STATE_CONTENT
        unset RunningGPUid; declare -Ag RunningGPUid
        unset WasItEnabled; declare -Ag WasItEnabled
        unset RunningWatts; declare -Ag RunningWatts
        unset WhatsRunning; declare -Ag WhatsRunning
        cat ${RUNNING_STATE} \
            | grep -e "^GPU-" \
            | readarray -n 0 -O 0 -t RUNNING_STATE_CONTENT

        for (( i=0; i<${#RUNNING_STATE_CONTENT[@]}; i++ )); do
            read RunningUUID RunningGPUidx GenerallyEnabled Watt RunningAlgo <<<"${RUNNING_STATE_CONTENT[$i]//:/ }"
            RunningGPUid[${RunningUUID}]=${RunningGPUidx}
            WasItEnabled[${RunningUUID}]=${GenerallyEnabled}
            RunningWatts[${RunningUUID}]=${Watt}
            WhatsRunning[${RunningUUID}]=${RunningAlgo}
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
