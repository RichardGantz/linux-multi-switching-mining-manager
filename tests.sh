#!/bin/bash
[[ ${#_GLOBALS_INCLUDED}     -eq 0 ]] && source globals.inc
[[ ${#_GPU_ABFRAGE_INCLUDED} -eq 0 ]] && source ${LINUX_MULTI_MINING_ROOT}/gpu-abfrage.inc
[[ ${#_ALGOINFOS_INCLUDED}   -eq 0 ]] && source ${LINUX_MULTI_MINING_ROOT}/algo_infos.inc
[[ ${#_MINERFUNC_INCLUDED}   -eq 0 ]] && source ${LINUX_MULTI_MINING_ROOT}/miner-func.inc
[[ ${#_NVIDIACMD_INCLUDED}   -eq 0 ]] && source ${LINUX_MULTI_MINING_ROOT}/benchmarking/nvidia-befehle/nvidia-query.inc
[[ ${#_LOGANALYSIS_INCLUDED} -eq 0 ]] && source ${LINUX_MULTI_MINING_ROOT}/logfile_analysis.inc
#    [[ ${#_GPU_BENCH_INCLUDED}   -eq 0 ]] && source ${LINUX_MULTI_MINING_ROOT}/GPU-skeleton/gpu-bENCH.inc
#[[ ${#_GPU_BENCH_INCLUDED}   -eq 0 ]] && source ${LINUX_MULTI_MINING_ROOT}/${gpu_uuid}/gpu-bENCH.inc
#source ${LINUX_MULTI_MINING_ROOT}/miners/${miner_name}#${miner_version}.starts
#source ${LINUX_MULTI_MINING_ROOT}/multi_mining_calc.inc
#source ${LINUX_MULTI_MINING_ROOT}/estimate_delays.inc
#source ${LINUX_MULTI_MINING_ROOT}/estimate_yeses.inc

_read_in_SYSTEM_FILE_and_SYSTEM_STATEin

#function  _set_Miner_Device_to_Nvidia_GpuIdx_maps () {
_set_ALLE_MINER_from_path
    _ALL_MINERS_DATA_CHANGED_ON_DISK_=$?

    unset miner_gpu_idx
    echo "\${index[@]}=${index[@]}"

    if [ ${#miner_gpu_idx[@]} -eq 0 -o ${_ALL_MINERS_DATA_CHANGED_ON_DISK_} -ne 0 ]; then
        echo "$(basename $0):${gpu_idx}: ###---> Updating Table \"<Miner Device-Num> to <Nvidia gpu_idx>\"."

        # Key/index dieses Assoziativen Arrays ist eine Kombination aus ${MINER}#${gpu_idx}
        # ${gpu_idx} ist die Nvidia GPU-Indexnummer.
        # In dieser Funktion finden wir heraus, welche Nummer wir dem Miner beim MinerStart übergeben müssen.
        #    damit er die richtige, von uns auch ausgewählte Nividia ${gpu_idx} minet.
        unset miner_gpu_idx;    declare -Ag miner_gpu_idx

        for MinerFullName in "${ALLE_MINER[@]}"; do

	    echo "\${MinerFullName}=${MinerFullName}"
            case "${MinerFullName}" in

                # Die Ausnahmen hier oben
                # "xmrMiner#0.2.1")
                #   miner_gpu_idx["${MinerFullName}#0"]=
                #   miner_gpu_idx["${MinerFullName}#1"]=
                #   miner_gpu_idx["${MinerFullName}#2"]=
                #   miner_gpu_idx["${MinerFullName}#3"]=
                #   miner_gpu_idx["${MinerFullName}#4"]=
                #   miner_gpu_idx["${MinerFullName}#5"]=
                #   miner_gpu_idx["${MinerFullName}#6"]=
                #   ;;

                # Die Ausnahmen hier oben
                t-rex#*|zm#*)
                    # miner_gpu_idx[  ${MINER}#${gpu_idx}  ] = miner_dev
                    #miner_gpu_idx["${MinerFullName}#0"]=1          # Bisher sind nur die ersten beiden vertauscht.
                    #miner_gpu_idx["${MinerFullName}#1"]=0
                    # 2018-01-25 ${bus[${gidx}]} enthält die "PCI-Bus ID" dezimal
                    #            Das Array ${zm_device_on_pci_bus[ "PCI-Bus ID" ]} hält die Miner Device ID
                    for gidx in ${index[@]}; do
			#echo "gidx=${gidx}, bus[${gidx}]=${bus[${gidx}]}, zm_device_on_pci_bus[${bus[${gidx}]}]=${zm_device_on_pci_bus[${bus[${gidx}]}]}"
                        miner_gpu_idx["${MinerFullName}#${gidx}"]=${zm_device_on_pci_bus[${bus[${gidx}]}]}
			echo "gidx=${gidx}, bus[${gidx}]=${bus[${gidx}]}, ${miner_gpu_idx["${MinerFullName}#${gidx}"]}"
                    done
                    ;;

                *)
		    # Die miner_devices sind bei diesem Miner mit dem offiziellen Namen "gminer" identisch mit der Nvidia-Ausgabe
                    for gidx in ${index[@]}; do
                        miner_gpu_idx["${MinerFullName}#${gidx}"]=${gidx}
			echo "gidx=${gidx}, bus[${gidx}]=${bus[${gidx}]}, ${miner_gpu_idx["${MinerFullName}#${gidx}"]}"
                    done
                    ;;

            esac
        done
    fi
#function  _set_Miner_Device_to_Nvidia_GpuIdx_maps () ENDE

exit

#./algo_multi_abfrage.sh
_read_in_ALGO_PORTS_KURSE
exit

source ./gpu-abfrage.sh
ATTENTION_FOR_USER_INPUT=1
_func_gpu_abfrage_sh

debug=2
GPU_DIR=GPU-c6467c28-be24-03ad-e7ea-9bc0e989488f
lfdUuid=GPU-c6467c28-be24-03ad-e7ea-9bc0e989488f
gpu_uuid="${GPU_DIR}"
cd ${lfdUuid}
${LINUX_MULTI_MINING_ROOT}/${lfdUuid}/gpu_gv-algo.sh | tee tests.log
exit

GPU_DIR=GPU-c6467c28-be24-03ad-e7ea-9bc0e989488f
gpu_uuid="${GPU_DIR}"
IMPORTANT_BENCHMARK_JSON=${GPU_DIR}"/benchmark_${gpu_uuid}.json"
_read_in_SYSTEM_FILE_and_SYSTEM_STATEin
_set_Miner_Device_to_Nvidia_GpuIdx_maps
_test_=1
_read_in_ALL_Mining_Available_and_Missing_Miner_Algo_Arrays
echo Mining_t_rex_0_19_12_Algos: ${!Mining_t_rex_0_19_12_Algos[@]}:${Mining_t_rex_0_19_12_Algos[@]}
# output: Mining_t_rex_0_19_12_Algos: daggerhashimoto:ethash
exit

_read_in_static_COIN_MININGALGO_SERVERNAME_PORT_from_Pool_Info_Array
echo -e Coin_MiningAlgo_ServerName_Port: ${!Coin_MiningAlgo_ServerName_Port[@]}:${Coin_MiningAlgo_ServerName_Port[@]} "\n"
echo -e UniqueMiningAlgoArray: ${!UniqueMiningAlgoArray[@]}:${UniqueMiningAlgoArray[@]} "\n"
echo -e CoinsOfPool_nh: ${!CoinsOfPool_nh[@]}:${CoinsOfPool_nh[@]} "\n"
echo -e MiningAlgosOfPool_nh: ${!MiningAlgosOfPool_nh[@]}:${MiningAlgosOfPool_nh[@]} "\n"
#echo ${!miner_gpu_idx[@]}:${miner_gpu_idx[@]}

#_set_ALLE_LIVE_MINER
#echo ${!ALLE_LIVE_MINER[@]}:${ALLE_LIVE_MINER[@]}
exit

_set_ALLE_MINER_from_path
echo ALLE_MINER: key: ${!ALLE_MINER[@]} val: ${ALLE_MINER[@]}
echo ${COINS_MiningAlgos[@]}
echo ${actMiningAlgos[@]}

exit

<<COMMENT
date ist die schnellste Variante, wenn man keine Fractions braucht.
stat ist um etwa 18% langsamer als date, kann aber auch eine fraction enthalten
find ist mehr als doppelt so langsam wie stat, hat aber gleich die fraction mit dabei:

count=10000

find:
Pay_Time=$(find . -name ${algoID_KURSE_PORTS_PAY##*/} -printf '%T@')
PortTime=$(find . -name ${algoID_KURSE_PORTS_ARR##*/} -printf '%T@')

real	0m54,996s
user	0m31,402s
sys	0m23,806s
1618312974.2800629310, 1618312907.3279139210

stat:
Pay_Time=$(stat -c %Y ${algoID_KURSE_PORTS_PAY})
PortTime=$(stat -c %Y ${algoID_KURSE_PORTS_ARR})

real	0m24,763s
user	0m18,242s
sys	0m7,114s
1618312974, 1618312907

date:
Pay_Time=$(date --utc --reference=${algoID_KURSE_PORTS_PAY} +%s)
PortTime=$(date --utc --reference=${algoID_KURSE_PORTS_ARR} +%s)

real	0m20,291s
user	0m15,092s
sys	0m5,792s
1618312974, 1618312907

count=100 #0000
time while ((count--)); do
    unset ALGOs;    declare -ag ALGOs
    unset PORTs;    declare -Ag PORTs
    unset ALGO_IDs; declare -Ag ALGO_IDs
    unset READARR
    readarray -n 0 -O 0 -t READARR <${algoID_KURSE_PORTS_ARR}
    for ((i=0; $i<${#READARR[@]}; i+=3)) ; do
        ALGOs[${READARR[$i+2]}]=${READARR[$i]}
        PORTs[${READARR[$i]}]=${READARR[$i+1]}
        ALGO_IDs[${READARR[$i]}]=${READARR[$i+2]}
    done
    #count=${count}
done

Die zwei date Abfragen, zwei gleiche Läufe
real	0m20,455s
user	0m15,224s
sys	0m5,942s

real	0m20,219s
user	0m14,904s
sys	0m6,032s

Das einlesen der Datei in die Arrays, zwei gleiche Läufe
real	0m5,667s
user	0m5,501s
sys	0m0,100s

real	0m5,643s
user	0m5,512s
sys	0m0,060s
COMMENT

exit

