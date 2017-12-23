#!/bin/bash
#
# lspci 
# darüber sieht man auf welchem bus was läuft
# "01:00.0 VGA compatible controller: NVIDIA Corporation Device 17c8 (rev a1)" 
#
# dmidecode -t slot
# hier ist aufgelistet welche bus adresse auf welchem port auf dem Mainboard zugewiesen ist 
# "Designation: PCIEX16_1 -> Bus Address: 0000:01:00.0 "
# 
# nvidia-smi -L
# "GPU 0: GeForce GTX 980 Ti (UUID: GPU-742cb121-baad-f7c4-0314-cfec63c6ec70)"
#
# nvidia-smi -q
#
# nvidia-smi --query-gpu=gpu_name,gpu_bus_id,gpu_uuid --format=csv
#
#
# http://nvidia.custhelp.com/app/answers/detail/a_id/3751/~/useful-nvidia-smi-queries
# Auflistung der GPUS mit indexnummer für Miner Programme, da GPUs über index nummern angesprochen werden
#
# nvidia-smi --query-gpu=index,gpu_name,gpu_bus_id,gpu_uuid --format=csv,noheader
# 0, GeForce GTX 980 Ti, 0000:01:00.0, GPU-742cb121-baad-f7c4-0314-cfec63c6ec70
#
# gpuverzeichniss müsste die gpu_uuid werden, zwecks direkter zuordnung, da sich diese nicht ändert ...
# kann durch umsetzung des pci slots oder durch pltzlichen ausfall "error oder übertaktung" passieren
# dann indexiert er möglichweise neu
#
# utulization = abfrage ob der gpu arbeitet, alle 10 sec abfrage abfrage sammeln und nach 30 mittelwert berechnen
# gff abruch/reset des miners "da irgendwas nicht stimmt -> logfile vom miner prüfen
#
# nvidia-smi --id=0 --query-gpu=index,gpu_name,gpu_bus_id,gpu_uuid,utilization.gpu --format=csv,noheader
# 0, GeForce GTX 980 Ti, 0000:01:00.0, GPU-742cb121-baad-f7c4-0314-cfec63c6ec70, 1 %
#
# Nvidia karten einstelleungen automatisch ( boost)
# nvidia-smi --auto-boost-default=ENABLED -i 0 ..... nvidia-smi --auto-boost-permission=UNRESTRICTED -i 0
#
# nvidia-smi  -q --id=0 -d CLOCK
#
#
#
#
###########################################################################################
#
# Erst wird generell abgefragt wieviel NVIDIA GPU's sich im System befinden und in 
# gpu_system.out gesichert
#
#
# nvidia-smi --query-gpu=index,gpu_name,gpu_bus_id,gpu_uuid --format=csv,noheader > gpu_system.out
# 0, GeForce GTX 980 Ti, 0000:01:00.0, GPU-742cb121-baad-f7c4-0314-cfec63c6ec70, 100 % 
# 1, GeForce GTX xxx Ti, 0000:02:00.0, GPU-742cb121-baad-f7c4-0314-xxxxxxxxxxxx, 1 %
#
# 1. Der Index(wichtig) fängt bei 0 an und läuft dann bis unendlich hoch (je nach Mainboard/chip möglichkeit),
#    die indexnummer wird dann dem jeweiligen miner mit übergeben, welche karten sollen mit miner xy laufen
# 2. Der GPU Name, welche dort meist die generlle bezeichnung des GPU chips
# 3. wichtig der PCIE Port auf dem der GPU Hardware Seitig installiert ist
# 4. die GPU UUID (wichtig) diese zahlen combi ist einzigartig und wird dann auch als direkte zuordnung verwendet,
#    sowie der Verzeichnissname lautet so
#
#
# ausgabe bitte jeweils in variablen packen und alle $[] "index" "gpu-name" "bus" "uuid"
#

# GLOBALE VARIABLEN, nützliche Funktionen
[[ ${#_GLOBALS_INCLUDED} -eq 0 ]] && source globals.inc

# Erst mal die beiden Funktionen _read_in_SYSTEM_FILE_and_SYSTEM_STATEin und _update_SYSTEM_STATEin_if_necessary
[[ ${#_GPU_ABFRAGE_INCLUDED} -eq 0 ]] && source gpu-abfrage.inc


function _func_gpu_abfrage_sh () {
    unset READARR
    declare -ig GPU_COUNT
    if [ $NoCards ]; then
        GPU_COUNT=$(gawk -e 'BEGIN {FS=", | %| W"} \
                   {print $1; print $2; print $3; print $4; print $5; print substr( $7, 1, index($7,".")-1 ) }' \
                         .FAKE.nvidia-smi.output >${SYSTEM_FILE} \
                   | wc -l)
    else
        GPU_COUNT=$(nvidia-smi --query-gpu=index,gpu_name,gpu_bus_id,gpu_uuid,utilization.gpu,power.default_limit --format=csv,noheader \
                  | gawk -e 'BEGIN {FS=", | %| W"} {print $1; print $2; print $3; print $4; print $5; print substr( $7, 1, index($7,".")-1 ) }' \
                         >${SYSTEM_FILE} \
                  | wc -l )
    fi

    _read_in_SYSTEM_FILE_and_SYSTEM_STATEin

    unset beChatty
    if [ ${#ATTENTION_FOR_USER_INPUT} -gt 0 ] && [ ${ATTENTION_FOR_USER_INPUT} -gt 0 ]; then beChatty=1; fi
    _update_SYSTEM_STATEin_if_necessary "$beChatty"


    ######################################
    # Überprüfung ob folder da ist.
    # Wenn nicht: Erstellen und leere, für CCminer 2.2 vorbereitete benchmark datei kopieren
    # Den aktuellen GPU-Index in den Folder in die Datei gpu_index.in ausgeben.
    # Script gpu_gv-algo.sh hinein kopieren
    #
    for ((i=0; $i<${#index[@]}; i+=1)) ; do
        if [ ! -d ${uuid[${index[$i]}]} ]; then
            #erstellen des folders mit der UUID + copy einer bench-skeleton + gpu_algo.sh
            if [ ${#beChatty} -gt 0 ]; then
                echo "Erstelle den GPU-Folder '${uuid[${index[$i]}]}'"
            fi
            mkdir ${uuid[${index[$i]}]}
            cp GPU-skeleton/benchmark_skeleton.json ${uuid[${index[$i]}]}/benchmark_${uuid[${index[$i]}]}.json
            if [ ${#beChatty} -gt 0 ]; then
                echo "---> 1. Die Karte ist neu! Bitte editiere die Datei 'benchmark_${uuid[${index[$i]}]}.json' !!!"
            fi
        fi
        if [ ! -f ${uuid[${index[$i]}]}/benchmark_${uuid[${index[$i]}]}.json ]; then
            cp GPU-skeleton/benchmark_skeleton.json ${uuid[${index[$i]}]}/benchmark_${uuid[${index[$i]}]}.json
        fi
        if [ ! -f "${uuid[${index[$i]}]}/gpu_gv-algo.sh" ]; then cp GPU-skeleton/gpu_gv-algo.sh ${uuid[${index[$i]}]}/; fi

        if [ ! -f "${uuid[${index[$i]}]}/gpu-bENCH.sh"   ]; then
            cp -f GPU-skeleton/gpu-bENCH.sh ${uuid[${index[$i]}]}/
        elif [ $(stat -c %Y GPU-skeleton/gpu-bENCH.sh) -gt $(stat -c %Y ${uuid[${index[$i]}]}/gpu-bENCH.sh) ]; then
            cp -f GPU-skeleton/gpu-bENCH.sh ${uuid[${index[$i]}]}/
        fi

        if [ ${#beChatty} -gt 0 ]; then
            echo Kartenverzeichnis ${name[${index[$i]}]} existiert
        fi
        echo ${index[$i]} > ${uuid[${index[$i]}]}/gpu_index.in
    done
}

