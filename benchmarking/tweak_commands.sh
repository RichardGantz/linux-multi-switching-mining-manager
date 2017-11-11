#!/bin/bash
###############################################################################
#
# Entgegennehmen, absetzen und protokollieren von TWEAK-Kommandos
#
#
# SYNC MIT DEM BENCHMARKER-PROZESS bench_30s_2.sh:
# Um sicherzustellen, dass alle Werte in der Endlosschleife gültig berechnet und abgeschlossen wurden,
# wird diese Datei kurz vor dem sleep 1 in der Endlosschleife erzeugt.
# tweak_commands.sh setzt den kill -15 Befehl dann nur ab, wenn diese Datei existiert.
# Sobald der Prozess aus dem Sleep kommt, verarbeitet er das Signal und schließt die Berechnungen ab.
READY_FOR_SIGNALS=benchmarker_ready_for_kill_signal

function _On_Exit () {
    # Bench stoppen, welches den CCminer stoppt
    if [ -s bench_30s_2.pid ]; then
        # Das kill Signal erst senden, wenn bench_30s_2.pid in den SLEEP 1 gegangen ist
        declare -i killing_loop_counter=0
        while [ ! -f ${READY_FOR_SIGNALS} ]; do let killing_loop_counter++; done
        kill $(< "bench_30s_2.pid")
        echo $(date "+%Y-%m-%d %H:%M:%S") " : " ${killing_loop_counter} >>tweak_commands_killing_loop_counter
    fi
    # Am Schluss Kopie der Log-Datei, damit sie nicht verloren geht mit dem aktuellen Zeitpunkt
    if [ -s tweak_commands.log ]; then
        cp ${OWN_LOGFILE} ${LOGPATH}/tweak_commands_$(date "+%Y%m%d_%H%M%S").log
    fi
}
trap _On_Exit EXIT

# Für Fake in Entwicklungssystemen ohne Grakas
if [ "$HOME" == "/home/richard" ]; then
    NoCards=true
    PATH=${PATH}:./nvidia-befehle
fi

read OWN_LOGFILE WATT_LOGFILE HASH_LOGFILE <<<$(< tweak_to_these_logs)
gpu_idx=$(< bensh_gpu_30s_.index)
gpu_uuid=$(< uuid)
algorithm=$(< benching_${gpu_idx}_algo)
read algo miner_name miner_version <<<"${algorithm//#/ }"
LOGPATH="../${gpu_uuid}/benchmarking/${algo}/${miner_name}#${miner_version}"

# Jetz haben wir gleich alle Daten für den $algorithm !
IMPORTANT_BENCHMARK_JSON="../${gpu_uuid}/benchmark_${gpu_uuid}.json"
bENCH_SRC="../${gpu_uuid}/bENCH.in"
# für das folgende "source"
LINUX_MULTI_MINING_ROOT=$(pwd | gawk -e 'BEGIN {FS="/"} { for ( i=1; i<NF; i++ ) {out = out "/" $i }; \
                   print substr(out,2) }')

workdir=$(pwd)
cd ../${gpu_uuid}
# Ist schlechter Stil. Sollte keine Frage sein, dass diese Datei wirklich da ist.
# Diese Abfrage Muss raus, sobald das sichergestellt ist.
if [ ! -f gpu-bENCH.sh ]; then cp -f ../GPU-skeleton/gpu-bENCH.sh .; fi
source gpu-bENCH.sh
_read_IMPORTANT_BENCHMARK_JSON_in
cd ${workdir} >/dev/null

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
#declare -a nvidiaPara=( 0 0 0 0 )
declare -a nvidiaPara=(
    ${GRAFIK_CLOCK[${algorithm}]}
    ${MEMORY_CLOCK[${algorithm}]}
    ${FAN_SPEED[${algorithm}]}
    ${POWER_LIMIT[${algorithm}]}
)

echo "Die gewünschte Logdatei für die Tweaking-Kommandos lautet: $OWN_LOGFILE"
echo "Zusätzlich muss das Kommando in die folgenden Dateien geschrieben werden:"
echo "Wattwerte: $WATT_LOGFILE und Hashwerte: $HASH_LOGFILE"

declare -i lfdCmd cmdNr para
while :; do

    if [ ${DoIt} ]; then
        clear
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
