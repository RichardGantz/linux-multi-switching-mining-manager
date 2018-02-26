#!/bin/bash
###############################################################################
[[ ${#_GLOBALS_INCLUDED}     -eq 0 ]] && source globals.inc
[[ ${#_MINERFUNC_INCLUDED}   -eq 0 ]] && source ${LINUX_MULTI_MINING_ROOT}/miner-func.inc
[[ ${#_GPU_ABFRAGE_INCLUDED} -eq 0 ]] && source ${LINUX_MULTI_MINING_ROOT}/gpu-abfrage.inc
[[ ${#_LOGANALYSIS_INCLUDED} -eq 0 ]] && source ${LINUX_MULTI_MINING_ROOT}/logfile_analysis.inc
source estimate_delays.inc

# Zwei wichtige Pfade
GRAF_DST_DIR="/home/avalon/temp/graf";
ARCHIV_DIR=${GRAF_DST_DIR}/.logs
if [ $NoCards ]; then
    GRAF_DST_DIR="$LINUX_MULTI_MINING_ROOT/graf";
    ARCHIV_DIR=${LINUX_MULTI_MINING_ROOT}/.logs
fi

This=$(basename $0 .sh)

debug=0
live_system=0
mm_ext=".BAK"

#[[ $# -eq 0 ]] && set -- "-h"
while [[ $# -gt 0 ]]; do
    parameter="$1"

    case $parameter in
        -a|--archive)
            ARCHIVE=$2
            shift 2
            ;;
        -l|--live-system)
            live_system=1
            mm_ext=""
            shift
            ;;
        -d|--debug-infos)
            debug=1
            shift
            ;;
        -h|--help)
            echo $0 <<EOF '
                 [-a|--archive]
                 [-l|--live-system]
                 [-d|--debug-infos] 
                 [-h|--help]'
EOF
            echo "-a ARCHIVE-Name with or without a path"
            echo "-l use live-system, do NOT use Archives"
            echo "-d keeps temporary files for debugging purposes"
            echo "-h this help message"
            exit
            ;;
        *)
            POSITIONAL+=("$1") # save it in an array for later
            shift # past argument
            ;;
    esac
done

_reserve_and_lock_file ${SYSTEM_STATE}         # Zum Lesen und Bearbeiten reservieren...
_read_in_SYSTEM_FILE_and_SYSTEM_STATEin
_remove_lock                                   # ... und wieder freigeben

#########################################################################
###
### DER LOGFILE NAME
### Um die Dateien aus dem letzten Archiv zu holen:
###
if [ -z "${ARCHIVE}" ]; then
    #ARCHIVE=${ARCHIV_DIR}/last_logfiles_1519516408.tar.bz2
    ARCHIVES=($(ls ${ARCHIV_DIR}/*.bz2))
    max=0
    for arch in ${ARCHIVES[@]}; do
        #echo $max
        LOGNR=${arch##*_}
        LOGNR=${LOGNR%%.*}
        if [ ${LOGNR} -gt ${max} ]; then
            max=${LOGNR}
            ARCHIVE=${arch}
        fi
    done
fi

# Die letzten 8 Ziffern des Epochdate des Logfile-Archivs. ACHTUNG: Die Reihenfolge der Befehle ist hier wichtig, um die Zahlz zu isolieren
LOGNR=${ARCHIVE##*_}   # Zuerst alles von vorne wegnehmen bis einschließlich des "_" vor der Zahl
LOGNR=${LOGNR%%.*}     # Dann von hinten alles wegnehmen bis einschlißlich des "." nach der Zahl
LOGNR=${LOGNR:2}       # Die ersten beiden Ziffern brauchen wir (noch) nicht.
if [ ! -d ${ARCHIV_DIR}/${LOGNR} ]; then
    mkdir -p ${ARCHIV_DIR}/${LOGNR}
    tar -xvjf ${ARCHIVE} -C ${ARCHIV_DIR}
    cd ${ARCHIV_DIR}
    TARCHIVE=${ARCHIVE%.*}
    TARCHIVE=${TARCHIVE##*/}
    tar -xvf ${TARCHIVE} -C ${LOGNR} --wildcards \
        multi_mining_calc.log${mm_ext} \
        *gpu_gv-algo_*.log
    rm -f ${TARCHIVE}
    cd ${_WORKDIR_}
fi

# Dort wird die Logdateistruktur erwartet und dort landen auch die .csv Dateien
LOGFILES_ROOT=${ARCHIV_DIR}/${LOGNR}
if [ ${live_system} -eq 0 ]; then
    unset uuid uuidEnabledSOLL
    declare -Ag uuidEnabledSOLL
    UUIDS=($(ls -d ${LOGFILES_ROOT}/GPU-*))
    for UUID in ${UUIDS[@]}; do
        UUID=${UUID##*/}
        gpu_idx=$(cat ${LOGFILES_ROOT}/${UUID}/gpu_gv-algo_${UUID}.log \
            | grep -E -m1 -o -e 'GPU #[[:digit:]]' \
            | grep -E -o -e '[[:digit:]]$')
        if [ ${gpu_idx} -gt 0 ]; then
            uuid[${gpu_idx}]=${UUID}
            uuidEnabledSOLL[${UUID}]=1
        fi
    done
fi

declare -a CSVFILES
_calculate_mm
_calculate_gpu

# Jetzt die Erstellung der Grafiken
for CSV in ${CSVFILES[@]}; do
    php diagramm_validate_mm_GPU.php ${ARCHIV_DIR} ${LOGNR} ${CSV} ${GRAF_DST_DIR}
done


ls -la ${GRAF_DST_DIR}

exit

#################################################################################
#################################################################################
#########     ENDE DES SKRIPTS UND NÜTZLICHE SCRIPTS ALS "RESERVE"     ##########
#################################################################################
#################################################################################


#################################################################################
#
# GPU-Kommando-Ausführungszeiten
#
#################################################################################
cat ${LOGFILES_ROOT}/multi_mining_calc.err \
    | grep -E -e "ZEITMARKE t[01]:" \
    | gawk -M -e '
{ gpu=$5; t=$7; epoch=$3
  if ( t=="t0:" ) {
     if ( length( START[ gpu t ] ) > 0 ) {
        e=substr( ENDE[ gpu "t1:" ],  6, 5 )
        E=substr( ENDE[ gpu "t1:" ], 12, 2 )
        s=substr( START[ gpu t ],  6, 5 )
        S=substr( START[ gpu t ], 12, 2 )
        d= e - s
        F= E - S
        if ( F < 0 ) { d = d - 1; F = -1 * F }
        printf "Nvidia-Befehlsdauer ab Sekunde %s.%02i GPU%s %s.%02is\n", s, S, gpu, d, F
     }
     START[ gpu t ] = epoch
     #print START[ gpu t ]
     next
  }
  ENDE[ gpu t ] = epoch
  #print ENDE[ gpu t ]
}'

