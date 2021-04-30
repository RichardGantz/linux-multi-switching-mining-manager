#!/bin/bash

TREXLOGPATH="home/avalon/miner/t-rex"
[ "$(uname -n)" == "mining" ] && TREXLOGPATH="/${TREXLOGPATH}"

miner_device=8
coin=octopus

miner_name=t-rex
miner_version=0.19.14
gpu_idx=9
miner_device=7
coin=daggerhashimoto

rm t-rex-012345679-${coin}-[1619420865].log.diffs
for miner_device in 0 1 2 3 4 5 6 7 9; do
#for miner_device in 9; do
BENCHLOGFILE="/home/avalon/miner/t-rex/t-rex-"${miner_device}"-"${coin}"-[1619420865].log"
DiffCheckFILE="/home/avalon/miner/t-rex/t-rex-"${miner_device}"-"${coin}"-[1619420865].log.diffs"

[ "${coin}" == "daggerhashimoto" ] \
    && \
    cat ${BENCHLOGFILE} \
	| gawk -e 'BEGIN { lastDiff=0; OKs=0; ShAvg=0; seconds=0; wdseconds=0; last_up_sec=0; last_wd_sec=0; }
/ethash epoch:/ {
	actDiff=$(NF-1); if ($NF=="G") { actDiff*=1000 }
	if (actDiff != lastDiff ) {
	   if ( lastDiff > 0 ) {
	      print "WDtime: " wdseconds " Sekunden, " ShAvg " OKs/min"
	      # Ist nicht ganz sauber, aber besser werden wir das nicht unbedingt hinbekommen.
	      # Die wdseconds sind die letzte Zeitangabe vor dem neu erscheinenden Diff und den bis dahin kommenden OKs.
	      # Die OKs werden ja gezählt und deren Anzahl ist akkurat.
	      # Aber dann tritt der neue diff auf und wir haben nur den "veralteten" Zeitstempel, den wir jetzt zur Messung des Durchschnitts heranziehen.
	      secs[ lastDiff ] = secs[ lastDiff ] + wdseconds - last_wd_sec
	      last_wd_sec = wdseconds
	      printf "Diff %8.2f: %6i OKs von insgesamt %6i OKs, Laufzeit %6is, Durchschnitt bisher: %7.3f/min\n\n",
	      	      lastDiff, allOKs[lastDiff], OKs, secs[lastDiff], allOKs[lastDiff]/secs[lastDiff]*60
	   }
	   #print "New Diff: " actDiff;
	}
	lastDiff = actDiff;
	next
    }
/Shares\/min:.*Avr\./ {
	ShAvg = substr( $NF, 1, length($NF)-1 )
	next
    }
match( $0, /Uptime: [[:digit:]]+ [^|]*\|/ ) \
    {  M=substr($0, RSTART+8, RLENGTH-10);
       seconds = 0;
       if ( match( M, /([[:digit:]]+) days?/,  d ) ) { seconds += d[1]*86400 }
       if ( match( M, /([[:digit:]]+) hours?/, h ) ) { seconds += h[1]*3600 }
       if ( match( M, /([[:digit:]]+) mins?/,  m ) ) { seconds += m[1]*60 }
       if ( match( M, /([[:digit:]]+) secs?/,  s ) ) { seconds += s[1] }
       #       print "Uptime: " seconds " Sekunden, " ShAvg " OKs/min"
       getline
       if (match( $0, /^WD: [[:digit:]]+ [^,]*,/ )) {
       	      M=substr($0, RSTART+3, RLENGTH-4);
	      wdseconds = 0;
	      if ( match( M, / ([[:digit:]]+) days?/,  d ) ) { wdseconds += d[1]*86400 }
	      if ( match( M, / ([[:digit:]]+) hours?/, h ) ) { wdseconds += h[1]*3600 }
	      if ( match( M, / ([[:digit:]]+) mins?/,  m ) ) { wdseconds += m[1]*60 }
	      if ( match( M, / ([[:digit:]]+) secs?/,  s ) ) { wdseconds += s[1] }
	      #	      print "WDtime: " wdseconds " Sekunden, " ShAvg " OKs/min"
	      }
       next
    }
/\[ OK \] / {
       ++allOKs[ actDiff ]
       ++OKs
       # print actDiff ": " allOKs[ actDiff ] " OKs von insgesamt " OKs " OKs"
    }
END {
    print "Vom Miner ermittelter und regelmäßig ausgegebener Gesamtdurchschnitt: " wdseconds " Sekunden, " ShAvg " OKs/min"
    PROCINFO["sorted_in"]="@ind_num_asc"
    for ( diff in allOKs ) {
        printf "Diff %8.2f: %6i OKs von insgesamt %6i OKs, Laufzeit %6is, Durchschnitt für diesen Diff: %7.3f/min\n",
	        diff, allOKs[diff], OKs, secs[diff], allOKs[diff]/secs[diff]*60
    }
}
' > ${DiffCheckFILE} \
	|| echo "${coin} not yet implented."

echo -e "\n"${DiffCheckFILE} | tee -a t-rex-012345679-${coin}-[1619420865].log.diffs
tail -10 ${DiffCheckFILE} | grep -A10 "^Vom Miner" | tee -a t-rex-012345679-${coin}-[1619420865].log.diffs
done

exit

# Die Entwicklung der "Shares/min"
#for miner_device in 0 1 2 3 4 5 6 7 9; do
    BENCHLOGFILE="/home/avalon/miner/t-rex/t-rex-"${miner_device}"-"${coin}"-[1619420865].log"
    echo ${BENCHLOGFILE}
    grep "^Shares/min:" ${BENCHLOGFILE}
#done

exit

# Erstes Auftreten von "Uptime:"
for miner_device in 0 1 2 3 4 5 6 7 9; do
    BENCHLOGFILE="/home/avalon/miner/t-rex/t-rex-"${miner_device}"-"${coin}"-[1619420865].log"
    echo ${BENCHLOGFILE}
    grep -B20 -m1 "^Uptime: " ${BENCHLOGFILE}
done

exit

BENCHLOGFILE="/home/avalon/miner/t-rex/t-rex-"${miner_device}"-"${coin}"-[1619420865].log"
grep -A1 "^Uptime: " ${BENCHLOGFILE}

exit

# Der folgende Test zeigt, dass die beiden Zeilen "Uptime:" und "WD" nahezu immer zusammen auftreten.
# Am Anfang kann es vorkommen, dass nur eine "Uptime" ohne ein "WD" vorhanden ist.
# Das "WD" wird erst nach wenigstens einem erfolgreichen [ OK ] ausgegeben.
# Das kan uns etwas über die Initialisierungszeit sagen.
for miner_device in 0 1 2 3 4 5 6 7 9; do
    BENCHLOGFILE="/home/avalon/miner/t-rex/t-rex-"${miner_device}"-"${coin}"-[1619420865].log"
    echo ${BENCHLOGFILE}
    diff <(grep -A1 "^Uptime: " ${BENCHLOGFILE}) <(grep -B1 "^WD: " ${BENCHLOGFILE})
done

exit

BENCHLOGFILE="/home/avalon/miner/t-rex/t-rex-0-daggerhashimoto-[1619420865].log"
<<COMMENT
Diff: 851.74, 22 Umschaltungen
Diff: 425.87, 27 Umschaltungen
Diff: 858.99, 482 Umschaltungen
Diff: 429.50, 658 Umschaltungen
Diff: 214.75, 33 Umschaltungen
Bei 1222 Zeilen
COMMENT
#BENCHLOGFILE="/home/avalon/miner/t-rex/t-rex-1-daggerhashimoto-[1619420865].log"
<<COMMENT
Diff: 851.74, 159 Umschaltungen
Diff: 1.72, 1 Umschaltungen
Diff: 425.87, 170 Umschaltungen
Diff: 858.99, 244 Umschaltungen
Diff: 429.50, 300 Umschaltungen
Diff: 214.75, 29 Umschaltungen
Bei 903 Zeilen
COMMENT
#BENCHLOGFILE="/home/avalon/miner/t-rex/t-rex-2-daggerhashimoto-[1619420865].log"
<<COMMENT
Diff: 851.74, 112 Umschaltungen
Diff: 425.87, 144 Umschaltungen
Diff: 858.99, 411 Umschaltungen
Diff: 429.50, 520 Umschaltungen
Diff: 214.75, 38 Umschaltungen
Bei 1225 Zeilen
COMMENT
#BENCHLOGFILE="/home/avalon/miner/t-rex/t-rex-3-daggerhashimoto-[1619420865].log"
<<COMMENT
Diff: 851.74, 152 Umschaltungen
Diff: 1.72, 1 Umschaltungen
Diff: 425.87, 174 Umschaltungen
Diff: 858.99, 308 Umschaltungen
Diff: 429.50, 368 Umschaltungen
Diff: 214.75, 43 Umschaltungen
Bei 1046 Zeilen
COMMENT
#BENCHLOGFILE="/home/avalon/miner/t-rex/t-rex-4-daggerhashimoto-[1619420865].log"
#BENCHLOGFILE="/home/avalon/miner/t-rex/t-rex-5-daggerhashimoto-[1619420865].log"
<<COMMENT
Diff: 851.74, 152 Umschaltungen
Diff: 1.72, 1 Umschaltungen
Diff: 425.87, 174 Umschaltungen
Diff: 858.99, 308 Umschaltungen
Diff: 429.50, 368 Umschaltungen
Diff: 214.75, 43 Umschaltungen
Bei 1046 Zeilen
COMMENT
#BENCHLOGFILE="/home/avalon/miner/t-rex/t-rex-6-daggerhashimoto-[1619420865].log"
<<COMMENT
Diff: 851.74, 41 Umschaltungen
Diff: 1.72, 6 Umschaltungen
Diff: 425.87, 61 Umschaltungen
Diff: 858.99, 450 Umschaltungen
Diff: 429.50, 544 Umschaltungen
Diff: 214.75, 35 Umschaltungen
Bei 1137 Zeilen
COMMENT
#BENCHLOGFILE="/home/avalon/miner/t-rex/t-rex-7-daggerhashimoto-[1619420865].log"
<<COMMENT
Diff: 851.74, 53 Umschaltungen
Diff: 1.72, 4 Umschaltungen
Diff: 425.87, 53 Umschaltungen
Diff: 858.99, 482 Umschaltungen
Diff: 429.50, 648 Umschaltungen
Diff: 214.75, 52 Umschaltungen
Bei 1292 Zeilen
COMMENT
#BENCHLOGFILE="/home/avalon/miner/t-rex/t-rex-8-octopus-[1619420865].log"
#BENCHLOGFILE="/home/avalon/miner/t-rex/t-rex-9-daggerhashimoto-[1619420865].log"
<<COMMENT
Diff: 851.74, 10 Umschaltungen
Diff: 425.87, 17 Umschaltungen
Diff: 858.99, 83 Umschaltungen
Diff: 429.50, 725 Umschaltungen
Diff: 214.75, 311 Umschaltungen
Bei 1146 Zeilen
COMMENT

grep "^ ethash epoch:" ${BENCHLOGFILE} \
    | gawk -e 'BEGIN { rows=0; }
{ diff[ $(NF-1) ]++; rows++ }
END { for ( d in diff ) { print "Diff: " d ", " diff[ d ] " Umschaltungen"; }
print "Bei " rows " Zeilen" }
'
exit

# Durchschnittswerte für eventuelle manuelle Eintragung ins .json File
grep -B2 -A1 "^Uptime:" ${BENCHLOGFILE} \
    | gawk -e 'BEGIN { wattCnt=0; wattSum=0; rows=0; }
match( $0, / P:[[:digit:]]+W, / ) \
     { M=substr($0, RSTART, RLENGTH); wattSum = wattSum + substr( M, index(M,":")+1, RLENGTH-6 ); wattCnt++; next }
match( $0, /^WD: [[:digit:]]+ [^,]*,/ ) \
     { M=substr($0, RSTART+3, RLENGTH-4); rows++;
       seconds = 0;
       if ( match( M, / ([[:digit:]]+) days?/,  d ) ) { seconds += d[1]*86400 }
       if ( match( M, / ([[:digit:]]+) hours?/, h ) ) { seconds += h[1]*3600 }
       if ( match( M, / ([[:digit:]]+) mins?/,  m ) ) { seconds += m[1]*60 }
       if ( match( M, / ([[:digit:]]+) secs?/,  s ) ) { seconds += s[1] }
       shares = substr( $NF, 1, index( $NF, "/" )-1 )
       next
     }
END { print "Summe Wattwerte: " wattSum ", Anzahl Wattwerte: " wattCnt ", Durchschnitt: " wattSum / wattCnt "W, Rows: " rows ", Gesamtzeit: " seconds "s, Shares: " shares }
'
