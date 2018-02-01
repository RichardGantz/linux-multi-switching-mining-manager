#!/bin/bash
###############################################################################
[[ ${#_GLOBALS_INCLUDED}     -eq 0 ]] && source globals.inc
[[ ${#_MINERFUNC_INCLUDED}   -eq 0 ]] && source ${LINUX_MULTI_MINING_ROOT}/miner-func.inc
[[ ${#_GPU_ABFRAGE_INCLUDED} -eq 0 ]] && source ${LINUX_MULTI_MINING_ROOT}/gpu-abfrage.inc
[[ ${#_LOGANALYSIS_INCLUDED} -eq 0 ]] && source ${LINUX_MULTI_MINING_ROOT}/logfile_analysis.inc

This=$(basename $0 .sh)

_reserve_and_lock_file ${SYSTEM_STATE}         # Zum Lesen und Bearbeiten reservieren...
_read_in_SYSTEM_FILE_and_SYSTEM_STATEin
_remove_lock                                   # ... und wieder freigeben

LOGFILES_ROOT=${LINUX_MULTI_MINING_ROOT}
if [ $NoCards ]; then
    LOGFILES_ROOT=${LINUX_MULTI_MINING_ROOT}/.logs/long
fi

# Datenstrukturen bzgl. des Output der Miner
source ${This}.inc

PHASE=1
[[ $# -eq 0 ]] && set -- "-h"
while [[ $# -gt 0 ]]; do
    parameter="$1"

    case $parameter in
        -p|--phase)
            PHASE=$2
	    [ ! "${PHASE}" == "1" ] && PHASE=2
            shift 2
            ;;
        -h|--help)
            echo $0 <<EOF '
                 [-p|--phase]
                 [-h|--help]'
EOF
            echo "-p PHASE"
            echo "   PHASE=1: dauert sehr lang, wertet alle Logfiles aus, 1 Zeile pro Logfile"
            echo "   PHASE=2: Wertet das Logfile von Phase 1 aus zu einer Gesamtberechnung, geht sehr schnell"
            echo "-h this help message"
            exit
            ;;
        *)
            POSITIONAL+=("$1") # save it in an array for later
            shift # past argument
            ;;
    esac
done


if [ ${PHASE} -eq 1 ]; then
    # Backup des letzten Auswertungslaufes
    [ -f ${This}.log ] && mv -f ${This}.log ${This}_$(date "+%Y%m%d_%H%M%S").log.BAK

    for gpu_idx in ${!uuid[@]}; do
        UUID=${uuid[${gpu_idx}]}
        LIVEDIR=${LOGFILES_ROOT}/${UUID}/live
        if [ -d ${LIVEDIR} ]; then
            cd ${LIVEDIR}
            MINERS=($(ls -ld * | grep -e '^d' | gawk -e '{print $NF}'))
            for MINER in ${MINERS[@]}; do
                read miner_name miner_version <<<${MINER//#/ }
                #[[ "${miner_name}" != "zm" ]] && continue
                cd "${MINER}"
                miningAlgos=($(ls -ld * | grep -e '^d' | gawk -e '{print $NF}'))
                for miningAlgo in ${miningAlgos[@]}; do
                    echo "GPU#${gpu_idx} ${MINER} ${miningAlgo}" | tee -a ${LINUX_MULTI_MINING_ROOT}/${This}.log
                    cd ${miningAlgo}
                    LOGFILES=($(ls -l *.log | gawk -e '{print $NF}'))
                    for LOGFILE in ${LOGFILES[@]}; do


                        start_time=$(grep -E -n -m1 -e "${start_msg[${MINER}]}" ${LOGFILE})
                        if [ ${#start_time} -gt 0 ]; then
                            start_line=$(( ${start_time%%:*} + 1 ))
                            #echo ${start_line}; pwd
                            start_time=${start_time%\]*}
                            #echo ${start_time}
                            start_time=${start_time%\|*}
                            #echo ${start_time}
                            start_time=${start_time#*:}
                            #echo ${start_time}
                            start_time=${start_time#*\[}
                            #echo ${start_time}
                            START_TIME=$(date -d "${start_time}" +%s)
                            #echo ${START_TIME} ${start_time}
                            #date -d "@${START_TIME}" "+%Y-%m-%d %H:%M:%S"

                            read seq_booos booos yeses <<<$(tail -n +${start_line} ${LOGFILE} \
                                                                   | gawk -v YES="${YESEXPR}" -v BOO="${BOOEXPR}" -e '
                                   BEGIN { yeses=0; booos=0; seq_booos=0 }
                                   $0 ~ BOO { booos++; seq_booos++; next }
                                   $0 ~ YES { yeses++; seq_booos=0;
                                               if (match( $NF, /[+*]+/ ) > 0)
                                                  { yeses+=(RLENGTH-1) }
                                            }
                                   END { print seq_booos " " booos " " yeses }' )
                            #echo ${seq_booos} ${booos} ${yeses}

                            end_time=$(tail -n 10 ${LOGFILE} \
                                              | grep -E -o -e '^\[?[[:digit:]-]+ [[:digit:]:]+' \
                                              | tail -n 1)
                            #echo Endtime: ${end_time}
                            str_pos=$(( ${#end_time} - 19 ))
                            end_time=${end_time:${str_pos}}
                            END_TIME=$(date -d "${end_time}" +%s)
                            #echo ${END_TIME} ${end_time}
                            DELTA=$(( ${END_TIME} - ${START_TIME} + 1 ))
                            #echo Innerhalb von ${DELTA} Sekunden Rechenzeit gab es ${yeses} Yeses
                            printf "%s %6s Sekunden, %5s Yeses, Durchschnitt pro Sekunde: %12s\n" "${end_time}" ${DELTA} ${yeses} \
                                   $(echo "scale=8; ${yeses} / ${DELTA}" | bc ) \
                                >>${LINUX_MULTI_MINING_ROOT}/${This}.log
                            #exit
                        fi


                    done
                    cd ..
                done
                cd ..
            done
        fi
    done
fi

# Auswertung einer vorhandenen Logdatei
cd ${_WORKDIR_}
gawk -e 'BEGIN { Switch=0 }
/^GPU/ { if (Switch == 2) {
             # Gesammelte Werte ausgeben
             print Index " " Miner " " Algo;
             printf "%8s Sekunden, %8s Yeses, Gesamtdurchschnitt pro 31 Sekunden: %12s\n", \
Runtime[ Index Miner Algo ], Yeses[ Index Miner Algo ], (31 * Yeses[ Index Miner Algo ] / Runtime[ Index Miner Algo ] )
         }
         Index=$1; Miner=$2; Algo=$3
         Switch=1
         next
       }
{ Runtime[ Index Miner Algo ]+=$3
  Yeses[ Index Miner Algo ]+=$5
  if (Switch == 1) Switch=2
}
END {# Gesammelte Werte ausgeben
    if (Switch == 2) {
        print Index " " Miner " " Algo;
             printf "%8s Sekunden, %8s Yeses, Gesamtdurchschnitt pro 31 Sekunden: %12s\n", \
Runtime[ Index Miner Algo ], Yeses[ Index Miner Algo ], (31 * Yeses[ Index Miner Algo ] / Runtime[ Index Miner Algo ] )
    }
}' ${This}.log

