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
[[ ${#_GLOBALS_INCLUDED}     -eq 0 ]] && source globals.inc
[[ ${#_MINERFUNC_INCLUDED}   -eq 0 ]] && source ${LINUX_MULTI_MINING_ROOT}/miner-func.inc

# Erst mal die beiden Funktionen _read_in_SYSTEM_FILE_and_SYSTEM_STATEin und _update_SYSTEM_STATEin_if_necessary
[[ ${#_GPU_ABFRAGE_INCLUDED} -eq 0 ]] && source ${LINUX_MULTI_MINING_ROOT}/gpu-abfrage.inc


function _func_gpu_abfrage_sh () {

    # Jeder, der ${SYSTEM_FILE} und/oder ${SYSTEM_STATE}.in lesen möchte, muss erst ${SYSTEM_STATE}.lock für sich reserviert haben.
    #        und muss es natürlich anschließend wieder freigeben.
    _reserve_and_lock_file ${SYSTEM_STATE}         # Zum Lesen und Bearbeiten reservieren...


    # Hier überschreiben wir ${SYSTEM_FILE}...
    #
    if [ $NoCards ]; then
        GPU_COUNT=$(cat ${LINUX_MULTI_MINING_ROOT}/.FAKE.nvidia-smi.output \
                   | grep -E -v -e "^#|^$"      \
                   | gawk -e 'BEGIN {FS=", "} { \
print $1; print $2; print $3; print $4
if ($5 !~ /^[[:digit:]]+ %$/) { print "0" } else { print substr( $5, 1, index($5," ")-1 ) }
if ($6 !~ /^[[:digit:].]+ W$/)  { print "1" } else { print substr( $6, 1, index($6,".")-1 ) }
if ($7 !~ /^[[:digit:].]+ W$/)  { print "1" } else { print substr( $7, 1, index($7,".")-1 ) }
}' \
                   | tee ${SYSTEM_FILE} \
                   | wc -l)
    else
        GPU_COUNT=$(nvidia-smi --query-gpu=index,gpu_name,gpu_bus_id,gpu_uuid,utilization.gpu,power.default_limit,enforced.power.limit --format=csv,noheader \
                   | gawk -e 'BEGIN {FS=", "} { \
print $1; print $2; print $3; print $4
if ($5 !~ /^[[:digit:]]+ %$/) { print "0" } else { print substr( $5, 1, index($5," ")-1 ) }
if ($6 !~ /^[[:digit:].]+ W$/)  { print "1" } else { print substr( $6, 1, index($6,".")-1 ) }
if ($7 !~ /^[[:digit:].]+ W$/)  { print "1" } else { print substr( $7, 1, index($7,".")-1 ) }
}' \
                  | tee ${SYSTEM_FILE} \
                  | wc -l )
    fi
    GPU_COUNT=$(( ${GPU_COUNT} / ${num_gpu_rows} ))

    # zm --list-devices Abfrage auswerten
    ZM_GPU_COUNT=$(${zm_list_devices_cmd} \
                  | gawk -e '{ print substr( $NF, 1, length($NF)-1 ) $2 }' \
                  | tee ${ZM_FILE} \
                  | wc -l)
    if [[ ${GPU_COUNT} -ne ${ZM_GPU_COUNT} ]]; then
        echo "Das geht gar nicht: NVIDIA listet ${GPU_COUNT} Devices, ZM listet ${ZM_GPU_COUNT} devices. Bitte prüfen. Es erfolgt ein Abbruch"
        exit 2
    fi

    # Beim allerersten Start gibt es noch keine System.in und die System.in wird erst beim _update geschrieben
    #      wobei alle GPUs in der Datei auf Enabled gesetzt werden.
    # Um nach dem Update auch die Arrays aus der system.in gesetzt zu haben, muss sie nochmal eingelesen werden.
    _read_in_SYSTEM_FILE_and_SYSTEM_STATEin

    # Hier überschreiben wir ${SYSTEM_STATE}.in, wenn nötig...
    #      ODER schreiben es zum allerersten mal...
    #
    unset beChatty
    if [ ${#ATTENTION_FOR_USER_INPUT} -gt 0 ] && [ ${ATTENTION_FOR_USER_INPUT} -gt 0 ]; then beChatty=1; fi
    _update_SYSTEM_STATEin_if_necessary "$beChatty"

    # Falls sie bei ersten mal noch nicht vorhanden war, muss sie jetzt da sein und kann eingelesen werden
    [ ${#uuidEnabledSOLL[@]} -eq 0 ] && _read_in_SYSTEM_FILE_and_SYSTEM_STATEin

    _remove_lock                                     # ... und wieder freigeben

    _set_Miner_Device_to_Nvidia_GpuIdx_maps

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
        # Wenn es zu chaotisch geworden ist, kann die Datei auch einfach gelöscht werden.
        # Sie wird dann hier wieder hergestellt und durch automatisches Benchmarking aufgefüllt werden.
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
            echo Kartenverzeichnis ${name[${index[$i]}]} existiert und die Karte ist \
                 $( [[ "${uuidEnabledSOLL[${uuid[${index[$i]}]}]}" == "1" ]] && echo "Enabled" || echo "DISABLED" )
        fi
        echo ${index[$i]} > ${uuid[${index[$i]}]}/gpu_index.in
    done
}

if [ 1 -eq 0 ]; then
    if [ $NoCards ]; then
        ATTENTION_FOR_USER_INPUT=1
        _func_gpu_abfrage_sh
        exit
    fi
fi
