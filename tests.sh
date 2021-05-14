#!/bin/bash
[[ ${#_GLOBALS_INCLUDED}     -eq 0 ]] && source globals.inc
#[[ ${#_GPU_ABFRAGE_INCLUDED} -eq 0 ]] && source ${LINUX_MULTI_MINING_ROOT}/gpu-abfrage.inc
#[[ ${#_ALGOINFOS_INCLUDED}   -eq 0 ]] && source ${LINUX_MULTI_MINING_ROOT}/algo_infos.inc
#[[ ${#_MINERFUNC_INCLUDED}   -eq 0 ]] && source ${LINUX_MULTI_MINING_ROOT}/miner-func.inc
#[[ ${#_NVIDIACMD_INCLUDED}   -eq 0 ]] && source ${LINUX_MULTI_MINING_ROOT}/benchmarking/nvidia-befehle/nvidia-query.inc
#[[ ${#_LOGANALYSIS_INCLUDED} -eq 0 ]] && source ${LINUX_MULTI_MINING_ROOT}/logfile_analysis.inc
#    [[ ${#_GPU_BENCH_INCLUDED}   -eq 0 ]] && source ${LINUX_MULTI_MINING_ROOT}/GPU-skeleton/gpu-bENCH.inc
#[[ ${#_GPU_BENCH_INCLUDED}   -eq 0 ]] && source ${LINUX_MULTI_MINING_ROOT}/${gpu_uuid}/gpu-bENCH.inc
#source ${LINUX_MULTI_MINING_ROOT}/miners/${miner_name}#${miner_version}.starts
#source ${LINUX_MULTI_MINING_ROOT}/multi_mining_calc.inc
#source ${LINUX_MULTI_MINING_ROOT}/estimate_delays.inc
#source ${LINUX_MULTI_MINING_ROOT}/estimate_yeses.inc

function _prepare_ALGO_PORTS_KURSE_from_the_Web_old () {
    # Auswertung und Erzeugung der PAY-Datei, aus der das Array KURSE eingelesen wird
    gawk -e 'BEGIN { RS=":[[]{|},{|}[]],"} \
          match( $0, /"algorithm":"[[:alnum:]]*/ )\
               { M=substr($0, RSTART, RLENGTH); print tolower( substr(M, index(M,":")+2 ) ) }  \
          match( $0, /"speed":[.[:digit:]]*/ )\
               { M=substr($0, RSTART, RLENGTH); print substr(M, index(M,":")+1 ) } \
          match( $0, /"paying":[.[:digit:]E\-]*/ )\
               { M=substr($0, RSTART, RLENGTH); print substr(M, index(M,":")+1 ) }' \
         ${algoID_KURSE__PAY__WEB}
}

function _prepare_ALGO_PORTS_KURSE_from_the_Web () {
    gawk -e 'BEGIN { RS=":[[]{|},{|}[]],"} \
          match( $0, /"algorithm":"[[:alnum:]]*/ )\
               { M=substr($0, RSTART, RLENGTH); print tolower( substr(M, index(M,":")+2 ) ) }  \
          match( $0, /"speed":[.[:digit:]]*/ )\
               { M=substr($0, RSTART, RLENGTH); print substr(M, index(M,":")+1 ) } \
          match( $0, /"paying":[.[:digit:]E\-]*/ )\
               { M=substr($0, RSTART, RLENGTH)
	       	 M=substr(M, index(M,":")+1 )
	       	 if (split( M, pay, "E" ) == 1) {
		    print M
		 } else {
		    print "(" pay[1] "*10^" pay[2] ")"
		 }
	       }' \
         ${algoID_KURSE__PAY__WEB}
}

diff <(_prepare_ALGO_PORTS_KURSE_from_the_Web_old) <(_prepare_ALGO_PORTS_KURSE_from_the_Web)
exit

read muck MAX_PROFIT   MAX_PROFIT_GPU_Algo_Combination <<<$(< .MAX_PROFIT.in)   #${_MAX_PROFIT_in}
read muck MAX_FP_MINES MAX_FP_GPU_Algo_Combination     muck2 MAX_FP_WATTS <<<$(< .MAX_FP_MINES.in) #${_MAX_FP_MINES_in}
if [[ "${MAX_PROFIT_GPU_Algo_Combination}" != "${MAX_FP_GPU_Algo_Combination}" \
          && "${MAX_FP_MINES}" > "${MAX_PROFIT}" ]]; then
    echo "FULL POWER MINES ${MAX_FP_MINES} wären mehr als die EFFIZIENZ Mines ${MAX_PROFIT}"
fi
exit

#_read_in_SYSTEM_FILE_and_SYSTEM_STATEin
RUNNING_STATE=xyz
read RunSecs  RunFrac <<<$(_get_file_modified_time_ ${RUNNING_STATE})
echo $RunSecs
if [[ ${RunSecs} > 0 ]]; then
    echo "Time got"
fi
exit

# Die führenden Nulen müssen von der Fraction, um nicht als Octalzahlen interpretiert zu werden
#     und wenn zufälligerweise 0 sein sollte, muss es auf 1 gesetzt werden.
_fraction_=000092600000
#_fraction_=000000000
_fraction_=${_fraction_##*(0)}
_fraction_=${_fraction_:-1}
echo $_fraction_
exit

#cat $(ls .bc_result_GPUs_3_0_1_4)
cat $(ls .bc_result_GPUs_*) \
    | tee >(grep -E -e '^#TOTAL '  | awk -e 'BEGIN {sum=0} {sum+=$NF} END {print sum}' >.GLOBAL_GPU_COMBINATION_LOOP_COUNTER) \
	  >(grep -e '^MAX_PROFIT:' | sort -g -k2 | tail -n 1 >.MAX_PROFIT.in) \
	  >(grep -e '^FP_M:'       | sort -g -k2 | tail -n 1 >.MAX_FP_MINES.in) \
	  >/dev/null
while [[ ! -s .MAX_PROFIT.in || ! -s .MAX_FP_MINES.in || ! -s .GLOBAL_GPU_COMBINATION_LOOP_COUNTER ]]; do sleep .05; done
echo "I'm out now"
cat .GLOBAL_GPU_COMBINATION_LOOP_COUNTER
cat .MAX_PROFIT.in
cat .MAX_FP_MINES.in
	    
	    
exit

# Läuft gut.
cat $(ls .bc_result_GPUs_*) \
    | tee >(grep -E -e '^#TOTAL '  | awk -e 'BEGIN {sum=0} {sum+=$NF} END {print sum}') \
	  >(grep -e '^MAX_PROFIT:' | sort -g -k2 | tail -n 1 ) \
	  >(grep -e '^FP_M:'       | sort -g -k2 | tail -n 1 ) \
	  >/dev/null
exit

cat $(ls .bc_result_GPUs_*) \
    | tee >(grep -E -e '#TOTAL ' | awk -e 'BEGIN {sum=0} {sum+=$NF} END {print sum}' >.GLOBAL_GPU_COMBINATION_LOOP_COUNTER; \
            rm -f .GLOBAL_GPU_COMBINATION_LOOP_COUNTER.lock) \
    | grep -E -v -e '^#|^$' \
    | tee >(grep -e '^MAX_PROFIT:'   | sort -g -r -k2 | grep -E -m1 '.*' >.MAX_PROFIT.in; \
            rm -f .MAX_PROFIT.in.lock) \
          >(grep -e '^FP_M:' | sort -g -r -k2 | grep -E -m1 '.*' >.MAX_FP_MINES.in; \
            rm -f .MAX_FP_MINES.in.lock) \
          >/dev/null

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
date ist die schnellste Variante, Fractions möglich.
stat ist um etwa 18% langsamer als date,  Fractions möglich.
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
Pay_Time=$(date --reference=${algoID_KURSE_PORTS_PAY} +%s)
PortTime=$(date --reference=${algoID_KURSE_PORTS_ARR} +%s)

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

