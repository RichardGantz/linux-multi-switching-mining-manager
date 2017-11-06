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

declare -i t_base=3             # Messintervall in Sekunden für Temperatur
declare -i k_base=1024          # CCminer scheint gemäß bench.cpp mit 1024 zu rechnen
declare -i MIN_HASH_COUNT=20    # Mindestanzahl Hashberechnungswerte, die abgewartet werden müssen
declare -i MIN_WATT_COUNT=30    # Mindestanzahl Wattwerte, die in Sekundenabständen gemessen werden
STOP_AFTER_MIN_REACHED=1     # Abbruch nach der Mindestlaufzeit- und Mindest-Hashzahleenermittlung

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
        -d|--debug-infos)
            debug=1
            shift
            ;;
        -h|--help)
            echo $0 \[-w\|--min-watt-seconds TIME\] \
                 \[-m\|--min-hash-count HASHES\] \
                 \[-t\|--tweak-mode\] \
                 \[-d\|--debug-infos\] \
                 \[-h\|--help\]
            echo "-w default is ${MIN_WATT_COUNT} seconds"
            echo "-m default is ${MIN_HASH_COUNT} hashes"
            echo "-t runs the script infinitely. Otherwise it stops after both minimums are reached."
            echo "-d keeps temporary files for debugging purposes"
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

function _edit_BENCHMARK_JSON_and_put_in_the_new_values () {
    ######################## 
    # 
    # Benschmarkspeeed HASH und WATT werte
    # (original benchmakŕk.json) für herrausfinden wo an welcher stelle ersetzt werden muss  
    # 
    # bechchmarkfile="benchmark_${gpu_uuid}.json"
    # gpu index uuid in "../${gpu_uuid}/benchmark_${gpu_uuid}.json" 

    IMPORTANT_BENCHMARK_JSON=../${gpu_uuid}/benchmark_${gpu_uuid}.json
    cp -f ${IMPORTANT_BENCHMARK_JSON} ${IMPORTANT_BENCHMARK_JSON}.BAK

    #
    # Erweiterung der Blockstruktur des benchmark_${gpu_uuid}.json um MinerVersion, etc.
    # Kann wieder raus, wenn es keine "veralteten" benchmark_*.json Dateien gibt
    #
    grep -c "\"MinerVersion\": \"" ${IMPORTANT_BENCHMARK_JSON}.BAK &>/dev/null \
        || gawk -e 'BEGIN {FS=":"} \
           match( $0, /"MinerName": "[[:alnum:]]*/ )\
               { M=substr($0, RSTART, RLENGTH); miner=tolower( substr(M, index(M,":")+3 ) ); \
                 if ( miner == "equihash" ) { miner="miner"; version="0.3.4b" } else { miner="ccminer"; version="2.2" } \
                 print "      \"MinerName\": \"" miner "\","; \
                 print "      \"MinerVersion\": \"" version "\","; \
                 next } \
           match( $0, /"LessThreads": [[:digit:]]*/ )\
               { M=substr($0, RSTART, RLENGTH); miner=tolower( substr(M, index(M,":")+2 ) ); \
                 print "      \"GPUGraphicsClockOffset[3]\": 0,"; \
                 print "      \"GPUMemoryTransferRateOffset[3]\": 0,"; \
                 print "      \"GPUTargetFanSpeed\": 0,"; \
                 print "      \"PowerLimit\": 0," \
               } \
           {print}' ${IMPORTANT_BENCHMARK_JSON}.BAK >${IMPORTANT_BENCHMARK_JSON}

    # Den EXAKTEN Textblock für ${algo} && ${miner_name} && ${miner_version} raussuchen
    # Zeilennummern in temporärer Datei merken
    # Das folgende Kommando funktioniert exakt wie das gut dokumentierte:
    #sed -n -e '/"Name": "'${algo}'",/{N;N;N;/"MinerName": "'${miner_name}'",/bversion;d;:version;N;/"MinerVersion": "'${miner_version}'/bmatched;d;:matched;N;=}' \

    sed -n -e '/"Name": "'${algo}'",/ {                  # if found...
        N                                                # append N(ext) line to pattern-space, here "NiceHashID"
        N                                                # append N(ext) line to pattern-space, "MinerBaseType"
        N                                                # append N(ext) line to pattern-space, "MinerName"
        /"MinerName": "'${miner_name}'",/ b version      # if found ${miner_name} b(ranch) to :version
        d                                                # d(elete) pattern-space, read next line and start from beginning
        :version
        N                                                # append N(ext) line to pattern-space, "MinerVersion"
        /"MinerVersion": "'${miner_version}'/ b matched  # if found ${miner_version} b(ranch) to :matched
        d                                                # d(elete) pattern space, read next line and start from beginning
        :matched
        N                                                # append N(ext) line to pattern-space, here "BenchmarkSpeed"
        =                                                # print line number, here line of "BenchmarkSpeed"
        }' \
        ${IMPORTANT_BENCHMARK_JSON} \
        > tempazb

    #" <-- wegen richtigem Highlightning in meinem proggi ... bitte nicht entfernen
    ## Benchmark Datei bearbeiten "wenn diese schon besteht"(wird erstmal von ausgegangen) und die zeilennummer ausgeben. 
    # cat benchmark_GPU-742cb121-baad-f7c4-0314-cfec63c6ec70.json |grep -n -A 4 equihash | grep BenchmarkSpeed 
    # Zeilennummer ; Name ; HASH, 
    # 80-      "BenchmarkSpeed": 469.765087, 
 

    # 
    # ccminer log vom algo test/benchmark_$algo_${gpu_uuid}.log 
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


    #######################################################
    #
    # Wegen des MH, KH umrechnung wird später bevor die daten in die bench hineingeschrieben wird der wert angepasst.
    #
    #######################################

    # herrausfiltern ob KH,MH ....
    temp_einheit=$(cat ${BENCHLOGFILE} | grep -m1 "/s$" | gawk -e '{print $NF}')
    case "${temp_einheit:0:1}" in
        S|H) faktor=1                  ;;
        k)   faktor=${k_base}          ;;
        M)   faktor=$((${k_base}**2))  ;;
        G)   faktor=$((${k_base}**3))  ;;
        T)   faktor=$((${k_base}**4))  ;;
        P)   faktor=$((${k_base}**5))  ;;
        *)   echo "Shit: Unknown Umrechnungsfaktor '${temp_einheit:0:1}'"
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
        '      \"MinerVersion\": \"%s\",\n'
        '      \"BenchmarkSpeed\": %s,\n'
        '      \"ExtraLaunchParameters\": \"%s\",\n'
        '      \"WATT\": %s,\n'
        '      \"GPUGraphicsClockOffset[3]\": %s,\n'
        '      \"GPUMemoryTransferRateOffset[3]\": %s,\n'
        '      \"GPUTargetFanSpeed\": %s,\n'
        '      \"PowerLimit\": %s,\n'
        '      \"LessThreads\": %s\n'
    )

    # ## in der temp_algo_zeile steht die zeilen nummer zum editieren des hashwertes
    declare -i tempazb=$(< "tempazb") 

    avgWATT=$((${avgWATT/%[.][[:digit:]]*}+1))

    if [ ${tempazb} -gt 1 ] ; then
        echo "Die NiceHashID \"${ALGO_IDs[${algo}]}\" wird nun in der Zeile $((tempazb-4)) eingefügt" 
        sed -i -e "$((tempazb-4))s/[0-9]\+/${ALGO_IDs[${algo}]}/" ${IMPORTANT_BENCHMARK_JSON}
        echo "der Hash wert $avgHASH wird nun in der Zeile $tempazb eingefügt"
        sed -i -e "${tempazb}s/[0-9.]\+/$avgHASH/" ${IMPORTANT_BENCHMARK_JSON}
        echo "der WATT wert $avgWATT wird nun in der Zeile $((tempazb+2)) eingefügt"
        sed -i -e "$((tempazb+2))s/[0-9.]\+/$avgWATT/" ${IMPORTANT_BENCHMARK_JSON}
        if [ ${#grafik_clock} -ne 0 ]; then
            echo "der GraphicClock Wert ${grafik_clock} wird nun in der Zeile $((tempazb+3)) eingefügt"
            sed -i -e "$((tempazb+3))s/[0-9]\+,/${grafik_clock}/" ${IMPORTANT_BENCHMARK_JSON}
        fi
        if [ ${#memory_clock} -ne 0 ]; then
            echo "der MemoryClock Wert ${memory_clock} wird nun in der Zeile $((tempazb+4)) eingefügt"
            sed -i -e "$((tempazb+4))s/[0-9]\+,/${memory_clock}/" ${IMPORTANT_BENCHMARK_JSON}
        fi
        if [ ${#fan_speed}    -ne 0 ]; then
            echo "der FanSpeed Wert ${fan_speed} wird nun in der Zeile $((tempazb+5)) eingefügt"
            sed -i -e "$((tempazb+5))s/[0-9]\+,/${fan_speed}/" ${IMPORTANT_BENCHMARK_JSON}
        fi
        if [ ${#power_limit}  -ne 0 ]; then
            echo "der PowerLimit Wert ${powerlimit} wird nun in der Zeile $((tempazb+6)) eingefügt"
            sed -i -e "$((tempazb+6))s/[0-9]\+,/${powerlimit}/" ${IMPORTANT_BENCHMARK_JSON}
        fi
    else
        if [ ${#miner_base_type} -eq 0 ]; then miner_base_type=9; fi
        if [ ${#grafik_clock}    -eq 0 ]; then grafik_clock=0;    fi
        if [ ${#memory_clock}    -eq 0 ]; then memory_clock=0;    fi
        if [ ${#fan_speed}       -eq 0 ]; then fan_speed=0;       fi
        if [ ${#power_limit}     -eq 0 ]; then powerlimit=0;      fi
        if [ ${#less_threads}    -eq 0 ]; then less_threads=0;    fi
        BLOCK_VALUES=(
            ${algo}
            ${ALGO_IDs[${algo}]}
            ${miner_base_type}
            ${miner_name}
            ${miner_version}
            ${avgHASH}
            ""
            ${avgWATT}
            ${grafik_clock}
            ${memory_clock}
            ${fan_speed}
            ${power_limit}
            ${less_threads}
        )
        echo "Der Algo wird zur Benchmark Datei hinzugefügt"
        sed -i -e '/ ]/,/}$/d'     ${IMPORTANT_BENCHMARK_JSON}
        printf ",   {\n"         >>${IMPORTANT_BENCHMARK_JSON}
        for (( i=0; $i<${#BLOCK_FORMAT[@]}; i++ )); do
            printf "${BLOCK_FORMAT[$i]}" "${BLOCK_VALUES[$i]}" \
                | tee -a ${IMPORTANT_BENCHMARK_JSON}
        done
        printf "    }\n  ]\n}\n" >>${IMPORTANT_BENCHMARK_JSON}
    fi
}

function _On_Exit () {
    # CCminer stoppen
    if [ -s ccminer.pid ]; then
        kill $(cat "ccminer.pid")
        rm ccminer.pid
    fi
    if [ $debug -eq 0 ]; then
        rm -f uuid bensh_gpu_30s_.index tweak_to_these_logs watt_bensh_30s.out COUNTER temp_hash_bc_input \
           temp_hash_sum temp_watt_sum watt_bensh_30s_max.out tempazb temp_hash temp_einheit \
           HASHCOUNTER benching_${gpu_idx}_algo benching_${gpu_idx}_miner
    fi
    # Am Schluss Kopie der Log-Datei, damit sie nicht verloren geht mit dem aktuellen Zeitpunkt
    if [ -f ${BENCHLOGFILE} ]; then
        sed -e 's/\x1B[[][[:digit:]]*m//g' ${BENCHLOGFILE} \
            >${LOGPATH}/benchmark_$(date "+%Y%m%d_%H%M%S").log
    fi
    if [ -f ${TWEAKLOGFILE} ]; then
        if [ ${#TWEAK_MSGs[@]} -gt 0 ]; then
            echo "Letzter Stand aller verwendeten Befehle:" >>${TWEAKLOGFILE}
            for tweak_msg in "${!TWEAK_MSGs[@]}"; do
                echo "${TWEAK_MSGs[${tweak_msg}]}" >>${TWEAKLOGFILE}
                value=$(echo "${TWEAK_MSGs[${tweak_msg}]}" | grep -o -e '[[:digit:]]\+$')
                if [ "${tweak_msg}" == "./nvidia-befehle/smi --id" ]; then
                    power_limit=${value}
                elif [ "${tweak_msg}" == "nvidia-settings --assign [fan:${gpu_idx}]/GPUTargetFanSpeed" ]; then
                    fan_speed=${value}
                elif [ "${tweak_msg}" == "nvidia-settings --assign [gpu:${gpu_idx}]/GPUGraphicsClockOffset[3]" ]; then
                    grafik_clock=${value}
                else
                    memory_clock=${value}
                fi
            done
        fi

        cp ${TWEAKLOGFILE} ${LOGPATH}/tweak_$(date "+%Y%m%d_%H%M%S").log
    fi
    # Es sind ja wenigstens avgHASH und avgWATT ermittelt worden.
    _edit_BENCHMARK_JSON_and_put_in_the_new_values
    rm -f $(basename $0 .sh).pid
}
trap _On_Exit EXIT

# Für Fake in Entwicklungssystemen ohne Grakas
if [ $HOME == "/home/richard" ]; then NoCards=true; fi

###################################################################################
#
#                _query_actual_Power_Temp_and_Clocks
#
# NVIDIA Befehle
#nvidia-smi -q -i ${gpu_idx} -d Clock,Power
#nvidia-smi -i ${gpu_idx} --query-gpu=temperature.gpu --format=csv,noheader
#
# Die folgenden Strings kommen vor und dienen als Index für die Assoziativen Arrays
# actClocks[] und maxClocks[]
# "Graphics"
# "SM"
# "Memory"
# "Video"
#
# Die folgenden Strings kommen vor und dienen als Index für das Assoziative Array
# actPowers[]
# "Power Draw"
# "Power Limit"
# "Default Power Limit"
# "Enforced Power Limit"
# "Min Power Limit"
# "Max Power Limit"
#
#                _query_actual_Power_Temp_and_Clocks
#
source nvidia-befehle/nvidia-query.inc
source ../algo_infos.inc

# Aktuelle eigene PID merken
echo $$ >$(basename $0 .sh).pid
if [ ! -d test ]; then mkdir test; fi

################################################################################
###
###                     1. Auswahl der GPU
###
################################################################################

if [ ! $NoCards ]; then
    # 
    # Devices auflisten welches einen benchmark durchführen soll 
    # list devices 
    nvidia-smi --query-gpu=index,gpu_name,gpu_uuid --format=csv,noheader 
    # 0, GeForce GTX 980 Ti, GPU-742cb121-baad-f7c4-0314-cfec63c6ec70 
    # 1, GeForce GTX 1060 3GB, GPU-84f7ca95-d215-185d-7b27-a7f017e776fb 
 
    # auswahl des devices "eingabe wartend" 
    read -p "Für welches GPU device soll ein Benchmark druchgeführt werden: " gpu_idx

    # Sync mit tweak_command.sh
    echo ${gpu_idx} > bensh_gpu_30s_.index

    # mit ausgewählten device fortfahren (mit der Index zahl die ausgewählt wurde) 
    # Sync mit tweak_command.sh
    nvidia-smi --id=${gpu_idx} --query-gpu=index,gpu_name,gpu_uuid --format=csv,noheader \
        | gawk -e 'BEGIN {FS=", | %"} {print $3}' > uuid 
 
else
    # Sync mit tweak_command.sh
    echo "GPU-84f7ca95-d215-185d-7b27-a7f017e776fb" >uuid
    # Sync mit tweak_command.sh
    echo 1 > bensh_gpu_30s_.index
fi
gpu_uuid=$(cat "uuid")
gpu_idx=$(cat "bensh_gpu_30s_.index")       #später indexnummer aus gpu folder einfügen !!!

################################################################################
###
###                     2. Auswahl des Miners
###
################################################################################

declare -a minerChoice minerVersion
unset TestAlgos; declare -A TestAlgos

cd ../miners
minerNames=$(ls *.algos)
cd - >/dev/null

echo ""
echo " Die folgenden Miner können getestet werden:"
echo ""
unset i;   declare -i i=0
for minerName in ${minerNames}; do
    read minerChoice[$i] minerVersion[$i] <<<"${minerName//#/ }"
    minerVersion[$i]=${minerVersion[$i]%.algos}
    printf " %2i : %s V. %s\n" $((i+1)) ${minerChoice[$i]} ${minerVersion[$i]}
    i+=1
done
echo ""
read -p "Welchen Miner möchtest Du benchmarken/tweaken ? " choice

miner_name=${minerChoice[$(($choice-1))]}
miner_version=${minerVersion[$(($choice-1))]}
miner_algos=$(< ../miners/${miner_name}#${miner_version}.algos)
# Sync mit tweak_command.sh
echo "${miner_name}#${miner_version}" >benching_${gpu_idx}_miner

################################################################################
###
###                     3. Infos über Algos in Arbeitsspeicher
###
################################################################################

# Einlesen der Algorithmusinformationen, wenn sie schon vorhanden sind oder Abruf aus dem Web
# Eigentlich sollten wir erst den Abruf so oder so aus dem Netz machen, um die AlgoNames zu erfahren.
# Wir holen hier mal der Bequemlichkeit halber die aus einer eventuell vorhandenen ALGO_NAMES.json
# Müssen aber dennoch checken, ob sie gültig ist!

#                       GLOBALE VARIABLEN für spätere Implementierung
# Diese Variablen sind Kandidaten, um als Globale Variablen in einem "source" file überall integriert zu werden.
# Sie wird dann nicht mehr an dieser Stelle stehen, sondern über "source GLOBAL_VARIABLES.inc" eingelesen

NH_DOMAIN="nicehash.com"
export LD_LIBRARY_PATH=/usr/local/cuda-8.0/lib64/:$LD_LIBRARY_PATH
ALGO_NAMES_WEB="ALGO_NAMES.json"
ALGO_PORTS_WEB="MULTI_ALGO_INFO.json"

# Da manche Skripts in Unterverzeichnissen laufen, müssen diese Skripts die Globale Variable für sich intern anpassen
# ---> Wir könnten auch mit Symbolischen Links arbeiten, die in den Unterverzeichnissen angelegt werden und auf die
# ---> gleichnamigen Dateien darüber zeigen.
ALGO_NAMES_WEB="../${ALGO_NAMES_WEB}"
ALGO_PORTS_WEB="../${ALGO_PORTS_WEB}"

_read_in_ALGO_NAMES
_read_in_ALGO_PORTS


####################################################################################
###
###                     4. Auswahl des zu benchmarkenden Algos
###
####################################################################################

# Gibt es eine ALGO-NAMEN - KONVERTIERUNGSTABELLE von NiceHash Algonamen zu $miner_name Algonamen?
# ---> Datei NiceHash#ccminer.names <---
# Diese Datei zu pflegen ist wichtig!
# Einlesen der Datei NiceHash#ccminer.names, die die Zuordnung der NH-Namen zu den CC-Namen enthält
unset NH_CC_Algos

cd ../miners/
internalAlgoNames=$(ls NiceHash#${miner_name}.names 2>/dev/null)
if [ ${#internalAlgoNames} -gt 0 ]; then
    cat ${internalAlgoNames} | grep -v -e '^#' | readarray -n 0 -O 0 -t NH_CC_Algos

    # Aufbau des Arrays TestAlgos, damit der ccminer mit '-a ${TestAlgos[${algo}]} gerufen werden kann.
    for algoPair in "${NH_CC_Algos[@]}"; do
        read           algo      cc_algo        <<<"${algoPair}"
        TestAlgos[${algo}]="${cc_algo}"
    done
fi
cd - >/dev/null

for algo in ${miner_algos}; do
    if [ "${TestAlgos[${algo}]}" == "" ]; then
        TestAlgos[${algo}]="${algo}"
    fi
done

# Auswahl des Algos
declare -a menuItems=( "${!TestAlgos[@]}" )
if [ ${#menuItems[@]} -gt 1 ]; then
    for i in ${!menuItems[@]}; do
        printf "%10s=%17s" "a$i" "\"${menuItems[$i]}\""
        if [ $(((i+1) % 3)) -eq 0 ]; then printf "\n"; fi
    done
    printf "\n"

    read -p "Für welchen Algo willst du testen: " algonr
else
    algonr=a0
fi
algo=${menuItems[${algonr:1}]}
    
echo "das ist der Algo den du ausgewählt hast : ${algo}" 
if [ "$algo" = "scrypt" ] ; then
    echo "Dieser Algo ist nicht mehr mit Grafikkarten lohnenswert. Dafür ermitteln wir keine Werte mehr."
    exit
fi

# Ein paar Standardverzeichnisse zur Verbesserung der Übersicht:
if   [ ! -d ../${gpu_uuid}/benchmarking ]; then
    mkdir   ../${gpu_uuid}/benchmarking
fi
if   [ ! -d ../${gpu_uuid}/benchmarking/${algo} ]; then
    mkdir   ../${gpu_uuid}/benchmarking/${algo}
fi
if   [ ! -d ../${gpu_uuid}/benchmarking/${algo}/${miner_name}#${miner_version} ]; then
    mkdir   ../${gpu_uuid}/benchmarking/${algo}/${miner_name}#${miner_version}
fi
LOGPATH="../${gpu_uuid}/benchmarking/${algo}/${miner_name}#${miner_version}"
BENCHLOGFILE="test/benchmark_${algo}_${gpu_uuid}.log"
TWEAKLOGFILE="test/tweak_${algo}_${gpu_uuid}.log"

# Sync mit tweak_command.sh
echo "${algo}" >benching_${gpu_idx}_algo

####################################################################################
###
###                          START DES BENCHMARKING
###
####################################################################################

# Dieser Aufruf zieht die entsprechenden Variablen rein, die für den Miner
# definiert sind, damit die Aufrufmechanik für alle gleich ist.
source ../miners/${miner_name}#${miner_version}.starts

# ---> Die folgenden Variablen müssen noch vollständig implementiert werden! <---
continent="eu"        # Noch nicht vollständig implementiert!      <--------------------------------------
worker="1060"         # Noch nicht vollständig implementiert!      <--------------------------------------

algo_port=${PORTs[${algo}]}

rm -f ${BENCHLOGFILE}
# Jetzt bauen wir den Benchmakaufruf zusammen, der in dem .inc entsprechend vorbereitet ist.
# 1. Erzeugung der Parameterliste

# Diese Funktion musste leider erfunden werden wegen der internen anderen Algonamen,
# die NiceHash willkürlich anders benannt hat.
# Im Benchmaring-Fall braucht diese Funktion eigentlich sowieso nicht gerufen werden,
# deshalb kommentieren wir sie hier zur Gedächtnisstütze aus, damit wir es im Live Fall nicht vergessen.

# So rufen wir eine Funktion, wenn sie definiert wurde.
declare -f PREP_BENCH_PARAMETERSTACK >/dev/null && PREP_BENCH_PARAMETERSTACK
paramlist=""
for (( i=0; $i<${#BENCH_PARAMETERSTACK[@]}; i++ )); do
    declare -n param="${BENCH_PARAMETERSTACK[$i]}"
    paramlist+="${param} "
done
printf -v minerstart "${BENCH_START_CMD}" ${paramlist}
echo "${minerstart} >>${BENCHLOGFILE} &"


if [ ! $NoCards ]; then
    ${minerstart} >>${BENCHLOGFILE} &
    echo $! > ccminer.pid
    sleep 3
else
    if [ ! -f "${BENCHLOGFILE}" ]; then
        if [ "${miner_name}" == "miner" ]; then
            #sed -e 's/\x1B[[][[:digit:]]*m//g' equihash.log >${BENCHLOGFILE}
            cp -f equihash.log ${BENCHLOGFILE}
        else
            cp test/benchmark_blake256r8vnl_GPU-742cb121-baad-f7c4-0314-cfec63c6ec70.fake ${BENCHLOGFILE}
        fi
    fi
fi  ## $NoCards




if [ ! ${STOP_AFTER_MIN_REACHED} -eq 1 ]; then
    ###
    ### Variablen für TWEAKING MODE 
    ###
    rm -f ${TWEAKLOGFILE}
    TWEAK_CMD_LOG=tweak_commands.log
    rm -f ${TWEAK_CMD_LOG}
    touch ${TWEAK_CMD_LOG}
    declare -i TWEAK_CMD_LOG_AGE
    declare -i new_TweakCommand_available=$(stat -c %Y ${TWEAK_CMD_LOG})
    tweak_msg=''
    declare -A TWEAK_MSGs
    echo "$TWEAK_CMD_LOG"                          >tweak_to_these_logs
    echo "watt_bensh_30s.out"                     >>tweak_to_these_logs
    echo "${BENCHLOGFILE}" >>tweak_to_these_logs
    declare -i wattCount=0
    declare -i queryCnt=0
fi

rm -f COUNTER watt_bensh_30s.out watt_bensh_30s_max.out
countWatts=1
countHashes=1
declare -i COUNTER=0
declare -i hashCount=0




echo "Starten des Wattmessens..."

while [ $countWatts -eq 1 ] || [ $countHashes -eq 1 ] || [ ! $STOP_AFTER_MIN_REACHED -eq 1 ]; do
    ### Wattwert messen und in Datei protokollieren
    if [ ! $NoCards ]; then
        nvidia-smi --id=${gpu_idx} --query-gpu=power.draw --format=csv,noheader \
            | gawk -e 'BEGIN {FS=" "} {print $1}' >> watt_bensh_30s.out
    else
        echo $((222 + $COUNTER)) >> watt_bensh_30s.out
    fi
    if [ $((++COUNTER)) -ge $MIN_WATT_COUNT ]; then countWatts=0; fi
    echo $COUNTER > COUNTER

    ### Hashwerte nachsehen und zählen
    hashCount=$(cat ${BENCHLOGFILE} \
                       | sed -e 's/\x1B[[][[:digit:]]*m//g' \
                       | grep -c "/s$")
    if [ $hashCount -ge $MIN_HASH_COUNT ]; then countHashes=0; fi

    if [ ! ${STOP_AFTER_MIN_REACHED} -eq 1 ]; then
        ###
        ### TWEAKING MODE
        ###
        TWEAK_CMD_LOG_AGE=$(stat -c %Y ${TWEAK_CMD_LOG})
        if [ $new_TweakCommand_available -lt ${TWEAK_CMD_LOG_AGE} ]; then
            new_TweakCommand_available=${TWEAK_CMD_LOG_AGE}
            # Ermittle das gerade gegebene Tweaking-Kommando
            tweak_msg="$(tail -n 1 ${TWEAK_CMD_LOG})"
            TWEAK_MSGs["${tweak_msg/=[[:digit:]]*/}"]="${tweak_msg}"
            tweak_pat="${tweak_msg//[[]/\\[}"
            tweak_pat="${tweak_pat//[\]]/\\]}"
            tweak_pat="${tweak_pat//[.]/\.}"
            if [ $NoCards ]; then
                # Hänge ein paar andere Werte an die Logdateien - zum Testen
                cat test/more_hash_values.fake >>${BENCHLOGFILE}
                cat more_watt_values.fake >>watt_bensh_30s.out
            fi
            hash_line=$(cat ${BENCHLOGFILE} \
                      | grep -n -e "${tweak_pat}" \
                      | tail -n 1 \
                      | gawk -e 'BEGIN {FS="-"} {print $1+1}' \
                     )
            watt_line=$(cat "watt_bensh_30s.out" \
                      | grep -n -e "${tweak_pat}" \
                      | tail -n 1 \
                      | gawk -e 'BEGIN {FS="-"} {print $1+1}' \
                     )
            printf "${tweak_msg}\n" \
                | tee -a ${TWEAKLOGFILE}
            printf "Hashwerte ab jetzt ab Zeile $hash_line und Wattwerte ab Zeile $watt_line\n" \
                | tee -a ${TWEAKLOGFILE}
        fi
        # Suche die Zeile in der Logdatei
        if [ ${#tweak_msg} -gt 0 ]; then
            # Calculate only the values after the last command
            hashCount=$(cat ${BENCHLOGFILE} \
                      | sed -e 's/\x1B[[][[:digit:]]*m//g' \
                      | tail -n +$hash_line \
                      | grep -e "/s$" \
                      | tee >(gawk -M -e 'BEGIN{out="0"}{hash=NF-1; out=out "+" $hash}END{print out}' \
                                   | tee temp_hash_bc_input | bc >temp_hash_sum ) \
                      | wc -l \
                     )
            wattCount=$(cat "watt_bensh_30s.out" \
                      | tail -n +$watt_line \
                      | tee >(gawk -M -e 'BEGIN {sum=0} {sum+=$1} END {print sum}' >temp_watt_sum ) \
                      | wc -l \
                     )
        else
            # Nimm alle Werte aus der BenchLog und der WattLog Datei, um den lfd. Durchschnitt zu errechnen
            # zuerst die BenchLog...
            hashCount=$(cat ${BENCHLOGFILE} \
                      | sed -e 's/\x1B[[][[:digit:]]*m//g' \
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

        if [ ${hashCount} -gt 0 ]; then
            echo "scale=2; \
                  avghash  = $hashSum / $hashCount; \
                  avgwatt  = $wattSum / $wattCount; \
                  quotient = avghash / avgwatt; \
                  print avghash, \" \", avgwatt, \" \", quotient" | bc \
                | read avgHASH avgWATT quotient
        else
            avgHASH=0; avgWATT=0; quotient=0
        fi

        if [ $((queryCnt++ % ${t_base})) -eq 0 ]; then
            _query_actual_Power_Temp_and_Clocks
            # Möglich sind: ( "Graphics" "SM" "Memory" "Video" )
            # ("Power Draw" "Power Limit" "Default Power Limit" "Enforced Power Limit" "Min Power Limit" "Max Power Limit")
            printf "%5iMHz/%5iMHz %5iMHz/%5iMHz %7.2fW/%7.2fW %3i°C\n" \
                   ${actClocks["Graphics"]} ${maxClocks["Graphics"]} \
                   ${actClocks["Memory"]}   ${maxClocks["Memory"]} \
                   ${actPowers["Power Limit"]/\./,} ${actPowers["Max Power Limit"]/\./,} \
                   ${actTemp} \
                | tee -a ${TWEAKLOGFILE}
        fi
        printf "%12s H; %#12.2f W; %#10.2f H/W\n" \
               ${avgHASH/\./,} ${avgWATT/\./,} ${quotient/\./,} \
            | tee -a ${TWEAKLOGFILE}
    else
        ###
        ### "Normal" BENCHMARK MODE
        ###
        printf "%3s Hashwerte von mindestens $MIN_HASH_COUNT und %3s Wattwerte von mindestens $MIN_WATT_COUNT\n" \
               ${hashCount} ${COUNTER}
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
unset i
for i in $WATT ; do  
    sum=$(echo "$sum + $i" | bc) 
done 

avgWATT=$(echo "$sum / $COUNTER" | bc) 

printf " Summe        : %12s; Messwerte: %5s\n" $sum $COUNTER
printf " Durchschnitt : %12s\n" $avgWATT
printf " Max WATT Wert: %12s\n" $MAXWATT


############################################################################### 
# 
#Berechnung der Durchschnittlichen Hash wertes 
# 

#cat miner.out |gawk -e 'BEGIN {FS=", "} {print $2}' |grep -E -o -e '[0-9.]*' 
# ---> nur die mit "yes!" zur berechnung des hashes nehmen bei "THREADING" <---

# Wegen des MH, KH umrechnung wird später bevor die daten in die bench hineingeschrieben wird der wert angepasst.
# die Werte werden in zwei schritten herausgefiltert und in eine hash temp datei zusammengepakt, so dass jeder hash
# wert erfasst werden kann

# Ausfiltern von Farben Escape-Sequenzen
sed -i -e 's/\x1B[[][[:digit:]]*m//g' ${BENCHLOGFILE}

rm -f temp_hash
cat ${BENCHLOGFILE} | grep "/s$" \
    | gawk -e '{hash=NF-1; print $hash }' >>temp_hash

# herrausfiltern ob KH,MH ....
cat ${BENCHLOGFILE} | grep -m1 "/s$" \
    | gawk -e '{print $NF}' > temp_einheit
temp_einheit=$(< "temp_einheit")


HASHCOUNTER=0 

HASH_temp=$(< "temp_hash")
sum=0
for float in $HASH_temp ; do  
 
  sum=$(echo "scale=9; $sum + $float" | bc)
  let HASHCOUNTER=HASHCOUNTER+1
  echo $HASHCOUNTER > HASHCOUNTER
done 
 
avgHASH=$(echo "scale=9; $sum / $HASHCOUNTER" | bc) 
 
printf " Summe        : %12.2f; Messwerte: %5s\n" ${sum/\./,} $HASHCOUNTER
printf " Durchschnitt : %12.2f %6s\n" ${avgHASH/\./,} ${temp_einheit}

#_edit_BENCHMARK_JSON_and_put_in_the_new_values
#kill -15 $(< $(basename $0 .sh).pid)