#!/bin/bash

[[ ${#_GLOBALS_INCLUDED} -eq 0     ]] && source ../globals.inc
[[ ${#_LOGANALYSIS_INCLUDED} -eq 0 ]] && source ../logfile_analysis.inc

SYNCFILE="${LINUX_MULTI_MINING_ROOT}/you_can_read_now.sync"
#touch -t 05090705.00 ${SYNCFILE}

if [ 1 -eq 1 ]; then
#    m_time=$(stat -c "%Y.%y" ${SYNCFILE})
#    echo $m_time
#    m_time=$(find ${SYNCFILE} -printf "%T@")
#    echo $m_time
#    m_time=$(date --reference=${SYNCFILE} "+%s %N")
#    echo $m_time

    m_time=$(stat -c "%Y.%y" ${SYNCFILE})
    _modified_time_=${m_time%%.*}
    _fraction_=${m_time##*.}
    _fraction_=${_fraction_%% *}
    echo $_modified_time_ $_fraction_

    read _modified_time_ _fraction_ <<<$(date --reference=${SYNCFILE} "+%s %N")
    echo $_modified_time_ $_fraction_

    read _modified_time_ _fraction_ <<<$(date -r ${SYNCFILE} "+%s %N")
    echo $_modified_time_ $_fraction_

    [ $_fraction_ -eq 0 ] && echo NULL || echo NOT NULL
    exit
fi

durchgaenge=1
while ((durchgaenge--)); do
    COUNT=1000 #0000

    count=${COUNT}
    rm -f .test.out
    { time while ((count--)); do

	# Put your code to test BELOW this line

	read _modified_time_ _fraction_ <<<$(date -r ${SYNCFILE} "+%s %N")

	# Put your code to test ABOVE this line

    done ; } >.test.out 2>&1
    until [ -s .test.out ]; do sleep .01; done

    read muck good rest <<<$(cat .test.out | grep -m1 "^real")
    good=${good//,/.}
    minutes=${good%m*}
    seconds=${good#*m}
    seconds=${seconds%s}
    echo "scale=4; sekunden=${minutes}*60 + ${seconds}; print sekunden, \"\n\"" | bc | tee .test.1

    count=${COUNT}
    rm -f .test.out
    { time while ((count--)); do

	# Put your code to test BELOW this line

	read _modified_time_ _fraction_ <<<$(date --reference=${SYNCFILE} "+%s %N")

	# Put your code to test ABOVE this line

    done ; } >.test.out 2>&1
    until [ -s .test.out ]; do sleep .01; done

    read muck good rest <<<$(cat .test.out | grep -m1 "^real")
    good=${good//,/.}
    minutes=${good%m*}
    seconds=${good#*m}
    seconds=${seconds%s}
    echo "scale=4; sekunden=${minutes}*60 + ${seconds}; print sekunden, \"\n\"" | bc | tee .test.2

    echo 'scale=2; print "Das Verhältnis von Test1 zu Test2 beträgt ", '$(< .test.1)'/'$(< .test.2)'*100, " %\n"' | bc

    sleep .1
done

rm -f .test.*
exit

################################################################################
###
### 2021-05-06 08:50
###
### Vergleich der BENCHLOGFILE-Auswertung mit und ohne vorgeschaltetes grep
###
################################################################################

miner_name=miniZ
miner_version=1.7x3
MINER=${miner_name}#${miner_version}
BENCHLOGFILE="../miners/miniz-ethash-test.log"
BENCHLOGFILE="../miners/miniZ-zhash-test.log"

# Aufbau ohne grep
detect_miniZ_hash_count='BEGIN { hash=6 }
match( $0, /S:.*[]][*].*(Sol|H)\/s/ ) {
   S1 = substr( $0, RSTART, RLENGTH )
   SN = split( S1, SA )
   if (match( SA[ SN ], /\([[:digit:].]+\)(Sol|H)\/s/ )) {
       M = substr( SA[ SN ], RSTART+1, RLENGTH )
       speed   = substr( M, 1, index(M,")")-1 )
       einheit = substr( SA[ SN ], index( SA[ SN ], ")" )+1 )
       shares  = substr( SA[ 2 ], 1, index(SA[ 2 ],"/")-1 )
       }
   }
END { print shares " " speed " " einheit }
'
	cat ${BENCHLOGFILE} \
	| gawk -e "${detect_miniZ_hash_count}"
	    

# Aufbau mit grep
detect_miniZ_hash_count='BEGIN { hash=2 }
match( $0, /\([[:digit:].]+\)(Sol|H)\/s/ ) {
       M = substr( $0, RSTART+1, RLENGTH )
       speed   = substr( M, 1, index(M,")")-1 )
       einheit = substr( $NF, index( $NF, ")" )+1 )
       shares  = substr( $hash, 1, index($hash,"/")-1 )
       }
END { print shares " " speed " " einheit }
'

	cat ${BENCHLOGFILE} \
	| grep -E -o 'S:.*\]\*.*(Sol|H)\/s' \
	| gawk -e "${detect_miniZ_hash_count}"
	    
# Ergebnis mit grep oben. 5 Durchläufe a 10000 Schleifen
60.940
55.177
Das Verhältnis von Test1 zu Test2 beträgt 110.00 %
108.633
55.496
Das Verhältnis von Test1 zu Test2 beträgt 195.00 %
108.761
55.566
Das Verhältnis von Test1 zu Test2 beträgt 195.00 %
108.896
55.790
Das Verhältnis von Test1 zu Test2 beträgt 195.00 %
108.976
55.613
Das Verhältnis von Test1 zu Test2 beträgt 195.00 %

# Ergebnis mit grep unten. 5 Durchläufe a 10000 Schleifen
54.367
109.075
Das Verhältnis von Test1 zu Test2 beträgt 49.00 %
55.784
109.204
Das Verhältnis von Test1 zu Test2 beträgt 51.00 %
55.832
108.893
Das Verhältnis von Test1 zu Test2 beträgt 51.00 %
55.891
109.366
Das Verhältnis von Test1 zu Test2 beträgt 51.00 %
55.989
109.269
Das Verhältnis von Test1 zu Test2 beträgt 51.00 %
