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
#if [ $# -eq 0 ]; then kill -9 $$; fi

# Wenn debug=1 ist, werden die temporären Dateien beim Beenden nicht gelöscht.
debug=0
# Damit bei vorzeitigem Abbruch und nicht gültigem Variableninhalt/-zustand kein Mist in die .json geschrieen wird,
# setzen wir dieses Flag erst genau dann, wenn das Benchmarking auch tatsächlich losgeht.
# Schiefgehen kann dann natürlich immer noch was, aber die Benutzerabbrüche sind schon mal keine Problemquelle mehr.
BENCHMARKING_WAS_STARTED=0
# Um sicherzustellen, dass alle Werte in der Endlosschleife gültig berechnet und abgeschlossen wurden,
# wird diese Datei kurz vor dem sleep 1 in der Endlosschleife erzeugt.
# tweak_commands.sh setzt den kill -15 Befehl dann nur ab, wenn diese Datei existiert.
# Sobald der Prozess aus dem Sleep kommt, verarbeitet er das Signal und schließt die Berechnungen ab.
READY_FOR_SIGNALS=benchmarker_ready_for_kill_signal

declare -i t_base=3             # Messintervall in Sekunden für Temperatur, Clocks und Power in Sekunden
declare -i k_base=1024          # CCminer scheint gemäß bench.cpp mit 1024 zu rechnen

# Durch Parameterübergabe beim Aufruf änderbar:
declare -i MIN_HASH_COUNT=20    # -m Anzahl         : Mindestanzahl Hashberechnungswerte, die abgewartet werden müssen
declare -i MIN_WATT_COUNT=30    # -w Anzahl Sekunden: Mindestanzahl Wattwerte, die in Sekundenabständen gemessen werden
STOP_AFTER_MIN_REACHED=1        # -t : setzt Abbruch nach der Mindestlaufzeit- und Mindest-Hashzahleenermittlung auf 0
                                #      Das ist der Tweak-Mode. Standard ist der Benchmark-Modus
BENCH_KIND=2                    # -t == 1; Standardwerte == 2; -w/-m used == 3; 0 == unknown
ATTENTION_FOR_USER_INPUT=1      # -a : setzt die Attention auf 0, übergeht menschliche Eingaben
                                #      ---------> und wird über Variablen und Dateien gesteuert  <---------
                                #      ---------> MUSS ERST IMPLEMENTIERT WERDEN !!!!!!!!!       <---------
                                #      ---------> IM MOMENT NUR DIE UNTERDRÜCKUNG VON AUSGABEN   <---------

#POSITIONAL=()
while [[ $# -gt 0 ]]; do
    parameter="$1"

    case $parameter in
        -a|--auto)
            ATTENTION_FOR_USER_INPUT=0
            shift
            ;;
        -w|--min-watt-seconds)
            MIN_WATT_COUNT="$2"
            BENCH_KIND=3                    # -t == 1; Standardwerte == 2; -w/-m used == 3; 0 == unknown
            shift 2
            ;;
        -m|--min-hash-count)
            MIN_HASH_COUNT="$2"
            BENCH_KIND=3                    # -t == 1; Standardwerte == 2; -w/-m used == 3; 0 == unknown
            shift 2
            ;;
        -t|--tweak-mode)
            STOP_AFTER_MIN_REACHED=0
            BENCH_KIND=1                    # -t == 1; Standardwerte == 2; -w/-m used == 3; 0 == unknown
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

    # Den EXAKTEN Textblock für ${algo} && ${miner_name} && ${miner_version} raussuchen
    # Zeilennummern in temporärer Datei merken
    # Das folgende Kommando funktioniert exakt wie das gut dokumentierte:
    #sed -n -e '/"Name": "'${algo}'",/{N;N;N;/"MinerName": "'${miner_name}'",/bversion;d;:version;N;/"MinerVersion": "'${miner_version}'/bmatched;d;:matched;N;=}' \

    sed -n -e '/"Name": "'${algo}'",/ {                   # if found...
        N                                                 # append N(ext) line to pattern-space, here "NiceHashID"
        N                                                 # append N(ext) line to pattern-space, "MinerBaseType"
        N                                                 # append N(ext) line to pattern-space, "MinerName"
        /"MinerName": "'${miner_name}'",/ b version       # if found ${miner_name} b(ranch) to :version
        d                                                 # d(elete) pattern-space, read next line and start from beginning
        :version
        N                                                 # append N(ext) line to pattern-space, "MinerVersion"
        /"MinerVersion": "'${miner_version}'"/ b matched  # if found ${miner_version} b(ranch) to :matched
        d                                                 # d(elete) pattern space, read next line and start from beginning
        :matched
        N                                                 # append N(ext) line to pattern-space, here "BenchmarkSpeed"
        =                                                 # print line number, here line of "BenchmarkSpeed"
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

    # Im Moment haben wir die folgende Feldbelegung innerhalb des "$algorithm" Objects:
    # Die Zeile, die wir nachher suchen ist "BenchmarkSpeed" in die Datei tempabz.
    # Die weiteren Felder liegen entsprechend auf höheren Zeilennummern.
    # tempazb     : BenchmarkSpeed
    # tempazb +  1: ExtraLaunchParameters
    # tempazb +  2: WATT
    # tempazb +  3: MAX_WATT
    # tempazb +  4: HASHCOUNT
    # tempazb +  5: HASH_DURATION
    # tempazb +  6: BENCH_DATE
    # tempazb +  7: BENCH_KIND
    # tempazb +  8: MinerFee
    # tempazb +  9: GPUGraphicsClockOffset[3]
    # tempazb + 10: GPUMemoryTransferRateOffset[3]
    # tempazb + 11: GPUTargetFanSpeed
    # tempazb + 12: PowerLimit
    # tempazb + 13: LessThreads

    # ## in der temp_algo_zeile steht die zeilen nummer zum editieren des hashwertes
    declare -i tempazb=$(< "tempazb") 

    avgWATT=$((${avgWATT/%[.][[:digit:]]*}+1))
    MAX_WATT=$(($(< "watt_bensh_30s_max.out")+1))
    BENCH_DATE=$BENCH_OR_TWEAK_END

    if [ ${tempazb} -gt 1 ] ; then
        echo "Die NiceHashID \"${ALGO_IDs[${algo}]}\" wird nun in der Zeile $((tempazb-4)) eingefügt" 
        echo "der Hash wert $avgHASH wird nun in der Zeile $tempazb eingefügt"
        echo "der WATT wert $avgWATT wird nun in der Zeile $((tempazb+2)) eingefügt"
        echo "$((tempazb-4))s/: [0-9.]*,$/: ${ALGO_IDs[${algo}]},/"  >sed_insert_on_different_lines_cmd
        echo     "${tempazb}s/: [0-9.]*,$/: ${avgHASH},/"           >>sed_insert_on_different_lines_cmd
        echo "$((tempazb+2))s/: [0-9.]*,$/: ${avgWATT},/"           >>sed_insert_on_different_lines_cmd
        if [ ${#MAX_WATT} -ne 0 ]; then
            echo "der MAX_WATT Wert ${MAX_WATT} wird nun in der Zeile $((tempazb+3)) eingefügt"
            echo "$((tempazb+3))s/: [0-9.]*,$/: ${MAX_WATT},/"      >>sed_insert_on_different_lines_cmd
        fi
        if [ ${#hashCount} -ne 0 ]; then
            echo "der HASHCOUNT Wert ${hashCount} wird nun in der Zeile $((tempazb+4)) eingefügt"
            echo "$((tempazb+4))s/: [0-9]*,$/: ${hashCount},/"      >>sed_insert_on_different_lines_cmd
        fi
        if [ ${#HASH_DURATION} -ne 0 ]; then
            echo "der HASH_DURATION Wert ${HASH_DURATION} wird nun in der Zeile $((tempazb+5)) eingefügt"
            echo "$((tempazb+5))s/: [0-9]*,$/: ${HASH_DURATION},/"  >>sed_insert_on_different_lines_cmd
        fi
        if [ ${#BENCH_DATE} -ne 0 ]; then
            echo "der BENCH_DATE Wert ${BENCH_DATE} wird nun in der Zeile $((tempazb+6)) eingefügt"
            echo "$((tempazb+6))s/: [0-9]*,$/: ${BENCH_DATE},/"     >>sed_insert_on_different_lines_cmd
        fi
        if [ ${#BENCH_KIND} -ne 0 ]; then
            echo "der BENCH_KIND Wert ${BENCH_KIND} wird nun in der Zeile $((tempazb+7)) eingefügt"
            echo "$((tempazb+7))s/: [0-9]*,$/: ${BENCH_KIND},/"     >>sed_insert_on_different_lines_cmd
        fi
        if [ ${#MinerFee} -ne 0 ]; then
            echo "der MinerFee Wert ${MinerFee} wird nun in der Zeile $((tempazb+8)) eingefügt"
            echo "$((tempazb+8))s/: [0-9]*,$/: ${MinerFee},/"       >>sed_insert_on_different_lines_cmd
        fi
        if [ ${#grafik_clock} -ne 0 ]; then
            echo "der GraphicClock Wert ${grafik_clock} wird nun in der Zeile $((tempazb+9)) eingefügt"
            echo "$((tempazb+9))s/: [0-9]*,$/: ${grafik_clock},/"   >>sed_insert_on_different_lines_cmd
        fi
        if [ ${#memory_clock} -ne 0 ]; then
            echo "der MemoryClock Wert ${memory_clock} wird nun in der Zeile $((tempazb+10)) eingefügt"
            echo "$((tempazb+10))s/: [0-9]*,$/: ${memory_clock},/"  >>sed_insert_on_different_lines_cmd
        fi
        if [ ${#fan_speed}    -ne 0 ]; then
            echo "der FanSpeed Wert ${fan_speed} wird nun in der Zeile $((tempazb+11)) eingefügt"
            echo "$((tempazb+11))s/: [0-9]*,$/: ${fan_speed},/"     >>sed_insert_on_different_lines_cmd
        fi
        if [ ${#power_limit}  -ne 0 ]; then
            echo "der PowerLimit Wert ${power_limit} wird nun in der Zeile $((tempazb+12)) eingefügt"
            echo "$((tempazb+12))s/: [0-9]*,$/: ${power_limit},/"   >>sed_insert_on_different_lines_cmd
        fi
        if [ ${#less_threads}  -ne 0 ]; then
            echo "der LessThreads Wert ${less_threads} wird nun in der Zeile $((tempazb+13)) eingefügt"
            echo "$((tempazb+13))s/: [0-9]*$/: ${less_threads}/"    >>sed_insert_on_different_lines_cmd
        fi
        sed -i -f sed_insert_on_different_lines_cmd ${IMPORTANT_BENCHMARK_JSON}
    else
        BLOCK_FORMAT=(
            '      \"Name\": \"%s\",\n'
            '      \"NiceHashID\": %s,\n'
            '      \"MinerBaseType\": %s,\n'
            '      \"MinerName\": \"%s\",\n'
            '      \"MinerVersion\": \"%s\",\n'
            '      \"BenchmarkSpeed\": %s,\n'
            '      \"ExtraLaunchParameters\": \"%s\",\n'
            '      \"WATT\": %s,\n'
            '      \"MAX_WATT\": %s,\n'
            '      \"HASHCOUNT\": %s,\n'
            '      \"HASH_DURATION\": %s,\n'
            '      \"BENCH_DATE\": %s,\n'
            '      \"BENCH_KIND\": %s,\n'
            '      \"MinerFee\": %s,\n'
            '      \"GPUGraphicsClockOffset[3]\": %s,\n'
            '      \"GPUMemoryTransferRateOffset[3]\": %s,\n'
            '      \"GPUTargetFanSpeed\": %s,\n'
            '      \"PowerLimit\": %s,\n'
            '      \"LessThreads\": %s\n'
        )
        if [ ${#MAX_WATT}            -eq 0 ]; then MAX_WATT=0;        fi
        if [ ${#hashCount}           -eq 0 ]; then hashCount=0;       fi
        if [ ${#HASH_DURATION}       -eq 0 ]; then HASH_DURATION=0;   fi
        if [ ${#BENCH_DATE}          -eq 0 ]; then BENCH_DATE=0;      fi
        if [ ${#BENCH_KIND}          -eq 0 ]; then BENCH_KIND=0;      fi
        if [ ${#MinerFee}            -eq 0 ]; then MinerFee=0;        fi
        if [ ${#miner_base_type}     -eq 0 ]; then miner_base_type=9; fi
        if [ ${#grafik_clock}        -eq 0 ]; then grafik_clock=0;    fi
        if [ ${#memory_clock}        -eq 0 ]; then memory_clock=0;    fi
        if [ ${#fan_speed}           -eq 0 ]; then fan_speed=0;       fi
        if [ ${#power_limit}         -eq 0 ]; then power_limit=0;     fi
        if [ ${#less_threads}        -eq 0 ]; then less_threads=0;    fi
        BLOCK_VALUES=(
            ${algo}
            ${ALGO_IDs[${algo}]}
            ${miner_base_type}
            ${miner_name}
            ${miner_version}
            ${avgHASH}
            ""
            ${avgWATT}
            ${MAX_WATT}
            ${hashCount}
            ${HASH_DURATION}
            ${BENCH_DATE}
            ${BENCH_KIND}
            ${MinerFee}
            ${grafik_clock}
            ${memory_clock}
            ${fan_speed}
            ${power_limit}
            ${less_threads}
        )
        echo "Der Algo wird zur Benchmark Datei hinzugefügt"
        sed -i -e '/^ \+]/,/}$/d'     ${IMPORTANT_BENCHMARK_JSON}
        printf ",   {\n"         >>${IMPORTANT_BENCHMARK_JSON}
        for (( i=0; $i<${#BLOCK_FORMAT[@]}; i++ )); do
            printf "${BLOCK_FORMAT[$i]}" "${BLOCK_VALUES[$i]}" \
                | tee -a ${IMPORTANT_BENCHMARK_JSON}
        done
        printf "    }\n  ]\n}\n" >>${IMPORTANT_BENCHMARK_JSON}
    fi
}

function _delete_temporary_files () {
    rm -f uuid bensh_gpu_30s_.index tweak_to_these_logs watt_bensh_30s.out COUNTER temp_hash_bc_input \
       temp_hash_sum temp_watt_sum watt_bensh_30s_max.out tempazb temp_hash temp_einheit \
       HASHCOUNTER benching_${gpu_idx}_algo sed_insert_on different_lines_cmd ccminer.pid
}

function _On_Exit () {
    # CCminer stoppen
    echo "... Wattmessen ist beendet!!" 
    echo "Beenden des Miners"
    if [ ! $NoCards ]; then
        ## Beenden des miners
        #ccminer=$(cat "ccminer.pid")
        kill -15 $(< "ccminer.pid")
        sleep 2
    fi  ## $NoCards
    #
    # Bis jetzt könnten Werte in das $BENCHLOGFILE hineingekommen sein.
    # Das ist vor allem für den Tweak-Fall interessant, weil der das $BENCHLOGFILE nochmal
    # durchgehen muss! Denn es könnte noch ein Wert dazu gekommen sein!
    # ---> BITTE NOCHMAL NACHPROGRAMMIEREN!                      <---
    # ---> MUSS DAS BENCHFILE UACH IM TWEAKMODE NOCHMAL SCANNEN! <---
    #
    BENCH_OR_TWEAK_END=$(date --utc +%s)
    # Das stimmt im Falle des Tweakens nicht so genau.
    # Hier sollten wir nur die Dauer seit der letzten Parameteränderung messen, ODER ???
    # --->   IST EVENTUELL NOCH ZU KORRIGIEREN   <---
    HASH_DURATION=$((${BENCH_OR_TWEAK_END}-${BENCH_DATE}))

    # Als wichtiges Kennzeichen für den Ausstieg, denn da werden die Logdateien gesichert
    # und die Werte in die .json Datei geschrieben.
    # Das darf nicht geschehen, wenn das Programm vorher abnormal beendet wurde und gar keine Daten erhoben wurden
    #
    if [ ${BENCHMARKING_WAS_STARTED} -eq 1 ]; then
        # Am Schluss Kopie der Log-Datei, damit sie nicht verloren geht mit dem aktuellen Zeitpunkt
        if [ -f ${BENCHLOGFILE} ]; then
            # Wir müssen vorläufig keine Escape-Sequenzen mehr ausfiltern
            # sed -e 's/\x1B[[][[:digit:]]*m//g' ${BENCHLOGFILE} \
            cp -f ${BENCHLOGFILE} ${LOGPATH}/benchmark_$(date "+%Y%m%d_%H%M%S").log
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

        ####################################################################
        #    Aufbereitung der Werte zum Schreiben in die benchmark_*.json
        #
        temp_einheit=$(cat ${BENCHLOGFILE} | grep -m1 "/s$" | gawk -e '{print $NF}')
        if [ ${STOP_AFTER_MIN_REACHED} -eq 1 ]; then
            ###
            ### BENCHMARKING MODE was invoked
            ###
            hashCount=$(cat ${BENCHLOGFILE} \
                      | grep "/s$" \
                      | tee >(gawk -M -e 'BEGIN{out="0"}{hash=NF-1; out=out "+" $hash}END{print out}' \
                                   | tee temp_hash_bc_input | bc >temp_hash_sum )\
                      | wc -l \
                     )
            # ... dann die WattLog
            wattCount=$(cat "watt_bensh_30s.out" \
                      | tee >(gawk -M -e 'BEGIN {sum=0} {sum+=$1} END {print sum}' >temp_watt_sum ) \
                            >(gawk -M -e 'BEGIN {max=0} {if ($1>max) max=$1 } END {print max}' >watt_bensh_30s_max.out ) \
                      | wc -l \
                     )
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
        #else
            ###
            ### TWEAKING MODE was invoked
            ###
            ### Im Tweaking-Mode sind alle Werte gültig, wurden jede Sekunde aktuell berechnet.
            ### Bis zum Schluss.
            ### ---> BITTE NOCH ABSOLUT SICHERSTELLEN, DASS NUR WÄHREND DES SLEEP ABGEBROCHEN WIRD <---
            ### 
        fi
            
        # Ist das wirklich noch nötig?
        printf " Summe WATT   : %12s; Messwerte: %5s\n" $wattSum $wattCount
        printf " Durchschnitt : %12s\n" $avgWATT
        printf " Max WATT Wert: %12s\n" $(< watt_bensh_30s_max.out)
        printf " Summe HASH   : %12s; Messwerte: %5s\n" ${hashSum:0:$(($(expr index "$hashSum" ".")+2))} $hashCount
        printf " Durchschnitt : %12s %6s\n" ${avgHASH:0:$(($(expr index "${avgHASH}" ".")+2))} ${temp_einheit}

        # Es sind ja wenigstens avgHASH und avgWATT ermittelt worden.
        _edit_BENCHMARK_JSON_and_put_in_the_new_values

    fi  ## if [ ${BENCHMARKING_WAS_STARTED} -eq 1 ]

    if [ $debug -eq 0 ]; then
        _delete_temporary_files
    fi
    rm -f $(basename $0 .sh).pid
}
trap _On_Exit EXIT

# Aktuelle eigene PID merken
echo $$ >$(basename $0 .sh).pid
if [ ! -d test ]; then mkdir test; fi

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
if [ ${#_MINERFUNC_INCLUDED} -eq 0 ];then
    source ../miner-func.inc
fi

# Das ist jetzt richtig aktiv und liest die folgenden Systeminformationen in die entsprechenden Arrays:
#      index[0-n]=gpu_idx
#          name[${gpu_idx}]=
#           bus[${gpu_idx}]=
#          uuid[${gpu_idx}]=
#    auslastung[${gpu_idx}]=
#            GPU${gpu_idx}Algos[]=          # declaration only
#            GPU${gpu_idx}Watts[]=          # declaration only
#            GPU${gpu_idx}Mines[]=          # declaration only
#     uuidEnabledSOLL[${gpu_uuid}]=         # 0/1
#        AlgoDisabled[${algo}]=             # STRING with all Info
workdir=$(pwd)
cd ..
source gpu-abfrage.sh
_func_gpu_abfrage_sh
cd ${workdir} >/dev/null

################################################################################
################################################################################
###
###                     1. Bereitstellung globaler Daten im Arbeisspeicher
###
################################################################################
################################################################################

################################################################################
###
###          1.1. Infos über Algos und Ports aus dem Web in Arbeitsspeicher
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

################################################################################
################################################################################
###
###                     2. Auswahl der GPU
###
################################################################################
################################################################################

################################################################################
###
###          2.1. Nach der GPU-Abfrage die manuelle Auswahl durch den Benutzer
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
gpu_uuid=$(< "uuid")
gpu_idx=$(< "bensh_gpu_30s_.index")       #später indexnummer aus gpu folder einfügen !!!
IMPORTANT_BENCHMARK_JSON="../${gpu_uuid}/benchmark_${gpu_uuid}.json"

################################################################################
###
###          2.2. Einlesen ALLER verfügbaren Miner und deren Algos
###
################################################################################

# Gibt es eine ALGO-NAMEN - KONVERTIERUNGSTABELLEN von NiceHash Algonamen zu $miner_name Algonamen?
# ---> Datei NiceHash#${miner_name}.names <---
#      Diese Datei zu pflegen ist wichtig!
# Einlesen der Datei NiceHash#${miner_name}.names, die die Zuordnung der NH-Namen zu den CC-Namen enthält
# Dann Einlesen der restlichen Algos aus den ${miner_name}#${miner_version}.algos Dateien
# In ALLE die Arrays "Internal_${miner_name}_${miner_version//\./_}_Algos"

_set_ALLE_MINER_from_path "../miners"

# Dann gleich Bereitstellung zweier Arrays mit AvailableAlgos und MissingAlgos.
# Die MissingAlgos könnte man in einer automatischen Schleife benchmarken lassen,
# bis es keine MissingAlgos mehr gibt.

for minerName in ${ALLE_MINER}; do
    read miner_name miner_version <<<"${minerName//#/ }"
    miner_version=${miner_version%.algos}
    declare -n actInternalAlgos="Internal_${miner_name}_${miner_version//\./_}_Algos"
    _split_into_Available_and_Missing_Miner_Algo_Arrays
done


################################################################################
################################################################################
###
###                     3. Auswahl des Miners
###
################################################################################
################################################################################

declare -a minerChoice minerVersion
echo ""
echo " Die folgenden Miner können getestet werden:"
echo ""
unset i;   declare -i i=0
for minerName in ${ALLE_MINER}; do
    read minerChoice[$i] minerVersion[$i] <<<"${minerName//#/ }"
    minerVersion[$i]=${minerVersion[$i]%.algos}
    printf " %2i : %s V. %s\n" $((i+1)) ${minerChoice[$i]} ${minerVersion[$i]}
    i+=1
done
echo ""
read -p "Welchen Miner möchtest Du benchmarken/tweaken ? " choice

miner_name=${minerChoice[$(($choice-1))]}
miner_version=${minerVersion[$(($choice-1))]}


####################################################################################
################################################################################
###
###                     4. Auswahl des zu benchmarkenden Algos
###
################################################################################
####################################################################################

# Checken, ob wir für alle Algos auch schon Werte in der ../${gpu_uuid}/benchmark_${gpu_uuid}.json haben
# Diejenigen Algos anzeigen, zu denen es noch keine Eintragsmöglichkeit gibt.
# Das wurde nach dem Einlesen in ALLE_MINER gemacht und es wurden auch die beiden Arrays
#     "Missing_${miner_name}_${miner_version//\./_}_Algos" und
#     "Available_${miner_name}_${miner_version//\./_}_Algos" erstellt,
#     die die Namen der entsprechenden algos als Werte haben.
declare -n actMissingAlgos="Missing_${miner_name}_${miner_version//\./_}_Algos"
if [ ${#actMissingAlgos[@]} -gt 0 ]; then
    for algo in ${actMissingAlgos[@]}; do
        printf "%17s <-------------------- Bitte Benchmark durchführen. Noch keine Daten vorhanden\n" ${algo}
    done
fi

# Auswahl des Algos durch den Benutzer...

# Wegen des Startparameters die Miner... oder sollen wir das auch auf eine glatte Variable umstellen,
# die man ohne Funktion rufen kann? Könnte man sich einen Funktionsaufruf sparen.
unset InternalAlgos
declare -A InternalAlgos
declare -n                 actInternalAlgos="Internal_${miner_name}_${miner_version//\./_}_Algos"
declare -a menuItems=( "${!actInternalAlgos[@]}" )
numAlgos=${#menuItems[@]}

if [ $numAlgos -gt 1 ]; then
    for i in ${!menuItems[@]}; do
        printf "%10s=%17s" "a$i" "\"${menuItems[$i]}\""
        if [ $(((i+1) % 3)) -eq 0 ]; then printf "\n"; fi
        # Für alle, die intern andere Namen benutzen als wie sie sie abliefern
        InternalAlgos[${menuItems[$i]}]=${actInternalAlgos[${menuItems[$i]}]}
    done
    printf "\n"

    read -p "Für welchen Algo willst du testen: " algonr
elif [ $numAlgos -eq 1 ]; then
    # ... oder angenommener einziger Algo aus der Datei für die Algos.
    algonr=a0
    # Für alle, die intern andere Namen benutzen als wie sie sie abliefern
    InternalAlgos[${menuItems[0]}]=${actInternalAlgos[${menuItems[0]}]}
else
    # Au weia, ... noch gar keine Algos einlesen können.
    error_msg="Sorry, dieser Miner weiss nicht, welche Algos er minen kann.\n"
    error_msg+="Es gibt weder eine Datei ../miners/${miner_name}#${miner_version}.algos\n"
    error_msg+="noch eine Namenkonvertierungsdatei ../miners/NiceHash#${miner_name}.names\n"
    error_msg+="ODER die Dateien sind vorhanden, aber leer."
    error_msg+="Bitte erst eine oder beide dieser Dateien erstellen.\n"
    printf ${error_msg}
    read -p "Das Programm wird nach <ENTER> mit den selben Parametern \"$*\" neu gestartet..." restart
    exec $0 "$*"
fi
algo=${menuItems[${algonr:1}]}

echo "das ist der Algo den du ausgewählt hast : ${algo}"
if [ "$algo" = "scrypt" ] ; then
    echo "Dieser Algo ist nicht mehr mit Grafikkarten lohnenswert. Dafür ermitteln wir keine Werte mehr."
    read -p "Das Programm wird nach <ENTER> mit den selben Parametern \"$*\" neu gestartet..." restart
    exec $0 "$*"
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
rm -f ${BENCHLOGFILE} ${TWEAKLOGFILE}

# Sync mit tweak_command.sh
echo "${algo}#${miner_name}#${miner_version}" >benching_${gpu_idx}_algo


####################################################################################
################################################################################
###
###                        5. START DES BENCHMARKING
###
################################################################################
####################################################################################

# Dieser Aufruf zieht die entsprechenden Variablen rein, die für den Miner
# definiert sind, damit die Aufrufmechanik für alle gleich ist.
source ../miners/${miner_name}#${miner_version}.starts

# ---> Die folgenden Variablen müssen noch vollständig implementiert werden! <---
continent="eu"        # Noch nicht vollständig implementiert!      <--------------------------------------
worker="1060"         # Noch nicht vollständig implementiert!      <--------------------------------------

algo_port=${PORTs[${algo}]}

# Jetzt bauen wir den Benchmakaufruf zusammen, der in dem .inc entsprechend vorbereitet ist.
# 1. Erzeugung der Parameterliste

# Diese Funktion musste leider erfunden werden wegen der internen anderen Algonamen,
# die NiceHash willkürlich anders benannt hat.
# Im Benchmaring-Fall braucht diese Funktion eigentlich sowieso nicht gerufen werden,
# deshalb kommentieren wir sie hier zur Gedächtnisstütze aus, damit wir es im Live Fall nicht vergessen.

# So rufen wir eine Funktion, wenn sie definiert wurde.
declare -f PREP_BENCH_PARAMETERSTACK &>/dev/null && PREP_BENCH_PARAMETERSTACK
paramlist=""
for (( i=0; $i<${#BENCH_PARAMETERSTACK[@]}; i++ )); do
    declare -n param="${BENCH_PARAMETERSTACK[$i]}"
    paramlist+="${param} "
done
printf -v minerstart "${BENCH_START_CMD}" ${paramlist}
echo "${minerstart} >>${BENCHLOGFILE} &"


# Als wichtiges Kennzeichen für den Ausstieg, denn da werden die Logdateien gesichert
# und die Werte in die .json Datei geschrieben.
# Das darf nicht geschehen, wenn das Programm vorher abnormal beendet wurde und gar keine Daten erhoben wurden
# 
BENCHMARKING_WAS_STARTED=1
BENCH_DATE=$(date --utc +%s)

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
MAX_WATT=0



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
    #   Wir müssen keine ESC-Sequenzen mehr rausfiltern!
    #       | sed -e 's/\x1B[[][[:digit:]]*m//g' \
    hashCount=$(cat ${BENCHLOGFILE} \
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
            if [ ${#tweak_msg} -gt 0 ]; then
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
        fi  ## if [ $new_TweakCommand_available -lt ${TWEAK_CMD_LOG_AGE} ]
        
        # Suche das Tweak-Kommando in der Logdatei.
        # Wenn noch kein Tweak-Kommando gegeben wurde, was durch ${#tweak_msg} == 0 ausgedrückt wird,
        #      dann nimm alle Zeilen ab dem Dateianfang.
        if [ ${#tweak_msg} -gt 0 ]; then
            # Calculate only the values after the last command
            # Farben Escape-Sequenzen müssen wir nicht mehr ausfiltern
            #         | sed -e 's/\x1B[[][[:digit:]]*m//g' \
            hashCount=$(cat ${BENCHLOGFILE} \
                      | tail -n +$hash_line \
                      | grep -e "/s$" \
                      | tee >(gawk -M -e 'BEGIN{out="0"}{hash=NF-1; out=out "+" $hash}END{print out}' \
                                   | tee temp_hash_bc_input | bc >temp_hash_sum ) \
                      | wc -l \
                     )
            wattCount=$(cat "watt_bensh_30s.out" \
                      | tail -n +$watt_line \
                      | tee >(gawk -M -e 'BEGIN {sum=0} {sum+=$1} END {print sum}' >temp_watt_sum ) \
                            >(gawk -M -e 'BEGIN {max=0} {if ($1>max) max=$1 } END {print max}' >watt_bensh_30s_max.out ) \
                      | wc -l \
                     )
        else
            # Nimm alle Werte aus der BenchLog und der WattLog Datei, um den lfd. Durchschnitt zu errechnen
            # zuerst die BenchLog...
            # Farben Escape-Sequenzen müssen wir nicht mehr ausfiltern
            #         | sed -e 's/\x1B[[][[:digit:]]*m//g' \
            hashCount=$(cat ${BENCHLOGFILE} \
                      | grep "/s$" \
                      | tee >(gawk -M -e 'BEGIN{out="0"}{hash=NF-1; out=out "+" $hash}END{print out}' \
                                   | tee temp_hash_bc_input | bc >temp_hash_sum )\
                      | wc -l \
                     )
            # ... dann die WattLog
            wattCount=$(cat "watt_bensh_30s.out" \
                      | tee >(gawk -M -e 'BEGIN {sum=0} {sum+=$1} END {print sum}' >temp_watt_sum ) \
                            >(gawk -M -e 'BEGIN {max=0} {if ($1>max) max=$1 } END {print max}' >watt_bensh_30s_max.out ) \
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
            printf "%5iMHz/%5iMHz %5iMHz/%5iMHz %7sW/%7sW %3i°C\n" \
                   ${actClocks["Graphics"]} ${maxClocks["Graphics"]} \
                   ${actClocks["Memory"]}   ${maxClocks["Memory"]} \
                   ${actPowers["Power Limit"]:0:$(($(expr index ${actPowers["Power Limit"]} ".")+2))} \
                   ${actPowers["Max Power Limit"]:0:$(($(expr index ${actPowers["Max Power Limit"]} ".")+2))} \
                   ${actTemp} \
                | tee -a ${TWEAKLOGFILE}
        fi
        printf "%12s H; %#12s W; %#10s H/W\n" \
               ${avgHASH:0:$(($(expr index "${avgHASH}" ".")+2))} \
               ${avgWATT:0:$(($(expr index "${avgWATT}" ".")+2))} \
               ${quotient:0:$(($(expr index "${quotient}" ".")+2))} \
            | tee -a ${TWEAKLOGFILE}
    else
        ###
        ### "Normal" BENCHMARK MODE
        ###
        printf "%3s Hashwerte von mindestens $MIN_HASH_COUNT und %3s Wattwerte von mindestens $MIN_WATT_COUNT\n" \
               ${hashCount} ${COUNTER}
    fi

    # Eine Sekunde pausieren vor dem nächsten Wattwert.
    # Jetzt auch bereit für Unterbrechnungen bzw. Beenden der Messzyklen
    echo "I'm going to sleep now" >${READY_FOR_SIGNALS}
    sleep 1
    rm -f ${READY_FOR_SIGNALS}

done  ##  while [ $countWatts ] || [ $countHashes ] || [ ! $STOP_AFTER_MIN_REACHED ]

exit

############################################################################################
############################################################################################
############################################################################################
################                                                    ########################
################                  ENDE DES SKRIPTES                 ########################
################                                                    ########################
############################################################################################
############################################################################################
############################################################################################

#       Verlagerung des Restes in die On_Exit Routine, da die auch dann
#       sofort aktiviert wird, wenn der Tweaker von aussen beendet...
#       Dieser ganze Rest kann bald gelöscht werden...

echo "... Wattmessen ist beendet!!" 

echo "Beenden des Miners"
if [ ! $NoCards ]; then
    ## Beenden des miners
    ccminer=$(cat "ccminer.pid")
    kill -15 $ccminer
    rm ccminer.pid
    sleep 2
fi  ## $NoCards


####################################################################################
###
###                        6. AUSWERTUNG DES BENCHMARKING
###
####################################################################################


###############################################################################
#
#Berechnung der Durchschnittlichen Verbrauches 
#
# Die Anzahl Wattwerte, die gemessen wurden. Jede Sekunde ein Wert.
# Daher ist das auch gleichzeitig die Dauer der Hashwerteermittlung
COUNTER=$(< "COUNTER")
HASH_DURATION=$COUNTER

sort watt_bensh_30s.out |tail -1 > watt_bensh_30s_max.out

WATT=$(< "watt_bensh_30s.out")
MAX_WATT=$(< "watt_bensh_30s_max.out")

sum_str='0'
for w in $WATT ; do
    sum_str+="+$w"
done
read sum avgWATT <<<$(echo "sum = ${sum_str};\
     print sum, \" \", sum / $COUNTER"\
    | bc)

printf " Summe        : %12s; Messwerte: %5s\n" $sum $COUNTER
printf " Durchschnitt : %12s\n" $avgWATT
printf " Max WATT Wert: %12s\n" $MAX_WATT


############################################################################### 
# 
#Berechnung der Durchschnittlichen Hash wertes 
# 

#cat miner.out |gawk -e 'BEGIN {FS=", "} {print $2}' |grep -E -o -e '[0-9.]*' 
# ---> nur die mit "yes!" zur berechnung des hashes nehmen bei "THREADING" <---

# Wegen des MH, KH umrechnung wird später bevor die daten in die bench hineingeschrieben wird der wert angepasst.
# die Werte werden in zwei schritten herausgefiltert und in eine hash temp datei zusammengepakt, so dass jeder hash
# wert erfasst werden kann

# Ausfiltern von Farben Escape-Sequenzen, damit grep das "/s$" auch finden kann.
#sed -i -e 's/\x1B[[][[:digit:]]*m//g' ${BENCHLOGFILE}

rm -f temp_hash
cat ${BENCHLOGFILE} | grep "/s$" \
    | tee >(grep -m1 "/s$" | gawk -e '{print $NF}' > temp_einheit) \
    | gawk -e '{hash=NF-1; print $hash }' >>temp_hash
HASH_temp=$(< "temp_hash")

sum_str='0'
declare -i HASHCOUNTER=0 
for float in $HASH_temp ; do  
    sum_str+="+${float}"
    let HASHCOUNTER++
done
echo $HASHCOUNTER > HASHCOUNTER
read sum avgHASH <<<$(echo "scale=9; sum = ${sum_str};\
     print sum, \" \", sum / $HASHCOUNTER"\
    | bc)

printf " Summe        : %12s; Messwerte: %5s\n" ${sum:0:$(($(expr index "$sum" ".")+2))} $HASHCOUNTER
printf " Durchschnitt : %12s %6s\n" ${avgHASH:0:$(($(expr index "${avgHASH}" ".")+2))} $(< temp_einheit)

# Es folgt zum Schluss die On_Exit-Routine, die diese Funktion aufruft!
# _edit_BENCHMARK_JSON_and_put_in_the_new_values

