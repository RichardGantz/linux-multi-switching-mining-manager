#!/bin/bash
###############################################################################
[[ ${#_GLOBALS_INCLUDED}     -eq 0 ]] && source globals.inc
[[ ${#_MINERFUNC_INCLUDED}   -eq 0 ]] && source ${LINUX_MULTI_MINING_ROOT}/miner-func.inc
[[ ${#_GPU_ABFRAGE_INCLUDED} -eq 0 ]] && source ${LINUX_MULTI_MINING_ROOT}/gpu-abfrage.inc
[[ ${#_LOGANALYSIS_INCLUDED} -eq 0 ]] && source ${LINUX_MULTI_MINING_ROOT}/logfile_analysis.inc

This=$(basename $0 .sh)

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

_reserve_and_lock_file ${SYSTEM_STATE}         # Zum Lesen und Bearbeiten reservieren...
_read_in_SYSTEM_FILE_and_SYSTEM_STATEin
_remove_lock                                   # ... und wieder freigeben

LOGFILES_ROOT=${LINUX_MULTI_MINING_ROOT}
if [ $NoCards ]; then
    LOGFILES_ROOT=${LINUX_MULTI_MINING_ROOT}/.logs/long
fi

# Datenstrukturen bzgl. des Output der Miner
source ${This}.inc

debug=0
Exit=0

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

                        #[ "${LOGFILE}" != "20180121_230126_mining.log" ] && continue

                        #if [ ${#next_file} -eq 0 ]; then
                        #    next_file=0; continue
                        #elif [ ${next_file} -ge 0 ]; then
                        #    [[ $(( ++next_file )) -lt 4 ]] && continue
                        #fi

                        difficulty=$(grep -E -o -m1 -e "${diff_msg[${MINER}]}" ${LOGFILE})
                        [ ${#difficulty} -eq 0 ] && continue
                        start_time=$(grep -E -n -m1 -e "${diff_msg[${MINER}]}" ${LOGFILE})
                        [ ${#start_time} -eq 0 ] && continue
                        end_time=$(tail -n 10 ${LOGFILE} \
                                          | grep -E -o -e '^\[?[[:digit:]-]+ [[:digit:]:]+' \
                                          | tail -n 1)
                        [ ${debug} -gt 0 ] && echo Endtime: ${end_time}
                        str_pos=$(( ${#end_time} - 19 ))
                        end_time=${end_time:${str_pos}}
                        END_TIME=$(date -d "${end_time}" +%s)
                        [ ${debug} -gt 0 ] && echo ${END_TIME} ${end_time}

                        echo "# ${LOGFILES_ROOT}/${UUID}/live/${MINER}/${miningAlgo}/${LOGFILE}" >>${LINUX_MULTI_MINING_ROOT}/${This}.log
                        start_line=${start_time%%:*}
                        [ ${debug} -gt 0 ] && echo ${start_line}

     REGEXPAT="${start_msg[${MINER}]}|${diff_msg[${MINER}]}|${YESEXPR}"
     tail -n +${start_line} ${LOGFILE} \
         | grep -E -o -e "${REGEXPAT}" \
         | gawk -M \
                -v YES="${YESEXPR}" \
                -v start_msg="${start_msg[${MINER}]}" \
                -v diff_msg="${diff_msg[${MINER}]}" \
                -v END_TIME=${END_TIME} \
                -e '
{   if (match($0, diff_msg )) {
        match($0, /[\[]?(([[:digit:]]{4})-([[:digit:]]{2})-([[:digit:]]{2}) ([[:digit:]]{2}):([[:digit:]]{2}):([[:digit:]]{2}))/, datum )
        end_date=datum[1]
        date_str=datum[2] " " datum[3] " " datum[4] " " datum[5] " " datum[6] " " datum[7]
        ende=mktime( date_str )
        new_DIFF=$NF
        if (print_out == 1) {
            if ( new_DIFF != DIFF ) {
                seconds[ DIFF ]+=(ende - start)
                DIFF=new_DIFF
                start=ende
            }
        } else {
            print_out=1
            DIFF=new_DIFF
            start=ende
        }
        DIFFs[ DIFF ]=1
        next
    }
}
{   if (match($0, start_msg )) {
        match($0, /[\[]?(([[:digit:]]{4})-([[:digit:]]{2})-([[:digit:]]{2}) ([[:digit:]]{2}):([[:digit:]]{2}):([[:digit:]]{2}))/, datum )
        end_date=datum[1]
        date_str=datum[2] " " datum[3] " " datum[4] " " datum[5] " " datum[6] " " datum[7]
        start=mktime( date_str )
        next
    }
}
$0 ~ YES {
    yeses[ DIFF ]++;
    if (match( $NF, /[+*]+/ ) > 0)
        { yeses[ DIFF ]+=(RLENGTH-1) }
}
END {
    if (print_out == 1) {
        seconds[ DIFF ]+=(END_TIME - start + 1)
        for (DIFF in DIFFs) {
            if (seconds[ DIFF ] == 0) printf "#"
            printf "%s %6s Sekunden, %5i Yeses, Durchschnitt pro Sekunde: %12s Diff: %s\n", \
                   end_date, \
                   seconds[ DIFF ], \
                   yeses[ DIFF ], \
                   (yeses[ DIFF ]/seconds[ DIFF ]), \
                   DIFF
        }
    }
}' 2>/dev/null >>${LINUX_MULTI_MINING_ROOT}/${This}.log
#}' 2>/dev/null | tee -a ${LINUX_MULTI_MINING_ROOT}/${This}.log

                        [ ${Exit} -gt 0 ] && exit



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
grep -E -v -e '^#|^$' ${This}.log | gawk -e 'BEGIN { Switch=0 }
/^GPU/ {
        if (Switch == 2) {
            print Index " " Miner " " Algo
            for (DIFF in DIFFs) {
                printf "%8s Sekunden, %8s Yeses, Gesamtdurchschnitt pro 31 Sekunden: %12s   Diff: %s\n", \
                        Runtime[ Index Miner Algo DIFF ],\
                        Yeses[ Index Miner Algo DIFF ],  \
                        (31 * Yeses[ Index Miner Algo DIFF ] / Runtime[ Index Miner Algo DIFF ] ), \
                        DIFF
            }
            delete DIFFs
        }
        Index=$1; Miner=$2; Algo=$3
        Switch=1
        next
       }
{ DIFF=$NF
  DIFFs[ DIFF ]=1
  Runtime[ Index Miner Algo DIFF ]+=$3
  Yeses[ Index Miner Algo DIFF ]+=$5
  Switch=2
}
END {
        if (Switch == 2) {
            print Index " " Miner " " Algo;
            for (DIFF in DIFFs) {
                printf "%8s Sekunden, %8s Yeses, Gesamtdurchschnitt pro 31 Sekunden: %12s   Diff: %s\n", \
                        Runtime[ Index Miner Algo DIFF ],\
                        Yeses[ Index Miner Algo DIFF ],  \
                        (31 * Yeses[ Index Miner Algo DIFF ] / Runtime[ Index Miner Algo DIFF ] ), \
                        DIFF
            }
        }
}'

