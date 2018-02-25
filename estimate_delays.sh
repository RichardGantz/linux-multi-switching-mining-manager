#!/bin/bash
###############################################################################
[[ ${#_GLOBALS_INCLUDED}     -eq 0 ]] && source globals.inc
[[ ${#_MINERFUNC_INCLUDED}   -eq 0 ]] && source ${LINUX_MULTI_MINING_ROOT}/miner-func.inc
[[ ${#_GPU_ABFRAGE_INCLUDED} -eq 0 ]] && source ${LINUX_MULTI_MINING_ROOT}/gpu-abfrage.inc
[[ ${#_LOGANALYSIS_INCLUDED} -eq 0 ]] && source ${LINUX_MULTI_MINING_ROOT}/logfile_analysis.inc
source estimate_delays.inc

This=$(basename $0 .sh)

debug=0
Exit=0

PHASE=1
#[[ $# -eq 0 ]] && set -- "-h"
while [[ $# -gt 0 ]]; do
    parameter="$1"

    case $parameter in
        -a|--archive)
            ARCHIVE=$2
            shift 2
            ;;
        -d|--debug-infos)
            debug=1
            shift
            ;;
        -h|--help)
            echo $0 <<EOF '
                 [-a|--archive]
                 [-d|--debug-infos] 
                 [-h|--help]'
EOF
            #echo "-p PHASE"
            #echo "   PHASE=1: dauert sehr lang, wertet alle Logfiles aus, 1 Zeile pro Logfile"
            #echo "   PHASE=2: Wertet das Logfile von Phase 1 aus zu einer Gesamtberechnung, geht sehr schnell"
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

GRAF_DST_DIR="/home/avalon/temp/graf";
ARCHIV_DIR=${GRAF_DST_DIR}/.logs
if [ $NoCards ]; then
    GRAF_DST_DIR="$LINUX_MULTI_MINING_ROOT/graf";
    ARCHIV_DIR=${LINUX_MULTI_MINING_ROOT}/.logs
fi

#########################################################################
###
### DER LOGFILE NAME
### Um die Dateien aus dem letzten Archiv zu holen:
###
ARCHIVE=last_logfiles_1519516408.tar.bz2

# Die letzten 8 Ziffern des Epochdate des Logfile-Archivs
LOGNR=${ARCHIVE%%.*}
LOGNR=${LOGNR##*_}
LOGNR=${LOGNR:2}
if [ ! -d ${ARCHIV_DIR}/${LOGNR} ]; then
    mkdir -p ${ARCHIV_DIR}/${LOGNR}
    cd ${ARCHIV_DIR}
    tar -xvjf ${ARCHIV_DIR}/${ARCHIVE}
    ARCHIVE=${ARCHIVE%.*}
    tar -xvf ${ARCHIVE} -C ${LOGNR} --wildcards \
	multi_mining_calc.log.BAK \
	*gpu_gv-algo_*.log
    rm -f ${ARCHIVE}
    cd ${_WORKDIR_}
fi

# Dort wird die Logdateistruktur erwartet und dort landen auch die .csv Dateien
LOGFILES_ROOT=${ARCHIV_DIR}/${LOGNR}

declare -a CSVFILES
_calculate_mm
_calculate_gpu

# Jetzt die Erstellung der Grafiken
for CSV in ${CSVFILES[@]}; do
    php diagramm_validate_mm_GPU.php ${LOGNR} ${CSV}
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

