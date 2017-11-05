#!/bin/bash
###############################################################################
#
# Entgegennehmen, absetzen und protokollieren von TWEAK-Kommandos
#
#

function _On_Exit () {
    # Bench stoppen, welches den CCminer stoppt
    if [ -s bench_30s_2.pid ]; then kill $(cat "bench_30s_2.pid"); fi
    # Am Schluss Kopie der Log-Datei, damit sie nicht verloren geht mit dem aktuellen Zeitpunkt
    if [ -s tweak_commands.log ]; then
        cp ${OWN_LOGFILE} ${LOGPATH}/tweak_commands_$(date "+%Y%m%d_%H%M%S").log
    fi
}
trap _On_Exit EXIT

# Für Fake in Entwicklungssystemen ohne Grakas
if [ $HOME == "/home/richard" ]; then
    NoCards=true
    PATH=${PATH}:./nvidia-befehle
fi

read OWN_LOGFILE WATT_LOGFILE HASH_LOGFILE <<<$(< tweak_to_these_logs)
gpu_idx=$(< bensh_gpu_30s_.index)
gpu_uuid=$(< uuid)
algo=$(< benching_${gpu_idx}_algo)
miner=$(<benching_${gpu_idx}_miner)
LOGPATH="../${gpu_uuid}/benchmarking/${algo}/${miner}"

# Fan-Kontrolle ermöglichen. Heisst: MANUELL. GPUFanControlState=0 heisst AUTOMATIC
if [ ! $NoCards ]; then
    nvidia-settings --assign [gpu:${gpu_idx}]/GPUFanControlState=1
fi

#nvidia-smi --id=${gpu_idx} -pl 82 (root powerconsumption)
#nvidia-settings --assign [gpu:${gpu_idx}]/GPUGraphicsClockOffset[3]=170
#nvidia-settings --assign [gpu:${gpu_idx}]/GPUMemoryTransferRateOffset[3]=360
#nvidia-settings --assign [fan:${gpu_idx}]/GPUTargetFanSpeed=66

nvidiaCmd[0]="nvidia-settings --assign [gpu:%i]/GPUGraphicsClockOffset[3]=%i"
nvidiaCmd[1]="nvidia-settings --assign [gpu:%i]/GPUMemoryTransferRateOffset[3]=%i"
nvidiaCmd[2]="nvidia-settings --assign [fan:%i]/GPUTargetFanSpeed=%i"
nvidiaCmd[3]="./nvidia-befehle/smi --id=%i -pl %i"
declare -a nvidiaPara=( 0 0 0 0 )

echo "Die gewünschte Logdatei für die Tweaking-Kommandos lautet: $OWN_LOGFILE"
echo "Zusätzlich muss das Kommando in die folgenden Dateien geschrieben werden:"
echo "Wattwerte: $WATT_LOGFILE und Hashwerte: $HASH_LOGFILE"

declare -i lfdCmd cmdNr para
while :; do

    clear
    if [ ${DoIt} ]; then
        printf -v cmd "${nvidiaCmd[$((${cmdNr}-1))]}" ${gpu_idx} ${para}

        echo "---> DAS FOLGENDE KOMMANDO WIRD JETZT ABGESETZT: <---"
        echo "---> ${cmd} <---"
        echo ""
        ${cmd} && nvidiaPara[$((${cmdNr}-1))]=${para} || echo "ERROR: Das ist was schief gegangen: Exit-Code $?"

        if [ "${para}" == "${nvidiaPara[$((${cmdNr}-1))]}" ]; then
            echo ""
            echo "Das Benchmarking-Programm wird synchronisiert"
            echo "${cmd}" | tee -a ${WATT_LOGFILE} ${HASH_LOGFILE} >>${OWN_LOGFILE}
        fi
    else
        DoIt=true
    fi

    echo ""
    echo "Benchmark is actually running for the following GPU:"
    echo "GPU #${gpu_idx} with UUID: ${uuid}"

    for (( lfdCmd=0; $lfdCmd<${#nvidiaCmd[@]}; lfdCmd++ )); do
        printf "%3i : ${nvidiaCmd[${lfdCmd}]}\n" $((${lfdCmd}+1)) ${gpu_idx} ${nvidiaPara[${lfdCmd}]}
    done
    
    echo ""
    read -p "Welches Kommando für GPU #${gpu_idx} ( 1 ... ${#nvidiaCmd[@]} ) ? " cmdNr

    printf -v cmd "${nvidiaCmd[$((${cmdNr}-1))]}" ${gpu_idx} ${nvidiaPara[$((${cmdNr}-1))]}
    read -p "${cmd} Neuer Wert? " para
    
done
