#!/bin/bash

[[ ${#_GLOBALS_INCLUDED} -eq 0     ]] && source ../globals.inc
[[ ${#_LOGANALYSIS_INCLUDED} -eq 0 ]] && source ../logfile_analysis.inc

miner_name=miner
miner_version=2.51
MINER=${miner_name}#${miner_version}
if [ "$(uname -n)" == "mining-2" ]; then
    BENCHLOGFILE="/home/avalon/lmms/GPU-2c54bba2-342f-d409-3e22-fc70f37bb2d7/benchmarking/miner#2.51/cuckatoo32/NoBenchStarted_20210528_203050_benchmark.log"
#    BENCHLOGFILE="/home/avalon/lmms/GPU-2c54bba2-342f-d409-3e22-fc70f37bb2d7/benchmarking/miner#2.51/cuckatoo31/NoBenchStarted_20210527_174128_benchmark.log"
#    BENCHLOGFILE="/home/avalon/lmms/GPU-2c54bba2-342f-d409-3e22-fc70f37bb2d7/benchmarking/miner#2.51/beamhash/NoBenchStarted_20210528_203258_benchmark.log"
#    BENCHLOGFILE="/home/avalon/lmms/GPU-2c54bba2-342f-d409-3e22-fc70f37bb2d7/benchmarking/miner#2.51/beamhash/NoBenchStarted_20210527_215442_benchmark.log"
#    BENCHLOGFILE="/home/avalon/miner/gminer/gpu-test.log"
#    BENCHLOGFILE="/home/avalon/lmms/GPU-2c54bba2-342f-d409-3e22-fc70f37bb2d7/benchmarking/miniZ#1.7x3/ethash/NoBenchStarted_20210528_162304_benchmark.log"
else
    #mining
    BENCHLOGFILE="/mnt/avalon/lmms/GPU-2c54bba2-342f-d409-3e22-fc70f37bb2d7/benchmarking/miniZ#1.7x3/ethash/NoBenchStarted_20210528_162304_benchmark.log"
fi
#cat ${BENCHLOGFILE}
hash_line=1

FATAL_ERR_CNT="${MINER}.FATAL"
RETRIES_COUNT="${MINER}.retry"
BoooooS_COUNT="${MINER}.booos"

# "mining-2" Output
# cuckatoo32
# '+---+-------+----+-----+---------+--------+------+----+-----+-----+-----------+
# '| ID   GPU   Temp  Fan    Speed   Fidelity Shares Core  Mem  Power Efficiency |
# '+---+-------+----+-----+---------+--------+------+----+-----+-----+-----------+
# '|  1  1080Ti 71 C  48 %  0.64 G/s     0.00    0/0 1809  5005 274 W  2.34 G/mW |
# '+---+-------+----+-----+---------+--------+------+----+-----+-----+-----------+
# beamhash
# '+---+-------+----+-----+-----------+------+----+-----+-----+-----------+
# '| ID   GPU   Temp  Fan     Speed    Shares Core  Mem  Power Efficiency |
# '+---+-------+----+-----+-----------+------+----+-----+-----+-----------+
# '|  1  1080Ti 72 C  51 %  28.6 Sol/s    3/0 1911  5005 285 W 0.10 Sol/W |
# '+---+-------+----+-----+-----------+------+----+-----+-----+-----------+
# "mining" Output
# ethash
# '|  1 Unknown  N/A 0 %  22.07 MH/s  0/0/0    0   0   N/A        N/A |

#echo ${FATAL_ERR_CNT}.lock ${RETRIES_COUNT}.lock ${BoooooS_COUNT}.lock

#    touch ${FATAL_ERR_CNT}.lock ${RETRIES_COUNT}.lock ${BoooooS_COUNT}.lock
	    hashCount=$(cat ${BENCHLOGFILE} \
		| tail -n +$hash_line \
		| tee >(grep -E -c -m1 -e "${ERREXPR}" >${FATAL_ERR_CNT}; \
			rm -f ${FATAL_ERR_CNT}.lock) \
		      >(grep -E -c -m1 -e "${CONEXPR}" >${RETRIES_COUNT}; \
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
 #   while [[ -f ${FATAL_ERR_CNT}.lock || -f ${RETRIES_COUNT}.lock || -f ${BoooooS_COUNT}.lock ]]; do sleep .001; done
#		| grep -E -c "/s\s*$"
#		| sed -Ee "${sed_Cut_YESmsg_after_hashvalue}" \

    echo $hashCount
    cat ${BoooooS_COUNT}
    exit

    hashCount=$(cat ${BENCHLOGFILE} \
		    | gawk -e "${detect_zm_hash_count}" \
		    | grep -E -c "/s\s*$"
             )
    exit
    
miner_name=miniZ
miner_version=1.7x3
MINER=${miner_name}#${miner_version}
BENCHLOGFILE="../miners/miniZ-zhash-test.log"
BENCHLOGFILE="../miners/miniz-ethash-test.log"
BENCHLOGFILE="../miners/miniz-beamhash-test.log"
#BENCHLOGFILE="../miners/miniz-equihash-test.log" # <--- Hat gerechnet, aber in 12 Minuten keinen einzigen Share abgeliefert. Muss die 320s Regel greifen!
#BENCHLOGFILE="../miners/miniz-kawpow-test.log"
BENCHLOGFILE="../miners/miniZ-6.log"
# mining-2
if [ "$(uname -n)" == "mining-2" ]; then
    BENCHLOGFILE="/home/avalon/lmms/GPU-2c54bba2-342f-d409-3e22-fc70f37bb2d7/benchmarking/miniZ#1.7x3/ethash/NoBenchStarted_20210528_162304_benchmark.log"
else
    #mining
    BENCHLOGFILE="/mnt/avalon/lmms/GPU-2c54bba2-342f-d409-3e22-fc70f37bb2d7/benchmarking/miniZ#1.7x3/ethash/NoBenchStarted_20210528_162304_benchmark.log"
fi
#cat ${BENCHLOGFILE}

# [ 0d 0h18m30s] S: 97/1/0 0>RTX 3070  100% [0.C/ 0%]* 61.87(56.98)MH/s   0(  0.0)W clk=1815MHz mclk=7001MHz MH/W=inf
# [INFO   ] Target set to 00000004F784BD45 (864.72M)
# [ 0d 0h18m40s] S:101/1/0 0>RTX 3070  100% [0.C/ 0%]* 62.26(57.11)MH/s   0(  0.0)W clk=1815MHz mclk=7001MHz MH/W=inf
# [ 0d 1h13m30s] S:448/15/4 0>RTX 3070 99.1% [0.C/ 0%]* 62.15(61.88)MH/s   0(  0.0)W clk=1815MHz mclk=7001MHz MH/W=inf

# mining-2 erster Benchmark-Lauf
# [ 0d 0h 1m20s] S:  0/0/0 0>GTX 1080 Ti  100% [44.C/87%]  32.11(32.11)MH/s 192(191.4)W clk=1974MHz mclk=5005MHz MH/W=0.17
# [ 0d 0h 1m30s] S:  1/0/0 0>GTX 1080 Ti  100% [45.C/87%]* 32.26(32.26)MH/s 192(191.6)W clk=1974MHz mclk=5005MHz MH/W=0.17
# [ 0d 0h 1m40s] S:  3/0/0 0>GTX 1080 Ti  100% [45.C/86%]* 32.39(32.39)MH/s 193(191.9)W clk=1974MHz mclk=5005MHz MH/W=0.17
# [ 0d 0h 1m50s] S:  3/0/0 0>GTX 1080 Ti  100% [45.C/90%]  32.57(32.57)MH/s 193(192.1)W clk=1974MHz mclk=5005MHz MH/W=0.17

detect_miniZ_hash_count='BEGIN { yeses=0; booos=0; seq_booos=0; last_shares=0 }
/[[]WARNING[]] (Bad|Stale) share:/ { booos++; seq_booos++; next }
match( $0, /S:.*[]][*].*(Sol|H)\/s/ ) {
   yeses++; seq_booos=0;
   S1 = substr( $0, RSTART+2, RLENGTH-2 )
   SN = split( S1, SA )
   if (match( SA[ SN ], /\([[:digit:].]+\).*(Sol|H)\/s/ )) {
       M = substr( SA[ SN ], RSTART+1, RLENGTH );
       speed   = substr( M, 1, index(M,")")-1 )
       einheit = substr( SA[ SN ], index( SA[ SN ], ")" )+1 )
       shares  = substr( SA[ 1 ], 1, index(SA[ 1 ],"/")-1 )
       if (length(_BC_)) {
       	  delta = shares - last_shares
	  last_shares = shares
	  print delta "*" speed " " einheit
       } else if (length(EINHEIT)) {
       	      if (einheit ~ /H\/s\s*$/) {einheit = "H/s"; exit}
	      einheit = "Sol/s"
       	      exit
	 }
   }
}
END {
    if (length(BOOFILE)) print seq_booos " " booos " >" yeses >BOOFILE
    if (length(_BC_)==0) print shares " " speed " " einheit
}
'
BOOFILE_for_GWAK=${MINER}.booos
rm ${BOOFILE_for_GWAK}

read hashCount speed einheit <<<$(
    cat ${BENCHLOGFILE} \
	| gawk -v BOOFILE="${BOOFILE_for_GWAK}" -e "${detect_miniZ_hash_count}" \
     )
echo ${hashCount} ${speed} ${einheit}
cat ${BOOFILE_for_GWAK}
exit






rm -f ${MINER}.fatal_err.lock ${MINER}.retry.lock ${MINER}.booos.lock ${MINER}.overclock.lock \
   ${BOOFILE_for_GWAK} \
   ${temp_hash_bc} ${temp_hash_sum}

exit

read hashCount speed einheit <<<$(cat ${BENCHLOGFILE} \
	| tee >(gawk -v _BC_="1" -M -e "${detect_miniZ_hash_count}" \
		    | gawk -v kBase=${k_base} -M -e "${prepare_hashes_for_bc}" \
		    | tee ${temp_hash_bc} \
		    | bc >${temp_hash_sum}; \
	      rm -rf ${temp_hash_sum}.lock; ) \
	| gawk -v BOOFILE="${BOOFILE_for_GWAK}" -e "${detect_miniZ_hash_count}" \
	)

cat ${temp_hash_bc}
cat ${temp_hash_sum}

hashSum=$(< ${temp_hash_sum})
echo "scale=2; \
              avghash     = $hashSum / $hashCount;     \
              print avghash, \" \", avgwatt, \" \", quotient, \" \", hashpersecs" | bc


temp_hash_bc="_temp_hash_bc_input"
temp_hash_sum="_temp_hash_sum"
BOOFILE_for_GWAK=

		read hashCount speed temp_einheit <<<$(cat ${BENCHLOGFILE} \
			| gawk -v EINHEIT="1" -e "${detect_miniZ_hash_count}" \
		     )

echo ${hashCount} ${speed} ${temp_einheit}
exit

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

# LÄUFT NOCH NICHT !!!
# Bitte die Schleifengeschwindigkeit testen for in vs. for ((
cat ${LINUX_MULTI_MINING_ROOT}/GLOBAL_ALGO_DISABLED | grep -E -v -e '^#|^$' | readarray -n 0 -O 0 -t GLOBAL_ALGO_DISABLED_ARR
declare -p GLOBAL_ALGO_DISABLED_ARR
for ((i=0; i<${#GLOBAL_ALGO_DISABLED_ARR[@]}; i++)) ; do

    unset disabled_algos_GPUs
    read -a disabled_algos_GPUs <<<${GLOBAL_ALGO_DISABLED_ARR[$i]//:/ }
    DisAlgo=${disabled_algos_GPUs[0]}
    if [ ${#disabled_algos_GPUs[@]} -gt 1 ]; then
        # Nur für bestimmte GPUs disabled. Wenn die eigene GPU nicht aufgeführt ist, übergehen
        [[ ! ${GLOBAL_ALGO_DISABLED_ARR[$i]} =~ ^.*:${gpu_uuid} ]] && unset DisAlgo
    fi
    if [ -n "${DisAlgo}" ]; then
        for ccoin in ${!actMiningAlgos[@]}; do
            [ "${actMiningAlgos[$ccoin]}" == "${DisAlgo}" ] && unset actMiningAlgos[$ccoin]
        done
        for a in ${!actMissingAlgos[@]}; do
            if [ "${actMissingAlgos[$a]}" == "${DisAlgo}" ]; then
                unset actMissingAlgos[$a]
                # Es konnte nur einen Eintrag mit diesem Ccoin geben, deshalb um der Performance willen Abbruch der Schleife
                break
            fi
        done
        disd_msg+=( "---> Algo ${DisAlgo} wegen des Vorhandenseins in der Datei GLOBAL_ALGO_DISABLED herausgenommen." )
    fi
done

exit

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
