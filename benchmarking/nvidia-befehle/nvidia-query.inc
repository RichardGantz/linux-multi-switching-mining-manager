#!/bin/bash
###############################################################################
#
# Abfrage von "Clock", "Power" und "Temperature" der GPU ${gpu_idx}
#
#

if [ $NoCards ]; then
    temperatures=( "54" "52" "58" "57" "60" "54" )
    declare -i lfdTemp=0
fi

# NVIDIA Befehle
#nvidia-smi -q -i ${gpu_idx} -d Clock,Power
#nvidia-smi -i ${gpu_idx} --query-gpu=temperature.gpu --format=csv,noheader
#
# Die folgenden Strings kommen vor und dienen als Index für die Assoziativen Arrays
# actClocks[] und maxClocks[]
# "Graphics"
# "SM"
# "Memory"
# "Video"
#
# Die folgenden Strings kommen vor und dienen als Index für das Assoziative Array
# actPowers[]
# "Power Draw"
# "Power Limit"
# "Default Power Limit"
# "Enforced Power Limit"
# "Min Power Limit"
# "Max Power Limit"

shopt -s lastpipe
function _query_actual_Power_Temp_and_Clocks () {
    if [ ! $NoCards ]; then
        nvidia-smi -q -i ${gpu_idx} -d Clock,Power >nvidia-befehle/nvidia-Clock-Power.out
        actTemp=$(nvidia-smi -i ${gpu_idx} --query-gpu=temperature.gpu --format=csv,noheader)
    else
        actTemp=${temperatures[$((lfdTemp++ % ${#temperatures[@]}))]}
    fi

    unset actClocks; declare -Ag actClocks
    unset maxClocks; declare -Ag maxClocks
    unset actPowers; declare -Ag actPowers

    unset NVIDIA_ARR
    cat nvidia-befehle/nvidia-Clock-Power.out \
        | grep -A 4 -e '^[[:space:]]*Clocks$' \
        | readarray -n 0 -O 0 -t NVIDIA_ARR
    for ((i=1; $i<${#NVIDIA_ARR[@]}; i++)); do
        actClocks[$(echo ${NVIDIA_ARR[$i]} | cut -d ' ' -f1)]="${NVIDIA_ARR[$i]//[![:digit:]]/}"
    done

    unset NVIDIA_ARR
    cat nvidia-befehle/nvidia-Clock-Power.out \
        | grep -A 4 -e '^[[:space:]]*Max Clocks$' \
        | readarray -n 0 -O 0 -t NVIDIA_ARR
    for ((i=1; $i<${#NVIDIA_ARR[@]}; i++)); do
        maxClocks[$(echo ${NVIDIA_ARR[$i]} | cut -d ' ' -f1)]="${NVIDIA_ARR[$i]//[![:digit:]]/}"
    done

    unset NVIDIA_ARR
    cat nvidia-befehle/nvidia-Clock-Power.out \
        | grep -A 7 -e '^[[:space:]]*Power Readings$' \
        | readarray -n 0 -O 0 -t NVIDIA_ARR
    for ((i=2; $i<${#NVIDIA_ARR[@]}; i++)); do
        key=$(echo ${NVIDIA_ARR[$i]} | cut -d ':' -f1)
        key=${key%[[:space:]]*}
        actPowers[${key}]="${NVIDIA_ARR[$i]//[![:digit:].]/}"
    done
}

