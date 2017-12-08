#!/bin/bash
###############################################################################
# 
# Erstellung der Benchmarkwerte mit Hilfe des ccminers
# 
# Erstüberblick der möglichen Algos zum Berechnen + hash werte (nicht ganz aussagekräftig)
# 
#   
# 
# ## benchmark aufruf vom ccminer mit allen algoryhtmen welcher dieser kann
#   Vor--benchmark um einen ersten überblick zu bekommen über algos und hashes
# 
#if [ $# -eq 0 ]; then kill -9 $$; fi

# GLOBALE VARIABLEN, nützliche Funktionen
[[ ${#_GLOBALS_INCLUDED} -eq 0 ]] && source ../globals.inc

# Wenn debug=1 ist, werden die temporären Dateien beim Beenden nicht gelöscht.
declare -i debug=0

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

# Durch Parameterübergabe beim Aufruf änderbar:
declare -i MIN_HASH_COUNT=20    # -m Anzahl         : Mindestanzahl Hashberechnungswerte, die abgewartet werden müssen
declare -i MIN_WATT_COUNT=30    # -w Anzahl Sekunden: Mindestanzahl Wattwerte, die in Sekundenabständen gemessen werden
STOP_AFTER_MIN_REACHED=1        # -t : setzt Abbruch nach der Mindestlaufzeit- und Mindest-Hashzahleenermittlung auf 0
                                #      Das ist der Tweak-Mode. Standard ist der Benchmark-Modus
bENCH_KIND=2                    # -t == 1; Standardwerte == 2; -w/-m used == 3; 0 == unknown; 888 == FullPowerMode
ATTENTION_FOR_USER_INPUT=1      # -a | --auto: setzt die Attention auf 0, übergeht menschliche Eingaben
                                #      ---------> und wird über Variablen und Dateien gesteuert  <---------
                                #      ---------> MUSS ERST IMPLEMENTIERT WERDEN !!!!!!!!!       <---------
                                #      ---------> IM MOMENT NUR DIE UNTERDRÜCKUNG VON AUSGABEN   <---------

prepare_hashes_for_bc='BEGIN {out="0"}
{ hash=NF-1; einheit=NF
  switch ($einheit) {
    case /^Sol\/s$|^H\/s$/: faktor=1      ; break
    case /^k/:              faktor=kBase  ; break
    case /^M/:              faktor=kBase^2; break
    case /^G/:              faktor=kBase^3; break
    case /^T/:              faktor=kBase^4; break
    case /^P/:              faktor=kBase^5; break
  }
  out=out "+" $hash "*" faktor
}
END {print out}
'

initialParameters="$*"
POSITIONAL=()
while [[ $# -gt 0 ]]; do
    parameter="$1"

    case $parameter in
        -a|--auto)
            ATTENTION_FOR_USER_INPUT=0
            gpu_idx=$2
            algorithm=$3
            shift 3
            ;;
        -w|--min-watt-seconds)
            MIN_WATT_COUNT="$2"
            bENCH_KIND=3               # -t == 1; Standardwerte == 2; -w/-m used == 3; 0 == unknown; -p FullPower == 888
            shift 2
            ;;
        -m|--min-hash-count)
            MIN_HASH_COUNT="$2"
            bENCH_KIND=3               # -t == 1; Standardwerte == 2; -w/-m used == 3; 0 == unknown; -p FullPower == 888
            shift 2
            ;;
        -t|--tweak-mode)
            STOP_AFTER_MIN_REACHED=0
            bENCH_KIND=1               # -t == 1; Standardwerte == 2; -w/-m used == 3; 0 == unknown; -p FullPower == 888
            shift
            ;;
        -p|--full-power-mode)
            STOP_AFTER_MIN_REACHED=0
            bENCH_KIND=888             # -t == 1; Standardwerte == 2; -w/-m used == 3; 0 == unknown; -p FullPower == 888
            shift
            ;;
        -d|--debug-infos)
            debug=1
            shift
            ;;
        -h|--help)
            echo $0 <<EOF '[-w|--min-watt-seconds TIME] 
                 [-m|--min-hash-count HASHES] 
                 [-t|--tweak-mode] 
                 [-p|--full-power-mode] 
                 [-d|--debug-infos] 
                 [-h|--help]'
EOF
            echo "-w default is ${MIN_WATT_COUNT} seconds"
            echo "-m default is ${MIN_HASH_COUNT} hashes"
            echo "-t runs the script infinitely, ignores -w / -m, prepared for EFFICENCY tuning mode via tweak_commands.sh"
            echo "-p runs the script infinitely. ignores -w / -m, prepared for FULL POWER Mode via tweak_commands.sh"
            echo "   If both -t and -p are present then only the last one comes into effect."
            echo "-d keeps temporary files for debugging purposes"
            echo "-h this help message"
            echo ""
            echo "You can run the benchmarking in 3 major modes:"
            echo "1. Default mode, which is initially all offsets 0 and auto settings on"
            echo "   After tweaking or tuning the new EFFICIENCY values become the overall Default mode"
            echo "2. Tuning for best EFFICIENCY qoutient of Hashes per Watts (option -t)"
            echo "3. Tuning for MAXIMUM Hashes regardless of power and accordingly FULL POWER mode (option -p)"
            echo ""
            echo "This means:"
            echo "- GPUs ALWAYS start up with the Default mode settings."
            echo "- Once tweaked respectively tuned for EFFICIENCY, the GPUs Default mode is changed."
            echo "- Each Algorithm has its own Default mode sttings."
            echo ""
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
    ####################################################################################
    ###
    ###                        7. SCHREIBEN DER DATEN DES BENCHMARKING
    ###
    ####################################################################################

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


    # Der Zeitstempel dieser Messung, nach dem Herausfallen aus dem Sleep am Ende der Endlosschleife,
    # dem Eintritt in die On_Exit() Routine, dem kill <ccminer.pid und 1 Sekunde sleep.
    bENCH_DATE=$BENCH_OR_TWEAK_END

    # Die WATT-Werte noch zu Integern machen und dabei aufrunden
    avgWATT=$((${avgWATT/%[.][[:digit:]]*}+1))
    maxWATT=$((${maxWATT/%[.][[:digit:]]*}+1))

    declare -i tempazb=0
    # Full Power ($?=100) oder Effizienz Messung ($?=99)
    [[ ${bENCH_KIND} -eq 888 ]] \
        && sed_search='/"Name": "'${algo}'",/{                   # if found ${algo}
             N;N;N;/"MinerName": "'${miner_name}'",/{            # appe(N)d 3 lines; if found ${miner_name}
                 N;/"MinerVersion": "'${miner_version}'",/{      # appe(N)d 1 line;  if found ${miner_version}
                     N;N;N;N;N;N;N;N;/"BENCH_KIND": 888,/{       # appe(N)d 8 lines; if found BENCH_KIND 888
             =;Q100}}}};                                         # (=) print line-number; Quit and set $?=100
             ${Q99}                                              # on last line Quit and set $?=99 (NOT FOUND)
             ' \
        || sed_search='/"Name": "'${algo}'",/{                   # if found ${algo}
             N;N;N;/"MinerName": "'${miner_name}'",/{            # appe(N)d 3 lines; if found ${miner_name}
                 N;/"MinerVersion": "'${miner_version}'",/{      # appe(N)d 1 line;  if found ${miner_version}
                     N;N;N;N;N;N;N;N;/"BENCH_KIND": 888,/d;{     # appe(N)d 8 lines; if found 888, (d)elete and continue
             =;Q100}}}};                                         # otherwise (=) print line-number; Quit and set $?=100
             ${Q99}                                              # on last line Quit and set $?=99 (NOT FOUND)
             '
    sed -n -e "${sed_search}" \
        ${IMPORTANT_BENCHMARK_JSON} \
        > tempazb
    _Q_=$?
    # Die BenchmarkSpeed Zeile haben wir auf der Suche nach dem 888 um 7 Zeilen überschritten.
    # Deshalb müssen wir die abziehen, FALLS er etwas gefunden hat (Q100)
    [[ ${_Q_} -eq 100 ]] && tempazb=$(($(< "tempazb")-7))

    #" <-- wegen richtigem Highlightning in meinem proggi ... bitte nicht entfernen
    ## Benchmark Datei bearbeiten "wenn diese schon besteht"(wird erstmal von ausgegangen) und die zeilennummer ausgeben. 
    # cat benchmark_GPU-742cb121-baad-f7c4-0314-cfec63c6ec70.json |grep -n -A 4 equihash | grep BenchmarkSpeed 
    # Zeilennummer ; Name ; HASH, 
    # 80-      "BenchmarkSpeed": 469.765087, 
    # 
    # Benschmarkspeeed HASH und WATT werte
    # (original benchmakŕk.json) für herrausfinden wo an welcher stelle ersetzt werden muss  
    # 
    # bechchmarkfile="benchmark_${gpu_uuid}.json"
    # gpu index uuid in "../${gpu_uuid}/benchmark_${gpu_uuid}.json" 
    #
    # Zu 1. Backup Datei erstellen
    #
    cp -f ${IMPORTANT_BENCHMARK_JSON} ${IMPORTANT_BENCHMARK_JSON}.BAK

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

    # Haben wir in den Testfällen ohne Internet entdeckt, dass dieses Array dann leer ist.
    # Irgendeinen Wert brauchen wir aber, also nehmen wir einfach 777, bis er beim nächsten Benchmark mit Internet-Zugang korrigiert wird.
    if [[ ${#ALGO_IDs[${algo}]}   -eq 0 ]]; then ALGO_IDs[${algo}]=777; fi

    # ## in der temp_algo_zeile steht die zeilen nummer zum editieren des hashwertes
    if [ ${tempazb} -gt 1 ] ; then
        #
        # Das alles dient der Vorbereitung der zeilengenauen Bearbeitung der IMPORTANT_BENCHMARK_JSON
        #
        echo "Die NiceHashID \"${ALGO_IDs[${algo}]}\" wird nun in der Zeile $((tempazb-4)) eingefügt" 
        echo "der Hash wert $avgHASH wird nun in der Zeile $tempazb eingefügt"
        echo "der WATT wert $avgWATT wird nun in der Zeile $((tempazb+2)) eingefügt"
        echo "$((tempazb-4))s/: [0-9.]*,$/: ${ALGO_IDs[${algo}]},/"  >sed_insert_on_different_lines_cmd
        echo     "${tempazb}s/: [0-9.]*,$/: ${avgHASH},/"           >>sed_insert_on_different_lines_cmd
        echo "$((tempazb+2))s/: [0-9.]*,$/: ${avgWATT},/"           >>sed_insert_on_different_lines_cmd
        if [[ ${#maxWATT} -ne 0 ]]; then
            echo "der MAX_WATT Wert ${maxWATT} wird nun in der Zeile $((tempazb+3)) eingefügt"
            echo "$((tempazb+3))s/: [0-9.]*,$/: ${maxWATT},/"       >>sed_insert_on_different_lines_cmd
        fi
        if [[ ${#hashCount} -ne 0 ]]; then
            echo "der HASHCOUNT Wert ${hashCount} wird nun in der Zeile $((tempazb+4)) eingefügt"
            echo "$((tempazb+4))s/: [0-9.]*,$/: ${hashCount},/"     >>sed_insert_on_different_lines_cmd
        fi
        if [[ ${#hASH_DURATION} -ne 0 ]]; then
            echo "der HASH_DURATION Wert ${hASH_DURATION} wird nun in der Zeile $((tempazb+5)) eingefügt"
            echo "$((tempazb+5))s/: [0-9.]*,$/: ${hASH_DURATION},/" >>sed_insert_on_different_lines_cmd
        fi
        if [[ ${#bENCH_DATE} -ne 0 ]]; then
            echo "der BENCH_DATE Wert ${bENCH_DATE} wird nun in der Zeile $((tempazb+6)) eingefügt"
            echo "$((tempazb+6))s/: [0-9.]*,$/: ${bENCH_DATE},/"    >>sed_insert_on_different_lines_cmd
        fi
        if [[ ${#bENCH_KIND} -ne 0 ]]; then
            echo "der BENCH_KIND Wert ${bENCH_KIND} wird nun in der Zeile $((tempazb+7)) eingefügt"
            echo "$((tempazb+7))s/: [0-9.]*,$/: ${bENCH_KIND},/"    >>sed_insert_on_different_lines_cmd
        fi
        if [[ ${#minerFee} -ne 0 ]]; then
            echo "der MinerFee Wert ${minerFee} wird nun in der Zeile $((tempazb+8)) eingefügt"
            echo "$((tempazb+8))s/: [0-9.]*,$/: ${minerFee},/"      >>sed_insert_on_different_lines_cmd
        fi
        if [[ ${#grafik_clock} -ne 0 ]]; then
            echo "der GRAFIK_CLOCK Wert ${grafik_clock} wird nun in der Zeile $((tempazb+9)) eingefügt"
            echo "$((tempazb+9))s/: [0-9.]*,$/: ${grafik_clock},/"  >>sed_insert_on_different_lines_cmd
        fi
        if [[ ${#memory_clock} -ne 0 ]]; then
            echo "der MEMORY_CLOCK Wert ${memory_clock} wird nun in der Zeile $((tempazb+10)) eingefügt"
            echo "$((tempazb+10))s/: [0-9.]*,$/: ${memory_clock},/" >>sed_insert_on_different_lines_cmd
        fi
        if [[ ${#fan_speed}    -ne 0 ]]; then
            echo "der FanSpeed Wert ${fan_speed} wird nun in der Zeile $((tempazb+11)) eingefügt"
            echo "$((tempazb+11))s/: [0-9.]*,$/: ${fan_speed},/"    >>sed_insert_on_different_lines_cmd
        fi
        if [[ ${#power_limit}  -ne 0 ]]; then
            echo "der POWER_LIMIT Wert ${power_limit} wird nun in der Zeile $((tempazb+12)) eingefügt"
            echo "$((tempazb+12))s/: [0-9.]*,$/: ${power_limit},/"  >>sed_insert_on_different_lines_cmd
        fi
        if [[ ${#less_threads}  -ne 0 ]]; then
            echo "der LESS_THREADS Wert ${less_threads} wird nun in der Zeile $((tempazb+13)) eingefügt"
            echo "$((tempazb+13))s/: [0-9.]*$/: ${less_threads}/"   >>sed_insert_on_different_lines_cmd
        fi
        #
        # Das ist die tatsächliche Bearbeitung der IMPORTANT_BENCHMARK_JSON
        #
        sed -i -f sed_insert_on_different_lines_cmd ${IMPORTANT_BENCHMARK_JSON}
    else
        #
        # Der Algo für diese Minerversion war nicht vorhanden und wird nun zu IMPORTANT_BENCHMARK_JSON hinzugefügt
        #
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
        if [[ ${#maxWATT}             -eq 0 ]]; then maxWATT=0;         fi
        if [[ ${#hashCount}           -eq 0 ]]; then hashCount=0;       fi
        if [[ ${#hASH_DURATION}       -eq 0 ]]; then hASH_DURATION=0;   fi
        if [[ ${#bENCH_DATE}          -eq 0 ]]; then bENCH_DATE=0;      fi
        if [[ ${#bENCH_KIND}          -eq 0 ]]; then bENCH_KIND=0;      fi
        if [[ ${#minerFee}            -eq 0 ]]; then minerFee=0;        fi
        if [[ ${#miner_base_type}     -eq 0 ]]; then miner_base_type=9; fi
        if [[ ${#grafik_clock}        -eq 0 ]]; then grafik_clock=0;    fi
        if [[ ${#memory_clock}        -eq 0 ]]; then memory_clock=0;    fi
        if [[ ${#fan_speed}           -eq 0 ]]; then fan_speed=0;       fi
        if [[ ${#power_limit}         -eq 0 ]]; then power_limit=0;     fi
        if [[ ${#less_threads}        -eq 0 ]]; then less_threads=0;    fi
        BLOCK_VALUES=(
            ${algo}
            ${ALGO_IDs[${algo}]}
            ${miner_base_type}
            ${miner_name}
            ${miner_version}
            ${avgHASH}
            ""
            ${avgWATT}
            ${maxWATT}
            ${hashCount}
            ${hASH_DURATION}
            ${bENCH_DATE}
            ${bENCH_KIND}
            ${minerFee}
            ${grafik_clock}
            ${memory_clock}
            ${fan_speed}
            ${power_limit}
            ${less_threads}
        )
        echo "Der Algo wird zur Datei ${IMPORTANT_BENCHMARK_JSON} hinzugefügt"
        sed -i -e '/^ \+]/,/}$/d'  ${IMPORTANT_BENCHMARK_JSON}
        printf ",   {\n"         >>${IMPORTANT_BENCHMARK_JSON}
        for (( i=0; $i<${#BLOCK_FORMAT[@]}; i++ )); do
            printf "${BLOCK_FORMAT[$i]}" "${BLOCK_VALUES[$i]}" \
                | tee -a           ${IMPORTANT_BENCHMARK_JSON}
        done
        printf "    }\n  ]\n}\n" >>${IMPORTANT_BENCHMARK_JSON}
    fi
}

function _delete_temporary_files () {
    rm -f uuid bensh_gpu_30s_.index tweak_to_these_logs watt_bensh_30s.out COUNTER temp_hash_bc_input \
       temp_hash_sum temp_watt_sum watt_bensh_30s_max.out tempazb temp_hash temp_einheit \
       HASHCOUNTER benching_${gpu_idx}_algo sed_insert_on_different_lines_cmd* ccminer.pid \
       ${READY_FOR_SIGNALS} MULTI_ALGO_INFO.json boo_count
}
_delete_temporary_files

function _On_Exit () {
    ####################################################################################
    ###
    ###                        6. AUSWERTUNG DES BENCHMARKING
    ###
    ####################################################################################

    # Als wichtiges Kennzeichen für den Ausstieg, denn da werden die Logdateien gesichert
    # und die Werte in die .json Datei geschrieben.
    # Das darf nicht geschehen, wenn das Programm vorher abnormal beendet wurde und gar keine Daten erhoben wurden
    #
    if [[ ${BENCHMARKING_WAS_STARTED} -eq 1 ]]; then
        # CCminer stoppen
        echo "... Wattmessen ist beendet!!" 
        echo "Beenden des Miners..."
        kill -15 $(< "ccminer.pid")

        # Bis jetzt könnten Werte in das $BENCHLOGFILE hineingekommen sein.
        # Das ist vor allem für den Tweak-Fall interessant, weil der das $BENCHLOGFILE nochmal
        # durchgehen muss! Denn es könnte noch ein Wert dazu gekommen sein!
        # ---> BITTE NOCHMAL NACHPROGRAMMIEREN!                      <---
        # ---> MUSS DAS BENCHFILE AUCH IM TWEAKMODE NOCHMAL SCANNEN! <---
        #
        BENCH_OR_TWEAK_END=$(date +%s)

        if [ ! $NoCards ]; then
            sleep $Erholung
        fi

        echo "Beenden des Logger-Terminals..."
        kill_pids=$(ps -ef \
           | grep -e "${Bench_Log_PTY_Cmd}" \
           | grep -v 'grep -e ' \
           | gawk -e 'BEGIN {pids=""} {pids=pids $2 " "} END {print pids}')
        if [ ! "$kill_pids" == "" ]; then
            printf "Killing all ${Bench_Log_PTY_Cmd} processes... "
            kill $kill_pids
            printf "done.\n"
        fi

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
        temp_einheit=$(cat ${BENCHLOGFILE} | sed -e 's/ *(yes!)$//g' | grep -m1 "/s$" \
                              | gawk -e '/H\/s$/ {print "H/s"; next}{print "Sol/s"}')
        if [ ${STOP_AFTER_MIN_REACHED} -eq 1 ]; then
            ###
            ### BENCHMARKING MODE was invoked
            ###
            hashCount=$(cat ${BENCHLOGFILE}  \
                      | sed -e 's/ *(yes!)$//g' \
                      | grep "/s$" \
                      | tee >(gawk -v kBase=${k_base} -M -e "${prepare_hashes_for_bc}" \
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
            
        maxWATT=$(< "watt_bensh_30s_max.out")

        # Ist das wirklich noch nötig?
        printf " Summe WATT   : %12s; Messwerte: %5s\n" $wattSum $wattCount
        printf " Durchschnitt : %12s\n" $avgWATT
        printf " Max WATT Wert: %12s\n" ${maxWATT}
        printf " Summe HASH   : %12s; Messwerte: %5s\n" ${hashSum:0:$(($(expr index "$hashSum" ".")+2))} $hashCount
        printf " Durchschnitt : %12s %6s\n" ${avgHASH:0:$(($(expr index "${avgHASH}" ".")+2))} ${temp_einheit}

        # bENCH_START wird direkt vor dem Start des Miners gesetzt.
        # Im Falle des Tweakens wird bENCH_START nach jedem Tweak-Kommando neu gesetzt und der hashCount auf 0 zurückgesetzt.
        # Die Differenz aus ${BENCH_OR_TWEAK_END} und ${bENCH_START} ist also die tatsächliche Dauer zur Ermittlung der Anzahl an hashCount Werten
        hASH_DURATION=$((${BENCH_OR_TWEAK_END}-${bENCH_START}))

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

# Stellt auch die 5 bekannten Befehle in dem Array nvidiaCmd[0-4] zur Verfügung:
#nvidia-smi --id=${gpu_idx} -pl 82 (root powerconsumption)
#nvidia-settings --assign [gpu:${gpu_idx}]/GPUGraphicsClockOffset[3]=170
#nvidia-settings --assign [gpu:${gpu_idx}]/GPUMemoryTransferRateOffset[3]=360
#nvidia-settings --assign [fan:${gpu_idx}]/GPUTargetFanSpeed=66
# Fan-Kontrolle auf MANUELL = 1 oder 0 für AUTOMATISCH
#nvidia-settings --assign [gpu:${gpu_idx}]/GPUFanControlState=1
[[ ${#_NVIDIACMD_INCLUDED} -eq 0 ]] && source ${LINUX_MULTI_MINING_ROOT}/benchmarking/nvidia-befehle/nvidia-query.inc
# Funktionen zum Einlesen von ALGO_NAMES und ALGO_PORTS aus dem Web
[[ ${#_ALGOINFOS_INCLUDED} -eq 0 ]] && source ${LINUX_MULTI_MINING_ROOT}/algo_infos.inc
# Funktionen für das Einlesen aller bekannten Miner und Unterscheidung in Vefügbare sowie Fehlende.
[[ ${#_MINERFUNC_INCLUDED} -eq 0 ]] && source ${LINUX_MULTI_MINING_ROOT}/miner-func.inc


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
#
# UND:
#      Stellt sicher, dass aktuelle gpu-bENCH.sh Dateien in den GPU-UUID Verzeichnissen sind.
#      Diese sorgen durch "source"-ing dafür, dass die JSON-Einträge und Arrays zusammenpassen
#
# Das entsprechende "source"-ing machen wir weiter unten, wenn wir wissen, um welche GPU
#     und welchen $algorithm es sich handelt.
cd ..
source gpu-abfrage.sh
_func_gpu_abfrage_sh
cd ${_WORKDIR_} >/dev/null
gpu_idx_list="${index[@]}"

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


# Die Informationen frisch aus dem Web zu holen ist leider nötig,
# weil wir im Fall des Live-Benchmarkings keine Algos berechnen wollen, für die es 0 gibt.
# Allerdings macht das im laufenden Betrieb schon die algo_multi_abfrage.sh, der wir NICHT dazwischenfunken wollen.
#   Deshalb holen wir die Daten nur dann selbst, wenn die algoID_KURSE_PORTS_WEB älter als 120 Sekunden ist.
#   Denn dann läuft die algo_multi_abfrage.sh nicht
live_mode="lo"
if [[ -f ../I_n_t_e_r_n_e_t__C_o_n_n_e_c_t_i_o_n__L_o_s_t ]]; then
    live_mode="o"
    # Ohne Internetverbindung wird die Funktion _read_in_ALGO_PORTS_KURSE nicht aufgerufen,
    # wodurch die folgenden Arrays leer und nicht definiert sind.
    # Da wir die ALGO_ID des Algo aber auch in die benchmark.JSON schreiben, haben wir ein Problem, das wir lösen,
    #    indem wir die ALGO_ID auf 777 setzen und wissen, dass das falsch ist.
    # Das selbe machen wir unten mit dem algo_port. Der wird im Offline-Modus sowieso nicht benötigt.
    # Der nächste Benchmark mit Internetverbindung wird diesen Wert automatisch korrigieren
    #unset ALGOs;    declare -ag ALGOs
    #unset KURSE;    declare -Ag KURSE
    #unset PORTs;    declare -Ag PORTs
    #unset ALGO_IDs; declare -Ag ALGO_IDs
else
    if [ ! -s ${algoID_KURSE_PORTS_WEB} ] \
           || [[ $(($(date --utc --reference=${algoID_KURSE_PORTS_WEB} +%s)+120)) -lt $(date +%s) ]]; then
        declare -i secs=1
        _prepare_ALGO_PORTS_KURSE_from_the_Web
        while [ $? -eq 1 ]; do
            echo "Waiting for valid File ${algoID_KURSE_PORTS_WEB} from the Web, Second Nr. $secs"
            sleep 1
            let secs++
            _prepare_ALGO_PORTS_KURSE_from_the_Web
        done
    fi
    _read_in_ALGO_PORTS_KURSE
fi

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

# auswahl des devices "eingabe wartend"
if [[ ${ATTENTION_FOR_USER_INPUT} -eq 0 && ${#gpu_idx} -gt 0 && ${#algorithm} -gt 0 ]]; then
    echo "AUTO-BENCHMARKING GPU #${gpu_idx} for Algorithm ${algorithm}"
else
    echo ""
    while :; do
        _prompt="Für welches GPU device soll ein Benchmark druchgeführt werden? ${gpu_idx_list}: "
        read -p "${_prompt}" gpu_idx
        [[ ${gpu_idx} =~ ^[[:digit:]]*$ ]] && [[ ${gpu_idx_list} =~ ^.*${gpu_idx} ]] && break
    done
fi
gpu_uuid=${uuid[${gpu_idx}]}
echo "GPU #${gpu_idx} mit UUID ${gpu_uuid} soll benchmarked werden."

# Sync mit tweak_command.sh
echo ${gpu_idx}  >bensh_gpu_30s_.index
echo ${gpu_uuid} >uuid

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

# Dann gleich Bereitstellung zweier Arrays mit AvailableAlgos und MissingAlgos.
# Die MissingAlgos könnte man in einer automatischen Schleife benchmarken lassen,
# bis es keine MissingAlgos mehr gibt.
#_test_=1
_read_in_ALL_Internal_Available_and_Missing_Miner_Algo_Arrays "${LINUX_MULTI_MINING_ROOT}/miners"


################################################################################
################################################################################
###
###                     3. Auswahl des Miners
###
################################################################################
################################################################################

if [[ ${ATTENTION_FOR_USER_INPUT} -eq 0 && ${#gpu_idx} -gt 0 && ${#algorithm} -gt 0 ]]; then
    read algo miner_name miner_version muck888 <<<"${algorithm//#/ }"
else
    declare -a minerChoice minerVersion
    echo ""
    echo " Die folgenden Miner können getestet werden:"
    echo ""
    unset i;   declare -i i=0
    choice_list=''
    for minerName in ${ALLE_MINER[@]}; do
        read minerChoice[$i] minerVersion[$i] <<<"${minerName//#/ }"
        printf " %2i : %s V. %s\n" $((i+1)) ${minerChoice[$i]} ${minerVersion[$i]}
        i+=1; choice_list+="$i "
    done
    echo ""
    while :; do
        read -p "Welchen Miner möchtest Du mit GPU #${gpu_idx} benchmarken/tweaken? ${choice_list}: " choice
        [[ ${choice_list} =~ ^.*${choice} ]] && break
    done

    miner_name=${minerChoice[$(($choice-1))]}
    miner_version=${minerVersion[$(($choice-1))]}
fi

################################################################################
#
# Ab hier steht der Miner fest und die Variablen  miner_name und miner_version dürfen NICHT MEHR VERÄNDERT WERDEN!
#
################################################################################

declare -n actInternalAlgos="Internal_${miner_name}_${miner_version//\./_}_Algos"
declare -n actMissingAlgos="Missing_${miner_name}_${miner_version//\./_}_Algos"

# Dieser Aufruf zieht die entsprechenden Variablen rein, die für den Miner
# definiert sind, damit die Aufrufmechanik für alle Miner gleich ist.
source ../miners/${miner_name}#${miner_version}.starts


####################################################################################
################################################################################
###
###                     4. Auswahl des zu benchmarkenden Algos
###
################################################################################
####################################################################################

################################################################################
###
###          4.1. Anzeige aller fehlenden Algos, die möglich wären
###
################################################################################

# Vorher ausfiltern aller GLOBAL und Dauerhaft disabled Algos, denn sie sollen nicht angeboten werden
# und die Automatik soll sie nicht durchführen
#    Zunächst die über BENCH_ALGO_DISABLED Algos rausnehmen...
if [ -s ../BENCH_ALGO_DISABLED ]; then
    unset BENCH_ALGO_DISABLED_ARR
    cat ../BENCH_ALGO_DISABLED | grep -E -v -e '^#|^$' | readarray -n 0 -O 0 -t BENCH_ALGO_DISABLED_ARR
    for lfdAlgorithm in ${BENCH_ALGO_DISABLED_ARR[@]}; do
        unset actInternalAlgos[${lfdAlgorithm}*]
        actMissingAlgos=( ${actMissingAlgos[@]/${lfdAlgorithm}*/} )
        [ $debug -eq 1 ] && echo "Algo ${lfdAlgorithm} wegen des Vorhandensein in der Datei BENCH_ALGO_DISABLED herausgenommen."
    done
fi

#    Zusätzlich die über GLOBAL_ALGO_DISABLED Algos rausnehmen...
if [ -s ../GLOBAL_ALGO_DISABLED ]; then
    unset GLOBAL_ALGO_DISABLED_ARR
    cat ../GLOBAL_ALGO_DISABLED | grep -E -v -e '^#|^$' | readarray -n 0 -O 0 -t GLOBAL_ALGO_DISABLED_ARR
    for ((i=0; $i<${#GLOBAL_ALGO_DISABLED_ARR[@]}; i++)) ; do

        unset disabled_algos_GPUs
        read -a disabled_algos_GPUs <<<${GLOBAL_ALGO_DISABLED_ARR[$i]//:/ }
        DisAlgo=${disabled_algos_GPUs[0]}
        if [ ${#disabled_algos_GPUs[@]} -gt 1 ]; then
            # Nur für bestimmte GPUs disabled. Wenn die eigene GPU nicht aufgeführt ist, übergehen
            [[ ! ${GLOBAL_ALGO_DISABLED_ARR[$i]} =~ ^.*:${gpu_uuid} ]] && unset DisAlgo
        fi
        if [ -n "${DisAlgo}" ]; then
            unset actInternalAlgos[${DisAlgo}]
            for (( a=0; $a<${#actMissingAlgos[@]}; a++ )); do
                [ "${actMissingAlgos[$a]}" == "${DisAlgo}" ] && unset actMissingAlgos[$a]
            done
            [ $debug -eq 1 ] && echo "Algo ${DisAlgo} wegen des Vorhandenseins in der Datei GLOBAL_ALGO_DISABLED herausgenommen."
        fi
    done
fi

if [ -z "${actInternalAlgos[${algo}]}" ]; then
    [ ${ATTENTION_FOR_USER_INPUT} -eq 0 ] && exit 99
    echo "Der Algo ${algo} ist DISABLED und kann im Moment nicht getestet werden."
    read -p "Das Programm wird nach <ENTER> mit den selben Parametern \"${initialParameters}\" neu gestartet..." restart
    exec $0 ${initialParameters}
fi

# Checken, ob wir für alle Algos auch schon Werte in der ../${gpu_uuid}/benchmark_${gpu_uuid}.json haben
# Diejenigen Algos anzeigen, zu denen es noch keine Eintragsmöglichkeit gibt.
# Das wurde nach dem Einlesen in ALLE_MINER gemacht und es wurden auch die beiden Arrays
#     "Missing_${miner_name}_${miner_version//\./_}_Algos" und
#     "Available_${miner_name}_${miner_version//\./_}_Algos" erstellt,
#     die die Namen der entsprechenden algos als Werte haben.
if [[ ${ATTENTION_FOR_USER_INPUT} -eq 1 ]]; then
    if [ -n "${actMissingAlgos[@]}" ]; then
        for lfdAlgo in ${actMissingAlgos[@]}; do
            printf "%17s <-------------------- Bitte Benchmark durchführen. Noch keine Daten vorhanden\n" ${lfdAlgo}
        done
    fi
fi

################################################################################
###
###          4.2. Auswahl des Algos durch den Benutzer...
###
################################################################################

# Wegen des Startparameters die Miner... oder sollen wir das auch auf eine glatte Variable umstellen,
# die man ohne Funktion rufen kann? Könnte man sich einen Funktionsaufruf sparen.
unset InternalAlgos
declare -A InternalAlgos
if [[ ${ATTENTION_FOR_USER_INPUT} -eq 0 && ${#gpu_idx} -gt 0 && ${#algorithm} -gt 0 ]]; then
    for lfdAlgo in "${!actInternalAlgos[@]}"; do
        InternalAlgos[${lfdAlgo}]=${actInternalAlgos[${lfdAlgo}]}
    done
else
    declare -a menuItems=( "${!actInternalAlgos[@]}" )
    numAlgos=${#menuItems[@]}

    menuItems_list=''
    if [ $numAlgos -gt 1 ]; then
        for i in ${!menuItems[@]}; do
            menuItems_list+="a$i "
            printf "%10s=%17s" "a$i" "\"${menuItems[$i]}\""
            if [ $(((i+1) % 3)) -eq 0 ]; then printf "\n"; fi
            # Für alle, die intern andere Namen benutzen als wie sie sie abliefern
            InternalAlgos[${menuItems[$i]}]=${actInternalAlgos[${menuItems[$i]}]}
        done
        printf "\n"

        while :; do
            echo ${menuItems_list}
            read -p "Welchen Algo soll Miner ${miner_name} ${miner_version} mit GPU #${gpu_idx} testen : " algonr
            # Das matched beides ein ganzes Wort
            REGEXPAT="\<${algonr}\>"
            REGEXPAT="\b${algonr}\b"
            [[ ${menuItems_list} =~ ${REGEXPAT} ]] && break
        done
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
        read -p "Das Programm wird nach <ENTER> mit den selben Parametern \"${initialParameters}\" neu gestartet..." restart
        exec $0 ${initialParameters}
    fi
    algo=${menuItems[${algonr:1}]}

    algorithm="${algo}#${miner_name}#${miner_version}"
    # Hier ist die Stelle, an der wir den $algorithm korrigieren, wenn wir uns für den Full Power -p Modus
    # per Kommandozeilenparameter -p entschieden haben:
    [[ ${bENCH_KIND} -eq 888 ]] && algorithm+='#888'

    # Sync mit tweak_command.sh
    echo "${algorithm}" >benching_${gpu_idx}_algo

    echo "das ist der NH-Algo,    den du ausgewählt hast : ${algo}"
    echo "das ist der \$algorithm, den du ausgewählt hast : ${algorithm}"
    if [ "$algo" = "scrypt" ] ; then
        echo "Dieser Algo ist nicht mehr mit Grafikkarten lohnenswert. Dafür ermitteln wir keine Werte mehr."
        read -p "Das Programm wird nach <ENTER> mit den selben Parametern \"${initialParameters}\" neu gestartet..." restart
        exec $0 ${initialParameters}
    fi
fi

################################################################################
###
###          4.3. Vorbereitung aller benötigten Variablen
###
################################################################################

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
rm -f ${BENCHLOGFILE} ${TWEAKLOGFILE} COUNTER watt_bensh_30s.out watt_bensh_30s_max.out

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
    echo "$TWEAK_CMD_LOG"       >tweak_to_these_logs
    echo "watt_bensh_30s.out"  >>tweak_to_these_logs
    echo "${BENCHLOGFILE}"     >>tweak_to_these_logs
    declare -i queryCnt=0
fi
countWatts=1
countHashes=1
declare -i COUNTER=0
declare -i wattCount=0
declare -i hashCount=0
maxWATT=0

####################################################################################
################################################################################
###
###                        5. START DES BENCHMARKING
###
################################################################################
####################################################################################

################################################################################
###
###          5.1. LIVE oder OFFLINE benchmarken?
###
################################################################################

#[ "${KURSE[$algo]}" == "0" ] && live_mode=${live_mode//l/}
[ -z "${KURSE[$algo]}" -o "${KURSE[$algo]}" == "0" ] && live_mode="o"
[ -z "${BENCH_START_CMD}" ]  && live_mode=${live_mode//o/}

if [ -z "$live_mode" ]; then
    # Weder LIVE-Mode noch OFFLINE-Mode möglich
    [ ${ATTENTION_FOR_USER_INPUT} -eq 0 ] && exit 99
    echo "Weder der LIVE-Mode (wegen Kurs=0) noch der OFFLINE-Mode (wegen fehlendem BENCH_START_CMD) sind im Moment möglich."
    read -p "Das Programm wird nach <ENTER> mit den selben Parametern \"${initialParameters}\" neu gestartet..." restart
    exec $0 ${initialParameters}
elif [ "$live_mode" == "l" ]; then
    # Ausschliesslich LIVE mode möglich
    [ ${ATTENTION_FOR_USER_INPUT} -eq 1 ] && \
        echo "Im Moment ist nur der LIVE-Mode möglich, automatische Einstellung auf LIVE-Mode."
elif [ "$live_mode" == "o" ]; then
    # Ausschliesslich OFFLINE mode möglich
    [ ${ATTENTION_FOR_USER_INPUT} -eq 1 ] && \
        echo "Im Moment ist nur der OFFLINE-Mode möglich, automatische Einstellung auf OFFLINE-Mode."
else
    if [ ${ATTENTION_FOR_USER_INPUT} -eq 1 ]; then
        # Benutzer kann eine Auswahl treffen.
        echo ""
        echo "Noch eine letzte Frage:"
        echo "Willst Du LIVE oder OFFLINE Benchmarken oder Tunen?"
        while :; do
            read -p "--> l <-- für LIVE    und    --> o <-- für OFFLINE : " live_mode
            REGEXPAT="^[lo]$"
            [[ "${live_mode}" =~ ${REGEXPAT} ]] && break
        done
    else
        # Automatik bevorzugt den LIVE-Mode, weil die Kosten für den Test so oder so anfallen und im Live-Mode
        #           wenigstens noch ein paar SHares abgeliefert und bezahlt werden.
        live_mode="l"
    fi
fi

################################################################################
###
###          5.2. Setzen der GPU-Einstellungen
###
################################################################################

# Funktion zum Einlesen der Benchmarkdaten nach eventuellem vorherigen Update der JSON Datei
cd ../${gpu_uuid}
source gpu-bENCH.sh
cd ${_WORKDIR_} >/dev/null

# Alle Einstellungen aller Algorithmen der ausgewählten GPU einlesen
# Es sind jetzt jede Menge Assoziativer Arrays mit Werten aus der JSON da, z.B. die folgenden 4
_read_IMPORTANT_BENCHMARK_JSON_in without_miners

# Nvidia-Befhele zum tunen, die wir kennen und so gut es ging abstrahiert haben:
#nvidiaCmd[0]="nvidia-settings --assign [gpu:%i]/GPUGraphicsClockOffset[3]=%i"
#nvidiaCmd[1]="nvidia-settings --assign [gpu:%i]/GPUMemoryTransferRateOffset[3]=%i"
#nvidiaCmd[2]="nvidia-settings --assign [fan:%i]/GPUTargetFanSpeed=%i"
#nvidiaCmd[3]="./nvidia-befehle/smi --id=%i -pl %i"
#nvidiaCmd[4]="nvidia-settings --assign [gpu:%i]/GPUFanControlState=%i"
_setup_Nvidia_Default_Tuning_CmdStack

echo""
echo "Kurze Zusammenfassung:"
echo "GPU #${gpu_idx} mit UUID ${gpu_uuid} soll benchmarked werden."
echo "Das ist der Miner,      den Du ausgewählt hast : ${miner_name} ${miner_version}"
echo "das ist der NH-Algo,    den du ausgewählt hast : ${algo}"
echo "das ist der \$algorithm, den du ausgewählt hast : ${algorithm}"
[ "${InternalAlgos[$algo]}" != "${algo}" ] && echo "Das ist der Miner-Interne Algoname: ${InternalAlgos[$algo]}"
echo "Du hast Dich für den " $([ "$live_mode" == "l" ] && echo "LIVE" || echo "OFFLINE") " Modus entschieden"
echo ""
echo "DIE FOLGENDEN KOMMANDOS WERDEN NACH BESTÄTIGUNG ABGESETZT:"
for (( i=0; $i<${#CmdStack[@]}; i++ )); do
    echo "---> ${CmdStack[$i]} <---"
done

################################################################################
###
###          5.3. Zusammensetzung des Startkommandos
###
################################################################################

# Dieser Aufruf zieht die entsprechenden Variablen rein, die für den Miner
# definiert sind, damit die Aufrufmechanik für alle gleich ist.
# Musste wegen der LIVE/OFFLINE-Abfrage weiter oben includiert werden
#source ../miners/${miner_name}#${miner_version}.starts

# ---> Die folgenden Variablen müssen noch vollständig implementiert werden! <---
# "LOCATION eu, usa, hk, jp, in, br"  <--- von der Webseite https://www.nicehash.com/algorithm
continent="eu"        # Noch nicht vollständig implementiert!      <--------------------------------------
worker="1060"         # Noch nicht vollständig implementiert!      <--------------------------------------

algo_port=${PORTs[${algo}]}
if [ $NoCards ]; then algo_port=777; fi


# Jetzt bauen wir den Benchmakaufruf zusammen, der in dem .inc entsprechend vorbereitet ist.
# 1. Erzeugung der Parameterliste

case "$live_mode" in

    "l")
        # Diese Funktion musste leider erfunden werden wegen der internen anderen Algonamen,
        # die NiceHash willkürlich anders benannt hat.
        # So rufen wir eine Funktion, wenn sie definiert wurde.
        declare -f PREP_LIVE_PARAMETERSTACK &>/dev/null && PREP_LIVE_PARAMETERSTACK
        PARAMETERSTACK=""
        for (( i=0; $i<${#LIVE_PARAMETERSTACK[@]}; i++ )); do
            declare -n param="${LIVE_PARAMETERSTACK[$i]}"
            PARAMETERSTACK+="${param} "
        done

        # JETZT KOMMT DAS KOMPLETTE KOMMANDO ZUM STARTEN DES MINERS IN DIE VARIABLE ${minerstart}
        printf -v minerstart "${LIVE_START_CMD}" ${PARAMETERSTACK}
        ;;

    "o")
        # Diese Funktion musste leider erfunden werden wegen der internen anderen Algonamen,
        # die NiceHash willkürlich anders benannt hat.
        # So rufen wir eine Funktion, wenn sie definiert wurde.
        declare -f PREP_BENCH_PARAMETERSTACK &>/dev/null && PREP_BENCH_PARAMETERSTACK
        PARAMETERSTACK=""
        for (( i=0; $i<${#BENCH_PARAMETERSTACK[@]}; i++ )); do
            declare -n param="${BENCH_PARAMETERSTACK[$i]}"
            PARAMETERSTACK+="${param} "
        done

        # JETZT KOMMT DAS KOMPLETTE KOMMANDO ZUM STARTEN DES MINERS IN DIE VARIABLE ${minerstart}
        printf -v minerstart "${BENCH_START_CMD}" ${PARAMETERSTACK}
        ;;
esac

################################################################################
###
###          5.4. Letzte Abfrage, dann Startschuss setzen und Kommandos absetzen
###
################################################################################

echo "---> DER START DES MINERS SIEHT SO AUS: <---"
echo "${minerstart} >>${BENCHLOGFILE} &"

if [ ${ATTENTION_FOR_USER_INPUT} -eq 1 ]; then
    read -p "ENTER für OK und Benchmark-Start, <Ctrl>+C zum Abbruch " startIt
fi

# GPU-Kommandos absetzen...
for (( i=0; $i<${#CmdStack[@]}; i++ )); do
    ${CmdStack[$i]}
done

################################################################################
###
###          5.5. Miner Starten und Logausgabe in eigenes Terminal umleiten
###
################################################################################

if [ $NoCards ]; then
    if [ ! -f "${BENCHLOGFILE}" ]; then
        if [[ "${miner_name}" == "miner" ]]; then
            #sed -e 's/\x1B[[][[:digit:]]*m//g' equihash.log >${BENCHLOGFILE}
            cp -f equihash.log ${BENCHLOGFILE}
        elif [[ "${miner_name}" == "zm" ]]; then
            printf ""
        else
            cp test/benchmark_blake256r8vnl_GPU-742cb121-baad-f7c4-0314-cfec63c6ec70.fake ${BENCHLOGFILE}
            # cp test/bnch_retry_catch_fake.log ${BENCHLOGFILE}
        fi
    fi
fi  ## $NoCards

# Startsekunde festhalten.
# Wir halten auch die Sekunde nach dem Killing des Miners bei Eintritt in die On_Exit() Routine fest.
# Wir könnten also überlegen, ob wir Endesekunde - Startsekunde als Messdauer für die Hashwerte festhalten?
# Wir geben es mal beides aus.
# Dann sehen wir, wie stark eine eventuelle Diskrepanz auftritt
bENCH_START=$(date +%s)
BENCHMARKING_WAS_STARTED=1

${minerstart} >>${BENCHLOGFILE} &
echo $! > ccminer.pid
Bench_Log_PTY_Cmd="tail -f ${BENCHLOGFILE}"
gnome-terminal -e "${Bench_Log_PTY_Cmd}"
#if [ ! $NoCards ]; then
#    sleep 3
#fi


################################################################################
###
###          5.6. Wattmessung starten (3 Sekunden nach dem Minerstart !? )
###
################################################################################

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
                       | sed -e 's/ *(yes!)$//g' \
                       | grep -c "/s$")
    if [ $hashCount -ge $MIN_HASH_COUNT ]; then countHashes=0; fi

    if [ ! ${STOP_AFTER_MIN_REACHED} -eq 1 ]; then
        ###
        ### TWEAKING MODE
        ###
        TWEAK_CMD_LOG_AGE=$(stat -c %Y ${TWEAK_CMD_LOG})
        if [ $new_TweakCommand_available -lt ${TWEAK_CMD_LOG_AGE} ]; then
            new_TweakCommand_available=${TWEAK_CMD_LOG_AGE}
            bENCH_START=${TWEAK_CMD_LOG_AGE}
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
                      | sed -e 's/ *(yes!)$//g' \
                      | grep -e "/s$" \
                      | tee >(gawk -v kBase=${k_base} -M -e "${prepare_hashes_for_bc}" \
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
                      | sed -e 's/ *(yes!)$//g' \
                      | grep "/s$" \
                      | tee >(gawk -v kBase=${k_base} -M -e "${prepare_hashes_for_bc}" \
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

