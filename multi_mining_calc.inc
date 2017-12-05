#!/bin/bash
########################################################################
#
#               _decode_MAX_PROFIT_GPU_Algo_Combination_to_GPUINDEXES
#
#
# Der Berechnungsmechanismus hält die maximal beste Kombination aus GPUs immer dann in Form eines String fest,
#     wenn er feststellt, dass ein neuer Maximalwert errechnet wurde.
#
# Es handelt sich um durch Kommas getrennte Kombinationen aus GPU-Index und entsprechendem AlgoIndex,
#     die durch einen Doppelpunkt getrennt sind.
#
#    z.B.    "0:1,4:0,6:3,8:1,"   bedeutet:
#
#        4 GPUs mit den IndexNummern #0, #4, #6 und #8 wurden mit den angegebenen AlgorithmenIndexen berechnet:
#
#        GPU#0 hat (mindestens) 2 gewinnbringende Algorithmen, die über Index 0 und 1 angesteuert werden.
#              Bei dieser Berechnung ist GPU#0 mit dem Algo und Watt, der hinter Index 1 steckt, berechnet worden.
#        GPU#4 hat (mindestens) 1 gewinnbringenden Algorithmus, der über Index 0 angesteuert wird.
#        GPU#6 hat (mindestens) 4 gewinnbringende Algorithmen, die über Index 0 bis 3 angesteuert werden.
#              Bei dieser Berechnung ist GPU#6 mit dem Algo und Watt, der hinter Index 3 steckt, berechnet worden.
#        GPU#8 hat (mindestens) 2 gewinnbringende Algorithmen, die über Index 0 und 1 angesteuert werden.
#              Bei dieser Berechnung ist GPU#8 mit dem Algo und Watt, der hinter Index 1 steckt, berechnet worden.
#
# Diese Funktion macht daraus das Array GPUINDEXES, das anschließend ausgewertet werden kann,
# indem zu jeder GPU der entsprechende AlgoIndex hinter dem Doppelpunkt ausgewertet wird.
# Ist zugegebenermaßen nicht sehr ästhetisch und kann vielleicht noch besser aufbereitet werden.
#
function _decode_MAX_PROFIT_GPU_Algo_Combination_to_GPUINDEXES () {
    # Jetzt haben wir verschiedene Möglichkeiten, von dem String aus auf die GPU und den Algorithmus zu schließen.
    # Die erste Stelle ist der GPU-Index und der Wert ist der Index in die Algorithmenliste dieser GPU
    # echo "${MAX_PROFIT_GPU_Algo_Combination}"
    unset GPUINDEXES; declare -ag GPUINDEXES
    shopt_cmd_before=$(shopt -p lastpipe)
    shopt -s lastpipe
    echo ${MAX_PROFIT_GPU_Algo_Combination} | sed -e 's/\,/ /g' | read -a GPUINDEXES
    ${shopt_cmd_before}
}

########################################################################
#
#               _calculate_ACTUAL_REAL_PROFIT
#
#
# Diese Funktion bekommt die beschriebenen Parameter übergeben und berechnet
# danach den tatsächlichen Gewinn oder Verlust und setzt die Variable
# ACTUAL_REAL_PROFIT auf das Ergebnis
#
# $1 ist die Verfügbare Menge günstiger Power, z.B. ${SolarWattAvailable}
# $2 ist die Gesamtleistung, die verbraten wird
# $3 sind die gesamt BTC "Mines", die dabei erzeugt werden
#
function _calculate_ACTUAL_REAL_PROFIT () {
    # $1 ist die Verfügbare Menge günstiger Power, z.B. ${SolarWattAvailable}
    # $2 ist die Gesamtleistung, die verbraten wird
    # $3 sind die gesamt BTC "Mines", die dabei erzeugt werden

    if [[ $1 -ge $2 ]]; then
        # Die Gesamtwattzahl braucht dann nur mit den Minimalkosten ("solar" Preis) berechnet werden:
        gesamtKostenBTC="$2 * ${kWhMin}"
    else
        gesamtKostenBTC="$1 * ${kWhMin} + ($2 - $1) * ${kWhMax}"
    fi
    # Die Kosten müssen noch ein bisschen "frisiert" werden, damit die Einheiten rausgekürzt werden.
    # Deshalb müssen die Kosten immer mit 24 multipliziert und durch 1000 geteilt werden.
    # Also Kosten immer " * 24 / 1000", wobei wir darauf achten, dass das Teilen
    #     immer als möglichst letzte Rechenoperation erfolgt,
    #     weil alle Stellen >scale einfach weggeschmissen werden.
    gesamtFormel="mines_sum=$3; real_profit = mines_sum - ( ${gesamtKostenBTC} ) * 24 / 1000"
    echo "scale=8; ${gesamtFormel}; print real_profit, \" \", mines_sum" \
        | bc \
        | read ACTUAL_REAL_PROFIT ACTUAL_MAX_FP_MINES
    #        | tee bc_inner_commands \
    #   | tee bc_ergebnis \
}

########################################################################
#
#               _calculate_ACTUAL_REAL_PROFIT_and_set_MAX_PROFIT
#
#
# Diese Funktion bekommt die beschriebenen Parameter übergeben und berechnet
# danach den tatsächlichen Gewinn oder Verlust.
# Gleichzeitig überwacht und setzt sie die Variable MAX_PROFIT, falls der gerade
#     errechnete Wert ein neuer Höchstwert ist.
#
# $1 ist die Verfügbare Menge günstiger Power, z.B. ${SolarWattAvailable}
# $2 ist die Gesamtleistung, die verbraten wird
# $3 sind die gesamt BTC "Mines", die dabei erzeugt werden
#
function _calculate_ACTUAL_REAL_PROFIT_and_set_MAX_PROFIT () {

    shopt_cmd_before=$(shopt -p lastpipe)
    shopt -s lastpipe

    _calculate_ACTUAL_REAL_PROFIT $1 $2 "$3"

    # Da MAX_PROFIT eine Dezimalzahl und kein Integer ist, kann die bash nicht damit rechnen.
    # Wir lassen das also von bc berechnen.
    # Dazu merken wir uns den alten Wert in ${OLD_MAX_PROFIT} und geben MAX_PROFIT an bc rein
    # und bekommen es als zweite Zeile wieder raus, wenn der aktuell errechnete Wert größer ist
    # als OLD_MAX_PROFIT
    OLD_MAX_PROFIT=${MAX_PROFIT}

    echo "scale=8; if ( ${ACTUAL_REAL_PROFIT} > ${MAX_PROFIT} ) \
                        { print ${ACTUAL_REAL_PROFIT}, \" \", ${ACTUAL_REAL_PROFIT} } \
                   else { print ${ACTUAL_REAL_PROFIT}, \" \", \"${MAX_PROFIT}\" }" \
        | bc \
        | read ACTUAL_REAL_PROFIT MAX_PROFIT
    ${shopt_cmd_before}
    #   | tee bc_DEBUG_STRING.log \
    #   | tee bc_ERGEBNIS.log \
    #   | tee bc_NACH_sed.log \
    let GLOBAL_MAX_PROFIT_CALL_COUNTER++
}

########################################################################
#
#               _CALCULATE_GV_of_all_TestCombinationGPUs_members
#
#
# Diese Funktion ist ein Schwerpunkt, ja die nächst größere Schale um des ganze Berechnungsproblem herum
# Das parallele "Stellwerk"-Array testGPUs mit Integer Nullen initialisieren.
# Die Werte in diesem Array durchlaufen alle Kombinationen aus GPU{idx}Algo Indexnummern
# Und dieses Array gibt sozusagen die Anweisung, was gerade zu berechnen ist.
#
# Nach jeder Berechnung über _calculate_ACTUAL_REAL_PROFIT_And_set_MAX_PROFIT
# wird die "Anweisung" um eins weitergestellt, bis zum Überlauf.
# Wenn der Überlauf passiert, sind ALLE Kombinationen aus Algos dieser GPUs berechnet worden.
#
# Dieses Array testGPUs weiss nichts über die tatsächlichen GPU's.
# Es ist nur genau so lang wie das Array TestCombinationGPUs.
# Man weiss nur, dass jede Indexstelle von testGPUs mit einer Indexstelle eines anderen Arrays
#     korrespondiert oder synchron damit ist.
#     Hier ist es immer und fix das Array TestCombinationGPUs, das immer die zu untersuchenden GPU-Indexe
#     enthalten muss.
#     Also zuerst das Array TestCombinationGPUs mit den zu untersuchenden GPUs initialisieren
#     und dann erst diese Routine rufen.
# Es ist wichtig, sich das klar zu machen, um die Übersicht nicht zu verlieren.
#
# Diese Routine ermittelt dann die beste Kombination aller gewinnbringenden Algorithmen
# aller hier in TestCombinationGPUs angegebenen GPUs.
#
function _CALCULATE_GV_of_all_TestCombinationGPUs_members () {
    # Wir initialisieren die Indexreise mit 0,0,0,... und erhöhen bis zum Überlauf.
    # Der Überlauf ist das Zeichen zum Abbruch der Endlosschleife
    # TestCombinationGPUs enthält echte GPU-Indexes
    MAX_GPU_TIEFE=${#TestCombinationGPUs[@]}
    unset testGPUs
    for (( lfdGPU=0; $lfdGPU<${MAX_GPU_TIEFE}; lfdGPU++ )); do
        declare -i testGPUs[$lfdGPU]=0
    done

    declare -i finished=0
    while [[ $finished == 0 ]]; do
        # Der GV_COMBINATION key des assoziativen Arrays
        unset algosCombinationKey
        algosCombinationKey=''
        unset CombinationMines
        declare -i CombinationWatts=0
        CombinationMines=''
        
        # Aufaddieren der Watts und Mines über alle MAX_GPU_TIEFE GPU's
        for (( lfdGPU=0; $lfdGPU<${MAX_GPU_TIEFE}; lfdGPU++ )); do
            # Index innerhalb der "GPU${idx}*" Arrays, dessen Werte zu verarbeiten sind
            gpu_idx=${TestCombinationGPUs[${lfdGPU}]}

            declare -n actPossibleCandidateAlgoIndex="PossibleCandidate${gpu_idx}AlgoIndexes"
            algoIdx=${actPossibleCandidateAlgoIndex[${testGPUs[$lfdGPU]}]}

            algosCombinationKey+="${gpu_idx}:${algoIdx},"
            declare -n sumupGPUWatts="GPU${gpu_idx}Watts"
            declare -n sumupGPUMines="GPU${gpu_idx}Mines"
            CombinationWatts+=${sumupGPUWatts[${algoIdx}]}
            CombinationMines+="${sumupGPUMines[${algoIdx}]}+"
        done
        
        # Um die Gesamtformel besser zu verstehen:
        # Wir haben die Summe aller Brutto BTC "Mines" nun in ${CombinationMines}
        #   ${CombinationMines}
        # Wir ziehen davon die Gesamtkosten ab. Diese setzen sich zusammen aus der
        # Summe aller Wattzahlen ${CombinationWatts}
        # multipliziert mit den Kosten (in BTC) für anteilig SolarPower (kWhMin) und/oder NetzPower (kWhMax)
        # Wird überhaupt Netzstrom benötigt werden oder steht die Gesamte Leistung in SolarPower bereit?
        _calculate_ACTUAL_REAL_PROFIT_and_set_MAX_PROFIT \
            ${SolarWattAvailable} ${CombinationWatts} "( ${CombinationMines}0 )"
        if [[ ! "${MAX_PROFIT}" == "${OLD_MAX_PROFIT}" ]]; then
            MAX_PROFIT_GPU_Algo_Combination=${algosCombinationKey}
            # Hier könnten wir eigentlich schon ausgeben, welche GPU mit welchem Algo
            # ---> ARRAYPUSH 3c <---
            msg="New Maximum Profit ${MAX_PROFIT} with GPU:AlgoIndexCombination ${MAX_PROFIT_GPU_Algo_Combination}"
            if [[ ${arrayRedeclareTest} -eq 1 ]]; then
                MAX_PROFIT_MSG_STACK=(${MAX_PROFIT_MSG_STACK[@]} ${msg})
            else
                MAX_PROFIT_MSG_STACK[${#MAX_PROFIT_MSG_STACK[@]}]=${msg}
            fi
            if [[ ${verbose} == 1 ]]; then
                _decode_MAX_PROFIT_GPU_Algo_Combination_to_GPUINDEXES
                echoString="Exactly: "
                for (( i=0; $i<${#GPUINDEXES[@]}; i++ )); do
                    # Split the "String" at ":" into the 2 variables "gpu_idx" and "algoidx"
                    read gpu_idx algoidx <<<"${GPUINDEXES[$i]//:/ }"
                    echoString+="GPU#${gpu_idx}:Algo#"
                    declare -n actCombinedGPU="GPU${gpu_idx}Algos"
                    echoString+="${actCombinedGPU[${algoidx}]},"
                done
                echo "${echoString%%?}"
            fi  ## if [ ${verbose} == 1 ]
        fi

        # (17.11.2017)
        # Wir halten jetzt auch die MAX_FP_MINES und die dabei verbrauchten Watt in MAX_FP_WATTS fest
        # Das sind Daten, die wir "nebenbei" festhalten für den Fall,
        #     dass IM MOMENT (für den kommenden Zyklus) GARANTIERT KEINE NETZPOWER BEZOGEN WERDEN MUSS
        # Die ACTUAL_MAX_FP_MINES werden auch von der innersten Berechnung gesetzt (_calculate_ACTUAL_REAL_PROFIT),
        #     die oben im Rahmen von _calculate_ACTUAL_REAL_PROFIT_and_set_MAX_PROFIT bereits gerufen wurde.
        OLD_MAX_FP_MINES=${MAX_FP_MINES}
        MAX_FP_MINES=$(echo "scale=8; if ( ${ACTUAL_MAX_FP_MINES} > ${MAX_FP_MINES} ) \
                                                   { print ${ACTUAL_MAX_FP_MINES} } \
                                              else { print ${MAX_FP_MINES} }" \
                              | bc )
        if [[ ! "${MAX_FP_MINES}" == "${OLD_MAX_FP_MINES}" ]]; then
            MAX_FP_WATTS=${CombinationWatts}
            MAX_FP_GPU_Algo_Combination=${algosCombinationKey}
            # ---> ARRAYPUSH 3d <---
            msg="New FULL POWER Profit ${MAX_FP_MINES} with GPU:AlgoIndexCombination ${MAX_FP_GPU_Algo_Combination} and ${MAX_FP_WATTS}W"
            if [[ ${arrayRedeclareTest} -eq 1 ]]; then
                MAX_FP_MSG_STACK=(${MAX_FP_MSG_STACK[@]} ${msg})
            else
                MAX_FP_MSG_STACK[${#MAX_FP_MSG_STACK[@]}]=${msg}
            fi
        fi

        # Für Statistik-Zwecke. Dieser Zähler sollte über die 31s-Intervalle ziemlich gleich bleiben
        let GLOBAL_GPU_COMBINATION_LOOP_COUNTER++
        
        # Hier ist der Testlauf beendet und der nächste kann eingeleitet werden, sofern es noch einen gibt
    
        #########################################################################
        # Waren das schon alle Kombinationen?
        # Den letzten algoIdx schalten wir jetzt eins hoch und prüfen auf Überlauf auf dieser Stelle.
        #     Aus der lfdGPU Schleife ist er schon rausgefallen mit lfdGPU=${MAX_GPU_TIEFE}
        #     Also eins übers Ziel hinaus, deshalb Erhöhung des algoIdx der Letzen GPU
        # Man könnte dieses testGPU Array auch als Zahl sehen, deren einzelne Stellen
        #     verschiedene Basen haben können, die in exactNumAlgos aber festgelegt sind.
        #     Diese merkwürdige Zahl zählt man einfach hoch, bis ein Überlauf passieren
        #     würde, indem man auf eine Stelle VOR der Zahl zugreifen müsste
        #     bzw. UNTER den Index [0] des Arrays greifen müsste.

        testGPUs[$((--lfdGPU))]+=1
        while [[ ${testGPUs[$lfdGPU]} == ${exactNumAlgos[${TestCombinationGPUs[${lfdGPU}]}]} ]]; do
            # zurücksetzen...
            testGPUs[$lfdGPU]=0
            # und jetzt die anderen nach unten prüfen, solange es ein "unten" gibt...
            if [[ $lfdGPU -gt 0 ]]; then
                testGPUs[$((--lfdGPU))]+=1
                continue
            else
                finished=1
                break
            fi
        done
    done  # while [[ $finished == 0 ]]; do
}

########################################################################
#
#               _CREATE_AND_CALCULATE_EVERY_AND_ALL_SUBSEQUENT_COMBINATION_CASES
#
#
# Diese Funktion ist die Eierlegende Wollmilchsau, wenn sie denn funktionieren wird.
#
# Sie berechnet die Kombination aus GPU/Algorithmen, die in den aktuellen 31 Sekunden unter
# Berücksichtigung von Solarstrom die gewinnbringendste ist.
# Egal, ob es nur eine oder alle GPUs sind, die jede für sich schon im Gewinn arbeiten würde
#
# Die Parameter:
# 
# $1 Anzahl GPUs, die gleichzeitig laufen und daher verglichen werden sollen
# $2 Die Maximale Anzahl an gewinnbringenden GPUs, die wir vorab unter Beachtung vorhandener SoalrPower ermittelt haben
# $3 Start-Index der zu beginnenden "Ebene"
# $4 Anzahl Schleifendurchgänge der zu beginnenden Ebene
# $5... und weitere:
#       Jede gestartete Ebene hängt ihren momentanen Schleifenindex hinten mit an,
#            wenn sie eine weitere, tiefere Ebene initialisieren muss.
#       Damit kennt die innerste/letzte/tiefste Ebene alle GPU-Indexe, die JETZT diesen EINEN Fall 
#            einer ganz bestimmten GPUs/Algo Kombiantion berechnet und schaut, ob MAX_PROFIT überboten wird.
#       Wenn MAX_PROFIT überboten wird, wird auch die gerade getestete Kombination aus GPUs und Algos festgehalten
#            in der Form
#            "GPUindex:AlgoIndex,[GPUindex:AlgoIndex,]..."
#
#    z.B.    "0:1,4:0,6:3,8:1,"   bedeutet:
#
#        4 GPUs mit den IndexNummern #0, #4, #6 und #8 wurden mit den angegebenen AlgorithmenIndexen berechnet:
#
#        GPU#0 hat (mindestens) 2 gewinnbringende Algorithmen, die über Index 0 und 1 angesteuert werden.
#              Bei dieser Berechnung ist GPU#0 mit dem Algo und Watt, der hinter Index 1 steckt, berechnet worden.
#        GPU#4 hat (mindestens) 1 gewinnbringenden Algorithmus, der über Index 0 angesteuert wird.
#        GPU#6 hat (mindestens) 4 gewinnbringende Algorithmen, die über Index 0 bis 3 angesteuert werden.
#              Bei dieser Berechnung ist GPU#6 mit dem Algo und Watt, der hinter Index 3 steckt, berechnet worden.
#        GPU#8 hat (mindestens) 2 gewinnbringende Algorithmen, die über Index 0 und 1 angesteuert werden.
#              Bei dieser Berechnung ist GPU#8 mit dem Algo und Watt, der hinter Index 1 steckt, berechnet worden.
#
function _CREATE_AND_CALCULATE_EVERY_AND_ALL_SUBSEQUENT_COMBINATION_CASES () {
    # Parameter: $1 = maxTiefe
    #            $2 = Beginn Pointer1 bei Index 0
    #            $3 = Ende letzter Pointer 5
    #            $4-  Jede Ebene hängt dann ihren aktuellen Wert in der Schleife hin,
    #                 in der sie sich selbst gerade befindet.
    #                 Dieser Wert ist ein Index in das Array PossibleCandidateGPUidx
    local -i maxTiefe=$1
    local -i myStart=$2
    local -i myDepth=$3
    shift 3
    local -i iii

    if [[ ${myDepth} == ${maxTiefe} ]]; then
        # Das ist die "Abbruchbedingung", die innerste Schleife überhaupt.
        # Das ist der letzte "Pointer", der keinen Weiteren mehr initialisiert.
        # Hier rufen wir jetzt die eigentliche Kalkulation auf und kehren dann zurück.
        #echo "Innerste Ebene und Ausführungsebene erreicht. Alle zu testenden GPUs sind bekannt und werden nun berechnet."
        
        for (( iii=${myStart}; $iii<${myDepth}; iii++ )); do
            unset TestCombinationGPUs
            declare -ag TestCombinationGPUs
            # Jede Ebene vorher hat ihren aktuelen Indexwert an die Parameterliste gehängt.
            # Das Array TestCombinationGPUs, das die zu untersuchenden GPU-Indexe enthält,
            # wird jetzt komplett für die Berechnungsroutine aufgebaut.
            TestCombinationGPUs=($* ${PossibleCandidateGPUidx[${iii}]})
            #echo "Anzahl Test-Member-Array: ${#TestCombinationGPUs[@]}"
            _CALCULATE_GV_of_all_TestCombinationGPUs_members
        done

    else
        # Hier wird eine Schleife begonnen und dann die Funktion selbst wieder gerufen
        # Dies dient dem Initiieren des zweiten bis letzten Zeigers
        #echo "(Weitere) Schleife starten und nächsten \"Pointer\" initiieren"
        for (( iii=${myStart}; $iii<${myDepth}; iii++ )); do
            #echo "Nächste Ebene übergebene Parameter: ${maxTiefe} $((${iii}+1)) $((${myDepth}+1)) $* ${iii}"
            _CREATE_AND_CALCULATE_EVERY_AND_ALL_SUBSEQUENT_COMBINATION_CASES \
                ${maxTiefe} $((${iii}+1)) $((${myDepth}+1)) $* ${iii}
        done
    fi
}

_notify_about_GPU_INDEX_CHANGED_WHILE_RUNNING ()
{
    # Tja, was machen wir in dem Fall also?
    # Wir setzen eine Desktopmeldung ab... undd machen einen Eintrag
    #     in eine Datei FATAL_ERRORS.log, damit man nicht vergisst,
    #     sich langfristig um das Problem zu kümmern.
    echo "#############################   CHAOS BEHADLUNG   #############################"
    echo "Das gesamte System muss möglicherweise gestoppt und neu gestartet werden:"
    echo "Wir sind auf die Karte mit der UUID=${gpu_uuid} gestossen."
    echo "Sie lief bisher mit einem Miner, der sie als GPU-Index #${RunningGPUid[${gpu_uuid}]} angesprochen hat."
    echo "Jetzt soll sie aber ein Miner mit dem Index ${gpu_idx} ansprechen ???"
    echo "Was also ist mit dem Miner, der noch die vorherige GPU-Index-Nummer #${RunningGPUid[${gpu_uuid}]} bedient?"
    echo "#############################   CHAOS BEHADLUNG   #############################"
    if [[ ! "$ERROR_notified" == "1" ]]; then
        notify-send -t 10000 -u critical "###   CHAOS BEHADLUNG   ###" \
                 "Die Karte \"$1\" mit der UUID \"$2\" \
                 hat den GPU-Index von \"$3\" auf \"$4\" gewechselt. \
                 Wir brechen momentan ab, um diesen Fall in Ruhe gezielt zu bahandeln!"
        if [[ ! "$ERROR_recorded" == "1" ]]; then
            echo $(date "+%F %H:%M:%S") "Die Karte \"$1\" mit der UUID \"$2\"" >>FATAL_ERRORS.log
            echo "                    hat den GPU-Index von \"$3\" auf \"$4\" gewechselt." >>FATAL_ERRORS.log
            ERROR_recorded=1
        fi
        ERROR_notified=1
    else
        ERROR_notified=0
    fi
}

_read_in_kWhMin_kWhMax_kWhAkk () {
    ###############################################################################################
    #
    #     EINLESEN der STROMPREISE in BTC
    #
    # In algo_multi_abfrage.sh, die vor Kurzem gelaufen sein muss,
    # werden die EUR-Strompreise in BTC-Preise umgewandelt.
    # Diese Preise brauchen wir in BTC, um die Kosten von den errechneten "Mines" abziehen zu können.
    #
    unset kwh_BTC; declare -A kwh_BTC
    for ((grid=0; $grid<${#GRID[@]}; grid+=1)); do
        # ACHTUNG. DAS MUSS AUF JEDEN FALL EIN MAL PRO Preiseermittlungslauf LAUF GEMACHT WERDEN!!!
        # IST NUR DER BEQUEMLICHKEIT HALBER IN DIESE <GRID> SCHLEIFE GEPACKT,
        # WEIL SIE NUR 1x DURCHLÄUFT
        # Die in BTC umgerechneten Strompreise für die Vorausberechnungen später
        kwh_BTC[${GRID[$grid]}]=$(< kWh_${GRID[$grid]}_Kosten_BTC.in)
    done
    # AUSNAHME BIS GEKLÄRT IST, WAS MIT DEM SOLAR-AKKU ZU TU IST, hier nur diese beiden Berechnungen
    kWhMax=${kwh_BTC["netz"]}
    kWhMin=${kwh_BTC["solar"]}
    kWhAkk=${kwh_BTC["solar_akku"]}
}

_read_in_All_ALGO_WATTS_MINESin () {
    ###############################################################################################
    #
    #    EINLESEN ALLER ALGORITHMEN, WATTS und MINES, AUF DIE WIR GERADE GEWARTET HABEN
    #
    # In dieser Datei hat die jeweilige GPU jetzt aber ALL ihre Algos,
    #           die dabei verbrauchten Watts
    #           und die "Mines" in BTC, die sie dabei errechnet, festgehalten:
    # ALGO_WATTS_MINES.in
    # Und kann wie üblich über readarray eingelesen werden.

    #
    # Und wir speichern diese in einem Array-Drilling, der immer synchron zu setzen ist:
    #     GPU{realer_gpu_index}Algos[]                 also u.a.  GPU5Algos[]
    #     GPU{realer_gpu_index}Watts[]                 also u.a.  GPU5Watts[]
    #     GPU{realer_gpu_index}Mines[]                 also u.a.  GPU5Mines[]
    #
    # Wenn zur Zeit mehrere Algos für eine GPU möglich sind, sieht das z.B. so aus im Fall von 3 Algos:
    #     GPU{realer_gpu_index}Algos[0]="cryptonight"  also u.a.  GPU5Algos[0]="cryptonight"
    #                               [1]="equihash"                         [1]="equihash"
    #                               [2]="daggerhashimoto"                  [2]="daggerhashimoto"
    #     GPU{realer_gpu_index}Watts[0]="55"           also u.a.  GPU5Watts[0]="55"
    #                               [1]="104"                              [1]="104"    
    #                               [2]="98"                               [2]="98"
    #     GPU{realer_gpu_index}Mines[0]=".00011711"    also u.a.  GPU5Mines[0]=".00011711"
    #                               [1]=".00017009"                        [1]=".00017009"    
    #                               [2]=".00013999"                        [2]=".00013999"
    #
    for (( idx=0; $idx<${#index[@]}; idx++ )); do
        declare -n actGPUAlgos="GPU${index[$idx]}Algos"
        declare -n actAlgoWatt="GPU${index[$idx]}Watts"
        declare -n actAlgoMines="GPU${index[$idx]}Mines"

        # Damit ist sichergestellt, dass gpu_gv-algo.sh mit dem Schreiben ALLER Daten fertig ist.
        while [ -f ${uuid[${index[$idx]}]}/ALGO_WATTS_MINES.lock ]; do echo "Waiting..." >/dev/null; done
        if [ -s ${uuid[${index[$idx]}]}/ALGO_WATTS_MINES.in ]; then
            unset READARR
            readarray -n 0 -O 0 -t READARR <${uuid[${index[$idx]}]}/ALGO_WATTS_MINES.in
            for ((i=0; $i<${#READARR[@]}; i+=3)) ; do
                # Das ist eine sehr elegante Möglichkeit, einen neuen Wert auf ein Array zu pushen.
                # Wir nehmen das jetzt aber alles mal raus und machen es anders und beobachten wieder
                # die Durchlaufzeiten, ob die sich wieder mit der Zeit erhöhen UND ob sich
                # der Speicherbedarf erhöht, OBWOHL alle Arrays immer erst durch UNSET zerstört werden
                # ---> ARRAYPUSH 1 <---
                if [[ ${arrayRedeclareTest} -eq 1 ]]; then
                    actGPUAlgos=(${actGPUAlgos[@]}   "${READARR[$i]}")
                    actAlgoWatt=(${actAlgoWatt[@]}   "${READARR[$i+1]}")
                    actAlgoMines=(${actAlgoMines[@]} "${READARR[$i+2]}")
                else
                    actGPUAlgos[${#actGPUAlgos[@]}]="${READARR[$i]}"
                    actAlgoWatt[${#actAlgoWatt[@]}]="${READARR[$i+1]}"
                    actAlgoMines[${#actAlgoMines[@]}]="${READARR[$i+2]}"
                fi
            done
        fi
    done
}
