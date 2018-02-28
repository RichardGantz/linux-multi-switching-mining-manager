#!/bin/bash
###############################################################################
# Definiert werden hier die folgenden Funktionen:
#
# 1. _calculate_mm    : Wartezeit ab SYNC bis GPU-Daten ALLE gültig ; Zyklus-Dauer
#                       ${WAITTIME[*]}                              ; ${ENDOFCYCLE[*]}
# 2. _calculate_gpu   : VALID DATA ab SYNC ; New RUN_STATE (switch Miners) ; Ende Arbeit für diesen Zyklus
#                       CSV_ROWS[*]
#                       In die .csv Datei selbst packen wir noch die MM-Wartezeit zwischen VALID DATA und RUN_STATE rein.
#

_calculate_mm () {
    log_startline=1
    cat ${LOGFILES_ROOT}/multi_mining_calc.log${mm_ext} \
        | grep -E -n -e "Beginn neues Logfile um:" \
        | readarray -n 0 -O 0 -t LOG_STARTS
    str="${LOG_STARTS[@]}"
    if [ -n "${str}" ]; then
        read log_startline muck <<<"${LOG_STARTS[-1]//:/ }"
    fi

    # Ermittlung der Wartezeit ab SYNCFILE
    #cat ${LOGFILES_ROOT}/multi_mining_calc.log${mm_ext} \
    tail -n +${log_startline} ${LOGFILES_ROOT}/multi_mining_calc.log${mm_ext} \
        | grep -E -e "^Maximum waittime until:|^Last read nowSecs:|Going to wait for all GPUs" \
        | gawk -M -e '
        /^Max/ { m=substr( $NF,  3, 8 )
                 M=substr( $NF, 12, 2 )
                 s= m - '${MM_validating_delay}'
                 next
               }
        /^Las/ { if ( NF == 5 ) {
                    # Alte Logzeile ohne s.S - Angabe
                    l=substr( $NF,  3, 8 )
                    L=substr( $NF, 12, 2 )
                 } else {
                    l=substr( $4,  3, 8 )
                    L=substr( $4, 12, 2 )
                 }
                 print "SYNCFILE written: " s "." M
                 print "MM going to wait: " g
                 print "All Data valid..: " l "." L
                 d= l - s
                 D= L - M
                 if ( D < 0 ) { d -= 1; D += 100 }
                 print "Waittime........: " d "." D
                 next
               }
        /^[2]/ { g=substr( $3,  3, 8 ) }' \
        | grep Waitt \
        | grep -E -o -e '[[:digit:].]*$' \
        | readarray -n 0 -O 0 -t WAITTIME

    cat ${LOGFILES_ROOT}/multi_mining_calc.log${mm_ext} \
        | grep -E -e "Beginn neuer Zyklus um:|Ende des Zyklus um:" \
        | gawk -M -e '
$2 ~ /Beginn/ { b=$8; next }
{ d = 0 + $8 - b; print d }' \
        | readarray -n 0 -O 0 -t ENDOFCYCLE

    CSVFILES+=( "mm_cycles.csv" )
    rm -f ${LOGFILES_ROOT}/${CSVFILES[-1]}
    for ((i=0; i<$((${#WAITTIME[@]}-1)); i++)); do
        echo "${WAITTIME[$i]};${ENDOFCYCLE[$i]}" >>${LOGFILES_ROOT}/${CSVFILES[-1]}
    done

}

_calculate_gpu () {
    for gpu_idx in ${!uuid[@]}; do
        UUID=${uuid[${gpu_idx}]}
        if [ ${uuidEnabledSOLL[${UUID}]} -eq 1 ]; then
            local DSTFILE="GPU#${gpu_idx}.csv" DSTDIR=${LOGFILES_ROOT}
            CSVFILES+=( "${DSTFILE}" )
            unset CSV_ROWS; declare -ag CSV_ROWS
            cat ${LOGFILES_ROOT}/${UUID}/gpu_gv-algo_${UUID}.log \
                | grep -E -B 1 -e "Anfang der Endlosschleife|now UNLOCKED in ALGO_WATTS_MINES.in|GLOBAL_GPU_ALGO_RUNNING_STATE|Waiting for SYNCFILE and therefore" \
                | grep -E -v -e '#############|^--|^declare' \
                | gawk -M -e '
{ start=substr( $3,  3, 8 ); getline
  while (match( $0, "are now UNLOCKED" ) == 0) { getline }
  valid=substr( $3,  3, 8 ); V=substr( $3, 12, 2 ); getline
  Rstat=substr( $3,  3, 8 ); getline; getline
  ende =substr( $3,  3, 8 ); getline
  out_str=(valid - start) "." V " " (Rstat - start) " " (ende - start)
  if ( out_str != "0. 0 0" ) print out_str } ' \
                | readarray -n 0 -O 0 -t CSV_ROWS

            rm -f ${DSTDIR}/${DSTFILE}
            for ((i=0; i<$((${#CSV_ROWS[@]}-1)); i++)); do
                read valid_data run_state_there end_of_work <<<${CSV_ROWS[$i]}
                if [ "$1" == "mm_waittime" ]; then
                    echo "${valid_data};${WAITTIME[$i]};${run_state_there}" \
                         >>${DSTDIR}/${DSTFILE}
                else
                    echo "${valid_data};${run_state_there};${end_of_work}" >>${DSTDIR}/${DSTFILE}
                fi
            done
        fi
    done
}

