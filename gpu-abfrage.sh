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

# Wenn keine Karten da sind, dürfen verschiedene Befehle nicht ausgeführt werden
# und müssen sich auf den Inhalt fixer Dateien beziehen.
if [ $HOME == "/home/richard" ]; then NoCards=true; fi

### ERSTER Start und Erstellung der Grundkonfig 
SYSTEM_FILE="gpu_system.out"
SYSTEM_STATE="GLOBAL_GPU_SYSTEM_STATE"

# Ein paar Funktionen zur Verwaltung der Algos, die für alle oder nur für bestimmte GPU-UUIDs disabled sind.
# Es gibt das Array AlgoDisabled[$algo], das den entsprechenden STRING in der Form
#    "AlgoDisabled:equihash:GPU-7...:*:GPU-4..." oder
#    "AlgoDisabled:equihash:GPU-7...:GPU-4..."   oder
#    "AlgoDisabled:equihash:*:GPU-4..."          oder
#    "AlgoDisabled:equihash:GPU-4..."            oder
#    "AlgoDisabled:equihash:*"                   oder, oder, oder ... enthalten.
# Es gibt die Funktionen
#    _add_entry_into_AlgoDisabled                      $algo [$gpu_uuid]
#    _remove_entry_from_AlgoDisabled                   $algo [$gpu_uuid]
#    "yes" or "no" = $( _is_algo_disabled_for_gpu_uuid $algo [$gpu_uuid] )
source gpu-abfrage.inc

function _func_gpu_abfrage_sh () {
    unset READARR
    if [ $NoCards ]; then
        gawk -e 'BEGIN {FS=", | %"} {print $1; print $2; print $3; print $4; print $5}' .FAKE.nvidia-smi.output >${SYSTEM_FILE}
    else
        nvidia-smi --query-gpu=index,gpu_name,gpu_bus_id,gpu_uuid,utilization.gpu --format=csv,noheader | \
            gawk -e 'BEGIN {FS=", | %"} {print $1; print $2; print $3; print $4; print $5}' >${SYSTEM_FILE}
    fi
    readarray -n 0 -O 0 -t READARR <${SYSTEM_FILE}

    # Die Daten der GPUs in Arrays einlesen, die durch den GPU-Grafikkarten-Index indexiert werden können
    unset index;      declare -ag index
    unset name;       declare -ag name
    unset bus;        declare -ag bus
    unset uuid;       declare -ag uuid
    unset auslastung; declare -ag auslastung
    for ((i=0; $i<${#READARR[@]}; i+=5)) ; do
        j=$(expr $i / 5)
        index[$j]=${READARR[$i]}        # index[] = Grafikkarten-Index für miner
        name[${index[$j]}]=${READARR[$i+1]}
        bus[${index[$j]}]=${READARR[$i+2]}
        uuid[${index[$j]}]=${READARR[$i+3]}
        auslastung[${index[$j]}]=${READARR[$i+4]}
        # EXTREM WICHTIGE Deklarationen!
        # Seitdem dieser Teil am Anfang einer Endlosschleife enthalten ist, müssen wir die Arrays erst mal löschen!
        declare -n deleteIt="GPU${index[$j]}Algos";     unset deleteIt
        declare -n deleteIt="GPU${index[$j]}Watts";     unset deleteIt
        declare -n deleteIt="GPU${index[$j]}Mines";     unset deleteIt
        declare -ag "GPU${index[$j]}Algos"
        declare -ag "GPU${index[$j]}Watts"
        declare -ag "GPU${index[$j]}Mines"
    done

    # Die folgende Datei GLOBAL_GPU_SYSTEM_STATE.in (${SYSTEM_STATE}.in) bearbeiten wir manuell.
    # Sie wird, wenn nicht vorhanden vom Skript erstellt, damit wir die UUID's und Namen haben.
    # Und wenn sie vorhanden ist, merken wir uns die manuell gesetzten Enabled-Zustände,
    #     BEVOR wir die Datei neu schreiben.
    # Warum muss sie neu geschrieben werden?
    #     Weil möglicherweise in der Zwischenzeit Karten ein- oder ausgebaut wurden,
    #     die dazugenommen werden müssen mit einem Default-Wert ENABLED
    #     oder ganz rausfliegen können, weil sie eh nicht mehr im System sind
    # Eventuell können wir hier auch die temporär disabelten Algos (automatisch?) eintragen lassen
    #     und durchschleifen. DARUM KÜMMERN WIR UNS ABER, WENN ES SOWEIT IST.
    #     (Hier ist erst mal nur das Einlesen mitgemacht, weil der Code schon im multi_mining_calc.sh so drin war.)
    unset SYSTEM_STATE_CONTENT
    unset uuidEnabledSOLL;  declare -Ag uuidEnabledSOLL
    unset AlgoDisabled;     declare -Ag AlgoDisabled
    unset NumEnabledGPUs;   declare -ig NumEnabledGPUs
    if [ -s ${SYSTEM_STATE}.in ]; then
        cp -f ${SYSTEM_STATE}.in ${SYSTEM_STATE}.BAK
        shopt_cmd_before=$(shopt -p lastpipe)
        shopt -s lastpipe
        cat ${SYSTEM_STATE}.in               \
            | grep -v "^#"                   \
            | grep -e "^GPU-\|^AlgoDisabled" \
            | readarray -n 0 -O 0 -t SYSTEM_STATE_CONTENT

        for (( i=0; $i<${#SYSTEM_STATE_CONTENT[@]}; i++ )); do
            if [ "${SYSTEM_STATE_CONTENT[$i]:0:4}" == "GPU-" ]; then
                echo ${SYSTEM_STATE_CONTENT[$i]} \
                    | cut -d':' --output-delimiter=' ' -f1,3 \
                    | read UUID GenerallyEnabled
                declare -ig uuidEnabledSOLL[${UUID}]=${GenerallyEnabled}
                NumEnabledGPUs+=${GenerallyEnabled}
            elif [ "${SYSTEM_STATE_CONTENT[$i]:0:12}" == "AlgoDisabled" ]; then
                unset AlgoName
                read -a AlgoName <<<"${SYSTEM_STATE_CONTENT[$i]//:/ }"
                if [ ${#AlgoName[@]} -eq 2 ] && [ "${AlgoName[0]}" == "AlgoDisabled" ]; then
                    # Bestimmt den * vergessen oder nicht mal ein echter Algoname?
                    AlgoDisabled[${AlgoName[1]}]="AlgoDisabled:${AlgoName[1]}:*"
                else
                    AlgoDisabled[${AlgoName[1]}]="${SYSTEM_STATE_CONTENT[$i]}"
                fi
            fi
        done
        ${shopt_cmd_before}
    fi

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

