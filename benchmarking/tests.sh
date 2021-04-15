#!/bin/bash

[[ ${#_GLOBALS_INCLUDED} -eq 0     ]] && source ../globals.inc
[[ ${#_LOGANALYSIS_INCLUDED} -eq 0 ]] && source ../logfile_analysis.inc

gpu_uuid=GPU-000bdf4a-1a2c-db4d-5486-585548cd33cb
gpu_uuid=GPU-5c755a4e-d48e-f85c-43cc-5bdb1f8325cd
miner_name=t-rex
miner_version=0.10.12
miner_name=miner
miner_version=2.51
miningAlgo=octopus
miningAlgo=ethash
miningAlgo=beamhash

MINER=${miner_name}#${miner_version}

if [ 1 -eq 0 ]; then

    BENCHLOGFILE="test/${miningAlgo}_${gpu_uuid}_benchmark.log"
    WATTSLOGFILE="test/${miningAlgo}_${gpu_uuid}_watts_output.log"
    WATTSMAXFILE="test/${miningAlgo}_${gpu_uuid}_watts_max.log"
    temp_watt_sum="test/${miningAlgo}_${gpu_uuid}_temp_watt_sum"

    watt_line=1
    # ... dann die WattLog
    MinusM=-M           # Absolut bescheuertes Verhalten des gawk, möglicherweise ab API 2.0. Ist ein Bug drin.
    MinusM=--bignum
    MinusM=
    wattCount=$(cat "${WATTSLOGFILE}" \
		    | tail -n +$watt_line \
		    | grep -E -o -e "^[[:digit:]]+" \
		    | tee >(gawk ${MinusM} -e 'BEGIN {sum=0} {sum+=$1} END {print sum}' >${temp_watt_sum} ) \
			  >(gawk ${MinusM} -e 'BEGIN {max=0} {if ($1>max) max=$1 } END {print max}' >${WATTSMAXFILE} ) \
		    | wc -l \
             )
    wattSum=$(< ${temp_watt_sum})

    echo \$wattCount=$wattCount
    echo \$wattSum==$wattSum
    cat ${WATTSMAXFILE}

    exit
fi

###
### Zum Testen der Suchmuster
###

BENCHLOGFILE="test/${miningAlgo}_${gpu_uuid}_benchmark.log"
TWEAKLOGFILE="test/${miningAlgo}_${gpu_uuid}_tweak.log"
WATTSLOGFILE="test/${miningAlgo}_${gpu_uuid}_watts_output.log"
WATTSMAXFILE="test/${miningAlgo}_${gpu_uuid}_watts_max.log"

TEMPAZB_FILE="test/${miningAlgo}_${gpu_uuid}_tempazb"
TEMPSED_FILE="test/${miningAlgo}_${gpu_uuid}_sed_insert_on_different_lines_cmd"
temp_hash_bc="test/${miningAlgo}_${gpu_uuid}_temp_hash_bc_input"
temp_avgs_bc="test/${miningAlgo}_${gpu_uuid}_temp_avgs_bc_input"
temp_hash_sum="test/${miningAlgo}_${gpu_uuid}_temp_hash_sum"
temp_watt_sum="test/${miningAlgo}_${gpu_uuid}_temp_watt_sum"
FATAL_ERR_CNT="test/${miningAlgo}_${gpu_uuid}.FATAL"
RETRIES_COUNT="test/${miningAlgo}_${gpu_uuid}.retry"
BoooooS_COUNT="test/${miningAlgo}_${gpu_uuid}.booos"

FATAL_ERR_CNT="test/${MINER}_${gpu_uuid}.FATAL"
RETRIES_COUNT="test/${MINER}_${gpu_uuid}.retry"
BoooooS_COUNT="test/${MINER}_${gpu_uuid}.booos"

BENCHLOGFILE="/home/avalon/miner/t-rex/t-rex-dagger-[1617632601].log"                 # hat KEIN SPACE am Anfang
BENCHLOGFILE="${LINUX_MULTI_MINING_ROOT}/benchmarking/BENCHLOGFILE.t-rex#12.log"      # Hat ein SPACE am Anfang
BENCHLOGFILE="${LINUX_MULTI_MINING_ROOT}/benchmarking/BENCHLOGFILE.gminer-ethash.log"
BENCHLOGFILE="${LINUX_MULTI_MINING_ROOT}/benchmarking/BENCHLOGFILE.gminer-beamhash.log"
BENCHLOGFILE="${LINUX_MULTI_MINING_ROOT}/benchmarking/BENCHLOGFILE.gminer-cuckatoo31.log"
BENCHLOGFILE="/home/avalon/miner/gminer/gpu-test.log"

echo "${ERREXPR}"
echo "${BOOEXPR}"
echo "${YESEXPR}"

#YESEXPR='^\\s?[[] OK [\]][[:digit:]\/ -.]*M'
#echo "${YESEXPR}"

hash_line=1
touch ${FATAL_ERR_CNT}.lock ${RETRIES_COUNT}.lock ${BoooooS_COUNT}.lock
hashCount=$(cat ${BENCHLOGFILE} \
		| tail -n +$hash_line \
		| tee >(grep -E -c -m1 -e "${ERREXPR}" >${FATAL_ERR_CNT}; \
			rm -f ${FATAL_ERR_CNT}.lock) \
		      >(grep -E -c -e "${CONEXPR}" >${RETRIES_COUNT}; \
			rm -f ${RETRIES_COUNT}.lock) \
                      >(gawk -v YES="${YESEXPR}" -v BOO="${BOOEXPR}" -e '
                               BEGIN { yeses=0; booos=0; seq_booos=0 }
                               $0 ~ BOO { booos++; seq_booos++; next }
                               $0 ~ YES { yeses++; seq_booos=0;
                                            if (match( $NF, /[+*]+/ ) > 0)
                                               { yeses+=(RLENGTH-1) }
                                          }
                               END { print seq_booos " " booos " " yeses;
			             # zu Debugzwecken die Suchmuster, die angekommen sind, ausgeben
			             print BOO; print YES; }' >${BoooooS_COUNT} 2>/dev/null; \
				   rm -f ${BoooooS_COUNT}.lock) \
		| sed -Ee "${sed_Cut_YESmsg_after_hashvalue}" \
		| gawk -e "${detect_zm_hash_count}" \
		| grep -E -c "/s\s*$"
         )
while [[ -f ${FATAL_ERR_CNT}.lock || -f ${RETRIES_COUNT}.lock || -f ${BoooooS_COUNT}.lock ]]; do sleep .001; done
#exit
echo \$hashCount==$hashCount
echo \${FATAL_ERR_CNT}:
cat ${FATAL_ERR_CNT}
echo \${RETRIES_COUNT}:
cat ${RETRIES_COUNT}

read booos sum_booos sum_yeses <<<$(< ${BoooooS_COUNT})
echo $booos $sum_booos $sum_yeses

echo \${BoooooS_COUNT}:
cat ${BoooooS_COUNT}

touch ${temp_hash_sum}.lock
hashCount=$(cat ${BENCHLOGFILE} \
		| tail -n +$hash_line \
		| sed -Ee "${sed_Cut_YESmsg_after_hashvalue}" \
		| gawk -e "${detect_zm_hash_count}" \
		| grep -E -e "/s\s*$" \
		| tee >(gawk -v kBase=${k_base} -M -e "${prepare_hashes_for_bc}" \
                            | tee ${temp_hash_bc} \
			    | bc >${temp_hash_sum}; \
			rm -rf ${temp_hash_sum}.lock; ) \
		| wc -l \
         )
# Wir warten, bis die vom tee produzierten Prozesse vollständig fertig sind
while [[ -f ${temp_hash_sum}.lock ]]; do sleep .001; done

echo \$hashCount==$hashCount


exit

#declare -p YES_ACCEPTED_MSGs
#echo ${YESEXPR}
#YESEXPR='^ [[] OK [\]] '
BENCHLOGFILE=../GPU-c6467c28-be24-03ad-e7ea-9bc0e989488f/t-rex.log
BENCHLOGFILE=../GPU-c6467c28-be24-03ad-e7ea-9bc0e989488f/t-rex-hangup.log

# Langsames rantasten an die richtige Anzahl OKs
# Erschreckende Erkenntnis: Das mittels tee erstellte Duplikat ist wesentlich kürzer.
# Sobald der tee mit den unnamed Filehandles '>()' drin ist, ist die gaze Pipeline zu kurz und es kommen wesentlich weniger Zeilen durch.
# Alle in der enthaltenen Subshells sind dacon betroffen, auch die ERSTELLUNG DES Duplikats, des ersten tee nach dem cat !!!
# Damit ist die Anzahl am Ende wesentlich kleiner... und die in den Subprozessen ebenfalls zu klein.
#
# Das muss erst mal verdaut werden...
# Es sieht so aus als würde die ganze Pipeline an einem bestimmten Zeitpunkt gleichzeitig zusammenbrechen.

#    | tee BENCHLOGFILE.duplicate \

<<COMMENT
#COMMENT

# Das wird gefunden. Und das ist genau so in dem Array NOT_CONNECTED_MSGs[], das über join_pos() zu dem String CONEXPR gemacht wird
GREPEXPR="WARN: [[:alpha:] ]*\. Trying to reconnect\.\.\."
echo "${CONEXPR}"
GREPEXPR="${CONEXPR}"

# Das funktioniert:
cat ${BENCHLOGFILE} \
    | grep -E -c -e "${GREPEXPR}"
echo Status der Pipe: $?

cat ${BENCHLOGFILE} \
    | tee >(grep -E -c -e "${CONEXPR}" >${MINER}.retry; \
            rm -f ${MINER}.retry.lock ) \
    | wc -l

cat ${BENCHLOGFILE} \
    | wc -l
cat ${MINER}.retry

exit
COMMENT

# ACHTUNG: grep -m1 scheint der Böse zu sein. Der macht irgendwas schlimmes mit dem Input-Stream!
touch ${MINER}.retry.lock ${MINER}.booos.lock ${MINER}.overclock.lock
cat ${BENCHLOGFILE} \
    | tee >(grep -E -c -e "${CONEXPR}" >${MINER}.retry; \
            rm -f ${MINER}.retry.lock ) \
          >(gawk -v YES="${YESEXPR}" -v BOO="${BOOEXPR}" -e '
                                   BEGIN { yeses=0; booos=0; seq_booos=0 }
                                   $0 ~ BOO { booos++; seq_booos++; next }
                                   $0 ~ YES { yeses++; seq_booos=0;
                                               if (match( $NF, /[+*]+/ ) > 0)
                                                  { yeses+=(RLENGTH-1) }
                                            }
                                   END { print seq_booos " " booos " " yeses }' 2>/dev/null >${MINER}.booos; \
		rm -f ${MINER}.booos.lock ) \
	  >(grep -E -c -e "${OVREXPR}" >${MINER}.overclock; \
	    rm -f ${MINER}.overclock.lock) \
    | sed -Ee "${sed_Cut_YESmsg_after_hashvalue}" \
    | grep -E -e "/s\s*$" \
    | gawk -e "${detect_zm_hash_count}" \
    | wc -l \
	 >test/OK_only
echo Status der Pipe: $?
#while [[ -f ${MINER}.retry.lock || -f ${MINER}.booos.lock || -f ${MINER}.overclock.lock ]]; do sleep .1; done

cat test/OK_only
tail -n 1 ${BENCHLOGFILE}
echo BOOOS:
cat ${MINER}.booos
echo RETRIES:
cat ${MINER}.retry
echo OVERCLOCK-Probleme:
cat ${MINER}.overclock

# (/ 48186 13961)
exit

# Ermittlung der Einheit der gemessenen Hashwerte
cat ${BENCHLOGFILE} \
                   | sed -Ee "${sed_Cut_YESmsg_after_hashvalue}" \
		   | gawk -e "${detect_zm_hash_count}" \
		   | grep -E -m1 "/s\s*$" \
		   | gawk -e '/H\/s\s*$/ {print "H/s"; next}{print "Sol/s"}'
exit

cat ${BENCHLOGFILE} \
    | tee >(grep -E -c -e "${CONEXPR}" >${MINER}.retry; \
            rm -f ${MINER}.retry.lock ) \
          >(gawk -v YES="${YESEXPR}" -v BOO="${BOOEXPR}" -e '
                                   BEGIN { yeses=0; booos=0; seq_booos=0 }
                                   $0 ~ BOO { booos++; seq_booos++; next }
                                   $0 ~ YES { yeses++; #seq_booos=0;
                                               if (match( $NF, /[+*]+/ ) > 0)
                                                  { yeses+=(RLENGTH-1) }
                                            }
                                   END { print seq_booos " " booos " " yeses }' 2>/dev/null >${MINER}.booos; \
		rm -f ${MINER}.booos.lock ) \
	  >(grep -E -c -e "${OVREXPR}" >${MINER}.overclock; \
	    rm -f ${MINER}.overclock.lock) \
	  | sed -Ee "${sed_Cut_YESmsg_after_hashvalue}" \
	  | gawk -e "${detect_zm_hash_count}" \
	  | grep -E -c "/s\s*$"

# Output: 8591
# 8744
exit

hash_line=1
temp_hash_bc="test/temp_hash_bc_input"
#temp_avgs_bc="test/temp_avgs_bc_input"
temp_hash_sum="test/temp_hash_sum"
#temp_watt_sum="test/temp_watt_sum"

# Das klappt schon mal
cat ${BENCHLOGFILE} \
              | tail -n +$hash_line \
              | sed -Ee "${sed_Cut_YESmsg_after_hashvalue}" \
              | grep -E -e "/s\s*$" \
              | tee >(gawk -v kBase=${k_base} -M -e "${prepare_hashes_for_bc}" \
                             | tee ${temp_hash_bc} | bc >${temp_hash_sum} ) \
              | wc -l
exit
