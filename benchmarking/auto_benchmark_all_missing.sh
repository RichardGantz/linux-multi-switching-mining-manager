#!/bin/bash
###############################################################################
#
# Wir nutzen Zeiten ohne Internet oder den Ausfal von NiceHash dazu,
# alle fehlenden Benchmark-Werte im OFFLINE-Modus zu ermitteln.
#
# Wir erzeugen fälschlicherweise die Datei ../I_n_t_e_r_n_e_t__C_o_n_n_e_c_t_i_o_n__L_o_s_t und starten
# Für jede GPU jeden fehlenden Miner-Algo mit folgendem Kommando:
#
#                   bench_30s_2.sh -a ${gpu_idx} ${algorithm}
#
# Wir können auch mit -w|--min-watt-seconds (default 30)
#       oder auch mit -m|--min-hash-count   (default 20)
# größere Werte übergeben, wenn wir wollen

# GLOBALE VARIABLEN, nützliche Funktionen
[[ ${#_GLOBALS_INCLUDED} -eq 0 ]] && source ../globals.inc

# Wenn debug=1 ist, werden die temporären Dateien beim Beenden nicht gelöscht.
debug=0

# Durch Parameterübergabe beim Aufruf änderbar:
declare -i MIN_HASH_COUNT=20    # -m Anzahl         : Mindestanzahl Hashberechnungswerte, die abgewartet werden müssen
declare -i MIN_WATT_COUNT=60    # -w Anzahl Sekunden: Mindestanzahl Wattwerte, die in Sekundenabständen gemessen werden

initialParameters="$*"
POSITIONAL=()
while [[ $# -gt 0 ]]; do
    parameter="$1"

    case $parameter in
        -w|--min-watt-seconds)
            MIN_WATT_COUNT="$2"
            bENCH_KIND=3               # -t == 1; Standardwerte == 2; -w/-m used == 3; 0 == unknown; -p FullPower == 888
            shift 2
            ;;
        -m|--min-hash-count)
            MIN_HASH_COUNT="$2"
            bENCH_KIND=3               # -t == 1; Standardwerte == 2; -w/-m used == 3; 0 == unknown; -p FullPower == 888
            shift 2
            ;;
        -p|--full-power-mode)
            STOP_AFTER_MIN_REACHED=0
            bENCH_KIND=888             # -t == 1; Standardwerte == 2; -w/-m used == 3; 0 == unknown; -p FullPower == 888
            shift
            ;;
        -d|--debug-infos)
            debug=1
            shift
            ;;
        -h|--help)
            echo $0 <<EOF '
                 [-w|--min-watt-seconds TIME] 
                 [-m|--min-hash-count HASHES] 
                 [-d|--debug-infos] 
                 [-h|--help]'
EOF
            echo "-w default is ${MIN_WATT_COUNT} seconds"
            echo "-m default is ${MIN_HASH_COUNT} hashes"
            echo "-d keeps temporary files for debugging purposes"
            echo "-h this help message"
            echo ""
            exit
            ;;
        *)
            POSITIONAL+=("$1") # save it in an array for later
            shift # past argument
            ;;
    esac
done
#set -- "${POSITIONAL[@]}" # restore positional parameters

function _delete_temporary_files () {
    rm -f ../I_n_t_e_r_n_e_t__C_o_n_n_e_c_t_i_o_n__L_o_s_t
}
_delete_temporary_files

function _On_Exit () {
    if [ $debug -eq 0 ]; then
        _delete_temporary_files
    fi
    rm -f $(basename $0 .sh).pid
}
trap _On_Exit EXIT

# Aktuelle eigene PID merken
echo $$ >$(basename $0 .sh).pid

###################################################################################
#
#                _query_actual_Power_Temp_and_Clocks
#
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
#
#                _query_actual_Power_Temp_and_Clocks
#

# Funktionen zum Einlesen von ALGO_NAMES und ALGO_PORTS aus dem Web
#[[ ${#_ALGOINFOS_INCLUDED} -eq 0 ]] && source ${LINUX_MULTI_MINING_ROOT}/algo_infos.inc
# Funktionen für das Einlesen aller bekannten Miner und Unterscheidung in Vefügbare sowie Fehlende.
[[ ${#_MINERFUNC_INCLUDED} -eq 0 ]] && source ${LINUX_MULTI_MINING_ROOT}/miner-func.inc

[ ${debug} -eq 1 ] && echo "miner-func.inc included"

# Das ist jetzt richtig aktiv und liest die folgenden Systeminformationen in die entsprechenden Arrays:
#      index[0-n]=gpu_idx
#          name[${gpu_idx}]=
#           bus[${gpu_idx}]=
#          uuid[${gpu_idx}]=
#    auslastung[${gpu_idx}]=
#            GPU${gpu_idx}Algos[]=          # declaration only
#            GPU${gpu_idx}Watts[]=          # declaration only
#            GPU${gpu_idx}Mines[]=          # declaration only
#     uuidEnabledSOLL[${gpu_uuid}]=         # 0/1
#
# UND:
#      Stellt sicher, dass aktuelle gpu-bENCH.sh Dateien in den GPU-UUID Verzeichnissen sind.
#      Diese sorgen durch "source"-ing dafür, dass die JSON-Einträge und Arrays zusammenpassen
#
# Das entsprechende "source"-ing machen wir weiter unten, wenn wir wissen, um welche GPU
#     und welchen $algorithm es sich handelt.
cd ..
source gpu-abfrage.sh
_func_gpu_abfrage_sh
cd ${_WORKDIR_} >/dev/null
gpu_idx_list="${index[@]}"

[ ${debug} -eq 1 ] && echo "GPU-Abfrage durchgeführt"

################################################################################
################################################################################
###
###          1. GROSSER FAKE, UM OFFLINE-BENCHMARKING ZU ERZWINGEN
###
################################################################################
################################################################################

#touch ../I_n_t_e_r_n_e_t__C_o_n_n_e_c_t_i_o_n__L_o_s_t
#[ ${debug} -eq 1 ] && echo "Internet Connection Lost - Fake etabliert"

################################################################################
###
### 1. Auswahl der GPU
###
for gpu_idx in ${index[@]}; do
    ###
    ### 2. Einlesen ALLER verfügbaren Miner und deren Algos
    ###
    gpu_uuid=${uuid[${gpu_idx}]}
    IMPORTANT_BENCHMARK_JSON="../${gpu_uuid}/benchmark_${gpu_uuid}.json"
    #_test_=1
    _read_in_ALL_Mining_Available_and_Missing_Miner_Algo_Arrays

    ###
    ### 3. Auswahl des Miners
    ###
    for minerName in ${ALLE_MINER[@]}; do
        read miner_name miner_version <<<"${minerName//#/ }"

        ###
        ### 4. Durchgehen aller Missing Algos
        ###
        declare -n actMissingAlgos="Missing_${miner_name//\-/_}_${miner_version//\./_}_Algos"
        if [ ${#actMissingAlgos[@]} -gt 0 ]; then
            for algo in ${actMissingAlgos[@]}; do
                algorithm=${algo}#${miner_name}#${miner_version}
                echo ""
                echo "Auto Benchmark für GPU #${gpu_idx} und Algo ${algorithm} wird nun gestartet"
                echo ""
                ./bench_30s_2.sh -a ${gpu_idx} ${algorithm} "${initialParameters}"
            done
        fi
    done
done

#rm -f ../I_n_t_e_r_n_e_t__C_o_n_n_e_c_t_i_o_n__L_o_s_t
