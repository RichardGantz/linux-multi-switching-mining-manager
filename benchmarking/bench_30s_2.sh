#!/bin/bash
############################################################################### 
# 
# Erstellung der Benchmarkwerte mit hielfe des ccminers 
# 
# Erstüberblick der möglichen Algos zum Berechnen + hash werte (nicht ganz aussagekräftig) 
# 
#   
# 
# ## benchmark aufruf vom ccminer mit allen algoryhtmen welcher dieser kann 
#   Vor--benchmark um einen ersten überblick zu bekommen über algos und hashes 
# 

# Wenn debug=1 ist, werden die temporären Dateien beim Beenden nicht gelöscht.
debug=0

# Umrechnungsfaktor für die kH/s, MH/s etc. Zahlen.
declare -i k_base=1024          # CCminer scheint gemäß bench.cpp mit 1024 zu rechnen
declare -i MIN_HASH_COUNT=20    # Mindestanzahl Hashberechnungswerte, die abgewartet werden müssen
declare -i MIN_WATT_COUNT=30    # Mindestanzahl Wattwerte, die in Sekundenabständen gemessen werden
STOP_AFTER_MIN_REACHED=1     # Abbruch nach der Mindestlaufzeit- und Mindest-Hashzahleenermittlung

TWEAK_CMD_LOG=tweak_cmd.log
touch ${TWEAK_CMD_LOG}

#POSITIONAL=()
while [[ $# -gt 0 ]]; do
    parameter="$1"

    case $parameter in
        -w|--min-watt-seconds)
            MIN_WATT_COUNT="$2"
            shift 2
            ;;
        -m|--min-hash-count)
            MIN_HASH_COUNT="$2"
            shift 2
            ;;
        -t|--tweak-mode)
            STOP_AFTER_MIN_REACHED=0
            shift
            ;;
        -h|--help)
            echo $0 \[-w\|--min-watt-seconds TIME\] \
                 \[-m\|--min-hash-count HASHES\] \
                 \[-t\|--tweak-mode\] \
                 \[-h\|--help\]
            echo "-w default is ${MIN_WATT_COUNT} seconds"
            echo "-m default is ${MIN_HASH_COUNT} hashes"
            echo "-t runs the script infinitely. Otherwise it stops after both minimums are reached."
            echo "-h this help message"
            exit
            ;;
        *)
            POSITIONAL+=("$1") # save it in an array for later
            shift # past argument
            ;;
    esac
done
#set -- "${POSITIONAL[@]}" # restore positional parameters

function _On_Exit () {
    # CCminer stoppen
    if [ -s ccminer.pid ]; then kill $(cat "ccminer.pid"); fi
    if [ $debug -eq 0 ]; then
        rm -f uuid bensh_gpu_30s_.index tweak_to_these_logs watt_bensh_30s.out COUNTER temp_hash_bc_input \
           temp_hash_sum temp_watt_sum watt_bensh_30s_max.out tempazb tempazw tempazI temp_hash temp_einheit \
           HASHCOUNTER
    fi
    rm -f $(basename $0 .sh).pid
}
trap _On_Exit EXIT

# Aktuelle eigene PID merken
echo $$ >$(basename $0 .sh).pid
if [ ! -d test ]; then mkdir test; fi

# Wenn auf 1 steht, wird der Code ausgeführt, wie er vorher war.
if [ $HOME == "/home/richard" ]; then NoCards=true; fi

if [ ! $NoCards ]; then
    # 
    # Devices auflisten welches einen benchmark durchführen soll 
    # list devices 
    nvidia-smi --query-gpu=index,gpu_name,gpu_uuid --format=csv,noheader 
    # 0, GeForce GTX 980 Ti, GPU-742cb121-baad-f7c4-0314-cfec63c6ec70 
    # 1, GeForce GTX 1060 3GB, GPU-84f7ca95-d215-185d-7b27-a7f017e776fb 
 
    # auswahl des devices "eingabe wartend" 
    read -p "Für welches GPU device soll ein Benchmark druchgeführt werden: " var 
 
    echo $var > bensh_gpu_30s_.index
 
    # mit ausgewählten device fortfahren (mit der Index zahl die ausgewählt wurde) 
    nvidia-smi --id=$var --query-gpu=index,gpu_name,gpu_uuid --format=csv,noheader \
        | gawk -e 'BEGIN {FS=", | %"} {print $3}' > uuid 
 
else
    echo "GPU-742cb121-baad-f7c4-0314-cfec63c6ec70" >uuid
    echo 0 > bensh_gpu_30s_.index
fi
uuid=$(cat "uuid")

# Aufbau des Arrays NH_algos[] mit allen bekannten NiceHash Algorithmennamen
# Eigentlich sollten wir erst den Abruf so oder so aus dem Netz machen, um die AlgoNames zu erfahren.
# Wir holen hier mal der Bequemlichkeit halber die aus einer eventuell vorhandenen ALGO_NAMES.json
# Müssen aber dennoch checken, ob sie gültig ist!

# Die Variable ist ein Kandidat, um als Globale Variable in einem "source" file überall integriert zu werden.
# Sie wird dann nicht mehr an dieser Stelle stehen, sondern über "source GLOBAL_VARIABLES.inc" eingelesen
ALGO_NAMES_WEB="ALGO_NAMES.json"

# Da manche Skripts in Unterverzeichnissen laufen, müssen diese Skripts die Globale Variable für sich intern anpassen
# ---> Wir könnten auch mit Symbolischen Links arbeiten, die in den Unterverzeichnissen angelegt werden und auf die
# ---> gleichnamigen Dateien darüber zeigen.
ALGO_NAMES_WEB="../${ALGO_NAMES_WEB}"

declare -i jsonValid=0
searchPattern='^[{]"result":[{]"algorithms":\['
while [ ${jsonValid} -eq 0 ]; do
    if [ -s "${ALGO_NAMES_WEB}" ]; then
        jsonValid=$(cat ${ALGO_NAMES_WEB} | grep -c -e "$searchPattern" )
    fi
    if [ ${jsonValid} -eq 0 ]; then
        jsonValid=$(curl "https://api.nicehash.com/api?method=buy.info" \
                  | tee ${ALGO_NAMES_WEB} \
                  | grep -c -e "$searchPattern" )
    fi
    if [ ${jsonValid} -eq 0 ]; then sleep 1; fi
done

# Algoname:kMGTP-Faktor:Algo-ID Paare extrahieren nach READARR
shopt -s lastpipe
unset READARR; declare -a READARR
gawk -e 'BEGIN { RS=":[\[]{|},{|}\],"; \
           f["k"]=1; f["M"]=2; f["G"]=3; f["T"]=4; f["P"]=5 } \
     match( $0, /"name":"[[:alnum:]]*/ )\
          { M=substr($0, RSTART, RLENGTH); print tolower( substr(M, index(M,":")+2 ) ) }  \
     match( $0, /"speed_text":"[[:alpha:]]*/ )\
          { M=substr($0, RSTART, RLENGTH); print 1024 ** f[substr(M, index(M,":")+2, 1 )] }  \
     match( $0, /"algo":[0-9]*/ )\
          { M=substr($0, RSTART, RLENGTH); print substr(M, index(M,":")+1 ) }' \
     ${ALGO_NAMES_WEB} 2>/dev/null \
    | readarray -n 0 -O 0 -t READARR

unset kMGTP ALGOs ALGO_IDs
declare -Ag kMGTP ALGO_IDs
for ((i=0; $i<${#READARR[@]}; i+=3)) ; do
    kMGTP[${READARR[$i]}]=${READARR[$i+1]}
    ALGOs[${READARR[$i+2]}]=${READARR[$i]}
    ALGO_IDs[${READARR[$i]}]=${READARR[$i+2]}
done
NH_Algos=(${ALGOs[@]})

# Die CC_Algos aus der Datei ccminer_algos einlesen, wenn wir sie brauchen sollten, was momentan nicht der Fall ist.
#unset CC_Algos
#cat ccminer_algos | cut -d ' ' -f 1 | readarray -n 0 -O 0 -t CC_Algos

# ---> Datei algo_zu_ccminer-algo <---
# Diese Datei zu pflegen ist wichtig!
# Einlesen der Datei algo_zu_ccminer-algo, die die Zuordnung der NH-Namen zu den CC-Namen enthält
unset NH_CC_Algos
cat algo_zu_ccminer-algo | grep -v -e '^#' | readarray -n 0 -O 0 -t NH_CC_Algos

# Aufbau des Arrays CC_testAlgos, damit der ccminer mit '-a ${CC_testAlgos[${algo}]} gerufen werden kann.
unset CC_testAlgos; declare -A CC_testAlgos
for algoPair in "${NH_CC_Algos[@]}"; do
    read           algo      cc_algo        <<<"${algoPair}"
    CC_testAlgos[${algo}]="${cc_algo}"
done
for algo in "${NH_Algos[@]}"; do
    if [ "${CC_testAlgos[${algo}]}" == "" ]; then
        CC_testAlgos[${algo}]="${algo}"
    fi
done

# Auswahl des Algos  
for i in "${!NH_Algos[@]}"; do
    printf "%10s=%17s" "a$i" "\"${NH_Algos[$i]}\""
    if [ $((($i+1)%3)) -eq 0 ]; then printf "\n"; fi
done

read -p "Für welchen Algo willst du testen: " algonr 
 
algo=${NH_Algos[${algonr:1}]}
    
echo "das ist der Algo den du ausgewählt hast : ${algo}" 
if [ "$algo" = "scrypt" ] ; then
    echo "Dieser Algo ist nicht mehr mit Grafikkarten lohnenswert. Dafür ermitteln wir keine Werte mehr."
    exit
fi


###
### START DES BENCHMARKING
###
if [ ! $NoCards ]; then
    # miner wird ausgeführt mit device und schreiben der log datei (mehrere minuten) 
    # CUDA export .. wo das Cuda verzeichnis ist und ggf version 
    export LD_LIBRARY_PATH=/usr/local/cuda-8.0/lib64/:$LD_LIBRARY_PATH 

    #wo der Miner ist und welcher benutzt wird 
    minerfolder="/media/avalon/dea6f367-2865-4032-8c39-d2ca4c26f5ce/ccminer-windows" 

    echo " ./ccminer --no-color -a ${CC_testAlgos[${algo}]} --benchmark --devices $var >> test/benchmark_${algo}_$uuid.log" 
    $minerfolder/ccminer --no-color -a ${CC_testAlgos[${algo}]} --benchmark --devices $var > test/benchmark_${algo}_${uuid}.log &
    echo $! > ccminer.pid 

    sleep 3
else
    echo " ./ccminer --no-color -a ${CC_testAlgos[${algo}]} --benchmark --devices $var >> test/benchmark_${algo}_$uuid.log"
    if [ ! -f "test/benchmark_${algo}_${uuid}.log" ]; then
        cp test/benchmark_blake256r8vnl_GPU-742cb121-baad-f7c4-0314-cfec63c6ec70.log test/benchmark_${algo}_${uuid}.log
    fi
fi  ## $NoCards




rm -f COUNTER watt_bensh_30s.out watt_bensh_30s_max.out
id=$(cat "bensh_gpu_30s_.index")       #später indexnummer aus gpu folder einfügen !!!
countWatts=1
countHashes=1
declare -i COUNTER=0
declare -i hashCount=0
declare -i wattCount=0
declare -i new_TweakCommand_available=$(stat -c %Y ${TWEAK_CMD_LOG})
tweak_msg=''
echo "$TWEAK_CMD_LOG"                      >tweak_to_these_logs
echo "watt_bensh_30s.out"                 >>tweak_to_these_logs
echo "test/benchmark_${algo}_${uuid}.log" >>tweak_to_these_logs


echo "Starten des Wattmessens..."
while [ $countWatts -eq 1 ] || [ $countHashes -eq 1 ] || [ ! $STOP_AFTER_MIN_REACHED -eq 1 ]; do
    ### Wattwert messen und in Datei protokollieren
    if [ ! $NoCards ]; then
        nvidia-smi --id=$id --query-gpu=power.draw --format=csv,noheader \
            | gawk -e 'BEGIN {FS=" "} {print $1}' >> watt_bensh_30s.out
    else
        echo $((222 + $COUNTER)) >> watt_bensh_30s.out
    fi
    if [ $((++COUNTER)) -ge $MIN_WATT_COUNT ]; then countWatts=0; fi
    echo $COUNTER > COUNTER

    ### Hashwerte nachsehen und zählen
    hashCount=$(cat test/benchmark_${algo}_${uuid}.log | grep -c "/s$")
    if [ $hashCount -ge $MIN_HASH_COUNT ]; then countHashes=0; fi

    if [ ! ${STOP_AFTER_MIN_REACHED} -eq 1 ]; then
        ### TWEAKING MODE
        if [ $new_TweakCommand_available -lt $(stat -c %Y ${TWEAK_CMD_LOG}) ]; then
            # Ermittle das gerade gegebene Tweaking-Kommando
            tweak_msg="$(tail -n 1 ${TWEAK_CMD_LOG})"
            new_TweakCommand_available=$(stat -c %Y ${TWEAK_CMD_LOG})
            if [ $NoCards ]; then
                # Hänge ein paar andere Werte an die Logdateien - zum Testen
                cat test/more_hash_values.fake >>test/benchmark_${algo}_${uuid}.log
                cat more_watt_values.fake >>watt_bensh_30s.out
            fi
        fi
        # Suche die Zeile in der Logdatei
        if [ ${#tweak_msg} -gt 0 ]; then
            # Calculate only the values after the last command
            from_line=$(cat test/benchmark_${algo}_${uuid}.log \
                      | grep -n "${tweak_msg}" \
                      | tail -n 1 \
                      | gawk -e 'BEGIN {FS="-"} {print $1+1}' \
                     )
            hashCount=$(cat test/benchmark_${algo}_${uuid}.log \
                      | tail -n +$from_line \
                      | grep "/s$" \
                      | tee >(gawk -M -e 'BEGIN{out="0"}{hash=NF-1; out=out "+" $hash}END{print out}' \
                                   | tee temp_hash_bc_input | bc >temp_hash_sum )\
                      | wc -l \
                     )
            from_line=$(cat "watt_bensh_30s.out" \
                      | grep -n "${tweak_msg}" \
                      | tail -n 1 \
                      | gawk -e 'BEGIN {FS="-"} {print $1+1}' \
                     )
            wattCount=$(cat "watt_bensh_30s.out" \
                      | tail -n +$from_line \
                      | tee >(gawk -M -e 'BEGIN {sum=0} {sum+=$1} END {print sum}' >temp_watt_sum ) \
                      | wc -l \
                     )
        else
            # Nimm alle Werte aus der BenchLog und der WattLog Datei, um den lfd. Durchschnitt zu errechnen
            # zuerst die BenchLog...
            hashCount=$(cat test/benchmark_${algo}_${uuid}.log \
                      | grep "/s$" \
                      | tee >(gawk -M -e 'BEGIN{out="0"}{hash=NF-1; out=out "+" $hash}END{print out}' \
                                   | tee temp_hash_bc_input | bc >temp_hash_sum )\
                      | wc -l \
                     )
            # ... dann die WattLog
            wattCount=$(cat "watt_bensh_30s.out" \
                      | tee >(gawk -M -e 'BEGIN {sum=0} {sum+=$1} END {print sum}' >temp_watt_sum ) \
                      | wc -l \
                     )
        fi
        hashSum=$(< temp_hash_sum)
        wattSum=$(< temp_watt_sum)

        echo "scale=2; \
              avghash  = $hashSum / $hashCount; \
              avgwatt  = $wattSum / $wattCount; \
              quotient = avghash / avgwatt; \
              print avghash, \" \", avgwatt, \" \", quotient" | bc \
            | read avgHASH avgWATT quotient

        printf "%12s H; %#12.2f W; %#10.2f H/W, GPU-Einstellung ???\n" \
               ${avgHASH/\./,} ${avgWATT/\./,} ${quotient/\./,}
    fi

    # Eine Sekunde pausieren vor dem nächsten Wattwert
    sleep 1

done  ##  while [ $countWatts ] || [ $countHashes ] || [ ! $STOP_AFTER_MIN_REACHED ]
echo "... Wattmessen ist beendet!!" 

echo "Beenden des Miners" 
if [ ! $NoCards ]; then
    ## Beenden des miners
    ccminer=$(cat "ccminer.pid")
    kill -15 $ccminer
    rm ccminer.pid
    sleep 2
fi  ## $NoCards

###############################################################################
#
#Berechnung der Durchschnittlichen Verbrauches 
#
COUNTER=$(cat "COUNTER")

sort watt_bensh_30s.out |tail -1 > watt_bensh_30s_max.out

WATT=$(cat "watt_bensh_30s.out")
MAXWATT=$(cat "watt_bensh_30s_max.out")

sum=0
for i in $WATT ; do  
    sum=$(echo "$sum + $i" | bc) 
done 

avgWATT=$(echo "$sum / $COUNTER" | bc) 

echo " Summe: $sum " 
echo " Durchschnitt: $avgWATT " 
echo " Max WATT wert: $MAXWATT " 




############################################################################### 
# 
# cat 980ti_bench_log |grep MB, |gawk -M -e 'BEGIN {FS=" "} {print $3}{print $5*1000}' ### noch fehle rdrin bei 0.4 dann ausgabe 0 
# 
#  cat benchmark_$uuid.log |grep MB, |gawk -M -e 'BEGIN {FS=" "} {print $3}{print $5*1000}' 
# 
#  

algo_original="$algo" 
 
######################## 
# 
# Benschmarkspeeed HASH und WATT werte
# (original benchmakŕk.json) für herrausfinden wo an welcher stelle ersetzt werden muss  
# 
#bechchmarkfile="benchmark_${uuid}.json"    # gpu index uuid in "../$uuid/benchmark_$uuid" 

# ---> WICHTIGE ANPUSSUNG NÖTIG, WENN "MinerName" endlich wirklich den "Miner" <---
# --->           und nicht den Algorithemnnamen enthält!!!
# Zeilennummern in temporärer Datei merken
cat benchmark_${uuid}.json |grep -m1 -n -A 6 -e '\"Name.*\"'${algo_original}'\"' \
    | tee >(grep BenchmarkSpeed | gawk -e 'BEGIN {FS="-"} {print $1}' > tempazb ) \
          >(grep NiceHashID     | gawk -e 'BEGIN {FS="-"} {print $1}' > tempazI ) \
    |       grep WATT           | gawk -e 'BEGIN {FS="-"} {print $1}' > tempazw


#" <-- wegen richtigem Highlightning in meinem proggi ... bitte nicht entfernen
## Benchmark Datei bearbeiten "wenn diese schon besteht"(wird erstmal von ausgegangen) und die zeilennummer ausgeben. 
# cat benchmark_GPU-742cb121-baad-f7c4-0314-cfec63c6ec70.json |grep -n -A 4 equihash | grep BenchmarkSpeed 
# Zeilennummer ; Name ; HASH, 
# 80-      "BenchmarkSpeed": 469.765087, 
 

# 
# ccminer log vom algo test/benchmark_$algo_$uuid.log 
# 
#[2017-10-28 16:46:56] 1 miner thread started, using 'lyra2v2' algorithm.
#[2017-10-28 16:46:56] GPU #0: Intensity set to 20, 1048576 cuda threads
#[2017-10-28 16:46:58] GPU #0: Zotac GTX 980 Ti, 33.95 MH/s
#[2017-10-28 16:46:59] Total: 34.36 MH/s
#[2017-10-28 16:47:00] Total: 34.21 MH/s
#[2017-10-28 16:47:01] Total: 34.22 MH/s
#[2017-10-28 16:47:02] GPU #0: Zotac GTX 980 Ti, 34.40 MH/s

#[2017-10-28 16:39:44] 1 miner thread started, using 'sib' algorithm.
#[2017-10-28 16:39:44] GPU #0: Intensity set to 19, 524288 cuda threads
#[2017-10-28 16:39:47] GPU #0: Zotac GTX 980 Ti, 8878.28 kH/s
#[2017-10-28 16:39:54] GPU #0: Zotac GTX 980 Ti, 9029.67 kH/s
#[2017-10-28 16:39:54] Total: 9029.67 kH/s
#[2017-10-28 16:40:04] GPU #0: Zotac GTX 980 Ti, 8964.48 kH/s
#[2017-10-28 16:40:04] Total: 8997.08 kH/s


# Wegen des MH, KH umrechnung wird später bevor die daten in die bench hineingeschrieben wird der wert angepasst.
# die Werte werden in zwei schritten herausgefiltert und in eine hash temp datei zusammengepakt, so dass jeder hash
# wert erfasst werden kann
rm -f temp_hash
cat test/benchmark_${algo}_${uuid}.log | grep "/s$" \
    | gawk -e '{hash=NF-1; print $hash }' >>temp_hash

# herrausfiltern ob KH,MH ....
cat test/benchmark_${algo}_${uuid}.log | grep -m1 "/s$" \
    | gawk -e '{print $NF}' > temp_einheit


############################################################################### 
# 
#Berechnung der Durchschnittlichen Hash wertes 
# 

HASHCOUNTER=0 

HASH_temp=$(cat "temp_hash")
sum=0
for i in $HASH_temp ; do  
 
  sum=$(echo "scale=9; $sum + $i" | bc)
  let HASHCOUNTER=HASHCOUNTER+1 
  echo $HASHCOUNTER > HASHCOUNTER
done 
 
avgHASH=$(echo "scale=9; $sum / $HASHCOUNTER" | bc) 
 
echo " Summe: $sum " 
echo " Durchschnitt: $avgHASH "
temp_einheit=$(cat "temp_einheit")
echo "${temp_einheit}"

#######################################################
#
# Wegen des MH, KH umrechnung wird später bevor die daten in die bench hineingeschrieben wird der wert angepasst.
#
#######################################

# if abfragen ob "MH/s" KH bla blub dann berechnung und richtigstellung $temp_einheit
case "${temp_einheit:0:1}" in

    H)  faktor=1                  ;;
    k)  faktor=${k_base}          ;;
    M)  faktor=$((${k_base}**2))  ;;
    G)  faktor=$((${k_base}**3))  ;;
    T)  faktor=$((${k_base}**4))  ;;
    P)  faktor=$((${k_base}**5))  ;;
    *)  echo "Shit: Unknown Umrechnungsfaktor '${temp_einheit:0:1}'"
esac

avgHASH=$(echo "${avgHASH} * $faktor" | bc)
echo "HASHWERT wurde in Einheit ${temp_einheit:1} umgerechnet: $avgHASH"


#########
#
# Einfügen des Hash wertes in die Original bench*.json datei

BLOCK_FORMAT=(
    '      \"Name\": \"%s\",\n'
    '      \"NiceHashID\": %s,\n'
    '      \"MinerBaseType\": %s,\n'
    '      \"MinerName\": \"%s\",\n'
    '      \"BenchmarkSpeed\": %s,\n'
    '      \"ExtraLaunchParameters\": \"%s\",\n'
    '      \"WATT\": %s,\n'
    '      \"LessThreads\": %s\n'
)

# ## in der temp_algo_zeile steht die zeilen nummer zum editieren des hashwertes
declare -i tempazw=$(cat "tempazw")
declare -i tempazb=$(cat "tempazb") 
declare -i tempazI=$(cat "tempazI") 

if [ $tempazw -gt 1 ] ; then
    if [ ${ALGO_IDs[${algo_original}]} -ne ${tempazI} ]; then
        # NiceHashID korrigieren?
        echo "Die NiceHashID \"${ALGO_IDs[${algo_original}]}\" wird nun in der Zeile $tempazI eingefügt" 
        sed -i -e "${tempazI}s/[0-9]\+/${ALGO_IDs[${algo_original}]}/" benchmark_${uuid}.json
    fi
    # Hash wert änderung
    echo "der Hash wert $avgHASH wird nun in der Zeile $tempazb eingefügt"
    sed -i -e "${tempazb}s/[0-9.]\+/$avgHASH/" benchmark_${uuid}.json
    # WATT wert änderung
    echo "der WATT wert $avgWATT wird nun in der Zeile $tempazw eingefügt"
    sed -i -e "${tempazw}s/[0-9.]\+/$avgWATT/" benchmark_${uuid}.json
else
    BLOCK_VALUES=(
        ${algo_original}
        ${ALGO_IDs[${algo_original}]}
        9
        ${algo_original}
        ${avgHASH}
        ""
        ${avgWATT}
        0
    )
    echo "Der Algo wird zur Benchmark Datei hinzugefügt"
    sed -i -e '/]/,/}$/d'                                    benchmark_${uuid}.json
    printf ",   {\n"                                       >>benchmark_${uuid}.json
    for (( i=0; $i<${#BLOCK_FORMAT[@]}; i++ )); do
        printf "${BLOCK_FORMAT[$i]}" ${BLOCK_VALUES[$i]}   >>benchmark_${uuid}.json
    done
    printf "    }\n  ]\n}\n"                               >>benchmark_${uuid}.json
fi

###################### 
# Löschen der Log datei 
#rm benchmark_$tempnv.log 
 
 
# 
# Benchmark test ist nur für den ccminer ($3) ## "MinerName" (wird später folder bezogen da es mehrere miner gibt ... noch nicht ganz klar) 
# Ein algo können mit xx verschiedenen minern betrieben werden  
# 
# Block_empty 
#    { 
#      "Name": "$1", 
#      "NiceHashID": 0, 
#      "MinerBaseType": 0, 
#      "MinerName": "$3",       #$3 wird am anfang dann vom miner xyz gesetzt bzw von hand eingetragen 
#      "BenchmarkSpeed": $2, 
#      "ExtraLaunchParameters": "", 
#      "WATT": 0, 
#      "LessThreads": 0 
#    }, 
# 
# 
# 
# 
# 
##### old 
#cat miner.out |gawk -e 'BEGIN {FS=", "} {print $2}' |grep -E -o -e '[0-9.]*' 
#nur die mit "yes!" zur berechnung des hashes nehmen bei "threading"
