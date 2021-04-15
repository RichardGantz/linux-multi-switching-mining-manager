#!/bin/bash
[[ ${#_GLOBALS_INCLUDED}     -eq 0 ]] && source ../globals.inc
#[[ ${#_GPU_ABFRAGE_INCLUDED} -eq 0 ]] && source ${LINUX_MULTI_MINING_ROOT}/gpu-abfrage.sh
#[[ ${#_GPU_ABFRAGE_INCLUDED} -eq 0 ]] && source ${LINUX_MULTI_MINING_ROOT}/gpu-abfrage.inc

debug=1

gpu_uuid=GPU-000bdf4a-1a2c-db4d-5486-585548cd33cb
gpu_uuid=GPU-2d93bcf7-ca3d-0ca6-7902-664c9d9557f4
gpu_uuid=GPU-3ce4f7c0-066c-38ac-2ef7-e23fef53af0f
gpu_uuid=GPU-50b643a5-f671-3b26-0381-2adea74a7103
gpu_uuid=GPU-bd3cdf4a-e1b0-59ef-5dd1-b20e2a43256b
gpu_uuid=GPU-c6467c28-be24-03ad-e7ea-9bc0e989488f
gpu_uuid=GPU-d4c4b983-7bad-7b90-f140-970a03a97f2d
gpu_idx=$(< ${LINUX_MULTI_MINING_ROOT}/${gpu_uuid}/gpu_index.in)
IMPORTANT_BENCHMARK_JSON="${LINUX_MULTI_MINING_ROOT}/${gpu_uuid}/benchmark_${gpu_uuid}.json"

# Achtung: Das ist gefährlich: Hier hängt er im emacs...
#[[ ${#_GPU_BENCH_INCLUDED}   -eq 0 ]] && source ${LINUX_MULTI_MINING_ROOT}/${gpu_uuid}/gpu-bENCH.sh
[[ ${#_GPU_BENCH_INCLUDED}   -eq 0 ]] && source ${LINUX_MULTI_MINING_ROOT}/${gpu_uuid}/gpu-bENCH.inc
[[ ${#_ALGOINFOS_INCLUDED}   -eq 0 ]] && source ${LINUX_MULTI_MINING_ROOT}/algo_infos.inc
[[ ${#_NVIDIACMD_INCLUDED}   -eq 0 ]] && source ${LINUX_MULTI_MINING_ROOT}/benchmarking/nvidia-befehle/nvidia-query.inc

_read_IMPORTANT_BENCHMARK_JSON_in # without_miners

_read_in_ALGO_PORTS_KURSE
# ----------------------------------------------------------
#    Zusätzlich die über GLOBAL_ALGO_DISABLED Algos rausnehmen...
unset GLOBAL_ALGO_DISABLED_ARR
_reserve_and_lock_file ../GLOBAL_ALGO_DISABLED
if [ -s ../GLOBAL_ALGO_DISABLED ]; then
    cat ../GLOBAL_ALGO_DISABLED | grep -E -v -e '^#|^$' | readarray -n 0 -O 0 -t GLOBAL_ALGO_DISABLED_ARR

    if [ $debug -eq 1 ]; then
        echo "GPU #${gpu_idx}: Vor  der Prüfung: GLOBAL_ALGO_DISABLED_ARRAY hat ${#GLOBAL_ALGO_DISABLED_ARR[@]} Einträge"
        declare -p GLOBAL_ALGO_DISABLED_ARR
    fi
    for ((i=0; $i<${#GLOBAL_ALGO_DISABLED_ARR[@]}; i++)) ; do
        unset disabled_algos_GPUs
        read -a disabled_algos_GPUs <<<${GLOBAL_ALGO_DISABLED_ARR[$i]//:/ }
        if [ ${#disabled_algos_GPUs[@]} -gt 1 ]; then
            # Nur für bestimmte GPUs disabled. Wenn die eigene GPU nicht aufgeführt ist, übergehen
            REGEXPAT="^.*:${gpu_uuid}\b"
            if [[ ${GLOBAL_ALGO_DISABLED_ARR[$i]} =~ ${REGEXPAT} ]]; then
                GLOBAL_ALGO_DISABLED_ARR[$i]=${disabled_algos_GPUs[0]}
            else
                unset GLOBAL_ALGO_DISABLED_ARR[$i]
            fi
        fi
    done
    if [ $debug -eq 1 ]; then
        echo "GPU #${gpu_idx}: Nach der Prüfung: GLOBAL_ALGO_DISABLED_ARRAY hat ${#GLOBAL_ALGO_DISABLED_ARR[@]} Einträge"
        declare -p GLOBAL_ALGO_DISABLED_ARR
    fi
fi
_remove_lock                                     # ... und wieder freigeben
# ----------------------------------------------------------

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
