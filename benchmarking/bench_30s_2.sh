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
    nvidia-smi --id=$var --query-gpu=index,gpu_name,gpu_uuid --format=csv,noheader | gawk -e 'BEGIN {FS=", | %"} {print $3}' > uuid 
 
    uuid=$(cat "uuid")
else
    uuid="GPU-742cb121-baad-f7c4-0314-cfec63c6ec70"
fi

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

unset kMGTP ALGOs
declare -Ag kMGTP
for ((i=0; $i<${#READARR[@]}; i+=3)) ; do
    kMGTP[${READARR[$i]}]=${READARR[$i+1]}
    ALGOs[${READARR[$i+2]}]=${READARR[$i]}
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

if [ ! $NoCards ]; then
    # miner wird ausgeführt mit device und schreiben der log datei (mehrere minuten) 
    # CUDA export .. wo das Cuda verzeichnis ist und ggf version 
    export LD_LIBRARY_PATH=/usr/local/cuda-8.0/lib64/:$LD_LIBRARY_PATH 

    #wo der Miner ist und welcher benutzt wird 
    minerfolder="/media/avalon/dea6f367-2865-4032-8c39-d2ca4c26f5ce/ccminer-windows" 

    echo " ./ccminer --no-color -a ${CC_testAlgos[${algo}]} --benchmark --devices $var >> benchmark_${algo}_$uuid.log" 
    $minerfolder/ccminer --no-color -a ${CC_testAlgos[${algo}]} --benchmark --devices $var > benchmark_${algo}_${uuid}.log &
    echo $! > ccminer.pid 

    sleep 3
else
    echo " ./ccminer --no-color -a ${CC_testAlgos[${algo}]} --benchmark --devices $var >> benchmark_${algo}_$uuid.log"
    case "${algo}" in

	sib)
	    echo "[2017-10-28 16:39:44] 1 miner thread started, using 'sib' algorithm."     >benchmark_${algo}_${uuid}.log
	    echo "[2017-10-28 16:39:44] GPU #0: Intensity set to 19, 524288 cuda threads"  >>benchmark_${algo}_${uuid}.log
	    echo "[2017-10-28 16:39:47] GPU #0: Zotac GTX 980 Ti, 8878.28 kH/s"            >>benchmark_${algo}_${uuid}.log
	    echo "[2017-10-28 16:39:54] GPU #0: Zotac GTX 980 Ti, 9029.67 kH/s"            >>benchmark_${algo}_${uuid}.log
	    echo "[2017-10-28 16:39:54] Total: 9029.67 kH/s"                               >>benchmark_${algo}_${uuid}.log
	    echo "[2017-10-28 16:40:04] GPU #0: Zotac GTX 980 Ti, 8964.48 kH/s"            >>benchmark_${algo}_${uuid}.log
	    echo "[2017-10-28 16:40:04] Total: 8997.08 kH/s"                               >>benchmark_${algo}_${uuid}.log
	    ;;

	*)
	    echo "[2017-10-28 16:46:56] 1 miner thread started, using '${algo}' algorithm." >benchmark_${algo}_${uuid}.log
	    echo "[2017-10-28 16:46:56] GPU #0: Intensity set to 20, 1048576 cuda threads" >>benchmark_${algo}_${uuid}.log
	    echo "[2017-10-28 16:46:58] GPU #0: Zotac GTX 980 Ti, 33.95 MH/s"              >>benchmark_${algo}_${uuid}.log
	    echo "[2017-10-28 16:46:59] Total: 34.36 MH/s"                                 >>benchmark_${algo}_${uuid}.log
	    echo "[2017-10-28 16:47:00] Total: 34.21 MH/s"                                 >>benchmark_${algo}_${uuid}.log
	    echo "[2017-10-28 16:47:01] Total: 34.22 MH/s"                                 >>benchmark_${algo}_${uuid}.log
	    echo "[2017-10-28 16:47:02] GPU #0: Zotac GTX 980 Ti, 34.40 MH/s"              >>benchmark_${algo}_${uuid}.log
	    ;;
    esac
fi  ## $NoCards

if [ ! $NoCards ]; then
    ### Starten der WATT Messung über 30 Sekunden um ein ersten wert zu bekommen 
    # Hier drin läuft der counter 30 Sekunden, danach werden Miner bench beendet 
    #  (wattmessung sekunde vorher als variable abfragen irgendwann) 
 
    echo "starten des Wattmessens" 
    #echo "watt_bensh_30s.sh &" 
    rm COUNTER 
    rm watt_bensh_30s.out 
    rm -f watt_bensh_30s_max.out

    #####
    #
    # Teilweise brauchen die Algos längere zeit um hash werte zu erzeugen, deswegen wird der timer
    # je nach algo hochgesetzt, wenn dieses gebraucht wird .... bzw ... anhand der ausgabe datei
    # kann es ggf festgesellt werden .... minium 20 hash werte sollten aufgerechnet werden können.
    time=30    #wieviel mal soll die schleife laufen ein durchlauf 1 sekunde
    
    if [ "$algo" = "scrypt" ] ; then 
        time=1 
        echo "Dieser Algo ist nicht mehr mit Graffikkarten lohnenswert" 
    else 
        echo "gibt keine zeit Anpassung läuft mit $time Sekunden" 
    fi

    COUNTER=0
    id=$(cat "bensh_gpu_30s_.index")       #später indexnummer aus gpu folder einfügen !!!


    #### für so und so viele Sekunden den Watt wert in eine Datei schreiben
    while [  $COUNTER -lt $time ]; do
	nvidia-smi --id=$id --query-gpu=power.draw --format=csv,noheader |gawk -e 'BEGIN {FS=" "} {print $1}'  >> watt_bensh_30s.out
	let COUNTER=COUNTER+1
	echo $COUNTER > COUNTER
	sleep 1
    done



    echo "Wattmessen ist beendet!!" 


    echo "beenden des miners" 
    ## Beenden des miners 
    ccminer=$(cat  "ccminer.pid") 
    kill -15 $ccminer 
    sleep 2 

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
fi  ## $NoCards

algo_original="$algo" 
 
######################## 
# 
# Benschmarkspeeed HASH und WATT werte
# (original benchmakŕk.json) für herrausfinden wo an welcher stelle ersetzt werden muss  
# 
#bechchmarkfile="benchmark_${uuid}.json"    # gpu index uuid in "../$uuid/benchmark_$uuid" 

# Zeilennummern in temporärer Datei merken
cat benchmark_${uuid}.json |grep -n -A 4 \"${algo_original}\" \
    | tee >(grep BenchmarkSpeed | gawk -e 'BEGIN {FS="-"} {print $1}' > tempazb ) \
    | grep WATT | gawk -e 'BEGIN {FS="-"} {print $1}'                 > tempazw


#" <-- wegen richtigem Highlightning in meinem proggi ... bitte nicht entfernen
## Benchmark Datei bearbeiten "wenn diese schon besteht"(wird erstmal von ausgegangen) und die zeilennummer ausgeben. 
# cat benchmark_GPU-742cb121-baad-f7c4-0314-cfec63c6ec70.json |grep -n -A 4 equihash | grep BenchmarkSpeed 
# Zeilennummer ; Name ; HASH, 
# 80-      "BenchmarkSpeed": 469.765087, 
 

# 
# ccminer log vom algo benchmark_$algo_$uuid.log 
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

cat benchmark_${algo}_${uuid}.log |grep Total | gawk -e 'BEGIN {FS=" "} {print $4}' > temp_hash
cat benchmark_${algo}_${uuid}.log |grep /s |grep GPU | gawk -e 'BEGIN {FS=" "} {print $9}' >> temp_hash
exit
#falls buchstaben hinzugekommen sind in einer zeile = falsch muss sie komplett entfernt werden
sed -i '/[a-z]/d' temp_hash

# herrausfiltern ob KH,MH ....
cat benchmark_${algo}_${uuid}.log |grep -m1 Total | gawk -e 'BEGIN {FS=" "} {print $5}' > temp_einheit

############################################################################### 
# 
#Berechnung der Durchschnittlichen Hash wertes 
# 

HASHCOUNTER=0 

HASH_temp=$(cat "temp_hash") 
sum=0 
 
for i in $HASH_temp ; do  
 
  sum=$(echo "$sum + $i" | bc)
  let HASHCOUNTER=HASHCOUNTER+1 
  echo $HASHCOUNTER > HASHCOUNTER  
done 
 
avgHASH=$(echo "$sum / $HASHCOUNTER" | bc) 
 
echo " Summe: $sum " 
echo " Durchschnitt: $avgHASH "
temp_einheit=$(cat "temp_einheit")
echo "${temp_einheit}"

#######################################################
#
# Wegen des MH, KH umrechnung wird später bevor die daten in die bench hineingeschrieben wird der wert angepasst.
#
#######################################

# if abfragen ob MH KH bla blub dann berechnung und richtigstellung $temp_einheit
if [ "$temp_einheit" = "kH/s" ] ; then  
    avgHASH=$(echo "${avgHASH} * 1000" | bc)
    echo "HASHWERT wurde in Einheit ${temp_einheit} umgerechnet $avgHASH"
    else
    
    if [ "$temp_einheit" = "MH/s" ] ; then  
        avgHASH=$(echo "${avgHASH} * 1000000" | bc)
        echo "HASHWERT wurde in Einheit ${temp_einheit} umgerechnet $avgHASH"
        else 
        
        if [ "$temp_einheit" = "GH/s" ] ; then  
            avgHASH=$(echo "${avgHASH} * 1000000000" | bc)
            echo "HASHWERT wurde in Einheit ${temp_einheit} umgerechnet $avgHASH"
            else 
            
            if [ "$temp_einheit" = "TH/s" ] ; then  
                avgHASH=$(echo "${avgHASH} * 1000000000000" | bc)
                echo "HASHWERT wurde in Einheit ${temp_einheit} umgerechnet $avgHASH"
                else 
                echo "HASHWERT $avgHASH brauchte nicht umgerechnet werden" 

            fi    

        fi   

    fi  
fi


#########
#
# Einfügen des Hash wertes in die Original bench*.json datei
 
# ## in der temp_algo_zeile steht die zeilen nummer zum editieren des hashwertes
tempazw=$(cat "tempazw")
tempazb=$(cat "tempazb") 

if [ "$tempazw" -gt 1 ] ; then  
        # Hash wert änderung
        echo "der Hash wert $avgHASH wird nun in der Zeile $tempazb eingefügt" 
        sed -i -e ''$tempazb's/[0-9.]\+/'$avgHASH'/' benchmark_${uuid}.json
        # WATT wert änderung
        echo "der WATT wert $avgWATT wird nun in der Zeile $tempazw eingefügt" 
        sed -i -e ''$tempazw's/[0-9.]\+/'$avgWATT'/' benchmark_${uuid}.json
    else 
        echo "Der Algo wird zur Benchmark Datei hinzugefügt"
        echo "{" >> benchmark_${uuid}.json
        echo ""Name": "$algo_original"," >> benchmark_${uuid}.json
        echo ""NiceHashID": 0," >> benchmark_${uuid}.json
        echo ""MinerBaseType": 0," >> benchmark_${uuid}.json
        echo ""MinerName": "$algo_original"," >> benchmark_${uuid}.json
        echo ""BenchmarkSpeed": $avgHASH," >> benchmark_${uuid}.json
        echo ""ExtraLaunchParameters": ""," >> benchmark_${uuid}.json
        echo ""WATT": $avgWATT," >> benchmark_${uuid}.json
        echo ""LessThreads": 0" >> benchmark_${uuid}.json
        echo "}," >> benchmark_${uuid}.json

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
