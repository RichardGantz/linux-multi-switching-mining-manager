#!/bin/bash
[[ ${#_GLOBALS_INCLUDED}     -eq 0 ]] && source ../globals.inc
#[[ ${#_GPU_ABFRAGE_INCLUDED} -eq 0 ]] && source ${LINUX_MULTI_MINING_ROOT}/gpu-abfrage.sh
#[[ ${#_GPU_ABFRAGE_INCLUDED} -eq 0 ]] && source ${LINUX_MULTI_MINING_ROOT}/gpu-abfrage.inc


<<PERFORMANCE_VERGLEICHE
SYNCFILE="${LINUX_MULTI_MINING_ROOT}/you_can_read_now.sync"

durchgaenge=10
while ((durchgaenge--)); do
    COUNT=100000 #0000

    count=${COUNT}
    rm -f .test.out
    { time while ((count--)); do

	# Put your code to test BELOW this line

#	m_time=$(find ${SYNCFILE} -printf "%T@")
#	m_time="1619158785.0992098300"
#	_modified_time_=${m_time%.*}
#	_fraction_=${m_time#*.}
	_fraction_=0992098300
	REGEXPAT="^0+([[:digit:]]*)"
	[[ "${_fraction_}" =~ ${REGEXPAT} ]] && _fraction_=${BASH_REMATCH[1]}
#	[  "${_fraction_}" = ""            ] && _fraction_="1"

	# Put your code to test ABOVE this line

    done ; } >.test.out 2>&1
    until [ -s .test.out ]; do sleep .01; done

    read muck good rest <<<$(cat .test.out | grep -m1 "^real")
    good=${good//,/.}
    minutes=${good%m*}
    seconds=${good#*m}
    seconds=${seconds%s}
    echo "scale=4; sekunden=${minutes}*60 + ${seconds}; print sekunden, \"\n\"" | bc | tee .test.1

    count=${COUNT}
    rm -f .test.out
    { time while ((count--)); do

	# Put your code to test BELOW this line

#	m_time=$(stat -c "%Y.%y" ${SYNCFILE})
#	m_time="1619158785.2021-04-23 08:19:45.099209830 +0200"
#	_modified_time_=${m_time%%.*}
#	_fraction_=${m_time##*.}
	_fraction_=0992098300
	[[ "${_fraction_}" =~ ^0+([[:digit:]]*) ]] && _fraction_=${BASH_REMATCH[1]}
#	[  "${_fraction_}" = ""            ] && _fraction_="1"

	# Put your code to test ABOVE this line

    done ; } >.test.out 2>&1
    until [ -s .test.out ]; do sleep .01; done

    read muck good rest <<<$(cat .test.out | grep -m1 "^real")
    good=${good//,/.}
    minutes=${good%m*}
    seconds=${good#*m}
    seconds=${seconds%s}
    echo "scale=4; sekunden=${minutes}*60 + ${seconds}; print sekunden, \"\n\"" | bc | tee .test.2

    echo 'scale=2; print "Das Verhältnis von Test1 zu Test2 beträgt ", '$(< .test.1)'/'$(< .test.2)'*100, " %\n"' | bc

    sleep 1
done

rm -f .test.*
exit

PERFORMANCE_VERGLEICHE

miner_name=t-rex
miner_version=0.19.12

gpu_uuid=GPU-c6467c28-be24-03ad-e7ea-9bc0e989488f
gpu_idx=$(< ${LINUX_MULTI_MINING_ROOT}/${gpu_uuid}/gpu_index.in)

MinerShell=MinerShell
coin_algorithm=coin_algorithm
continent=continent
algo_port=algo_port
worker=worker
domain=domain
server_name=server_name
declare -A miner_gpu_idx
miner_gpu_idx["${miner_name}#${miner_version}#${gpu_idx}"]=miner_gpu_idx
cmdParameterString=cmdParameterString

m_cmd="./${MinerShell}.sh\
	${coin_algorithm}\
	${gpu_idx}\
	${continent}\
	${algo_port}\
	${worker}\
	${gpu_uuid}\
	${domain}\
	${server_name}\
	${miner_gpu_idx["${miner_name}#${miner_version}#${gpu_idx}"]}\
	$cmdParameterString\
	>>${MinerShell}.log"

echo "${m_cmd}"
exit

debug=1

gpu_uuid=GPU-000bdf4a-1a2c-db4d-5486-585548cd33cb
gpu_uuid=GPU-2d93bcf7-ca3d-0ca6-7902-664c9d9557f4
gpu_uuid=GPU-3ce4f7c0-066c-38ac-2ef7-e23fef53af0f
gpu_uuid=GPU-50b643a5-f671-3b26-0381-2adea74a7103
gpu_uuid=GPU-5c755a4e-d48e-f85c-43cc-5bdb1f8325cd
gpu_uuid=GPU-bd3cdf4a-e1b0-59ef-5dd1-b20e2a43256b
gpu_uuid=GPU-c6467c28-be24-03ad-e7ea-9bc0e989488f
#gpu_uuid=GPU-d4c4b983-7bad-7b90-f140-970a03a97f2d
gpu_idx=$(< ${LINUX_MULTI_MINING_ROOT}/${gpu_uuid}/gpu_index.in)
IMPORTANT_BENCHMARK_JSON="${LINUX_MULTI_MINING_ROOT}/${gpu_uuid}/benchmark_${gpu_uuid}.json"
IMPORTANT_BENCHMARK_JSON="${LINUX_MULTI_MINING_ROOT}/GPU-skeleton/benchmark_skeleton.json"

# Achtung: Das ist gefährlich: Hier hängt er im emacs...
[[ ${#_GPU_BENCH_INCLUDED}   -eq 0 ]] && source ${LINUX_MULTI_MINING_ROOT}/${gpu_uuid}/gpu-bENCH.inc
#[[ ${#_GPU_BENCH_INCLUDED}   -eq 0 ]] && source ${LINUX_MULTI_MINING_ROOT}/GPU-skeleton/gpu-bENCH.inc
[[ ${#_MINERFUNC_INCLUDED}   -eq 0 ]] && source ${LINUX_MULTI_MINING_ROOT}/miner-func.inc
[[ ${#_ALGOINFOS_INCLUDED}   -eq 0 ]] && source ${LINUX_MULTI_MINING_ROOT}/algo_infos.inc
[[ ${#_NVIDIACMD_INCLUDED}   -eq 0 ]] && source ${LINUX_MULTI_MINING_ROOT}/benchmarking/nvidia-befehle/nvidia-query.inc

# Test der Feststellung der zu benchmarkenden Algorithms

_read_IMPORTANT_BENCHMARK_JSON_in

echo "Die folgenden beiden Arrays wurden von _read_IMPORTANT_BENCHMARK_JSON_in() gesetzt:"
declare -p algo_checked
declare -p pleaseBenchmarkAlgorithm

if [ 1 -eq 1 ]; then
    # Eintrag in Datei ../MINER_ALGO_DISABLED machen
    _set_Miner_Device_to_Nvidia_GpuIdx_maps
    _set_ALLE_LIVE_MINER
    _read_in_ALL_Mining_Available_and_Missing_Miner_Algo_Arrays
    _read_in_static_COIN_MININGALGO_SERVERNAME_PORT_from_Pool_Info_Array

    MINER=t-rex#0.19.14
    miningAlgo=ethash
    algorithm=${miningAlgo}#${MINER}
    coin=daggerhashimoto
    pool=nh
    coin_algorithm=${coin}#${pool}#${algorithm}

    nowDate=$(date "+%Y-%m-%d %H:%M:%S" )
    nowSecs=$(date +%s)
#    _disable_algo_for_5_minutes
fi

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

    declare -p MyDisabledAlgorithms
    declare -p MyDisabledAlgos

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

    declare -p MINER_ALGO_DISABLED_ARR
    
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
# Danach steht das Array WillBenchmarkAlgorithm mit den zu benchmarkenden Algorithms
_find_algorithms_to_benchmark

declare -p WillBenchmarkAlgorithm
exit

# Mal sehen, ob es überhaupt schon Benchmarkwerte gibt oder ob Benchmarks nachzuholen sind.
# Erst mal alle MiningAlgos ermitteln, die möglich sind und gegen die vorhandenen JSON Einträge checken.
_set_Miner_Device_to_Nvidia_GpuIdx_maps
_set_ALLE_LIVE_MINER
_read_in_ALL_Mining_Available_and_Missing_Miner_Algo_Arrays
_read_in_static_COIN_MININGALGO_SERVERNAME_PORT_from_Pool_Info_Array

# ----------------------------------------------------------
# Gibt es MissingAlgos, ziehen wir die Disabled Algos noch davon ab
unset ALL_MISSING_ALGORITHMs I_want_to_Disable_myself_for_AutoBenchmarking
declare -a ALL_MISSING_ALGORITHMs
for minerName in "${ALLE_MINER[@]}"; do
    [ ${debug} -ge 1 ] && echo "Durchgehen des Arrays ALLE_MINER, welches folgende Werte hat: ${ALLE_MINER[@]} "
    read m_name m_version <<<"${minerName//#/ }"
    declare -n   actMissingAlgos="Missing_${m_name//-/_}_${m_version//\./_}_Algos"
    #echo ${!actMissingAlgos}

    for actAlgo in ${!actMissingAlgos[@]}; do
        miningAlgo=${actMissingAlgos[$actAlgo]}
        algorithm="${miningAlgo}#${m_name}#${m_version}"
        if [[ "${#GLOBAL_ALGO_DISABLED_ARR[@]}" -gt 0 ]]; then
            REGEXPAT="\b${miningAlgo}\b"
            [[ "${GLOBAL_ALGO_DISABLED_ARR[@]}" =~ ${REGEXPAT}  ]] && continue
        fi
        if [[ "${#BENCH_ALGO_DISABLED_ARR[@]}" -gt 0 ]]; then
            REGEXPAT="\b${algorithm}\b"
            [[ "${BENCH_ALGO_DISABLED_ARR[@]}"  =~ ${REGEXPAT} ]] && continue
        fi
        ALL_MISSING_ALGORITHMs+=( ${algorithm} )
    done
done

#[ ${debug} -ge 1 ] && echo "\${#ALL_MISSING_ALGORITHMs[@]} == ${#ALL_MISSING_ALGORITHMs[@]}: ${ALL_MISSING_ALGORITHMs[@]}"
if [ ${#ALL_MISSING_ALGORITHMs[@]} -gt 0 ]; then
    I_want_to_Disable_myself_for_AutoBenchmarking=1
    if [ ${debug} -eq 1 ]; then
        echo "GPU #${gpu_idx}: Anzahl vermisster Algos: ${#ALL_MISSING_ALGORITHMs[@]} DisableMyself: ->$I_want_to_Disable_myself_for_AutoBenchmarking<-"
        declare -p ALL_MISSING_ALGORITHMs
    fi
fi
# ----------------------------------------------------------

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
    [ ${#MINER_FEES[${MINER}]} -gt 0 ] && miner_fee=${MINER_FEES[${MINER}]}
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
                                           && ${#KURSE[${coin}]}       -gt    0 \
                                           && ${#PoolFee[${pool}]}     -gt    0 \
                                           && ${WATTS[${algorithm}]}   -lt 1000 \
                            ]]; then

                            # "Mines" in BTC berechnen
                            algoMines=$(echo "scale=20;   ${bENCH[${algorithm}]}  \
                                                           * ${KURSE[${coin}]}  \
                                                           / ${k_base}^3  \
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
# ----------------------------------------------------------

exit

grep -m1 -c "\"HashCountPerSeconds\": " ${IMPORTANT_BENCHMARK_JSON}
exit

gpu_idx=0 #$(< gpu_index.in)
gpu_uuid=GPU-c6467c28-be24-03ad-e7ea-9bc0e989488f
printf -v worker "%02i${gpu_uuid:4:6}" ${gpu_idx}
echo $worker

# ----------------------------------------------------------
# Test zur Überprüfung, ob durch das in _update_SELF_if_necessary enthaltene EXEC
# die _On_Exit() Routine durchläuft, oder nicht.

# 1.
# _update_SELF_if_necessary wurde so erweitert, dass es die Datei .going-to-exec erzeugt

# 2.
# Dieser Teil war in _On_Exit() eingebaut:
if [ -s .going-to-exec ]; then
    mv -f .going-to-exec .going-to-exec-moved-by_On_Exit
else
    echo "Nothing to move from _update_SELF_if_necessary()"
fi

# 3.
# Eingebaut bald nach dem TRAP Kommando...

touch ../${SRC_DIR}/${SRC_FILE}
echo "Calling _update_SELF_if_necessary() the second time after TRAP is active and after touching ../${SRC_DIR}/${SRC_FILE}"
_update_SELF_if_necessary
if [ -s .going-to-exec ]; then
    echo ".going-to-exec is still there..."
else
    echo ".going-to-exec GONE... which means: _On_Exit() WAS called by exec!"
fi

echo "Now exiting for real... which should ultimately remove .going-to-exec ..."
exit

# ERGEBNIS: Die TRAP Routine _On_Exit wird NICHT durchlaufen...
# Es erfolgt also KEIN SIGTERM durch das EXEC
# ----------------------------------------------------------
