#!/bin/bash
[[ ${#_GLOBALS_INCLUDED}     -eq 0 ]] && source ../globals.inc
#echo ${LINUX_MULTI_MINING_ROOT}
#[[ ${#_GPU_ABFRAGE_INCLUDED} -eq 0 ]] && source ${LINUX_MULTI_MINING_ROOT}/gpu-abfrage.sh
[[ ${#_GPU_ABFRAGE_INCLUDED} -eq 0 ]] && source ${LINUX_MULTI_MINING_ROOT}/gpu-abfrage.inc
#[[ ${#_GPU_BENCH_INCLUDED}   -eq 0 ]] && source ${LINUX_MULTI_MINING_ROOT}/${gpu_uuid}/gpu-bENCH.inc
[[ ${#_GPU_BENCH_INCLUDED}   -eq 0 ]] && source ${LINUX_MULTI_MINING_ROOT}/GPU-skeleton/gpu-bENCH.inc
[[ ${#_MINERFUNC_INCLUDED}   -eq 0 ]] && source ${LINUX_MULTI_MINING_ROOT}/miner-func.inc
[[ ${#_ALGOINFOS_INCLUDED}   -eq 0 ]] && source ${LINUX_MULTI_MINING_ROOT}/algo_infos.inc
[[ ${#_NVIDIACMD_INCLUDED}   -eq 0 ]] && source ${LINUX_MULTI_MINING_ROOT}/benchmarking/nvidia-befehle/nvidia-query.inc


# -------------------------------------------------------------------------------- #
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

