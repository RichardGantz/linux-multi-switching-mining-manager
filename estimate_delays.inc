#!/bin/bash
###############################################################################

_calculate_gpu () {
    for gpu_idx in ${!uuid[@]}; do
        UUID=${uuid[${gpu_idx}]}
	if [ ${uuidEnabledSOLL[${UUID}]} -eq 1 ]; then
	    local DSTFILE="GPU#${gpu_idx}.csv" DSTDIR=${LOGFILES_ROOT}
	    CSVFILES=( ${CSVFILES[@]} "${DSTFILE}" )
	    echo "Valid;Run;End" >${DSTDIR}/${DSTFILE}
	    cat ${LOGFILES_ROOT}/${UUID}/gpu_gv-algo_${UUID}.log \
		| grep -E -B 1 -e "Anfang der Endlosschleife|now UNLOCKED in ALGO_WATTS_MINES.in|GLOBAL_GPU_ALGO_RUNNING_STATE|Waiting for SYNCFILE and therefore" \
		| grep -E -v -e '#############|^--|^declare' \
		| gawk -M -e '
{ start=substr( $3,  3, 8 ); getline
  valid=substr( $3,  3, 8 ); V=substr( $3, 12, 2 ); getline
  Rstat=substr( $3,  3, 8 ); getline; getline
  ende =substr( $3,  3, 8 ); getline
  out_str=(valid - start) "." V ";" (Rstat - start) ";" (ende - start)
  if ( out_str != "0.;0;0" ) print out_str } ' \
		       >>${DSTDIR}/${DSTFILE}
		       # | tee -a ${DSTDIR}/${DSTFILE}
	fi
    done
}

_calculate_mm () {

    cat ${LOGFILES_ROOT}/multi_mining_calc.log.BAK \
	| grep -E -e "^Maximum waittime until:|^Last read nowSecs:|Going to wait for all GPUs" \
	| gawk -M -e 'BEGIN { min=10; max=0 }
        /^Max/ { m=substr( $NF,  3, 8 )
                 M=substr( $NF, 12, 2 )
                 s= m - 10
               }
        /^Las/ { l=substr( $4,  3, 8 )
                 L=substr( $4, 12, 2 )
                 print "SYNCFILE written: " s "." M
                 print "MM going to wait: " g
                 print "All Data valid..: " l "." L
                 d= l - s
                 D= L - M
                 if ( D < 0 ) { d = d - 1; D = -1 * D }
                 print "Waittime........: " d "." D
                 next
               }
        /^[2]/ { g=substr( $3,  3, 8 ) }' \
	| grep Waitt \
	| grep -E -o -e '[[:digit:].]*$' \
	| readarray -n 0 -O 0 -t WAITTIME

    cat ${LOGFILES_ROOT}/multi_mining_calc.log.BAK \
	| grep -E -e "Beginn neuer Zyklus um:|Ende des Zyklus um:" \
	| gawk -M -e '
$2 ~ /Beginn/ { b=$8; next }
{ d = 0 + $8 - b; print d }' \
	| readarray -n 0 -O 0 -t ENDOFCYCLE

    CSVFILES=( ${CSVFILES[@]} "mm_cycles.csv" )
    rm -f ${LOGFILES_ROOT}/${CSVFILES[-1]}
    for ((i=0; i<${#WAITTIME[@]}; i++)); do
	echo "${WAITTIME[$i]};${ENDOFCYCLE[$i]}" >>${LOGFILES_ROOT}/${CSVFILES[-1]}
    done

}
