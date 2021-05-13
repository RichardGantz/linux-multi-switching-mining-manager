#!/bin/bash
###############################################################################
#
# Entgegennehmen, absetzen und protokollieren von TWEAK-Kommandos
#
#

# GLOBALE VARIABLEN, nützliche Funktionen
[[ ${#_GLOBALS_INCLUDED} -eq 0 ]] && source ../globals.inc

# Eigentliche wollen wir das Tweaken automatisch starten, aber das gnome-terminal sperrt sich
# und hat irgendwie das EXIT signal abgefangen. Es funktionieren weder <Ctrl>-C noch "exit" noch "kill -9 $$", um das Programm zu beenden.
# Ohne Startparameter erwarten wir die Startkommandos aus der Datei .start_params_for_tweak_commands_sh bzw. ${TWEAK_CMD_START_PARAMS}
manual_start=0
if [ $# -eq 0 ]; then
    manual_start=1
    if [ -s ${TWEAK_CMD_START_PARAMS} ]; then
        tail -n 1 ${TWEAK_CMD_START_PARAMS} \
        | read \
            gpu_idx \
            gpu_uuid \
            algorithm \
            BENCH_30s_PID \
            OWN_LOGFILE \
            WATT_LOGFILE \
            HASH_LOGFILE \
            LOGPATH \
            READY_FOR_SIGNALS
        rm -f ${TWEAK_CMD_START_PARAMS}
    else
        echo "Weder Startparameter übergeben noch Datei ${TWEAK_CMD_START_PARAMS} vorhanden."
        echo "Das Programm kann nicht gestartet werden."
        read -p "Beliebige Taste zum beenden des Programmes" finished
        exit 1
    fi
else
    # Alle Parameter sollen übergeben werden, damit der Tweaker auch genau den richtigen Miner tweakt.
    gpu_idx=$1
    gpu_uuid=$2
    algorithm=$3
    BENCH_30s_PID=$4
    OWN_LOGFILE=$5
    WATT_LOGFILE=$6
    HASH_LOGFILE=$7
    LOGPATH=$8
    # SYNC MIT DEM BENCHMARKER-PROZESS bench_30s_2.sh:
    # Um sicherzustellen, dass alle Werte in der Endlosschleife gültig berechnet und abgeschlossen wurden,
    # wird diese Datei kurz vor dem sleep 1 in der Endlosschleife erzeugt.
    # tweak_commands.sh setzt den kill -15 Befehl dann nur ab, wenn diese Datei existiert.
    # Sobald der Prozess aus dem Sleep kommt, verarbeitet er das Signal und schließt die Berechnungen ab.
    READY_FOR_SIGNALS=$9
fi

function _On_Exit () {
    # Bench stoppen, welches den CCminer stoppt
    # Das kill Signal erst senden, wenn bench_30s_2.sh in den SLEEP 1 gegangen ist
    #echo "In der _On_Exit() Routine"
    declare -i killing_loop_counter=0
    while [ ! -f ${READY_FOR_SIGNALS} ]; do let killing_loop_counter++; done
    kill ${BENCH_30s_PID}
    echo $(date "+%Y-%m-%d %H:%M:%S") " : " ${killing_loop_counter} >>.tweak_commands_killing_loop_counter

    # Am Schluss Kopie der Log-Datei, damit sie nicht verloren geht mit dem aktuellen Zeitpunkt
    if [ -s ${OWN_LOGFILE} ]; then
        cp ${OWN_LOGFILE} ${LOGPATH}/$(date "+%Y%m%d_%H%M%S")_tweak_commands.log
    fi
    ### SCREEN ADDITIONS: ###
    if [ ${UseScreen} -eq 1 ]; then
	screen -X eval remove
    fi
    #kill -9 $$
}
trap _On_Exit EXIT

# Stellt die 5 bekannten Befehle zur Verfügung:
#nvidia-smi --id=${gpu_idx} -pl 82 (root powerconsumption)
#nvidia-settings --assign [gpu:${gpu_idx}]/GPUGraphicsClockOffset[3]=170
#nvidia-settings --assign [gpu:${gpu_idx}]/GPUMemoryTransferRateOffset[3]=360
#nvidia-settings --assign [fan:${gpu_idx}]/GPUTargetFanSpeed=66
# Fan-Kontrolle auf MANUELL = 1 oder 0 für AUTOMATISCH
#nvidia-settings --assign [gpu:${gpu_idx}]/GPUFanControlState=1
[[ ${#_NVIDIACMD_INCLUDED}   -eq 0 ]] && source ${LINUX_MULTI_MINING_ROOT}/benchmarking/nvidia-befehle/nvidia-query.inc

# Sonst kann das DefaultPowerLimit nicht angezeigt werden, wenn noch kein Object in der ${IMPORTANT_BENCHMARK_JSON} ist
[[ ${#_GPU_ABFRAGE_INCLUDED} -eq 0 ]] && source ${LINUX_MULTI_MINING_ROOT}/gpu-abfrage.inc

_reserve_and_lock_file ${SYSTEM_STATE}   # Zum Lesen und Bearbeiten reservieren...
_read_in_SYSTEM_FILE_and_SYSTEM_STATEin
_remove_lock                             # ... und wieder freigeben

read miningAlgo miner_name miner_version muck888 <<<"${algorithm//#/ }"

[[ ${#_MINERFUNC_INCLUDED} -eq 0 ]] && source ${LINUX_MULTI_MINING_ROOT}/miner-func.inc
_set_Miner_Device_to_Nvidia_GpuIdx_maps

# Jetzt haben wir gleich alle Daten für den $algorithm !
IMPORTANT_BENCHMARK_JSON="../${gpu_uuid}/benchmark_${gpu_uuid}.json"

cd ../${gpu_uuid}
# Ist schlechter Stil. Sollte keine Frage sein, dass diese Datei wirklich da ist.
# Diese Abfrage Muss raus, sobald das sichergestellt ist.
if [ ! -f gpu-bENCH.sh ]; then cp -f ../GPU-skeleton/gpu-bENCH.sh .; fi
source gpu-bENCH.sh
cd ${_WORKDIR_} >/dev/null
_read_IMPORTANT_BENCHMARK_JSON_in without_miners

# Wenn es noch nichts aus der JSON gibt, sind die Werte mit 0 vorbelegt
_declare_and_fill_nvidiPara_Array

# Fan-Kontrolle ermöglichen. GPUFanControlState=1 heisst: MANUELL. GPUFanControlState=0 heisst AUTOMATIC
#nvidia-settings --assign [gpu:${gpu_idx}]/GPUFanControlState=1
printf -v cmd "${nvidiaCmd[-1]}" ${gpu_idx} 1
${cmd}
# Die Fan-Kontrolle MANUELL brauchen wir hier drin nicht mehr.
if [ ${manual_start} -eq 0 ]; then
    # Wir überschreiben den Wert mit dem Menüpunkt für den Abbruch, weil <Ctrl>-C im gnome-terminal nicht funktioniert
    nvidiaCmd[-1]="Tweaking und Benchmarking von GPU #%i BEENDEN"
else
    # Wir pop-en den Befehl für die generelle FAN-Kontrolle vom Kommando-Vorlagen-Stack
    unset nvidiaCmd[-1]
fi

clear
echo "Tweaking Terminal for ${miningAlgo} on GPU #${gpu_uuid}, Process ID ${BENCH_30s_PID}"
echo ""
echo "Die Logdateien, in die die Tweaking-Kommandos hineingepipet werden müssen lauten:"
echo "Kommandos: $OWN_LOGFILE"
echo "Wattwerte: $WATT_LOGFILE"
echo "Hashwerte: $HASH_LOGFILE"

declare -i lfdCmd cmdNr # para - Diese Deklaration als Integer hat sich gar nicht gut gemacht,
                        #        als Buchstaben eingegeben wurden. Er hat dan immer 0 draus gemacht.
                        #        Komischerweise passiert das bei cmdNr nicht ??? Sehr merkwürdig.
while :; do

    if [ ${DoIt} ]; then
        clear
        echo "Tweaking Terminal for ${miningAlgo} on GPU #${gpu_uuid}, Process ID ${BENCH_30s_PID}"
        echo ""
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
        DoIt=1
    fi

    echo ""
    echo "Benchmark wird momentan mit der folgenden GPU durchgeführt, die Du beeinflussen kannst:"
    echo "NVIDIA GPU #${gpu_idx} mit UUID: ${gpu_uuid}"
    echo "Der MINER \"${miner_name}#${miner_version}\" führt diese GPU als Device mit der Nummer " \
         ${miner_gpu_idx["${miner_name}#${miner_version}#${gpu_idx}"]} ". Also nicht verwirren lassen."
    echo "Hier werden Befehle unter Verwendung der echten NVIDIA-GPU-Indexnummer abgesetzt, was an der UUID zu erkennen ist."
    echo "Das ist der Miner,      der ausgewählt ist : ${miner_name} ${miner_version}"
    echo "das ist der MiningAlgo, der ausgewählt ist : ${miningAlgo}"
    echo "das ist der \$algorithm, der ausgewählt ist : ${algorithm}"
    if [ ${manual_start} -eq 1 ]; then
        echo "Zum Abbruch und Beenden des Tweaking und Benchmarking bitte <Ctrl>-C verwenden."
    fi
    echo ""
    cmdNr_list=''
    for (( lfdCmd=0; $lfdCmd<${#nvidiaCmd[@]}; lfdCmd++ )); do
        printf "%3i : ${nvidiaCmd[${lfdCmd}]}\n" $((${lfdCmd}+1)) ${gpu_idx} ${nvidiaPara[${lfdCmd}]}
        cmdNr_list+="$((${lfdCmd}+1)) "
    done
    echo ""

    while :; do
        read -p "Welches Kommando für GPU #${gpu_idx}? ${cmdNr_list} : " cmdNr
        REGEXPAT="\<${cmdNr}\>"
        [[ ${cmdNr_list} =~ ${REGEXPAT} ]] && break
    done

    if [ ${manual_start} -eq 0 ]; then
        # Beenden nach Auswahl des letzten Menüpunktes
        #[ ${cmdNr} -eq ${#nvidiaCmd[@]} ] && _On_Exit
        [ ${cmdNr} -eq ${#nvidiaCmd[@]} ] && exit
    fi

    printf -v cmd "${nvidiaCmd[$((${cmdNr}-1))]}" ${gpu_idx} ${nvidiaPara[$((${cmdNr}-1))]}
    while :; do
        read -p "${cmd} Neuer Wert? " para
        REGEXPAT="\<[[:digit:]]+\>"
        [[ ${para} =~ ${REGEXPAT} ]] && break
    done
done
