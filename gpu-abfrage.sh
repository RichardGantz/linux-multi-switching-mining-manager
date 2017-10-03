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

unset READARR
if [ 1 == 0 ]; then
    FIFO1=.gpu_system.out
    if [ ! -p $FIFO1 ]; then mkfifo $FIFO1; fi
    if [ $NoCards ]; then
        gawk -e 'BEGIN {FS=", | %"} {print $1; print $2; print $3; print $4; print $5}' .FAKE.nvidia-smi.output >$FIFO1 &
    else
        nvidia-smi --query-gpu=index,gpu_name,gpu_bus_id,gpu_uuid,utilization.gpu --format=csv,noheader | \
            gawk -e 'BEGIN {FS=", | %"} {print $1; print $2; print $3; print $4; print $5}' >$FIFO1 &
    fi
    readarray -n 0 -O 0 -t READARR <$FIFO1
else
    if [ $NoCards ]; then
        gawk -e 'BEGIN {FS=", | %"} {print $1; print $2; print $3; print $4; print $5}' .FAKE.nvidia-smi.output >gpu_system.out
    else
        nvidia-smi --query-gpu=index,gpu_name,gpu_bus_id,gpu_uuid,utilization.gpu --format=csv,noheader | \
            gawk -e 'BEGIN {FS=", | %"} {print $1; print $2; print $3; print $4; print $5}' >gpu_system.out
    fi
    readarray -n 0 -O 0 -t READARR <gpu_system.out
fi

# Die Daten der GPUs in Arrays einlesen, die durch den GPU-Grafikkarten-Index indexiert werden können
declare -a index
declare -a name
declare -a bus
declare -a uuid
declare -a auslastung
for ((i=0; $i<${#READARR[@]}; i+=5)) ; do
    j=$(expr $i / 5)
    index[$j]=${READARR[$i]}        # index[] = Grafikkarten-Index für miner
    name[${index[$j]}]=${READARR[$i+1]}
    bus[${index[$j]}]=${READARR[$i+2]}
    uuid[${index[$j]}]=${READARR[$i+3]}
    auslastung[${index[$j]}]=${READARR[$i+4]}
done


######
for ((i=0; $i<${#index[@]}; i+=1)) ; do
    echo "Diese GPU's gibt es: GPU ${index[$i]} ist ${name[${index[$i]}]} auf port ${bus[${index[$i]}]} und hat die ${uuid[${index[$i]}]} und ist zu ${auslastung[${index[$i]}]} % ausgelastet"
done

######################################
# überprüfung ob folder da ist wenn nicht erstellen und lehre vorbereitete benchmark datei kopieren
# und gpu_gb-algo.sh hinein kopieren
# wenn schon da, erstelle gpu_index
#
#
for ((i=0; $i<${#index[@]}; i+=1)) ; do
    if [ ! -d ${uuid[${index[$i]}]} ]; then
        #erstellen des folders mit der UUID + copy einer bench-skeleton + gpu_algo.sh
        echo "Erstelle den GPU-Folder '${uuid[${index[$i]}]}'"
        mkdir ${uuid[${index[$i]}]}
        cp GPU-skeleton/benchmark_skeleton.json ${uuid[${index[$i]}]}/benchmark_${uuid[${index[$i]}]}.json
        cp GPU-skeleton/gpu_gv-algo.sh ${uuid[${index[$i]}]}/
        echo "---> 1. Die Karte ist neu! Bitte editiere die Datei 'benchmark_${uuid[${index[$i]}]}.json' !!!"
        echo "---> 2. gpu_gv-algo.sh ist reinkopiert"
    fi

    echo Kartenverzeichnis ${name[${index[$i]}]} existiert
    echo ${index[$i]} > ${uuid[${index[$i]}]}/gpu_index.in
done

exit

#########################################
#
#
# Wieder aufrufung der abfrage, falls eine karte nach starten der miner nicht mehr aufgteslistet ist,
# oder keine $auslastung mehr aufweist(prüfung ob mit der karte gemined wird "uuid/mining[1 oder 0]")
# muss die karte resetet werden, und erneut geprüft werden ob sie wieder funktioniert,
# ansonsten reboot des gesammten systems
# nvidia-smi --query-gpu=index,gpu_name,gpu_bus_id,gpu_uuid,utilization.gpu --format=csv,noheader
#
#
#
nvidia-smi --query-gpu=index,gpu_name,gpu_bus_id,gpu_uuid,utilization.gpu --format=csv,noheader | \
gawk -e '{ sub(/\,/,"",$N); print $N}'  \
> gpu_system_check.out

index_uuid=$($uuid/gpu_index.in)
index_system= ($gpu_system.out) # <--- steht im array aray per while durchlaufen und kontrolieren

if [ -d $index_uuid nicht gleich "$index=$uuid" ]; then
    #GPU reset oder neustart des ganzensystems(noch zu prüfen)
    echo karte muss neu initialisiert werden
else
    touch $INDEX > $uuid/gpu_index.in
fi

# überprüfung der variablen ob diese noch gleich sind "index" == "uuid"
# wenn nicht neu einrichtung der index zahlen in den uuid foldern und
# versuch der neueinbindung der GPU bzw "reperatur"
