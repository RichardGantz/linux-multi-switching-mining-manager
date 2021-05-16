#!/bin/bash

[[ ${#_GLOBALS_INCLUDED} -eq 0     ]] && source ../globals.inc
[[ ${#_LOGANALYSIS_INCLUDED} -eq 0 ]] && source ../logfile_analysis.inc

# Welche Methode zum push auf ein Array ist schneller?
# arr+=( $x ) oder arr[${#arr[@]}]=$x ?

gpu_idx=999

durchgaenge=10
while ((durchgaenge--)); do
    COUNT=1000000 #0000

    unset SwitchNotGPUs
    count=${COUNT}
    rm -f .test.out
    { time while ((count--)); do

	# Put your code to test BELOW this line

	SwitchNotGPUs+=( ${gpu_idx} )
	SwitchNotGPUs+=( ${gpu_idx} )
	SwitchNotGPUs+=( ${gpu_idx} )
	SwitchNotGPUs+=( ${gpu_idx} )
	SwitchNotGPUs+=( ${gpu_idx} )
	SwitchNotGPUs+=( ${gpu_idx} )
	SwitchNotGPUs+=( ${gpu_idx} )
	SwitchNotGPUs+=( ${gpu_idx} )
	SwitchNotGPUs+=( ${gpu_idx} )
	SwitchNotGPUs+=( ${gpu_idx} )

	# Put your code to test ABOVE this line

    done ; } >.test.out 2>&1
    until [ -s .test.out ]; do sleep .01; done

    read muck good rest <<<$(cat .test.out | grep -m1 "^real")
    good=${good//,/.}
    minutes=${good%m*}
    seconds=${good#*m}
    seconds=${seconds%s}
    echo "scale=4; sekunden=${minutes}*60 + ${seconds}; print sekunden, \"\n\"" | bc | tee .test.1

    unset SwitchNotGPUs
    count=${COUNT}
    rm -f .test.out
    { time while ((count--)); do

	# Put your code to test BELOW this line

        SwitchNotGPUs[${#SwitchNotGPUs[@]}]=${gpu_idx}
        SwitchNotGPUs[${#SwitchNotGPUs[@]}]=${gpu_idx}
        SwitchNotGPUs[${#SwitchNotGPUs[@]}]=${gpu_idx}
        SwitchNotGPUs[${#SwitchNotGPUs[@]}]=${gpu_idx}
        SwitchNotGPUs[${#SwitchNotGPUs[@]}]=${gpu_idx}
        SwitchNotGPUs[${#SwitchNotGPUs[@]}]=${gpu_idx}
        SwitchNotGPUs[${#SwitchNotGPUs[@]}]=${gpu_idx}
        SwitchNotGPUs[${#SwitchNotGPUs[@]}]=${gpu_idx}
        SwitchNotGPUs[${#SwitchNotGPUs[@]}]=${gpu_idx}
        SwitchNotGPUs[${#SwitchNotGPUs[@]}]=${gpu_idx}

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
<<RESULT1
Oben:  SwitchNotGPUs[${#SwitchNotGPUs[@]}]=${gpu_idx}
Unten: SwitchNotGPUs+=( ${gpu_idx} )

53.332
51.923
Das Verhältnis von Test1 zu Test2 beträgt 102.00 %
53.048
51.759
Das Verhältnis von Test1 zu Test2 beträgt 102.00 %
53.020
51.836
Das Verhältnis von Test1 zu Test2 beträgt 102.00 %
53.055
52.071
Das Verhältnis von Test1 zu Test2 beträgt 101.00 %
52.886
52.011
Das Verhältnis von Test1 zu Test2 beträgt 101.00 %
52.455
51.774
Das Verhältnis von Test1 zu Test2 beträgt 101.00 %
52.926
52.042
Das Verhältnis von Test1 zu Test2 beträgt 101.00 %
52.697
51.574
Das Verhältnis von Test1 zu Test2 beträgt 102.00 %
52.501
51.961
Das Verhältnis von Test1 zu Test2 beträgt 101.00 %
52.299
52.012
Das Verhältnis von Test1 zu Test2 beträgt 100.00 %
RESULT1

<<RESULT2
Oben:  SwitchNotGPUs+=( ${gpu_idx} )
Unten: SwitchNotGPUs[${#SwitchNotGPUs[@]}]=${gpu_idx}

52.148
53.200
Das Verhältnis von Test1 zu Test2 beträgt 98.00 %
51.255
53.443
Das Verhältnis von Test1 zu Test2 beträgt 95.00 %
51.567
53.230
Das Verhältnis von Test1 zu Test2 beträgt 96.00 %
51.626
53.155
Das Verhältnis von Test1 zu Test2 beträgt 97.00 %
51.370
53.411
Das Verhältnis von Test1 zu Test2 beträgt 96.00 %
51.491
53.007
Das Verhältnis von Test1 zu Test2 beträgt 97.00 %
51.478
52.948
Das Verhältnis von Test1 zu Test2 beträgt 97.00 %
51.469
53.663
Das Verhältnis von Test1 zu Test2 beträgt 95.00 %
51.433
53.323
Das Verhältnis von Test1 zu Test2 beträgt 96.00 %
51.320
53.053
Das Verhältnis von Test1 zu Test2 beträgt 96.00 %
RESULT2
exit

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
