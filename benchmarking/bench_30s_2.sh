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
# Exit-Stati im --auto Mode:
#   99: No benchmark possible
#   98: No algo_port found
#   97: No coins for miningAlgo available - Kann eigentlich nicht auftreten. Bzw. man könnte coin=${miningAlgo} setzen (für CCminer)
#   96: Keine Kombination aus Coin und MiningAlgo in den Offline-Dateien gefunden.
#   95: Keine Hashwerte nach 30s
#   94: Internetconnection Lost detected
#   93: Verbindung zum Server gestört (Retries oder Socket-Errors)
#   92: Abbruch wegen zu vieler Booooooos
#   91: LIVE-Benchmarking nur bei "nh" erlaubt.
#if [ $# -eq 0 ]; then kill -9 $$; fi

# GLOBALE VARIABLEN, nützliche Funktionen
[[ ${#_GLOBALS_INCLUDED} -eq 0     ]] && source ../globals.inc
[[ ${#_LOGANALYSIS_INCLUDED} -eq 0 ]] && source ../logfile_analysis.inc

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
READY_FOR_SIGNALS=.$$_benchmarker_ready_for_kill_signal

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
    case /^Sol\/s *$|^H\/s *$/: faktor=1      ; break
    case /^k/:                  faktor=kBase  ; break
    case /^M/:                  faktor=kBase^2; break
    case /^G/:                  faktor=kBase^3; break
    case /^T/:                  faktor=kBase^4; break
    case /^P/:                  faktor=kBase^5; break
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
            echo $0 <<EOF '
                 [-w|--min-watt-seconds TIME] 
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

#########################################################################
# Auswertung der 2 Logdateien: Die des Miners und die eigene Wattmessung
# Benötigt werden die folgenden Variablen:
#     $hash_line
#     $watt_line
# Danach sind die folgenden Variablen gültig:
#     hashCount
#     wattCount
#     hashSum
#     wattSum
#     maxWATT
#     avgHASH
#     avgWATT
#     quotient
#     hashCountPerSeconds
_evaluate_BENCH_and_WATT_LOGFILE_and_build_sums_and_averages () {
    #
    # 1. Zähle die Messwerte ab der ersten Zeile des Messzyklus (hashCount bzw. wattCount)...
    # 2. Bilde gleichzeitig die Summe der Werte...
    # 3. Halte gleichzeitig den maximalen Wattwert fest...
    #
    # Zuerst die BenchLog mit den Hashwerten...
    hashCount=$(cat ${BENCHLOGFILE} \
              | tail -n +$hash_line \
              | sed -e 's/ *(yes!)$//g' \
              | gawk -e "${detect_zm_hash_count}" \
              | grep -E -e "/s *$" \
              | tee >(gawk -v kBase=${k_base} -M -e "${prepare_hashes_for_bc}" \
                             | tee ${temp_hash_bc} | bc >${temp_hash_sum} ) \
              | wc -l \
             )
    # ... dann die WattLog
    wattCount=$(cat "${WATTSLOGFILE}" \
              | tail -n +$watt_line \
              | grep -E -o -e "^[[:digit:]]+" \
              | tee >(gawk -M -e 'BEGIN {sum=0} {sum+=$1} END {print sum}' >${temp_watt_sum} ) \
                    >(gawk -M -e 'BEGIN {max=0} {if ($1>max) max=$1 } END {print max}' >${WATTSMAXFILE} ) \
              | wc -l \
             )
    hashSum=$(< ${temp_hash_sum})
    wattSum=$(< ${temp_watt_sum})

    if [ ${hashCount} -gt 0 -a $wattCount -gt 0 -a $hASH_DURATION -gt 0 ]; then
        echo "scale=2; \
              avghash     = $hashSum / $hashCount;     \
              avgwatt     = $wattSum / $wattCount;     \
              quotient    = avghash  / avgwatt;        \
              hashpersecs = $hashSum / $hASH_DURATION; \
              print avghash, \" \", avgwatt, \" \", quotient, \" \", hashpersecs" | bc \
            | read avgHASH avgWATT quotient hashCountPerSeconds
    else
        avgHASH=0; avgWATT=0; quotient=0; hashCountPerSeconds=0
    fi
    maxWATT=$(< "${WATTSMAXFILE}")
    if [[ ${wattSum} == 0 ]]; then
        avgWATT=999.99
        maxWATT=999.99
    fi
}

#########################################################################
#
#             Das ist der Kern der Endlosschleife
#             -----------------------------------
#
# 
#
#########################################################################
_measure_one_whole_WattsHashes_Cycle () {
    ###------------------------------------------------------------------
    ### 1. Wattwert messen und in Datei protokollieren
    ###------------------------------------------------------------------
    if [ ! $NoCards ]; then
        nvidia-smi --id=${gpu_idx} --query-gpu=power.draw --format=csv,noheader \
            | gawk -e 'BEGIN {FS=" "} {print $1}' >>${WATTSLOGFILE}
    else
        echo $((222 + 2 * $wattCount)) >>${WATTSLOGFILE}
    fi

    ###------------------------------------------------------------------
    ### 2. Die Flags für die Minimum Zählwerte prüfen und löschen
    ###------------------------------------------------------------------

    ### Wenn die Minimum Wattwerte Anzahl erreicht ist, signalisiere das durch zurücksetzen der Flagge
    wattCount=$(cat "${WATTSLOGFILE}" \
              | tail -n +$watt_line \
              | wc -l \
             )

    ### Hashwerte aus dem Hintergrund nachsehen, nur die Zeilen zählen und Flagge setzen, sobald die Minimum Hashwerte erreicht sind.
    touch ${RETRIES_COUNT}.lock ${BoooooS_COUNT}.lock
    hashCount=$(cat ${BENCHLOGFILE} \
              | tail -n +$hash_line \
              | tee >(grep -c -m1 -e "${CONEXPR//[|]/\\|}" >${RETRIES_COUNT}; \
                     rm -f ${RETRIES_COUNT}.lock) \
                    >(gawk -v YES="${YESEXPR}" -v BOO="${BOOEXPR}" -e '
                               BEGIN { yeses=0; booos=0; seq_booos=0 }
                               $0 ~ BOO { booos++; seq_booos++; next }
                               $0 ~ YES { yeses++; seq_booos=0;
                                            if (match( $NF, /[+*]+/ ) > 0)
                                               { yeses+=(RLENGTH-1) }
                                          }
                               END { print seq_booos " " booos " " yeses }' >${BoooooS_COUNT}; \
                     rm -f ${BoooooS_COUNT}.lock) \
              | sed -e 's/ *(yes!)$//g' \
              | gawk -e "${detect_zm_hash_count}" \
              | grep -E -c "/s *$"
             )
    while [[ -f ${RETRIES_COUNT}.lock || -f ${BoooooS_COUNT}.lock ]]; do sleep .01; done
    [ $hashCount -ge $MIN_HASH_COUNT ] && countHashes=0

    ###------------------------------------------------------------------
    ### 3. ABBRUCHBEDINGUNGEN
    ###------------------------------------------------------------------

    if [ $wattCount -ge $MIN_WATT_COUNT ]; then
        countWatts=0
        if [ $hashCount -eq 0 ]; then
            # Abbruch wegen 30s kein Hashwert
            countHashes=0
            _disable_algorithm "${algorithm}" "Abbruch wegen 30s nach dem Start noch kein Hashwert erhalten." "${gpu_idx}"
            BENCHMARKING_WAS_STARTED=0
            exit 95
        fi
    fi

    ###          1. ABBRUCHBEDINGUNG:       "VERBINDUNG ZUM SERVER VERLOREN"
    ###          Ist vor dem endgültigen Abbruch der "continent" zu wechseln?
    if [[ $(< ${RETRIES_COUNT}) -eq 1 ]]; then
        echo "GPU #${gpu_idx}: Connection loss detected..."

        # Die Minimum-Zähler auf "Minimum erreicht" einstellen
        countWatts=0
        countHashes=0
        BENCHMARKING_WAS_STARTED=0

        if [[ -f ../I_n_t_e_r_n_e_t__C_o_n_n_e_c_t_i_o_n__L_o_s_t ]]; then
            # Einfacher Abbruch ohne Disablen.
            # Der Benchmarker sollte unter diesen Umständen nicht mehr von anderen aufgerufen werden.
            exit 94
        fi

        nowDate=$(date "+%Y-%m-%d %H:%M:%S" )
        nowSecs=$(date +%s)
        # Miner-Abbrüche protokollieren nach bisher 3 Themen getrennt
        echo ${nowDate} ${nowSecs} \
             "GPU #${gpu_idx}: BEENDEN des Miners alias ${coin_algorithm} wegen dem Verlust der Server-Connection." \
            | tee -a ${LOG_CONLOSS_ALL} ${LOG_CONLOSS} ${ERRLOG} \
                  >>${BENCHLOGFILE}
        _disable_algorithm "${algorithm}" "Abbruch wegen dem Verlust der Serverconnection (Retries)." "${gpu_idx}"
        exit 93
    fi

    ###          2. ABBRUCHBEDINGUNG:       "ZU VIELE BOOOOS"
    ###          Ist vor dem endgültigen Abbruch der "continent" zu wechseln?
    read booos sum_booos sum_yeses <<<$(< ${BoooooS_COUNT})
    if [[ ${booos} -ge 10 ]]; then
        nowDate=$(date "+%Y-%m-%d %H:%M:%S" )
        nowSecs=$(date +%s)

        _disable_algorithm "${algorithm}" "Abbruch wegen zu vieler Booooos." "${gpu_idx}"

        # Miner-Abbrüche protokollieren nach bisher 3 Themen getrennt
        echo ${nowDate} ${nowSecs} \
             "GPU #${gpu_idx}: Abbruch des Miners alias ${coin_algorithm} wegen zu vieler 'booooos'..." \
            | tee -a ${LOG_BOOOOOS} ${LOG_BOOOOOS_ALL} ${ERRLOG} \
                  >>${BENCHLOGFILE}

        # Die Minimum-Zähler auf "Minimum erreicht" einstellen
        countWatts=0
        countHashes=0
        BENCHMARKING_WAS_STARTED=0

        exit 92
    elif [[ ${booos} -ge 5 ]]; then
        echo "GPU #${gpu_idx}: Miner alias ${coin_algorithm} gibt bereits ${booos} 'booooos' hintereinander von sich..."
        if [ $NoCards ]; then
            [[ $(($secs%3)) -gt 0 ]] && \
                echo "#[2017-11-20 18:00:37] accepted: 0/12 (diff 9.171), 1648.05 MH/s (booooo)" >>${BENCHLOGFILE}
        fi
    else
        if [ $NoCards ]; then
            [[ $(($secs%3)) -gt 0 ]] && \
                echo "#[2017-11-20 18:00:37] accepted: 0/12 (diff 9.171), 1648.05 MH/s (booooo)" >>${BENCHLOGFILE}
        fi
    fi

    ###------------------------------------------------------------------
    ### n. 
    ###------------------------------------------------------------------

    if [ ! ${STOP_AFTER_MIN_REACHED} -eq 1 ]; then
        ###
        ### TWEAKING MODE
        ###
        TWEAK_CMD_LOG_AGE=$(stat -c %Y ${TWEAK_CMD_LOG})
        if [ $new_TweakCommand_available -lt ${TWEAK_CMD_LOG_AGE} ]; then
            #
            # Ein neuer Messzyklus muss initiaisiert werden.
            # Das betrifft eigentlich auch die Minimalwerte-Verwaltung, die eigentlich auch beim Tweaken gelten sollten.
            # Es macht Sinn, immer auf mindestens 20 Hashwerte und 30 Sekunden Laufzeit zu achten, nicht wahr?
            #
            new_TweakCommand_available=${TWEAK_CMD_LOG_AGE}
            bENCH_START=${TWEAK_CMD_LOG_AGE}

            #
            # Diese Flaaggen auf 1 heisst: Die Minimum-Zähler sind wieder scharf.
            # Mal sehen, ob wir das auch realisiert bekommen, dass die _On_Exit Routine das berücksichtigt.
            #
            countHashes=1
            countWatts=1

            # Hole das gerade gegebene Tweaking-Kommando aus der Logdatei
            tweak_msg="$(tail -n 1 ${TWEAK_CMD_LOG})"
            if [ ${#tweak_msg} -gt 0 ]; then
                #
                # Merken, welche Tweak-Kommandos insgesamt gegeben wurden. Array ist Unique, das heisst: Ein Member pro Kommando
                #
                TWEAK_MSGs["${tweak_msg%=*}"]="${tweak_msg}"

                #
                # Vorbereiten des Suchmusters, damit das Kommando auch gefunden werden kann.
                # Unglücklicherweise enthalten manche Kommandos Zeichen, die von einer RegExp ganz anders interpretiert werden.
                # Das Kommando könnte nicht gefunden werden...
                #     ---> Bitte prüfen:
                #     ---> ... es sei denn, man bekäme es hin, dass ein harter Stringvergleich gemacht wird, ohne dass
                #     ---> die Metazeichen interpretiert werden.
                # Hier realisieren wir das, indem wir die Metazeichen mit einem Backslash versehen und sie so vor der Interpretation
                #      als Metazeichen schützen.
                #      Zu schützende Zeichen sind bisher die folgenden: "[", "]", "."
                #
                tweak_pat="${tweak_msg//[[]/\\[}"
                tweak_pat="${tweak_pat//[\]]/\\]}"
                tweak_pat="${tweak_pat//[.]/\.}"
                if [ $NoCards ]; then
                    # Hänge ein paar andere Werte an die Logdateien - zum Testen
                    cat test/more_hash_values.fake >>${BENCHLOGFILE}
                fi

                #
                # Suchen des letzten Kommandos in den beiden Logfiles für Hash- und Wattwerte und Ausgabe der Zeilennummer,
                #        die der Zeile mit dem Kommando folgt.
                #        grep -n schreibt die Zeilennummer gefolgt von einem "-" vor jede gefundene Zeile.
                #        tail -n 1 wartet die allerletzte gefundene Zeile ab.
                #        gawk spaltet die Zeile am "-" auf und $1 ist die Zeilennummer des Kommandos und muss um 1 erhöht werden.
                #
                hash_line=$(cat ${BENCHLOGFILE} \
                          | grep -n -e "${tweak_pat}" \
                          | tail -n 1 \
                          | gawk -e 'BEGIN {FS="-"} {print $1+1}' \
                         )
                watt_line=$(cat "${WATTSLOGFILE}" \
                          | grep -n -e "${tweak_pat}" \
                          | tail -n 1 \
                          | gawk -e 'BEGIN {FS="-"} {print $1+1}' \
                         )
                
                #
                # Hinweis für den Benutzer, dass ein neuer Zyklus beginnt.
                #
                printf "${tweak_msg}\n" \
                    | tee -a ${TWEAKLOGFILE}
                printf "Hashwerte ab jetzt ab Zeile $hash_line und Wattwerte ab Zeile $watt_line\n" \
                    | tee -a ${TWEAKLOGFILE}
            fi
        fi  ## if [ $new_TweakCommand_available -lt ${TWEAK_CMD_LOG_AGE} ]
        
        hASH_DURATION=$(($(date +%s)-${bENCH_START}))
        _evaluate_BENCH_and_WATT_LOGFILE_and_build_sums_and_averages

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
               ${hashCount} ${wattCount}
    fi

    # Eine Sekunde pausieren vor dem nächsten Wattwert.
    # Jetzt auch bereit für Unterbrechnungen bzw. Beenden der Messzyklen
    echo "I'm going to sleep now" >${READY_FOR_SIGNALS}
    sleep 1
    # Jetzt sind ale Funktionen geladen, bekannt und definiert.
    # Eine Sekunde Messung ist wenigstens sauber gelaufen. Alle Variablen sind konsistent.
    BENCHMARKING_WAS_STARTED=1
    rm -f ${READY_FOR_SIGNALS}
}

_edit_BENCHMARK_JSON_and_put_in_the_new_values () {
    ####################################################################################
    ###
    ###                        7. SCHREIBEN DER DATEN DES BENCHMARKING
    ###
    ####################################################################################

    # 
    # ccminer log vom coin test/benchmark_$coin_${gpu_uuid}.log 
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


    # Die WATT-Werte noch zu Integern machen und dabei aufrunden
    avgWATT=$((${avgWATT%.*}+1))
    maxWATT=$((${maxWATT%.*}+1))

    declare -i tempazb=0
    # Full Power ($?=100) oder Effizienz Messung ($?=99)
    [[ ${bENCH_KIND} -eq 888 ]] \
        && sed_search='/"Name": "'${miningAlgo}'",/{           # if found ${miningAlgo}
                 N;/"MinerName": "'${miner_name}'",/{          # appe(N)d 1 line;  if found ${miner_name}
                 N;/"MinerVersion": "'${miner_version}'",/{    # appe(N)d 1 line;  if found ${miner_version}
                     N;N;N;N;N;N;N;/"BENCH_KIND": 888,/{       # appe(N)d 7 lines; if found BENCH_KIND 888
             =;Q100}}}};                                       # (=) print line-number; Quit and set $?=100
             ${Q99}                                            # on last line Quit and set $?=99 (NOT FOUND)
             ' \
        || sed_search='/"Name": "'${miningAlgo}'",/{           # if found ${miningAlgo}
                 N;/"MinerName": "'${miner_name}'",/{          # appe(N)d 1 line;  if found ${miner_name}
                 N;/"MinerVersion": "'${miner_version}'",/{    # appe(N)d 1 line;  if found ${miner_version}
                     N;N;N;N;N;N;N;/"BENCH_KIND": 888,/d;{     # appe(N)d 7 lines; if found 888, (d)elete and continue
             =;Q100}}}};                                       # otherwise (=) print line-number; Quit and set $?=100
             ${Q99}                                            # on last line Quit and set $?=99 (NOT FOUND)
             '
    sed -n -e "${sed_search}" \
        ${IMPORTANT_BENCHMARK_JSON} \
        >${TEMPAZB_FILE}
    _Q_=$?
    # Die BenchmarkSpeed Zeile haben wir auf der Suche nach dem 888 um 6 Zeilen überschritten.
    # Deshalb müssen wir die abziehen, FALLS er etwas gefunden hat (Q100)
    [[ ${_Q_} -eq 100 ]] && tempazb=$(($(< "${TEMPAZB_FILE}")-6))

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
    # tempazb +  1: WATT
    # tempazb +  2: MAX_WATT
    # tempazb +  3: HASHCOUNT
    # tempazb +  4: HASH_DURATION
    # tempazb +  5: BENCH_DATE
    # tempazb +  6: BENCH_KIND
    # tempazb +  7: GPUGraphicsClockOffset[3]
    # tempazb +  8: GPUMemoryTransferRateOffset[3]
    # tempazb +  9: GPUTargetFanSpeed
    # tempazb + 10: PowerLimit
    # tempazb + 11: HashCountPerSeconds
    # tempazb + 12: BenchMode
    # tempazb + 13: LessThreads

    # ## in der temp_algo_zeile steht die zeilen nummer zum editieren des hashwertes
    if [ ${tempazb} -gt 1 ] ; then
        #
        # Das alles dient der Vorbereitung der zeilengenauen Bearbeitung der IMPORTANT_BENCHMARK_JSON
        #

        echo "der Hash wert $avgHASH wird nun in der Zeile $tempazb eingefügt"
        echo "der WATT wert $avgWATT wird nun in der Zeile $((tempazb+1)) eingefügt"
        echo     "${tempazb}s/: [0-9.]*,$/: ${avgHASH},/"            >${TEMPSED_FILE}
        echo "$((tempazb+1))s/: [0-9.]*,$/: ${avgWATT},/"           >>${TEMPSED_FILE}
        if [[ ${#maxWATT} -ne 0 ]]; then
            echo "der MAX_WATT Wert ${maxWATT} wird nun in der Zeile $((tempazb+2)) eingefügt"
            echo "$((tempazb+2))s/: [0-9.]*,$/: ${maxWATT},/"       >>${TEMPSED_FILE}
        fi
        if [[ ${#hashCount} -ne 0 ]]; then
            echo "der HASHCOUNT Wert ${hashCount} wird nun in der Zeile $((tempazb+3)) eingefügt"
            echo "$((tempazb+3))s/: [0-9.]*,$/: ${hashCount},/"     >>${TEMPSED_FILE}
        fi
        if [[ ${#hASH_DURATION} -ne 0 ]]; then
            echo "der HASH_DURATION Wert ${hASH_DURATION} wird nun in der Zeile $((tempazb+4)) eingefügt"
            echo "$((tempazb+4))s/: [0-9.]*,$/: ${hASH_DURATION},/" >>${TEMPSED_FILE}
        fi
        if [[ ${#bENCH_DATE} -ne 0 ]]; then
            echo "der BENCH_DATE Wert ${bENCH_DATE} wird nun in der Zeile $((tempazb+5)) eingefügt"
            echo "$((tempazb+5))s/: [0-9.]*,$/: ${bENCH_DATE},/"    >>${TEMPSED_FILE}
        fi
        if [[ ${#bENCH_KIND} -ne 0 ]]; then
            echo "der BENCH_KIND Wert ${bENCH_KIND} wird nun in der Zeile $((tempazb+6)) eingefügt"
            echo "$((tempazb+6))s/: [0-9.]*,$/: ${bENCH_KIND},/"    >>${TEMPSED_FILE}
        fi
        if [[ ${#grafik_clock} -ne 0 ]]; then
            echo "der GRAFIK_CLOCK Wert ${grafik_clock} wird nun in der Zeile $((tempazb+7)) eingefügt"
            echo "$((tempazb+7))s/: [0-9.]*,$/: ${grafik_clock},/"  >>${TEMPSED_FILE}
        fi
        if [[ ${#memory_clock} -ne 0 ]]; then
            echo "der MEMORY_CLOCK Wert ${memory_clock} wird nun in der Zeile $((tempazb+8)) eingefügt"
            echo "$((tempazb+8))s/: [0-9.]*,$/: ${memory_clock},/" >>${TEMPSED_FILE}
        fi
        if [[ ${#fan_speed}    -ne 0 ]]; then
            echo "der FanSpeed Wert ${fan_speed} wird nun in der Zeile $((tempazb+9)) eingefügt"
            echo "$((tempazb+9))s/: [0-9.]*,$/: ${fan_speed},/"    >>${TEMPSED_FILE}
        fi
        if [[ ${#power_limit}  -ne 0 ]]; then
            [ ${power_limit} -eq 0 ] && power_limit=${defPowLim[${gpu_idx}]}
            echo "der POWER_LIMIT Wert ${power_limit} wird nun in der Zeile $((tempazb+10)) eingefügt"
            echo "$((tempazb+10))s/: [0-9.]*,$/: ${power_limit},/"  >>${TEMPSED_FILE}
        fi
        if [[ ${#hashCountPerSeconds}  -ne 0 ]]; then
            echo "der HashCountPerSeconds Wert ${hashCountPerSeconds} wird nun in der Zeile $((tempazb+11)) eingefügt"
            echo "$((tempazb+11))s/: [0-9.]*,$/: ${hashCountPerSeconds},/"  >>${TEMPSED_FILE}
        fi
        if [[ ${#benchMode}  -ne 0 ]]; then
            echo "der BenchMode Wert ${benchMode} wird nun in der Zeile $((tempazb+12)) eingefügt"
            echo "$((tempazb+12))s/: [lo],$/: ${benchMode},/"  >>${TEMPSED_FILE}
        fi
        if [[ ${#less_threads}  -ne 0 ]]; then
            echo "der LESS_THREADS Wert ${less_threads} wird nun in der Zeile $((tempazb+13)) eingefügt"
            echo "$((tempazb+13))s/: [0-9.]*$/: ${less_threads}/"   >>${TEMPSED_FILE}
        fi
        #
        # Das ist die tatsächliche Bearbeitung der IMPORTANT_BENCHMARK_JSON
        #
        sed -i -f ${TEMPSED_FILE} ${IMPORTANT_BENCHMARK_JSON}
    else
        #
        # Der Algo für diese Minerversion war nicht vorhanden und wird nun zu IMPORTANT_BENCHMARK_JSON hinzugefügt
        #
        BLOCK_FORMAT=(
            '      \"Name\": \"%s\",\n'
            '      \"MinerName\": \"%s\",\n'
            '      \"MinerVersion\": \"%s\",\n'
            '      \"BenchmarkSpeed\": %s,\n'
            '      \"WATT\": %s,\n'
            '      \"MAX_WATT\": %s,\n'
            '      \"HASHCOUNT\": %s,\n'
            '      \"HASH_DURATION\": %s,\n'
            '      \"BENCH_DATE\": %s,\n'
            '      \"BENCH_KIND\": %s,\n'
            '      \"GPUGraphicsClockOffset[3]\": %s,\n'
            '      \"GPUMemoryTransferRateOffset[3]\": %s,\n'
            '      \"GPUTargetFanSpeed\": %s,\n'
            '      \"PowerLimit\": %s,\n'
            '      \"HashCountPerSeconds\": %s,\n'
            '      \"BenchMode\": %s,\n'
            '      \"LessThreads\": %s\n'
        )
        if [[ ${#maxWATT}             -eq 0 ]]; then maxWATT=0;             fi
        if [[ ${#hashCount}           -eq 0 ]]; then hashCount=0;           fi
        if [[ ${#hASH_DURATION}       -eq 0 ]]; then hASH_DURATION=0;       fi
        if [[ ${#bENCH_DATE}          -eq 0 ]]; then bENCH_DATE=0;          fi
        if [[ ${#bENCH_KIND}          -eq 0 ]]; then bENCH_KIND=0;          fi
        if [[ ${#grafik_clock}        -eq 0 ]]; then grafik_clock=0;        fi
        if [[ ${#memory_clock}        -eq 0 ]]; then memory_clock=0;        fi
        if [[ ${#fan_speed}           -eq 0 ]]; then fan_speed=0;           fi
        if [[ ${#power_limit} -eq 0 || ${power_limit} -eq 0 ]]; then power_limit=${defPowLim[${gpu_idx}]}; fi
        if [[ ${#hashCountPerSeconds} -eq 0 ]]; then hashCountPerSeconds=0; fi
        if [[ ${#benchMode}           -eq 0 ]]; then benchMode=0;           fi
        if [[ ${#less_threads}        -eq 0 ]]; then less_threads=0;        fi
        BLOCK_VALUES=(
            ${miningAlgo}
            ${miner_name}
            ${miner_version}
            ${avgHASH}
            ${avgWATT}
            ${maxWATT}
            ${hashCount}
            ${hASH_DURATION}
            ${bENCH_DATE}
            ${bENCH_KIND}
            ${grafik_clock}
            ${memory_clock}
            ${fan_speed}
            ${power_limit}
            ${hashCountPerSeconds}
            ${benchMode}
            ${less_threads}
        )
        echo "Der MiningAlgo \"${miningAlgo}\" wird zur Datei ${IMPORTANT_BENCHMARK_JSON} hinzugefügt"
        sed -i -e '/^ \+]/,/}$/d'  ${IMPORTANT_BENCHMARK_JSON}
        printf ",   {\n"         >>${IMPORTANT_BENCHMARK_JSON}
        for (( i=0; $i<${#BLOCK_FORMAT[@]}; i++ )); do
            printf "${BLOCK_FORMAT[$i]}" "${BLOCK_VALUES[$i]}" \
                | tee -a           ${IMPORTANT_BENCHMARK_JSON}
        done
        printf "    }\n  ]\n}\n" >>${IMPORTANT_BENCHMARK_JSON}
    fi
}

_delete_temporary_files () {
    rm -f ${temp_hash_bc} ${temp_hash_sum} ${temp_watt_sum} ${temp_avgs_bc} ${TEMPAZB_FILE} \
       ${TEMPSED_FILE} ${WATTSMAXFILE} ${WATTSLOGFILE}
    [ -s "${TWEAK_CMD_LOG}" ] || rm -f ${TWEAK_CMD_LOG}
}
#_delete_temporary_files

_terminate_Miner () {
    if [ -s "${CCMINER_PID}" ]; then
        printf "Beenden des Miners... "
        kill $(< "${CCMINER_PID}")
        if [ ! $NoCards ]; then
            sleep $Erholung
        fi
        printf "done.\n"
        rm  ${CCMINER_PID}
    fi
}

_terminate_Logging_Terminal () {
    if [ -n "${Bench_Log_PTY_Cmd}" ]; then
        echo "Beenden des Logger-Terminals..."
        kill_pids=$(ps -ef \
               | grep -e "${Bench_Log_PTY_Cmd}" \
               | grep -v 'grep -e ' \
               | gawk -e 'BEGIN {pids=""} {pids=pids $2 " "} END {print pids}')
        if [ -n "$kill_pids" ]; then
            printf "Killing all ${Bench_Log_PTY_Cmd} processes... "
            kill $kill_pids
            printf "done.\n"
        fi
    fi
}

_On_Exit () {
    # So wie es aussieht hat nur das erste <Ctrl>-C oder kill -15 eine Auswirkung auf den Prozess.
    # Er reagiert nicht mehr auf weitere <Ctrl>-C, sondern führt die Routine sauber zu Ende.
    # Einmal ein EXIT Signal empfangen, führt er die _On_Exit aus ohne auf weitere EXIT's zu hören.
    # Nur noch ein kill -9 == SIGKILL == KILL kann den Prozess vor seinem normalen Ende beenden.
    printf "\n--------->      Benchmarker GPU #${gpu_idx} hat ein EXIT Signal erhalten      <---------\n"

    ####################################################################################
    ###
    ###                        6. AUSWERTUNG DES BENCHMARKING
    ###
    ####################################################################################

    # Als wichtiges Kennzeichen für den Ausstieg, denn da werden die Logdateien gesichert
    # und die Werte in die .json Datei geschrieben.
    # Das darf nicht geschehen, wenn das Programm vorher abnormal beendet wurde und gar keine Daten erhoben wurden.
    # Deshalb wird diese Flagge erst gesetzt, wenn der Programmfluss aus dem ersten Sleep erfolgreich herauskommt.
    # Dann muss midndestens der Minimum-Werte Benchmark vervollständigt werden.
    #
    if [[ ${BENCHMARKING_WAS_STARTED} -eq 1 ]]; then
        # Einen eventuell unvollständigen Meszyklus kontrolliert und gültig zu Ende bringen
        while [ $countWatts -eq 1 ] || [ $countHashes -eq 1 ] ; do
            if [ -z "${once}" ]; then
                echo "---------> Die Messung wird bis zum Erreichen der Minimalwerte fortgesetzt <---------"
                once=1
            fi
            _measure_one_whole_WattsHashes_Cycle
        done

        _terminate_Miner
        _terminate_Logging_Terminal

        # Bis jetzt könnten Werte in das $BENCHLOGFILE hineingekommen sein.
        # Das ist vor allem für den Tweak-Fall interessant, weil der das $BENCHLOGFILE nochmal
        # durchgehen muss! Denn es könnte noch ein Wert dazu gekommen sein!
        # ---> BITTE NOCHMAL NACHPROGRAMMIEREN!                      <---
        # ---> MUSS DAS BENCHFILE AUCH IM TWEAKMODE NOCHMAL SCANNEN! <---
        #
        echo "... Wattmessen ist beendet!!" 

        # Der Zeitstempel dieser Messung,
        # ... nach dem Herausfallen aus dem Sleep am Ende der Endlosschleife,
        # ... dem Eintritt in die On_Exit() Routine,
        # ... dem kill <${CCMINER_PID}
        # ... und $Erholung Sekunde sleep.
        BENCH_OR_TWEAK_END=$(date +%s);
        LOGFILE_DATE=$(date "+%Y%m%d_%H%M%S")
        bENCH_DATE=$BENCH_OR_TWEAK_END

        # bENCH_START wird direkt vor dem Start des Miners gesetzt.
        # Im Falle des Tweakens wird bENCH_START nach jedem Tweak-Kommando neu gesetzt und der hashCount auf 0 zurückgesetzt.
        # Die Differenz aus ${BENCH_OR_TWEAK_END} und ${bENCH_START} ist also die tatsächliche Dauer
        #     zur Ermittlung der Anzahl an hashCount Werten
        hASH_DURATION=$((${BENCH_OR_TWEAK_END}-${bENCH_START}))

        _evaluate_BENCH_and_WATT_LOGFILE_and_build_sums_and_averages

        ####################################################################
        #    Aufbereitung der Werte zum Schreiben in die benchmark_*.json
        #

        # Weil im Logfile die Einheiten gemischt sein können (kH/s bis TH/s) rechnen wir alles in H/s bzw. Sol/s um.
        #      Diese Basiseinheit merken wir uns in der Variablem $temp_einheit
        temp_einheit=$(cat ${BENCHLOGFILE} \
                              | sed -e 's/ *(yes!)$//g' \
                              | gawk -e "${detect_zm_hash_count}" \
                              | grep -m1 "/s *$" \
                              | gawk -e '/H\/s *$/ {print "H/s"; next}{print "Sol/s"}')

        summary="\nZusammenfassung der ermittelten Werte:\n"
        summary+="$(printf " Summe WATT   : %12s; Messwerte: %5s\n" $wattSum $wattCount)\n"
        summary+="$(printf " Durchschnitt : %12s\n" $avgWATT)\n"
        summary+="$(printf " Max WATT Wert: %12s\n" ${maxWATT})\n"
        summary+="$(printf " Summe HASH   : %12s; Messwerte: %5s\n" ${hashSum:0:$(($(expr index "$hashSum" ".")+2))} $hashCount)\n"
        summary+="$(printf " Durchschnitt : %12s %6s\n" ${avgHASH:0:$(($(expr index "${avgHASH}" ".")+2))} ${temp_einheit})\n"
        printf "${summary}" | tee -a ${BENCHLOGFILE}

        benchMode=${live_mode}

        # Am Schluss Kopie der Log-Dateien, damit sie nicht verloren gehen, mit dem aktuellen Zeitpunkt
        if [ -f ${TWEAKLOGFILE} ]; then
            printf "${summary}" >>${TWEAKLOGFILE}
            if [ ${#TWEAK_MSGs[@]} -gt 0 ]; then
                printf "\nLetzter Stand aller verwendeten Befehle:\n" >>${TWEAKLOGFILE}
                # ACHTUNG: Die nvidiaCmd''s sind ab jetzt (kurz vor Programmende) ZWECKENTFREMDET und können nicht mehr wie geplant verwendet werden
                for (( nvi=0; $nvi<3; nvi++ )); do
                    nvidiaCmd[$nvi]="${nvidiaCmd[$nvi]//%i/${gpu_idx}}"
                done
                for tweak_msg in "${!TWEAK_MSGs[@]}"; do
                    echo "${TWEAK_MSGs[${tweak_msg}]}" >>${TWEAKLOGFILE}
                    value=$(echo "${TWEAK_MSGs[${tweak_msg}]}" | grep -E -o -e '[[:digit:]]+$')
                    # Nochmal die Kommandos suchen, um die Werte zuordnen zu können
                    tweak_pat="${tweak_msg//[[]/\\[}"
                    tweak_pat="${tweak_pat//[\]]/\\]}"
                    tweak_pat="${tweak_pat//[.]/\.}"
                    REGEXPAT="^${tweak_pat}"
                    if   [[ "${nvidiaCmd[3]}" =~ ${REGEXPAT} ]]; then
                        power_limit=${value}
                        [ ${power_limit} -eq 0 ] && power_limit=${defPowLim[${gpu_idx}]}
                    elif [[ "${nvidiaCmd[2]}" =~ ${REGEXPAT} ]]; then
                        fan_speed=${value}
                    elif [[ "${nvidiaCmd[0]}" =~ ${REGEXPAT} ]]; then
                        grafik_clock=${value}
                    else
                        memory_clock=${value}
                    fi
                done
            fi
            cp ${TWEAKLOGFILE} ${LOGPATH}/${LOGFILE_DATE}_tweak.log
        fi

        # Es sind ja wenigstens avgHASH und avgWATT ermittelt worden.
        _edit_BENCHMARK_JSON_and_put_in_the_new_values

    else
        _terminate_Miner
        _terminate_Logging_Terminal
    fi  ## if [ ${BENCHMARKING_WAS_STARTED} -eq 1 ]

    if [ -f ${BENCHLOGFILE} ]; then
        [ ${#LOGFILE_DATE} -eq 0 ] && LOGFILE_DATE="NoBenchStarted_"$(date "+%Y%m%d_%H%M%S")
        cp -f ${BENCHLOGFILE} ${LOGPATH}/${LOGFILE_DATE}_benchmark.log
    fi

    [ $debug -eq 0 ] && _delete_temporary_files
    rm -f ${READY_FOR_SIGNALS} ${This}.pid
}
trap _On_Exit EXIT

# Aktuelle eigene PID merken
This=.$(basename $0 .sh)_$$
echo $$ >${This}.pid
if [ ! -d test ]; then mkdir test; fi

################################################################################
#
# Gültige, nicht mehr zu verändernde Variablen:
#
# --auto:  ${gpu_idx}
#          ${algorithm}                  ( => $[miningAlgo}, ${miner_name}, ${miner_version} )
#
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
#
# UND:
#      Stellt sicher, dass aktuelle gpu-bENCH.sh Dateien in den GPU-UUID Verzeichnissen sind.
#      Diese sorgen durch "source"-ing dafür, dass die JSON-Einträge und Arrays zusammenpassen
#
# Das entsprechende "source"-ing machen wir weiter unten, wenn wir wissen, um welche GPU
#     und welchen $algorithm es sich handelt.
cd ${LINUX_MULTI_MINING_ROOT}
source gpu-abfrage.sh

#if [ ! -s ${SYSTEM_STATE}.in ]; then
    _func_gpu_abfrage_sh
#else
#    _reserve_and_lock_file ${SYSTEM_STATE}   # Zum Lesen und Bearbeiten reservieren...
#    _read_in_SYSTEM_FILE_and_SYSTEM_STATEin
#    _remove_lock                             # ... und wieder freigeben

#    _set_Miner_Device_to_Nvidia_GpuIdx_maps
#fi

cd ${_WORKDIR_} >/dev/null
gpu_idx_list="${index[@]}"

################################################################################
#
# Gültige, nicht mehr zu verändernde Variablen:
#
# --user-input:
#
# --auto:
#                ${gpu_idx}
#                ${gpu_uuid}
#
# --anyway:
#                ${gpu_idx_list}
#         index[0-n]=gpu_idx's
#          name[ @ ]=
#           bus[ @ ]=
#          uuid[ @ ]=
#    auslastung[ @ ]=
#           GPU{ @ }Algos[]=             # declaration only
#           GPU{ @ }Watts[]=             # declaration only
#           GPU{ @ }Mines[]=             # declaration only
#         uuidEnabledSOLL[ gpu_uuid's ]= # 0/1
#
#                ${ALLE_MINER[ i ]}=
#        ALLE    ${Mining_${mName}_${mVer}_Algos[ $coin ]}
#        ALLE    ${MINER_FEES[ ${mName}#${mVer} ]}
#
###################################################################################

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
switch_to_offline_msg="Deshalb wird an dieser Stelle automatisch in den OFFLINE-Mode geschaltet."
live_mode="lo"
Preise_Kurse_valid=0
if [[ -f ${LINUX_MULTI_MINING_ROOT}/I_n_t_e_r_n_e_t__C_o_n_n_e_c_t_i_o_n__L_o_s_t ]]; then
    echo "Solange keine Internetverbindung besteht, ist nur das OFFLINE-Benchmarking möglich."
    echo ${switch_to_offline_msg}
    live_mode="o"
else
    ###############################################################################
    # Wir laden die Kurse bzw. die Preise rein, wenn sie verfügbar sind.
    # Begründung:
    # Das Benchmarling im LIVE Modus wird grundsätzlich aus 2 Gründen bevorzugt:
    #     a) Es gibt Miner, die nur im LIVE-Modus laufen (z.B. "miner", "zm", ...)
    #     b) Wenn man die Wahl hat zwischen LIVE und Offline, dann macht es mehr Sinn,
    #        LIVE zu benchmarken, WENN DAS BENCHMARKING AUCH BEZAHLT WIRD.
    #        Das ist dann der Fall, wenn der Coin-Price > 0 ist.
    #
    # Wir berücksichtigen hier auch, dass die algo_multi_abfrage.sh laufen könnte,
    # die ja die Webabrufe macht.
    # Nur wenn die _WEB Dateien zu alt sind, rufen wir sie selbst ab.
    #     Und das sind im Moment ${web_timeout}s
    ###############################################################################
    if [ ${NoCards} ]; then web_timeout=300; else web_timeout=90; fi
    
    declare -i one_call_is_enough=0
    for ppool in ${!POOLS[@]}; do
        nowSecs=$(date +%s)
        if [ ${PoolActive[${ppool}]} -eq 1 ]; then
            # For future use to abort a long lasting Web problem or server/pool requests
            declare -i secs=1
            case ${ppool} in
                "nh")
                    echo "------------------   Nicehash-Kurse           ----------------------"
                    if [ ! -s ${algoID_KURSE_PORTS_WEB} ] \
                           || [[ $(($(date --reference=${algoID_KURSE_PORTS_WEB} +%s) + ${web_timeout})) -lt ${nowSecs} ]]; then
                        _prepare_ALGO_PORTS_KURSE_from_the_Web
                        while [ $? -eq 1 ]; do
                            echo "Waiting for valid File ${algoID_KURSE_PORTS_WEB} from the Web, Second Nr. $secs"
                            sleep 1
                            let secs++
                            _prepare_ALGO_PORTS_KURSE_from_the_Web
                        done
                    fi
                    _read_in_ALGO_PORTS_KURSE
                    echo "--------------------------------------------------------------------"
                    ;;

                "mh"|"sn")
                    if [ $((++one_call_is_enough)) -eq 1 ]; then
                        echo "------------------   WhatToMine BLOCK_REWARD  ----------------------"
                        if [ ! -s ${COIN_PRICING_WEB} ] \
                               || [[ $(($(date --reference=${COIN_PRICING_WEB} +%s) + ${web_timeout})) -lt ${nowSecs} ]]; then
                            _prepare_COIN_PRICING_from_the_Web
                            while [ $? -eq 1 ]; do
                                echo "Waiting for valid File ${COIN_PRICING_WEB} from the Web, Second Nr. $secs"
                                sleep 1
                                let secs++
                                _prepare_COIN_PRICING_from_the_Web
                            done
                        fi
                        _read_in_COIN_PRICING
                        echo "--------------------------------------------------------------------"

                        echo "------------------   Bittrex COIN-BTC-Faktor  ----------------------"
                        if [ ! -s ${COIN_TO_BTC_EXCHANGE_WEB} ] \
                               || [[ $(($(date --reference=${COIN_TO_BTC_EXCHANGE_WEB} +%s) + ${web_timeout})) -lt ${nowSecs} ]]; then
                            _prepare_COIN_TO_BTC_EXCHANGE_from_the_Web
                            while [ $? -eq 1 ]; do
                                echo "Waiting for valid File ${COIN_TO_BTC_EXCHANGE_WEB} from the Web, Second Nr. $secs"
                                sleep 1
                                let secs++
                                _prepare_COIN_TO_BTC_EXCHANGE_from_the_Web
                            done
                        fi
                        _read_in_COIN_TO_BTC_EXCHANGE_FACTOR
                        echo "--------------------------------------------------------------------"
                    fi
                    ;;
            esac
        fi
    done
    Preise_Kurse_valid=1
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
    echo "${This}: AUTO-BENCHMARKING GPU #${gpu_idx} for Algorithm ${algorithm}"
    read miningAlgo miner_name miner_version muck888 <<<"${algorithm//#/ }"
else
    echo ""
    while :; do
        _prompt="Für welches GPU device soll ein Benchmark druchgeführt werden? ${gpu_idx_list}: "
        read -p "${_prompt}" gpu_idx
        ((${#gpu_idx}>0)) && [[ "${gpu_idx}" =~ ^[[:digit:]]*$ ]] && [[ ${gpu_idx_list} =~ ^.*${gpu_idx} ]] && break
    done
fi
gpu_uuid=${uuid[${gpu_idx}]}
echo "${This}: GPU #${gpu_idx} mit UUID ${gpu_uuid} soll benchmarked werden."

################################################################################
#
# Gültige, nicht mehr zu verändernde Variablen:
#
# --user-input:
#                ${gpu_idx}
#                ${gpu_uuid}
#
# --auto:
#                ${gpu_idx}
#                ${gpu_uuid}
#                ${algorithm}
#                $[miningAlgo}
#                ${miner_name}
#                ${miner_version}
#                ${muck888}
#
# --anyway:
#                ${gpu_idx_list}
#                ${ALLE_MINER[ i ]}=
#        ALLE    ${Mining_${mName}_${mVer}_Algos[ $coin ]}
#        ALLE    ${MINER_FEES[ ${mName}#${mVer} ]}
#
#          name[ ${gpu_idx} ]=
#           bus[ ${gpu_idx} ]=
#          uuid[ ${gpu_idx} ]=
#    auslastung[ ${gpu_idx} ]=
#           GPU{ ${gpu_idx} }Algos[]=             # declaration only
#           GPU{ ${gpu_idx} }Watts[]=             # declaration only
#           GPU{ ${gpu_idx} }Mines[]=             # declaration only
#         uuidEnabledSOLL[ ${gpu_uuid} ]=         # 0/1
#
###################################################################################

# Ein paar Standardverzeichnisse zur Verbesserung der Übersicht:
if   [ ! -d ${LINUX_MULTI_MINING_ROOT}/${gpu_uuid}/benchmarking ]; then
    mkdir   ${LINUX_MULTI_MINING_ROOT}/${gpu_uuid}/benchmarking
fi

IMPORTANT_BENCHMARK_JSON="${LINUX_MULTI_MINING_ROOT}/${gpu_uuid}/benchmark_${gpu_uuid}.json"

# Funktion zum Einlesen der Benchmarkdaten nach eventuellem vorherigen Update der JSON Datei
cd ${LINUX_MULTI_MINING_ROOT}/${gpu_uuid}
source gpu-bENCH.sh
cd ${_WORKDIR_} >/dev/null

# Um Codeteile, die ursprüngöich in der MinerShell entwickelt wurden und dann als Funktion
# in die gpu-bENCH.inc übernommen wurden, auch hier rufen zu können und entsprechende Variablen
# initialisiert zu haben.
_init_some_file_and_path_variables

# Alle Einstellungen aller Algorithmen der ausgewählten GPU einlesen
# Es sind jetzt jede Menge Assoziativer Arrays mit Werten aus der JSON da
#
bENCH_SRC="${LINUX_MULTI_MINING_ROOT}/${gpu_uuid}/bENCH.in"
_read_IMPORTANT_BENCHMARK_JSON_in # without_miners
#echo "I'm here..."

################################################################################
###
###          2.2. Einlesen ALLER verfügbaren Miner und deren MiningAlgos und Algos/Coins
###
################################################################################

# Einlesen der Algos/Coins und MiningAlgos aus den ${miner_name}#${miner_version}.algos Dateien
# In ALLE die Arrays "Mining_${miner_name}_${miner_version//\./_}_Algos"

# Dann gleich Bereitstellung zweier Arrays mit AvailableAlgos und MissingAlgos.
#      ( "Available_${miner_name}_${miner_version//\./_}_Algos" und
#        "Missing_${miner_name}_${miner_version//\./_}_Algos" )
# Die MissingAlgos könnte man in einer automatischen Schleife benchmarken lassen,
# bis es keine MissingAlgos mehr gibt.
#_test_=1
_read_in_ALL_Mining_Available_and_Missing_Miner_Algo_Arrays

# Alle fehlenden Pool-Infos setzen wie Coin, ServerName und Port
# Ab hier sind die folgenden Informationen in den Arrays verfügbar
#    actCoinsOfPool                        ="CoinsOfPool_${pool}"
#    actMiningAlgosOfPool                  ="MiningAlgosOfPool_${pool}"
#    UniqueMiningAlgoArray[${miningAlgo}] +="${coin}#${pool}#${server_name}#${algo_port} <SPACE!>"
#    actCoinsPoolsOfMiningAlgo             ="CoinsPoolsOfMiningAlgo_${mining_Algo}"
#
#    #actServerNameOfPool="ServerNameOfPool_${pool}" (auskommentiert)
#    #actPortsOfPool="PortsOfPool_${pool}"           (auskommentiert)
_read_in_static_COIN_MININGALGO_SERVERNAME_PORT_from_Pool_Info_Array

################################################################################
################################################################################
###
###                     3. Auswahl des Miners
###
################################################################################
################################################################################

if [[ ${ATTENTION_FOR_USER_INPUT} -eq 1 ]]; then
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
        ((${#choice}>0)) && [[ ${choice} =~ ^[[:digit:]]*$ ]] && [[ "${choice_list}" =~ ^.*${choice} ]] && break
    done

    miner_name=${minerChoice[$(($choice-1))]}
    miner_version=${minerVersion[$(($choice-1))]}
fi
MINER=${miner_name}#${miner_version}

################################################################################
#
# Gültige, nicht mehr zu verändernde Variablen:
#
# --user-input:
#                ${gpu_idx}
#                ${gpu_uuid}
#                ${miner_name}
#                ${miner_version}
#                ${MINER}
#
# --auto:
#                ${gpu_idx}
#                ${gpu_uuid}
#                ${algorithm}
#                $[miningAlgo}
#                ${miner_name}
#                ${miner_version}
#                ${muck888}
#                ${MINER}
#
# --anyway:
#                ${gpu_idx_list}
#                ${ALLE_MINER[ i ]}=
#        ALLE    ${Mining_${mName}_${mVer}_Algos[ $coin ]}
#        ALLE    ${MINER_FEES[ ${mName}#${mVer} ]}
#        ALLE ${Available_${mName}_${mVer}_Algos[ $i    ]}
#        ALLE   ${Missing_${mName}_${mVer}_Algos[ $i    ]}
#
#          name[ ${gpu_idx} ]=
#           bus[ ${gpu_idx} ]=
#          uuid[ ${gpu_idx} ]=
#    auslastung[ ${gpu_idx} ]=
#           GPU{ ${gpu_idx} }Algos[]=             # declaration only
#           GPU{ ${gpu_idx} }Watts[]=             # declaration only
#           GPU{ ${gpu_idx} }Mines[]=             # declaration only
#         uuidEnabledSOLL[ ${gpu_uuid} ]=         # 0/1
#                ${IMPORTANT_BENCHMARK_JSON}   (${bENCH[ $algorithm ], etc.)
#
###################################################################################

declare -n actMiningAlgos="Mining_${miner_name}_${miner_version//\./_}_Algos"
declare -n actMissingAlgos="Missing_${miner_name}_${miner_version//\./_}_Algos"

# Dieser Aufruf zieht die entsprechenden Variablen rein, die für den Miner
# definiert sind, damit die Aufrufmechanik für alle Miner gleich ist.
source ${LINUX_MULTI_MINING_ROOT}/miners/${miner_name}#${miner_version}.starts


####################################################################################
################################################################################
###
###                     4. Auswahl des zu benchmarkenden MiningAlgos und Produktes
###
################################################################################
####################################################################################

################################################################################
###
###          4.0. Die MiningAlgos, die DISABLED sind aus der Menge der zu betrachtenden Algos herausnehmen
###
################################################################################

_disable_algorithm () {
    # $1 - $algorithm
    # $2 - $reason
    # $3 - $gpu_idx
    nowDate=$(date "+%Y-%m-%d %H:%M:%S" )
    nowSecs=$(date +%s)
    # Wenn es Probleme beim Benchmarking gibt, wegen zu weniger Werte oder wegen zu vieler boooos,
    # dann soll der $algorithm (ein miningAlgo eines ganz bestimmten Minerversion) disabled werden,
    # bis sich ein Mensch darum kümmert.
    _reserve_and_lock_file ../BENCH_ALGO_DISABLED
    printf "%s %s %02i %30s %s\n" "${nowDate}" "${nowSecs}" "$3" "$1" "$2" >>../BENCH_ALGO_DISABLED
    _remove_lock                                     # ... und wieder freigeben
    echo "Der Algorithm ${algorithm} wurde in die Datei BENCH_ALGO_DISABLED eingetragen."
}

# Vorher ausfiltern aller GLOBAL und Dauerhaft disabled Algos, denn sie sollen nicht angeboten werden
# und die Automatik soll sie nicht durchführen
#    Zunächst die über BENCH_ALGO_DISABLED Algos rausnehmen...
disd_msg[${#disd_msg[@]}]="--->-------------------------------------------------------------------------------<---"
disd_msg[${#disd_msg[@]}]="--->         Beginn mit der Durchsuchung der DISABLED Algos und/oder Coins         <---"
unset BENCH_ALGO_DISABLED_ARR
if [ -s ../BENCH_ALGO_DISABLED ]; then

    _reserve_and_lock_file ../BENCH_ALGO_DISABLED
    cat ../BENCH_ALGO_DISABLED | grep -E -v -e '^#|^$' | readarray -n 0 -O 0 -t BENCH_ALGO_DISABLED_ARR
    _remove_lock                                     # ... und wieder freigeben

    for actRow in "${BENCH_ALGO_DISABLED_ARR[@]}"; do
        read _date_ _oclock_ timestamp gpuIdx lfdAlgorithm Reason <<<${actRow}
        if [ ${gpuIdx} -eq ${gpu_idx} ]; then
            read mining_algo m_name m_version muck <<<"${lfdAlgorithm//#/ }"
            for ccoin in ${!actMiningAlgos[@]}; do
                [ "${actMiningAlgos[$ccoin]}" == "${mining_algo}" ] && unset actMiningAlgos[$ccoin]
            done
            [ ${debug} -eq 1 ] && declare -p ${!actMissingAlgos}
            actMissingAlgos=( $(echo ${actMissingAlgos[@]} | sed -e 's/\b'${mining_algo}'\b//g') )
            [ ${debug} -eq 1 ] && declare -p ${!actMissingAlgos}
            disd_msg[${#disd_msg[@]}]="---> Algo ${lfdAlgorithm} wegen des Vorhandenseins in der Datei BENCH_ALGO_DISABLED herausgenommen."
        fi
    done
fi

#    Zusätzlich die über GLOBAL_ALGO_DISABLED Algos rausnehmen...
unset GLOBAL_ALGO_DISABLED_ARR
if [ -s ../GLOBAL_ALGO_DISABLED ]; then
    _reserve_and_lock_file ../GLOBAL_ALGO_DISABLED
    cat ../GLOBAL_ALGO_DISABLED | grep -E -v -e '^#|^$' | readarray -n 0 -O 0 -t GLOBAL_ALGO_DISABLED_ARR
    _remove_lock                                     # ... und wieder freigeben

    for ((i=0; $i<${#GLOBAL_ALGO_DISABLED_ARR[@]}; i++)) ; do

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
            disd_msg[${#disd_msg[@]}]="---> Algo ${DisAlgo} wegen des Vorhandenseins in der Datei GLOBAL_ALGO_DISABLED herausgenommen."
        fi
    done
fi

if [ ${#disd_msg[@]} -gt 2 ]; then
    for (( i=0; i<${#disd_msg[@]}; i++)); do
        echo "${disd_msg[$i]}"
    done
    echo "${disd_msg[0]}"
fi
    
#####################################################################################################
###
###          4.1. Auswahl des MiningAlgos durch den Benutzer oder bereits als Parameter übergeben
###
#####################################################################################################

if [[ ${ATTENTION_FOR_USER_INPUT} -eq 0 ]]; then
    # Im --auto Mode beenden, wenn der miningAlgo nicht mehr unter den "Missing" (?) ist, weil z.B. disabled wurde
    # Um zu ermöglichen, dass vorhandene Algos nach einer längeren Zeit noch einmal benchmarkt werden können,
    # schauen wir doch lieber nach, ob der Algo unter allen noch Möglichen dabei ist.
    #    Diese Methode ist ungefähr 200 mal langsamer, als das Array zu durchsuchen...
    #    declare -i algo_cnt=$(echo ${actMiningAlgos[@]} | grep -E -c -w ${miningAlgo})
    algo_cnt=0
    for ccoin in ${!actMiningAlgos[@]}; do
        if [ "${actMiningAlgos[$ccoin]}" == "${miningAlgo}" ]; then algo_cnt=1; break; fi
    done
    [ ${algo_cnt} -eq 0 ] && exit 99
else
    ###
    ###          4.1.1. Anzeige aller fehlenden MiningAlgos, die möglich wären
    ###
    #     Anzeige derjenigen MiningAlgos, die als Objekte in der ../${gpu_uuid}/benchmark_${gpu_uuid}.json noch fehlen
    # UND die jetzt auch verwendet werden können(, weil sie NICHT disabled sind)
    if [ ${#actMissingAlgos[@]} -gt 0 ]; then
        for lfdMiningAlgo in ${actMissingAlgos[@]}; do
            printf "%17s <-------------------- Bitte Benchmark durchführen. Noch keine Daten vorhanden\n" ${lfdMiningAlgo}
        done
    fi

    ###
    ###          4.1.2. miningAlgo festlegen
    ###
    #declare -a menuItems=( ${actMiningAlgos[@]} )   # Dupletten besser raus
    #                                                    sed    's/ /\n/g'
    declare -a menuItems=( $(echo ${actMiningAlgos[@]} | tr ' ' '\n' | sort -u ))
    numMiningAlgos=${#menuItems[@]}

    menuItems_list=''
    if [ $numMiningAlgos -ge 2 ]; then
        ###
        ### 4.1.2.1. Nach Anzeige aller Optionen Eingabe vom Benutzer fordern und Fehleingaben abfangen...
        ###
        for i in ${!menuItems[@]}; do
            menuItems_list+="a$i "
            printf "%10s=%17s" "a$i" "\"${menuItems[$i]}\""
            if [ $(((i+1) % 3)) -eq 0 ]; then printf "\n"; fi
        done
        printf "\n"
        while :; do
            echo ${menuItems_list}
            read -p "Welchen MiningAlgo soll Miner ${miner_name} ${miner_version} mit GPU #${gpu_idx} testen : " algonr
            # Das matched beides ein ganzes Wort
            #REGEXPAT="\<${algonr}\>"
            REGEXPAT="\b${algonr}\b"
            ((${#algonr}>0)) && [[ ${menuItems_list} =~ ${REGEXPAT} ]] && break
        done
    elif [ $numMiningAlgos -eq 1 ]; then
        ###
        ### 4.1.2.2.  ... oder einzigen MiningAlgo automatisch setzen
        ###
        algonr="a0"
    else
        ###
        ### 4.1.2.3.  ... oder ... Au weia, ... nichts mehr übrig oder noch gar keine MiningAlgos einlesen können.
        ###
        error_msg="Sorry, entweder gibt es zu diesem Miner noch keine MiningAlgos,\n"
        error_msg+=" z.B. weil es keine Datei ../miners/${miner_name}#${miner_version}.algos gibt oder weil sie leer ist...\n"
        error_msg+="ODER diejenigen MiningAlgos, die er kennt, sind gerade Disabled.\n"
        printf ${error_msg}
        read -p "Das Programm wird nach <ENTER> mit den selben Parametern \"${initialParameters}\" neu gestartet..." restart
        exec $0 ${initialParameters}
    fi

    ###
    ###          >>> miningAlgo STEHT FEST. <<<
    ###
    miningAlgo=${menuItems[${algonr:1}]}

    ###
    ###          >>> algorithm STEHT FEST. <<<
    ###
    algorithm="${miningAlgo}#${miner_name}#${miner_version}"
    # Hier ist die Stelle, an der wir den $algorithm korrigieren, wenn wir uns für den Full Power -p Modus
    # per Kommandozeilenparameter -p entschieden haben:
    [[ ${bENCH_KIND} -eq 888 ]] && algorithm+='#888'

    echo "das ist der MiningAlgo, der ausgewählt wurde : ${miningAlgo}"
    echo "das ist der \$algorithm, der ausgewählt wurde : ${algorithm}"
fi

################################################################################
#
# Gültige, nicht mehr zu verändernde Variablen:
#
# --user-input:
#                ${gpu_idx}
#                ${gpu_uuid}
#                ${miner_name}
#                ${miner_version}
#                ${MINER}
#                ${algorithm}                     # im FP-Mode mit #888 inclusive
#
# --auto:
#                ${gpu_idx}
#                ${gpu_uuid}
#                ${algorithm}
#                $[miningAlgo}
#                ${miner_name}
#                ${miner_version}
#                ${muck888}
#                ${MINER}
#
# --anyway:
#                ${actMiningAlgos[ $coin ]}
#                ${actMissingAlgos[ $coin ]}
#                ${gpu_idx_list}
#                ${ALLE_MINER[ i ]}=
#      ( ALLE    ${Mining_${mName}_${mVer}_Algos[ $coin ]} )
#        ALLE    ${MINER_FEES[ ${mName}#${mVer} ]}
#        ALLE ${Available_${mName}_${mVer}_Algos[ $i    ]}
#      ( ALLE   ${Missing_${mName}_${mVer}_Algos[ $i    ]} )
#
#          name[ ${gpu_idx} ]=
#           bus[ ${gpu_idx} ]=
#          uuid[ ${gpu_idx} ]=
#    auslastung[ ${gpu_idx} ]=
#           GPU{ ${gpu_idx} }Algos[]=             # declaration only
#           GPU{ ${gpu_idx} }Watts[]=             # declaration only
#           GPU{ ${gpu_idx} }Mines[]=             # declaration only
#         uuidEnabledSOLL[ ${gpu_uuid} ]=         # 0/1
#                ${IMPORTANT_BENCHMARK_JSON}   (${bENCH[ $algorithm ], etc.)
#
###################################################################################

################################################################################
###
###          4.2. Auswahl des Produktes/Coins
###
################################################################################

# Das "Produkt", der "Coin", das was abgeliefert und bezahlt wird und meist
# in der Server-Adresse oder einem Server-Port enthalten ist, früher in $algo geführt, jetzt in $coin
# und was sich unter den keys des actMiningAlgos[---> $coin <---] Arrays befindet,
# will nun festgelegt werden, automatisch oder nach Angebieten mehrerer Möglichkeiten vom Benutzer
echo ""
echo "Es folgt die Auswahl der im Moment möglichen Produkte."
unset Products
declare -a Products
for ccoin in ${!actMiningAlgos[@]}; do
    [[ "${actMiningAlgos[$ccoin]}" == "$miningAlgo" ]] && Products[${#Products[@]}]=$ccoin
done

if [ ${#Products[@]} -eq 0 ]; then
    echo "Au weia, da würde was schwer schief gehen. Es gibt keine Coins, die der Miner minen könnte."
    if [ ${ATTENTION_FOR_USER_INPUT} -eq 0 ]; then
        reason="Abbruch des Auto-Benchmarkings mit exit code 97 No coins for miningAlgo available."
        _disable_algorithm "${algorithm}" "${reason}" "${gpu_idx}"
        exit 97   # No coins for miningAlgo available
    fi
    _ask_user_whether_to_disable_the_algorithm
    read -p "Das Programm wird nach <ENTER> mit den selben Parametern \"${initialParameters}\" neu gestartet..." restart
    exec $0 ${initialParameters}
fi

# Hier errechnen wir einen Preis, wenn der LIVE-Mode möglich ist, als Entscheidungshilfe, was zu Minen ist.
# Wir bevorzugen natürlich den Coin mit dem besten Preis-Leistungsverhältnis
#
# Das Auswahlmenü enthält den Coin und den Pool, an dem er abgeliefert werden kann.
# Aktuelle Coin Namen und Preise aus dem Web sind in den verschiedenen leider vom Pool abhängigen Arrays
# und sind eingangs abgerufen worden.
# Gültige Preise sind größer als 0, ungültige oder uninteressante Preise sind ".0"

unset menuItems menuMines algonr
declare -a menuItems menuMines
earnings_possible=0
gv_calculation_possible=0
if [[  "${Preise_Kurse_valid}" == "1" \
    && ${#bENCH[$algorithm]} -gt 0 \
    && ${#WATTS[$algorithm]} -gt 0 \
    && ${WATTS[$algorithm]} -lt 1000 ]]; then
    gv_calculation_possible=1
fi

if [ ${debug} -eq 1 ]; then
    msg="GV Calculation is possible"
    [ ${gv_calculation_possible} -eq 0 ] && echo "No ${msg}" || echo "${msg}"
fi

# Erster Durchlauf anhand der Online abgerufenen Daten, die eventuell einen Preis berechnen lassen.
for pidx in ${!Products[@]}; do
    ccoin=${Products[$pidx]}
    REGEXPAT="\b${ccoin}\b"
    for ppool in ${!POOLS[@]}; do
        if [ ${PoolActive[${ppool}]} -eq 1 ]; then
            case ${ppool} in

                "nh")
                    # Frage: Ist der Coin, den der Miner mittels des MiningAlgo generell produzieren kann
                    #        zufälligerweise unter den Produkten, die dieser Pool abnimmt, dabei?
                    [ ${debug} -eq 1 ] && echo "Case \"${ppool}\" entered with \${Preise_Kurse_valid}=${Preise_Kurse_valid}"
                    if [  "${Preise_Kurse_valid}" == "1" ]; then
                        [ ${debug} -eq 1 ] && echo "Case \"${ppool}\" entered, trying to find Coin ${REGEXPAT} in \${ALGOs[@]}: ${ALGOs[@]}"
                        if [[ "${ALGOs[@]}" =~ ${REGEXPAT} ]]; then
                            menuItems[${#menuItems[@]}]="${ccoin}#${ppool}"
                            # Einen Preis können wir vielleicht auch anbieten...
                            coin_mines=".0"
                            coin_kurs=${KURSE[$ccoin]//[.0]}
                            if [[ ${gv_calculation_possible} -eq 1 \
                                        && ${#coin_kurs}            -gt 0 \
                                        && ${#PoolFee[${ppool}]}    -gt 0 \
                                        && ${#MINER_FEES[${MINER}]} -gt 0 \
                                ]]; then
                                # "Mines" in BTC berechnen
                                algoMines=$(echo "scale=8;   ${bENCH[$algorithm]}  \
                                               * ${KURSE[$ccoin]}  \
                                               / ${k_base}^3  \
                                               * ( 100 - "${PoolFee[${ppool}]}" )    \
                                               * ( 100 - "${MINER_FEES[${MINER}]}" ) \
                                               / 10000
                                            " | bc )
                                minesValue=${algoMines//[.0]}
                                if [ ${#minesValue} -gt 0 ]; then
                                    coin_mines="${algoMines}"
                                    earnings_possible=1
                                fi
                            elif [[ ${#coin_kurs} -gt 0 ]]; then
                                coin_mines=${KURSE[$ccoin]}
                                earnings_possible=1
                            fi
                            menuMines[${#menuMines[@]}]=${coin_mines}
                        fi
                    else
                        found=$(grep -E -m 1 -c -e "^${ccoin}:${miningAlgo}:" ${LINUX_MULTI_MINING_ROOT}/${OfflineInfo[$ppool]})
                        if [ $found -eq 1 ]; then
                            menuItems[${#menuItems[@]}]="${ccoin}#${ppool}"
                            menuMines[${#menuMines[@]}]=".0"
                        fi
                    fi
                    ;;

                "mh"|"sn")
                    # ---> ACHTUNG: Hier ist noch ein Denkfehler drin.
                    # ---> ACHTUNG: Das findet auch Kombinationen, die nicht wirklich in dem Pool enthalten sind!
                    # ---> ACHTUNG: Wird momentan übergangen, indem wir die Kombinationen nur im LIVE-Modus auswrten ???
                    # Frage: Ist der Coin, den der Miner mittels des MiningAlgo generell produzieren kann
                    #        zufälligerweise unter den Produkten, die dieser Pool abnimmt, dabei?
                    [ ${debug} -eq 1 ] && echo "Case \"${ppool}\" entered with \${Preise_Kurse_valid}=${Preise_Kurse_valid}"
                    if [  "${Preise_Kurse_valid}" == "1" ]; then
                        [ ${debug} -eq 1 ] && echo "Case \"${ppool}\" entered, trying to find Coin ${REGEXPAT} in \${COINS[@]}: ${COINS[@]}"
                        if [[ "${COINS[@]}" =~ ${REGEXPAT} ]]; then
                            declare -n  actCoinsPoolsOfMiningAlgo="CoinsPoolsOfMiningAlgo_${miningAlgo}"
                            COINPOOLREGEXP="\b${ccoin}#${ppool}#[^#]+#[[:digit:]]+\b"
                            if [[ "${actCoinsPoolsOfMiningAlgo[@]}" =~ ${COINPOOLREGEXP} ]]; then
                                menuItems[${#menuItems[@]}]="${ccoin}#${ppool}"
                                # Einen Preis können wir vielleicht auch anbieten...
                                coin_mines=".0"
                                coin_kurs=${BlockReward[$ccoin]//[.0]}
                                if [[          ${gv_calculation_possible}    -eq 1   \
                                            && ${#coin_kurs}                 -gt 0   \
                                            && ${#BlockTime[${ccoin}]}       -gt 0   \
                                            && ${#CoinHash[${ccoin}]}        -gt 0   \
                                            && ${#Coin2BTC_factor[${ccoin}]} -gt 0   \
                                            && ${#PoolFee[${ppool}]}         -gt 0   \
                                            && ${#MINER_FEES[${MINER}]}      -gt 0   \
                                    ]]; then
                                    # "Mines" in BTC berechnen
                                    algoMines=$(echo "scale=8;   86400 * ${BlockReward[${ccoin}]} * ${Coin2BTC_factor[${ccoin}]}   \
                                               / ( ${BlockTime[${ccoin}]} * (1 + ${CoinHash[${ccoin}]} / ${bENCH[$algorithm]}) ) \
                                               * ( 100 - "${PoolFee[${ppool}]}" )    \
                                               * ( 100 - "${MINER_FEES[${MINER}]}" ) \
                                               / 10000
                                            " | bc )
                                    minesValue=${algoMines//[.0]}
                                    if [ ${#minesValue} -gt 0 ]; then
                                        coin_mines="${algoMines}"
                                        earnings_possible=1
                                    fi
                                elif [[ ${#coin_kurs} -gt 0 ]]; then
                                    coin_mines=${BlockReward[$ccoin]}
                                    earnings_possible=1
                                fi
                                menuMines[${#menuMines[@]}]=${coin_mines}
                            fi
                        fi
                    else
                        found=$(grep -E -m 1 -c -e "^${ccoin}:${miningAlgo}:" ${LINUX_MULTI_MINING_ROOT}/${OfflineInfo[$ppool]})
                        if [ $found -eq 1 ]; then
                            menuItems[${#menuItems[@]}]="${ccoin}#${ppool}"
                            menuMines[${#menuMines[@]}]=".0"
                        fi
                    fi
                    ;;
            esac
        fi
    done
done

[ ${debug} -eq 1 ] && printf "MenuItems nach dem Durchsuchen der Online Daten für Preise/Kurse: ${#menuItems[@]}
Verdienst wäre möglich bei \"\${earnings_possible}=1\". \${earnings_possible}=${earnings_possible}"

# ${earnings_possible} war NICHT 1
# Coin und Pool waren bei Lyra2z und myr-gr leer

# Wenn Verdienst möglich ist, gibt es auch etwas zu sortieren.
if [ ${earnings_possible} -eq 1 ]; then
    if [ ${#menuItems[@]} -ge 2 ]; then
        # Wenn es Preise (und Hashwerte, ohne die Preise nicht berechnet werden können) gab, wollen wir sie sortiert darstellen
        menuItems_list=''
        unset READARR
        rm -f .$$_pool_price_sort
        # Darstellung im Menü mit Preisen
        for (( i=0; i<${#menuItems[@]}; i++ )); do
            menuItems_list+="a$i "
            printf "%10s= %17s %12s\n" "a$i" "\"${menuItems[$i]}\"" "${menuMines[$i]}" >>.$$_pool_price_sort
        done
        cat .$$_pool_price_sort | sort -r -k 3 | readarray -n 0 -O 0 -t READARR
        rm -f .$$_pool_price_sort

        if [[ ${ATTENTION_FOR_USER_INPUT} -eq 1 ]]; then
            # Darstellung der Auswahlliste
            for (( i=0; i<${#READARR[@]}; i++ )); do
                echo "${READARR[$i]}"
            done
            # Eingabe der Auswahl durch den Benutzer
            while :; do
                echo ${menuItems_list}
                read -p "Welchen Coin soll Miner ${miner_name} ${miner_version} mit MiningAlgo ${miningAlgo} testen : " algonr
                REGEXPAT="\b${algonr}\b"
                ((${#algonr}>0)) && [[ ${menuItems_list} =~ ${REGEXPAT} ]] && break
            done
        else
            declare -p READARR
            # --auto Mode, wir wählen den Coin mit dem besten Preis.
            # Der steht in READARR[0].
            # Allerdings jetzt verbacken mit dem Rest des Strings in der Form
            # a12=blablabla.... also alles weg ab und inclusive dem "=" Zeichen
            echo "Der Coin mit dem besten Preis wird automatisch ausgewählt."
            algonr="${READARR[0]%%=*}"
            algonr="${algonr##* }"
        fi
    else
        echo "Der einzige Coin mit Verdienstmöglichkeit wird automatisch ausgewählt."
        algonr="a0"
    fi
else
    # Coin und Pool waren bei Lyra2z und myr-gr leer
    # Es gibt den Fall, dass Coins bei dem Abruf der Preise/Kurse einfach nicht dabei sind (WhatToMine)
    # In diesem Fall gibt es u.U. keinen menuItem!
    # Das bedeutet, dass auf jeden Fall in den Offline-Mode geschaltet werden muss, auch wenn wir hier ein Menuitem erzwingen,
    # damit der Offline-Benchmark vielleicht durchgeht.
    if [ ${#menuItems[@]} -eq 0 ]; then
        live_mode="o"
        # Das könnte man vielleicht auch noch machen:
        Preise_Kurse_valid=0

        # ${coin}#${pool}#${server_name}#${algo_port}
        mining_Algo=${miningAlgo//-/_}
        declare -n  actCoinsPoolsOfMiningAlgo="CoinsPoolsOfMiningAlgo_${mining_Algo}"
        read ccoin ppool srv_name pport <<<"${actCoinsPoolsOfMiningAlgo[0]//#/ }"
        menuItems[0]="${ccoin}#${ppool}"
    fi
    echo "Die Kombination \"${menuItems[0]}\" wird automatisch ausgewählt."
    algonr="a0"
fi

# JETZT sollten in jedem Fall ein menuitem und eine algonr da sein.
read coin pool <<<"${menuItems[${algonr:1}]//#/ }"
algoMines=${menuMines[${algonr:1}]}
minesValue=${algoMines//[.0]}

domain=${POOLS[${pool}]}
coin_algorithm=${coin}#${pool}#${algorithm}

################################################################################
#
# Ab hier steht im Benutzermodus der Coin und Pool und Domain fest
# und die Variablen  $coin und $pool und $domain dürfen NICHT MEHR VERÄNDERT WERDEN!
#
################################################################################


################################################################################
###
###          4.3. Vorbereitung aller benötigten Variablen
###
################################################################################

# Ein paar Standardverzeichnisse zur Verbesserung der Übersicht:
if   [ ! -d ${LINUX_MULTI_MINING_ROOT}/${gpu_uuid}/benchmarking/${miner_name}#${miner_version} ]; then
    mkdir   ${LINUX_MULTI_MINING_ROOT}/${gpu_uuid}/benchmarking/${miner_name}#${miner_version}
fi
if   [ ! -d ${LINUX_MULTI_MINING_ROOT}/${gpu_uuid}/benchmarking/${miner_name}#${miner_version}/${miningAlgo} ]; then
    mkdir   ${LINUX_MULTI_MINING_ROOT}/${gpu_uuid}/benchmarking/${miner_name}#${miner_version}/${miningAlgo}
fi

LOGPATH="${LINUX_MULTI_MINING_ROOT}/${gpu_uuid}/benchmarking/${miner_name}#${miner_version}/${miningAlgo}"
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
RETRIES_COUNT="test/${miningAlgo}_${gpu_uuid}.retry"
BoooooS_COUNT="test/${miningAlgo}_${gpu_uuid}.booos"
CCMINER_PID=.$$_ccminer.pid

rm -f ${BENCHLOGFILE} ${TWEAKLOGFILE} ${WATTSLOGFILE} ${WATTSMAXFILE}

if [ ! ${STOP_AFTER_MIN_REACHED} -eq 1 ]; then
    ###
    ### Variablen für TWEAKING MODE 
    ###
    TWEAK_CMD_LOG="test/${miningAlgo}_${gpu_uuid}_tweak_commands.log"
    rm -f ${TWEAK_CMD_LOG}
    touch ${TWEAK_CMD_LOG}
    declare -i TWEAK_CMD_LOG_AGE
    declare -i new_TweakCommand_available=$(stat -c %Y ${TWEAK_CMD_LOG})
    tweak_msg=''
    declare -A TWEAK_MSGs
    declare -i queryCnt=0
fi
countWatts=1
countHashes=1
# Wir gehen davon aus, dass das Benchmarking ordentlich beendet wurde und alle Werte in der Endlosschleife konsistent sind.
# Das ist so bei normalem Ende des Scripts im Standardbenchmarking und Stop nach x Werten
# Und das ist beim Tweaken so nach Beenden des Tweaking Terminals, welches den kill nur im Sleep sendet.
#
# Aber es gibt den Fall, dass der Tewakmode gewünscht wurde, aber keine Kommandos abgestzt (Benchlog- und Wattlog ohne Tweak-CMDs)
#      und es gibt den Fall, dass sehr wohl getweakt wurde.
#      Und in diesem 2. Fall dürfen wir die Logfiles nur nach dem letzten Kommando durchsuchen.
#      Genau wie innerhalb der Endlosschleife.
# Andernfalls müssen die Files von vorne ab durchsucht werden, was gleichbedeutend ist mit dem Beginn ab Zeile 1
#      Genaugenommen kann man sagen, dass die Logfiles von Anfang an ab Zeile 1 zu durchsuchen sind.
#      Jedes Tweak-Kommando korrigiert diese Zeilennummern dann nach oben.
declare -i watt_line=1
declare -i hash_line=1
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

_ask_user_whether_to_disable_the_algorithm () {
    while :; do
        echo ""
        read -p "Soll der \$algorithm ${algorithm} mit einem gleich einzugebenden Kommentar DISABLED werden ? (j/n) " yesno
        REGEXPAT="^[jn]$"
        ((${#yesno}>0)) && [[ "${yesno}" =~ ${REGEXPAT} ]] && break
    done
    if [ "${yesno}" == "j" ]; then
        read -p "Kommentar (mit <ENTER> abschließen): " reason
        _disable_algorithm "${algorithm}" "${reason}" "${gpu_idx}"
    fi
}

################################################################################
###
###          5.1. LIVE oder OFFLINE benchmarken?
###
################################################################################

# Ohne die entsprechenden Startkommandos ist der Modus auch nicht möglich.
if [ -z "${BENCH_START_CMD}" ]; then
    echo "Für den Miner ${miner_name}#${miner_version} gibt es kein OFFLINE Benchmark Startkommando."
    live_mode=${live_mode//o/}
fi
if [ -z "${LIVE_START_CMD}"  ]; then
    echo "Für den Miner ${miner_name}#${miner_version} gibt es kein LIVE Startkommando."
    live_mode=${live_mode//l/}
fi

if [ -z "$live_mode" ]; then
    # Weder LIVE-Mode noch OFFLINE-Mode möglich
    echo "WEDER der LIVE-Mode    wegen fehlendem LIVE_START_COMMAND oder fehlender Internetverbindung,"
    echo " NOCH der OFFLINE-Mode wegen fehlendem BENCH_START_CMD sind im Moment möglich."
    if [ ${ATTENTION_FOR_USER_INPUT} -eq 0 ]; then
        # Wir disablen den Algo mal, damit wir nicht dauernd wieder hier rein kommen.
        # Das hat noch nicht mal was mit irgendwelchen Hashwerten oder Wattwerten zu tun.
        # Wir sind noch nicht mal zum Starten der Messung gekommen.
        _disable_algorithm "${algorithm}" "Weder LIVE- noch OFFLINE-Mode möglich (fehlende cmd's oder no Internet)" "${gpu_idx}"
        exit 99
    fi
    _ask_user_whether_to_disable_the_algorithm
    read -p "Das Programm wird nach <ENTER> mit den selben Parametern \"${initialParameters}\" neu gestartet..." restart
    exec $0 ${initialParameters}
elif [ "$live_mode" == "l" ]; then
    # Ausschliesslich LIVE mode möglich
    # Der darf aber nur beiNH angewendet werden, weil die anderen Pools eine Mindestmenge erwarten, bevor sie in BTC wechseln
    # und der Kurs dann deutlich anders sein könnte...
    if [ "${pool}" != "nh" ]; then
        echo "Bis hierher wurde der OFFLINE-Mode bereits ausgeschlossen, es kann nur LIVE benchmarkt werden."
        echo "Allerdings ist der ausgewählte Pool \"${pool}\", den wir NICHT LIVE benchmarken wollen, weil er nur MINDESTMENGEN in BTC wandelt".
        if [ ${ATTENTION_FOR_USER_INPUT} -eq 0 ]; then
            # Wir disablen den Algo mal, damit wir nicht dauernd wieder hier rein kommen.
            # Das hat noch nicht mal was mit irgendwelchen Hashwerten oder Wattwerten zu tun.
            # Wir sind noch nicht mal zum Starten der Messung gekommen.
            _disable_algorithm "${algorithm}" "Das Benchmarking im LIVE-Mode ist für Pool \"${pool}\" nicht erlaubt." "${gpu_idx}"
            exit 91
        fi
        _ask_user_whether_to_disable_the_algorithm
        read -p "Das Programm wird nach <ENTER> mit den selben Parametern \"${initialParameters}\" neu gestartet..." restart
        exec $0 ${initialParameters}
    else
        [ ${ATTENTION_FOR_USER_INPUT} -eq 1 ] && \
            echo "Im Moment ist nur der LIVE-Mode möglich, automatische Einstellung auf LIVE-Mode."
    fi
elif [ "$live_mode" == "o" ]; then
    # Ausschliesslich OFFLINE mode möglich
    [ ${ATTENTION_FOR_USER_INPUT} -eq 1 ] && \
        echo "Der OFFLINE-Mode wurde manuell ausgewählt oder automatisch eingestellt."
else
    if [ ${ATTENTION_FOR_USER_INPUT} -eq 1 ]; then
        # Benutzer kann eine Auswahl treffen.
        echo ""
        echo "Noch eine letzte Frage:"
        echo "Willst Du LIVE oder OFFLINE Benchmarken oder Tunen?"
        while :; do
            read -p "--> l <-- für LIVE    und    --> o <-- für OFFLINE : " live_mode
            REGEXPAT="^[lo]$"
            ((${#live_mode}>0)) && [[ "${live_mode}" =~ ${REGEXPAT} ]] && break
        done
    else
        # Automatik bevorzugt den LIVE-Mode, weil die Kosten für den Test so oder so anfallen und im Live-Mode
        #           wenigstens noch ein paar SHares abgeliefert und bezahlt werden.
        live_mode="l"
        [ ! "${pool}" == "nh" ] && live_mode="o"
    fi
fi

################################################################################
###
###          5.2. Setzen der GPU-Einstellungen
###
################################################################################

# Alle Einstellungen aller Algorithmen der ausgewählten GPU wurden schon eingelesen.
# Es sind jetzt jede Menge Assoziativer Arrays mit Werten aus der JSON da, z.B. die folgenden 5 nvidia-Befehle
# Nvidia-Befhele zum tunen, die wir kennen und so gut es ging abstrahiert haben:
#nvidiaCmd[0]="nvidia-settings --assign [gpu:%i]/GPUGraphicsClockOffset[3]=%i"
#nvidiaCmd[1]="nvidia-settings --assign [gpu:%i]/GPUMemoryTransferRateOffset[3]=%i"
#nvidiaCmd[2]="nvidia-settings --assign [fan:%i]/GPUTargetFanSpeed=%i"
#nvidiaCmd[3]="./nvidia-befehle/smi --id=%i -pl %i"
#nvidiaCmd[4]="nvidia-settings --assign [gpu:%i]/GPUFanControlState=%i"
_setup_Nvidia_Default_Tuning_CmdStack

miner_device=${miner_gpu_idx["${miner_name}#${miner_version}#${gpu_idx}"]}
echo""
echo "Kurze Zusammenfassung:"
echo "GPU #${gpu_idx} mit UUID ${gpu_uuid} soll benchmarked werden."
echo "Die Miner Device-ID für GPU #${gpu_idx} ist die #${miner_device}"
echo "Das ist der Miner,           der ausgewählt wurde : ${miner_name} ${miner_version}"
echo "das ist der Coin,            der ausgewählt wurde : ${coin}"
echo "das ist der \$coin_algorithm, der ausgewählt wurde : ${coin_algorithm}"
[ "${actMiningAlgos[${coin}]}" != "${coin}" ] && echo "Das ist der Miner-Berechnungs Algorithmus........ : ${actMiningAlgos[${coin}]}"
echo "Der " $([ "$live_mode" == "l" ] && echo "LIVE" || echo "OFFLINE") " Modus ist eingestellt"
echo ""
echo "DIE FOLGENDEN KOMMANDOS WERDEN NACH BESTÄTIGUNG ABGESETZT:"
for (( i=0; $i<${#CmdStack[@]}; i++ )); do
    echo "---> ${CmdStack[$i]} <---"
done

# Coin und Pool waren bei Lyra2z und myr-gr leer

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
continent="SelbstWahl"   # Noch nicht vollständig implementiert!      <--------------------------------------
[[ "${miner_name}" == "zm" ]] && continent="br"
worker="1060"            # Noch nicht vollständig implementiert!      <--------------------------------------

_init_NH_continent_handling

###
### An dieser Stelle muss der Pool eigentlich schon ausgewählt sein.
###    und die domain haben wir eigentlich auch schon gesetzt.
###    Zumindest im Benutzer Eingabemodus.
###

# Parameter speziell für den equihash "miner", der ein Logfile angegeben haben muss,
# weil der Output über standard-out komischerweise nicht gespeichert werden kann
LIVE_LOGFILE=${BENCHLOGFILE}
if [ ${NoCards} ]; then
    # Der equihash "miner" arbeitet nur auf test-Systemen ohne Karten auch im Benchmark-Modus
    BENCH_LOGFILE=${BENCHLOGFILE}
fi

server_name="fake"
unset algo_port
REGEXPAT="\b${coin}\b"
if  [ "${pool}" == "nh" ]; then
    [ "${Preise_Kurse_valid}" == "1" ] && algo_port=${PORTs[${coin}]} || algo_port="NotNeeded"
elif [ "${pool}" == "sn" -o "${pool}" == "mh" ]; then
    read server_name_algo_port <<<$(cat ${LINUX_MULTI_MINING_ROOT}/${OfflineInfo[$pool]} \
                                           | grep -E -v -e '^#|^$' \
                                           | grep -m 1 -e "^${coin}:" \
                                           | cut -d ':' -f 3,4 )
    read server_name algo_port <<<${server_name_algo_port//:/ }
fi

if [ -z "${algo_port}" -o -z "${server_name}" ]; then
    msg="Es kann kein SERVERNAME PORT für den Algo/Coin \"${coin}\" in dem POOL \"${pool}\" gefunden werden!"
    echo ${msg}
    if [ ${ATTENTION_FOR_USER_INPUT} -eq 0 ]; then
        _disable_algorithm "${algorithm}" "${msg}" "${gpu_idx}"
        exit 98   # No algo_port found
    fi
    _ask_user_whether_to_disable_the_algorithm
    read -p "Das Programm wird nach <ENTER> mit den selben Parametern \"${initialParameters}\" neu gestartet..." restart
    exec $0 ${initialParameters}
fi


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

if [ ! -x ${minerfolder}/${miner_name} ]; then
    echo "OOOooops... das binary Exectable des Miners ${miner_name} ist nicht im Pfad ${minerfolder}/${miner_name} zu finden!"
    if [ ${ATTENTION_FOR_USER_INPUT} -eq 0 ]; then
        _disable_algorithm "${algorithm}" "Kein binary Exetuable des Miners ${miner_name} im Pfad ${minerfolder}/${miner_name} zu finden!" "${gpu_idx}"
        exit 99
    fi
    _ask_user_whether_to_disable_the_algorithm
    read -p "Das Programm wird nach <ENTER> mit den selben Parametern \"${initialParameters}\" neu gestartet..." restart
    exec $0 ${initialParameters}
fi

echo "---> DER START DES MINERS SIEHT SO AUS: <---"
echo "${minerstart} >>${BENCHLOGFILE} &"
echo ""
if [ ${ATTENTION_FOR_USER_INPUT} -eq 1 ]; then
    read -p "ENTER für OK und Benchmark-Start, <Ctrl>+C zum Abbruch " startIt
fi

# GPU-Kommandos absetzen...
echo $(date "+%Y-%m-%d %H:%M:%S" ) $(date +%s) "${This}: Executing GPU-Commands"
for (( i=0; $i<${#CmdStack[@]}; i++ )); do
    ${CmdStack[$i]}
done

################################################################################
###
###          5.5. Miner Starten und Logausgabe in eigenes Terminal umleiten
###
################################################################################

cd ${_WORKDIR_} >/dev/null

# Startsekunde festhalten.
# Wir halten auch die Sekunde nach dem Killing des Miners bei Eintritt in die On_Exit() Routine fest.
# Wir könnten also überlegen, ob wir Endesekunde - Startsekunde als Messdauer für die Hashwerte festhalten?
# Wir geben es mal beides aus.
# Dann sehen wir, wie stark eine eventuelle Diskrepanz auftritt
bENCH_START=$(date +%s)

echo $(date "+%Y-%m-%d %H:%M:%S" ) ${bENCH_START} "${This}: Starting Miner..."
${minerstart} >>${BENCHLOGFILE} &
echo $! >${CCMINER_PID}
Bench_Log_PTY_Cmd="tail -f ${BENCHLOGFILE}"
gnome-terminal --hide-menubar \
               --title="Benchmark Output of Miner ${miner_name}#${miner_version}" \
               -e "${Bench_Log_PTY_Cmd}"

####################################################################
# Automatischer Aufruf eines Terminals zum Tweaken im Tweak-Mode -t
####################################################################
if [ ${STOP_AFTER_MIN_REACHED} -eq 0 ]; then
    tweak_start_params="${gpu_idx} \
                        ${gpu_uuid} \
                        ${algorithm} \
                        $$ \
                        ${TWEAK_CMD_LOG} \
                        ${WATTSLOGFILE} \
                        ${BENCHLOGFILE} \
                        ${LOGPATH} \
                        ${READY_FOR_SIGNALS}"
    tweak_start_cmd="./tweak_commands.sh ${tweak_start_params}"

    if [ 1 -eq 0 ]; then
        unset ii; declare -i ii=0
        ofsX=$((ii*60+50))
        ofsY=$((ii*30+50))
        echo "Starting Tweaking Terminal..."
        gnome-terminal --hide-menubar \
                       --title="Tweaking Terminal for ${miningAlgo} on GPU #${gpu_uuid}" \
                       --geometry="100x24+${ofsX}+${ofsY}" \
                       -x bash -c ${tweak_start_cmd}
    elif [ 1 -eq 1 ]; then
        #xterm -kt vt220 -ti vt220 bash -c "${tweak_start_cmd}"
        xterm -T "Tweaking Terminal for ${miningAlgo} on GPU #${gpu_uuid}" \
              -fn 10x20         \
              -geometry 100x25  \
              -e "${tweak_start_cmd}" &
    else
        echo ${tweak_start_params} >${TWEAK_CMD_START_PARAMS}
    fi
fi

################################################################################
################################################################################
###
###          5.6. Wattmessung starten
###
################################################################################
################################################################################

echo "Starten des Wattmessens..."

while [ $countWatts -eq 1 ] || [ $countHashes -eq 1 ] || [ ! $STOP_AFTER_MIN_REACHED -eq 1 ]; do
    _measure_one_whole_WattsHashes_Cycle
done
