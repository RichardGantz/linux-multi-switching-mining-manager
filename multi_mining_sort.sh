#!/bin/bash
###############################################################################
#                           Multi-Mining-Sort
# 
# Hier werden die GPU's Algorythmen jeder Karte Sortiert und zusammengefasst.
# 
# Welche Karte "sieger" ist und als erstes z.b. anfangen darf zu minen
#
#
#
#
###############################################################################

# Aktuelle PID der 'multi_mining-controll.sh' ENDLOSSCHLEIFE
echo $$ >multi_mining_sort.pid

GPU_SYSTEM_DATA=gpu_system.out
if [ ! -f $GPU_SYSTEM_DATA ]; then
    #echo "-------------------------------------------"
    #echo "---           FATAL ERROR               ---"
    #echo "-------------------------------------------"
    #echo "No GPU System Data availlable."
    #echo "Please run gpu-abfrage.sh"
    #echo "-------------------------------------------"
    ./gpu-abfrage.sh
fi

###############################################################################
#
# Wie die abbfolge dieses Programm ist und wie es es abfragt
# 1. finde GPU folder
# 1.1. lade 3 arrays mit folgenden Daten "best_algo_netz.out","best_algo_solar","best_algo_solar_akku.out",
#      "gpu_index.in" alle 10 sekunden oder direkt nach "lausche auf" aktualisierung der GPU best* daten
# 1.2. Sortiere jeweils jedes array nach dem besten "profitabelsten" algorytmus
# 1.3. Gebe jede dieser arrays aus "best_all_netz.out","best_all_solar.out","best_all_solar_akku.out"
#      in diesen outs sind "index(GPU), algo, watt" pro NETZ, SOLAR, AKKU
# 

###############################################################################
# Zu 1. Finde GPU Folder
###############################################################################

# Sortierungsquelldateien
GRID[0]="netz"
GRID[1]="solar"
GRID[2]="solar_akku"
for ((grid=0; $grid<${#GRID[@]}; grid+=1)); do
    best[$grid]=best_all_${GRID[$grid]}.out
    rm -f ${best[$grid]}
    tmpSort[$grid]=.0${GRID[$grid]}_sort
    rm -f ${tmpSort[$grid]}.in
done

unset READARR
readarray -n 0 -O 0 -t READARR <$GPU_SYSTEM_DATA
# Aus den MinerName:BenchmarkSpeed Paaren das assoziative Array bENCH erstellen
declare -a index
declare -a name
#declare -a bus
declare -a uuid
#declare -a auslastung
for ((i=0; $i<${#READARR[@]}; i+=5)) ; do
    j=$(expr $i / 5)
    index[$j]=${READARR[$i]}        # index[] = Grafikkarten-Index für miner
    name[${index[$j]}]=${READARR[$i+1]}
    #bus[${index[$j]}]=${READARR[$i+2]}
    uuid[${index[$j]}]=${READARR[$i+3]}
    #auslastung[${index[$j]}]=${READARR[$i+4]}

    # Quelldateien für Sortierung erstellen
    # sort-key    algo      WATT    + GPU-Index
    #-.00007377 cryptonight 270 ${index[$j]}
    for ((grid=0; $grid<${#GRID[@]}; grid+=1)); do
        if [ ! -f ${uuid[${index[$j]}]}/best_algo_${GRID[$grid]}.out ]; then
            echo "-------------------------------------------"
            echo "---           FATAL ERROR               ---"
            echo "-------------------------------------------"
            echo "No file 'best_algo_${GRID[$grid]}.out' availlable"
            echo "for GPU ${name[${index[$j]}]}"
            echo "Please run '${uuid[${index[$j]}]}/gpu_gv-algo.sh'"
            echo "-------------------------------------------"
        else
            echo $(< ${uuid[${index[$j]}]}/best_algo_${GRID[$grid]}.out ) ${index[$j]} >>${tmpSort[$grid]}.in
        fi
    done
done

# Sortiert ausgeben:
for ((grid=0; $grid<${#GRID[@]}; grid+=1)); do
    if [ -f ${tmpSort[$grid]}.in ]; then
        cat ${tmpSort[$grid]}.in                         \
            | sort -rn                                   \
            | tee ${tmpSort[$grid]}.out                  \
            | gawk -e '{print $4 " " $1 " " $2 " " $3 }' \
            | sed -n '1p' \
            >${best[$grid]}
        if [ 1 == 1 ]; then
            txt=`echo ${tmpSort[$grid]%%_sort}`; txt=${txt:2}
            echo "--------------------------------------"
            echo "           ${txt^^}"
            echo "--------------------------------------"
            gawk -e '{print "GPU " $4 ": " $1 " " $2 " " $3 }' ${tmpSort[$grid]}.out
        fi
    fi
done

# GPU-Index-Datei für miner (==algo ?) erstellen.
# Hier: Komma-getrennt

# Alle GPU-Index-Dateien löschen ?
rm -f cfg_*
for ((grid=0; $grid<${#GRID[@]}; grid+=1)); do
    if [ -f ${best[$grid]} ]; then
        txt=`echo ${tmpSort[$grid]%%_sort}`       # "_sort" vom Namenende entfernen
        gawk -v grid=${txt:2} -e ' \
             $2 > 0 { ALGO[$3]=ALGO[$3] $1 "," } \
             END { for (algo in ALGO) \
                   print substr( ALGO[algo], 1, length(ALGO[algo])-1 ) > "cfg_" grid "_" algo }' \
             ${best[$grid]}
    fi
done

# ./miner --cuda_dev cfg_NETZ_equihash --solver $devices --server blablub.com -u btcadrtesse -p x 

# equihash
# ./miner --server server.com --port 7777 --user name --pass secret --cuda_devices 0 1 2 3 --eexit 1

# GLOBALER miner
# -i --intensity=N[,N] GPU intensity 8.0-25.0 (default: auto) Decimals are allowed for fine tuning 
#
# -d, --devices Comma separated list of CUDA devices to use.
#
# ./ccminer -a cryptonight -o stratum+tcp://cryptonight.eu.nicehash.com:3355 -u 12X6Enpg5FBQ332Re3vjU5FAxxQWUioBMg.980ti -p 0
