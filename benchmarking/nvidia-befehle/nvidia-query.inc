#!/bin/bash
###############################################################################
#
# Abfrage von "Clock", "Power" und "Temperature" der GPU ${gpu_idx}
#
#

_NVIDIACMD_INCLUDED=1

if [ $NoCards ]; then
    temperatures=( "54" "52" "58" "57" "60" "54" )
    declare -i lfdTemp=0
fi

# NVIDIA Befehle
#nvidia-smi -i ${gpu_idx} -q -d Clock,Power
#nvidia-smi -i ${gpu_idx} --query-gpu=temperature.gpu --format=csv,noheader
# list devices
#nvidia-smi --query-gpu=index,gpu_name,gpu_uuid --format=csv,noheader
# device $var auflisten
#nvidia-smi --id=${gpu_idx} --query-gpu=index,gpu_name,gpu_uuid --format=csv,noheader
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

nvidiaCmd[0]="nvidia-settings --assign [gpu:%i]/GPUGraphicsClockOffset[3]=%i"
nvidiaCmd[1]="nvidia-settings --assign [gpu:%i]/GPUMemoryTransferRateOffset[3]=%i"
nvidiaCmd[2]="nvidia-settings --assign [fan:%i]/GPUTargetFanSpeed=%i"
nvidiaCmd[3]="../benchmarking/nvidia-befehle/smi --id=%i -pl %i"
nvidiaCmd[4]="nvidia-settings --assign [gpu:%i]/GPUFanControlState=%i"

#
# 1. $algorithm muss korrekt sein
# 2. $IMPORTANT_BENCHMARK_JSON muss eingelesen sein, damit die Arrays gefüllt sind
#        Trotzdem kann es vorkommen, dass die Array-Variablen leer sind, wenn der Algo noch nicht enthalten ist!
#
function _declare_and_fill_nvidiPara_Array () {
    local    G=0; [[ ${#GRAFIK_CLOCK[${algorithm}]} -gt 0 ]] && G=${GRAFIK_CLOCK[${algorithm}]}
    local    M=0; [[ ${#MEMORY_CLOCK[${algorithm}]} -gt 0 ]] && M=${MEMORY_CLOCK[${algorithm}]}
    local    F=0; [[ ${#FAN_SPEED[${algorithm}]}    -gt 0 ]] && F=${FAN_SPEED[${algorithm}]}
    local -i P=0; [[ ${#POWER_LIMIT[${algorithm}]}  -gt 0 ]] && P=${POWER_LIMIT[${algorithm}]}
    [ ${P} -eq 0 ] && P=${defPowLim[${gpu_idx}]}
    unset nvidiaPara
    declare -ag nvidiaPara=( $G $M $F $P )
}

function _setup_Nvidia_Default_Tuning_CmdStack () {
    _declare_and_fill_nvidiPara_Array

    # Die Clocks nach den Werten in der JSON setzen
    unset CmdStack
    declare -ag CmdStack
    local i
    for (( i=0; $i<2; i++ )); do
        printf -v CmdStack[${#CmdStack[@]}] "${nvidiaCmd[$i]}" ${gpu_idx} ${nvidiaPara[$i]}
    done

    # Fan-Kontrolle nach den Werten in der JSON setzen
    if [ ${nvidiaPara[2]} -eq 0 ]; then
        # Automatik einschalten. Entsprechendes Kommando ist das LETZTE auf dem nvidiaCmd-Array
        printf -v CmdStack[${#CmdStack[@]}] "${nvidiaCmd[-1]}" ${gpu_idx} 0
    else
        # Fan Speed Kontrolle von AUTOMATIK auf MANUELL stellen
        printf -v CmdStack[${#CmdStack[@]}] "${nvidiaCmd[-1]}" ${gpu_idx} 1
        # Fan Speed auf eingelesenen Wert setzen
        printf -v CmdStack[${#CmdStack[@]}] "${nvidiaCmd[2]}" ${gpu_idx} ${nvidiaPara[2]}
    fi

    # Power Limit nach den Werten in der JSON setzen
    printf -v CmdStack[${#CmdStack[@]}] "${nvidiaCmd[3]}" ${gpu_idx} ${nvidiaPara[3]}
}


function _query_actual_Power_Temp_and_Clocks () {
    shopt -s lastpipe
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

