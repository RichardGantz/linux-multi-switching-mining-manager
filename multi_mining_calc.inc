#!/bin/bash
########################################################################
#
#               Funktionen und Daten, die der Multi-Miner ebnötigt
#
#


########################################################################
#
# Bis zu 150 Watt- und Mines- Array-Muster, die am Stück abgegriffen werden können, ohne sie in einer Schleife aufbauen zu müssen.
# Die Array-Muster entsprechen den Regeln, denen der bc folgt.
#

# Die ersten 10 Arrays haben inclusive des ";" eine Länge von jeweils 9 Zeichen.
bc_watts_array_pattern="wG[0]=%s;wG[1]=%s;wG[2]=%s;wG[3]=%s;wG[4]=%s;wG[5]=%s;wG[6]=%s;wG[7]=%s;wG[8]=%s;wG[9]=%s;"

# Die nächsten 90 Arrays haben inclusive des ";" eine Länge von jeweils 10 Zeichen.
bc_watts_array_pattern+="wG[10]=%s;wG[11]=%s;wG[12]=%s;wG[13]=%s;wG[14]=%s;wG[15]=%s;wG[16]=%s;wG[17]=%s;wG[18]=%s;wG[19]=%s;wG[20]=%s;wG[21]=%s;wG[22]=%s;wG[23]=%s;wG[24]=%s;wG[25]=%s;wG[26]=%s;wG[27]=%s;wG[28]=%s;wG[29]=%s;wG[30]=%s;wG[31]=%s;wG[32]=%s;wG[33]=%s;wG[34]=%s;wG[35]=%s;wG[36]=%s;wG[37]=%s;wG[38]=%s;wG[39]=%s;wG[40]=%s;wG[41]=%s;wG[42]=%s;wG[43]=%s;wG[44]=%s;wG[45]=%s;wG[46]=%s;wG[47]=%s;wG[48]=%s;wG[49]=%s;wG[50]=%s;wG[51]=%s;wG[52]=%s;wG[53]=%s;wG[54]=%s;wG[55]=%s;wG[56]=%s;wG[57]=%s;wG[58]=%s;wG[59]=%s;wG[60]=%s;wG[61]=%s;wG[62]=%s;wG[63]=%s;wG[64]=%s;wG[65]=%s;wG[66]=%s;wG[67]=%s;wG[68]=%s;wG[69]=%s;wG[70]=%s;wG[71]=%s;wG[72]=%s;wG[73]=%s;wG[74]=%s;wG[75]=%s;wG[76]=%s;wG[77]=%s;wG[78]=%s;wG[79]=%s;wG[80]=%s;wG[81]=%s;wG[82]=%s;wG[83]=%s;wG[84]=%s;wG[85]=%s;wG[86]=%s;wG[87]=%s;wG[88]=%s;wG[89]=%s;wG[90]=%s;wG[91]=%s;wG[92]=%s;wG[93]=%s;wG[94]=%s;wG[95]=%s;wG[96]=%s;wG[97]=%s;wG[98]=%s;wG[99]=%s;"

# Die nächsten 50 (bis zu 900) Arrays haben inclusive des ";" eine Länge von jeweils 11 Zeichen.
bc_watts_array_pattern+="wG[100]=%s;wG[101]=%s;wG[102]=%s;wG[103]=%s;wG[104]=%s;wG[105]=%s;wG[106]=%s;wG[107]=%s;wG[108]=%s;wG[109]=%s;wG[110]=%s;wG[111]=%s;wG[112]=%s;wG[113]=%s;wG[114]=%s;wG[115]=%s;wG[116]=%s;wG[117]=%s;wG[118]=%s;wG[119]=%s;wG[120]=%s;wG[121]=%s;wG[122]=%s;wG[123]=%s;wG[124]=%s;wG[125]=%s;wG[126]=%s;wG[127]=%s;wG[128]=%s;wG[129]=%s;wG[130]=%s;wG[131]=%s;wG[132]=%s;wG[133]=%s;wG[134]=%s;wG[135]=%s;wG[136]=%s;wG[137]=%s;wG[138]=%s;wG[139]=%s;wG[140]=%s;wG[141]=%s;wG[142]=%s;wG[143]=%s;wG[144]=%s;wG[145]=%s;wG[146]=%s;wG[147]=%s;wG[148]=%s;wG[149]=%s;"

# Die ersten 10 Arrays haben inclusive des ";" eine Länge von jeweils 9 Zeichen.
bc_mines_array_pattern="mG[0]=%s;mG[1]=%s;mG[2]=%s;mG[3]=%s;mG[4]=%s;mG[5]=%s;mG[6]=%s;mG[7]=%s;mG[8]=%s;mG[9]=%s;"

# Die nächsten 90 Arrays haben inclusive des ";" eine Länge von jeweils 10 Zeichen.
bc_mines_array_pattern+="mG[10]=%s;mG[11]=%s;mG[12]=%s;mG[13]=%s;mG[14]=%s;mG[15]=%s;mG[16]=%s;mG[17]=%s;mG[18]=%s;mG[19]=%s;mG[20]=%s;mG[21]=%s;mG[22]=%s;mG[23]=%s;mG[24]=%s;mG[25]=%s;mG[26]=%s;mG[27]=%s;mG[28]=%s;mG[29]=%s;mG[30]=%s;mG[31]=%s;mG[32]=%s;mG[33]=%s;mG[34]=%s;mG[35]=%s;mG[36]=%s;mG[37]=%s;mG[38]=%s;mG[39]=%s;mG[40]=%s;mG[41]=%s;mG[42]=%s;mG[43]=%s;mG[44]=%s;mG[45]=%s;mG[46]=%s;mG[47]=%s;mG[48]=%s;mG[49]=%s;mG[50]=%s;mG[51]=%s;mG[52]=%s;mG[53]=%s;mG[54]=%s;mG[55]=%s;mG[56]=%s;mG[57]=%s;mG[58]=%s;mG[59]=%s;mG[60]=%s;mG[61]=%s;mG[62]=%s;mG[63]=%s;mG[64]=%s;mG[65]=%s;mG[66]=%s;mG[67]=%s;mG[68]=%s;mG[69]=%s;mG[70]=%s;mG[71]=%s;mG[72]=%s;mG[73]=%s;mG[74]=%s;mG[75]=%s;mG[76]=%s;mG[77]=%s;mG[78]=%s;mG[79]=%s;mG[80]=%s;mG[81]=%s;mG[82]=%s;mG[83]=%s;mG[84]=%s;mG[85]=%s;mG[86]=%s;mG[87]=%s;mG[88]=%s;mG[89]=%s;mG[90]=%s;mG[91]=%s;mG[92]=%s;mG[93]=%s;mG[94]=%s;mG[95]=%s;mG[96]=%s;mG[97]=%s;mG[98]=%s;mG[99]=%s;"

# Die nächsten 50 (bis zu 900) Arrays haben inclusive des ";" eine Länge von jeweils 11 Zeichen.
bc_mines_array_pattern+="mG[100]=%s;mG[101]=%s;mG[102]=%s;mG[103]=%s;mG[104]=%s;mG[105]=%s;mG[106]=%s;mG[107]=%s;mG[108]=%s;mG[109]=%s;mG[110]=%s;mG[111]=%s;mG[112]=%s;mG[113]=%s;mG[114]=%s;mG[115]=%s;mG[116]=%s;mG[117]=%s;mG[118]=%s;mG[119]=%s;mG[120]=%s;mG[121]=%s;mG[122]=%s;mG[123]=%s;mG[124]=%s;mG[125]=%s;mG[126]=%s;mG[127]=%s;mG[128]=%s;mG[129]=%s;mG[130]=%s;mG[131]=%s;mG[132]=%s;mG[133]=%s;mG[134]=%s;mG[135]=%s;mG[136]=%s;mG[137]=%s;mG[138]=%s;mG[139]=%s;mG[140]=%s;mG[141]=%s;mG[142]=%s;mG[143]=%s;mG[144]=%s;mG[145]=%s;mG[146]=%s;mG[147]=%s;mG[148]=%s;mG[149]=%s;"

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

    # Da wussten wir noch nicht mit den BASH-Stringausgabe-Möglichkeiten umzugehen, deshalb haben wir den sed verwendet.
    # Und deshalb haben wir das in den read gepiped und ein weiteres Problem auf uns genommen, nämlich sicherzustellen,
    # dass die BASH die von read eingelesenen Werte nicht wieder verwirft, wenn dieser read aus einer Subshell herauskommt,
    # in der normalerweise jeder Prozess einer Pipe separat stattfindet...
    #
    #shopt_cmd_before=$(shopt -p lastpipe)
    #shopt -s lastpipe
    #echo ${MAX_PROFIT_GPU_Algo_Combination} | sed -e 's/\,/ /g' | read -a GPUINDEXES

    # ... stattdessen kann die BASH das mittlerweile selbst:
    read -a GPUINDEXES <<<"${MAX_PROFIT_GPU_Algo_Combination//,/ }"

    #${shopt_cmd_before}
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
    #gesamtFormel="mines_sum=$3; real_profit = mines_sum - ( ${gesamtKostenBTC} ) * 24 / 1000"
    #echo "scale=8; ${gesamtFormel}; print real_profit, \" \", mines_sum" \
    echo "scale=8; mines_sum=$3; real_profit = mines_sum - ( ${gesamtKostenBTC} ) * 24 / 1000; print real_profit, \" \", mines_sum" \
        | bc \
        | read ACTUAL_REAL_PROFIT ACTUAL_MAX_FP_MINES
    #   | tee bc_inner_commands \
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

    # Der Performance halber hier den Code rein, statt die Funktion zu rufen
    # Das ist der Anfang des selben Codeblockes wie diese Funktion hatte:
    #_calculate_ACTUAL_REAL_PROFIT $1 $2 "$3"

    # $1 ist die Verfügbare Menge günstiger Power, z.B. ${SolarWattAvailable}
    # $2 ist die Gesamtleistung, die verbraten wird
    # $3 sind die gesamt BTC "Mines", die dabei erzeugt werden

    if [[ $1 -ge $2 ]]; then
        # Die Gesamtwattzahl braucht dann nur mit den Minimalkosten ("solar" Preis) berechnet werden:
        gesamtKostenBTC="($2) * ${kWhMin}"
    else
        gesamtKostenBTC="$1 * ${kWhMin} + ($2 - $1) * ${kWhMax}"
    fi
    # Die Kosten müssen noch ein bisschen "frisiert" werden, damit die Einheiten rausgekürzt werden.
    # Deshalb müssen die Kosten immer mit 24 multipliziert und durch 1000 geteilt werden.
    # Also Kosten immer " * 24 / 1000", wobei wir darauf achten, dass das Teilen
    #     immer als möglichst letzte Rechenoperation erfolgt,
    #     weil alle Stellen >scale einfach weggeschmissen werden.
    #gesamtFormel="mines_sum=$3; real_profit = mines_sum - ( ${gesamtKostenBTC} ) * 24 / 1000"
    #echo "scale=8; ${gesamtFormel}; print real_profit, \" \", mines_sum" \

    # Da MAX_PROFIT eine Dezimalzahl und kein Integer ist, kann die bash nicht damit rechnen.
    # Wir lassen das also von bc berechnen.
    # Dazu merken wir uns den alten Wert in ${OLD_MAX_PROFIT} und geben MAX_PROFIT an bc rein
    # und bekommen es als zweite Zeile wieder raus, wenn der aktuell errechnete Wert größer ist
    # als OLD_MAX_PROFIT
    OLD_MAX_PROFIT=${MAX_PROFIT}
    OLD_MAX_FP_MINES=${MAX_FP_MINES}

    echo 'scale=8;
mines_sum='$3';
real_profit= mines_sum - ( '"${gesamtKostenBTC}"' ) * 24 / 1000;
max_profit='"${MAX_PROFIT}"';
if ( real_profit > '"${MAX_PROFIT}"' ) { max_profit=real_profit }
max_mines='"${MAX_FP_MINES}"';
if ( mines_sum > '"${MAX_FP_MINES}"' ) {
    max_mines=mines_sum;
    max_watts=watts_sum;
}
print real_profit, " ", mines_sum, " ", max_profit, " ", max_mines, " ", max_watts;
#quit
'        | bc \
         | read ACTUAL_REAL_PROFIT ACTUAL_MAX_FP_MINES MAX_PROFIT MAX_FP_MINES MAX_FP_WATTS
    #    | tee bc_ACTUAL_REAL_PROFIT_commands.log \
    #    | tee bc_ACTUAL_REAL_PROFIT_ergebnis.log \
        # | tee -a ${BERECHNUNGSLOG} \

    let GLOBAL_MAX_PROFIT_CALL_COUNTER++
    #[ ${GLOBAL_MAX_PROFIT_CALL_COUNTER} -eq 2 ] && exit 77
    #printf "\r${GLOBAL_MAX_PROFIT_CALL_COUNTER}, AlgosCombinationKey: \"${algosCombinationKey}\""
}

########################################################################
#
#               _CALCULATE_GV_of_all_TestCombinationGPUs_members_bash
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
function _CALCULATE_GV_of_all_TestCombinationGPUs_members_bash () {
    # Wir initialisieren die Indexreise mit 0,0,0,... und erhöhen bis zum Überlauf.
    # Der Überlauf ist das Zeichen zum Abbruch der Endlosschleife
    # TestCombinationGPUs enthält echte GPU-Indexes
    MAX_GPU_TIEFE=${#TestCombinationGPUs[@]}
    if [[ ${debug} -eq 1 ]]; then
        echo "\${MAX_GPU_TIEFE}: ${MAX_GPU_TIEFE}, GPU-Indexes: ${TestCombinationGPUs[@]}"
        for (( xi=0; xi<${#TestCombinationGPUs[@]}; xi++)); do
            echo "Anzahl Algos GPU #${xi}: ${exactNumAlgos[${TestCombinationGPUs[${xi}]}]}"
        done
        BERECHNUNGSLOG=.BERECHNUNGSLOG_${MAX_GPU_TIEFE}
    fi

    unset testGPUs
    for (( lfdGPU=0; $lfdGPU<${MAX_GPU_TIEFE}; lfdGPU++ )); do
        declare -i testGPUs[$lfdGPU]=0
    done

    declare -i finished=0
    while [[ $finished == 0 ]]; do
        # Der GV_COMBINATION key des assoziativen Arrays
        ###unset algosCombinationKey
        algosCombinationKey=''
        ###unset CombinationMines
        #        declare -i CombinationWatts=0
        CombinationWatts=''
        CombinationMines=''
        
        # Aufaddieren der Watts und Mines über alle MAX_GPU_TIEFE GPU's
        for (( lfdGPU=0; $lfdGPU<${MAX_GPU_TIEFE}; lfdGPU++ )); do
            # Index innerhalb der "GPU${idx}*" Arrays, dessen Werte zu verarbeiten sind
            gpu_idx=${TestCombinationGPUs[${lfdGPU}]}
            [[ ${debug} -eq 1 ]] && echo "\$gpu_idx >${gpu_idx}< ist mit der Berechnung dran"

            declare -n actPossibleCandidateAlgoIndex="PossibleCandidate${gpu_idx}AlgoIndexes"
            algoIdx=${actPossibleCandidateAlgoIndex[${testGPUs[$lfdGPU]}]}

            algosCombinationKey+="${gpu_idx}:${algoIdx},"
            declare -n sumupGPUWatts="GPU${gpu_idx}Watts"
            declare -n sumupGPUMines="GPU${gpu_idx}Mines"
            #CombinationWatts+=${sumupGPUWatts[${algoIdx}]}
            CombinationWatts+="${sumupGPUWatts[${algoIdx}]}+"
            CombinationMines+="${sumupGPUMines[${algoIdx}]}+"
        done

        _calculate_ACTUAL_REAL_PROFIT_and_set_MAX_PROFIT \
            ${SolarWattAvailable} "${CombinationWatts}0" "( ${CombinationMines}0 )"
#            ${SolarWattAvailable} ${CombinationWatts} "( ${CombinationMines}0 )"

        # Um die Gesamtformel besser zu verstehen:
        # Wir haben die Summe aller Brutto BTC "Mines" nun in ${CombinationMines}
        #   ${CombinationMines}
        # Wir ziehen davon die Gesamtkosten ab. Diese setzen sich zusammen aus der
        # Summe aller Wattzahlen ${CombinationWatts}
        # multipliziert mit den Kosten (in BTC) für anteilig SolarPower (kWhMin) und/oder NetzPower (kWhMax)
        # Wird überhaupt Netzstrom benötigt werden oder steht die Gesamte Leistung in SolarPower bereit?
if [ 1 -eq 1 ]; then
        if [[ ! "${MAX_PROFIT}" == "${OLD_MAX_PROFIT}" ]]; then
            MAX_PROFIT_GPU_Algo_Combination=${algosCombinationKey}
            # Hier könnten wir eigentlich schon ausgeben, welche GPU mit welchem Algo
            msg="New Maximum Profit ${MAX_PROFIT} with GPU:AlgoIndexCombination ${MAX_PROFIT_GPU_Algo_Combination}"
            MAX_PROFIT_MSG_STACK[${#MAX_PROFIT_MSG_STACK[@]}]=${msg}
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
        if [[ ! "${MAX_FP_MINES}" == "${OLD_MAX_FP_MINES}" ]]; then
            MAX_FP_WATTS=${CombinationWatts}
            MAX_FP_GPU_Algo_Combination=${algosCombinationKey}
            msg="New FULL POWER Profit ${MAX_FP_MINES} with GPU:AlgoIndexCombination ${MAX_FP_GPU_Algo_Combination} and ${MAX_FP_WATTS}W"
            MAX_FP_MSG_STACK[${#MAX_FP_MSG_STACK[@]}]=${msg}
        fi

        # Für Statistik-Zwecke. Dieser Zähler sollte über die 31s-Intervalle ziemlich gleich bleiben
        let GLOBAL_GPU_COMBINATION_LOOP_COUNTER++
fi
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
#               _CALCULATE_GV_of_all_TestCombinationGPUs_members
#
#
# Neue, verbesserte Version, weil die bash so viel mit ihrer eigenen Speicherverwaltung zu tun bekommt,
# dass sie keine Zeit mehr für den eigentlichen Prozess hat.
#
# Wir lassen die ganze Berechnung nun vom bc durchführen.
# Dieser wird dann nur ein einziges mal gerufen statt Millionen mal, um immer nur eine kleine Berechnung zu machen.
# Er wird jetzt der Reihe nach ALLE Berechnungen machen, weil erauch Schleifen verarbeiten kann.
#
# Die folgenden Überlegungen sind zu berücksichtigen:
#
# Diese Funktion bereitet im Wesentlichen den Programmcode vor, der vom bc anzuarbeiten ist.
# Und dieser besteht im Wesentlichen aus verschachtelten for-Schleifen. Eine for-Schleife pro GPU mit der Anzahl an Algos Durchläufen.
# Bei 2 GPUs gibt es zwei for-Schleifen, bei 7 GPUs gibt es 7 for-Schleifen.
#
# Bei 2 GPUs sind zwei Wattwerte  vor der eigentlichen Berechnung aufzusummieren, bei 7 GPUs sind es 7 aufzusummierende Wattwerte
# Bei 2 GPUs sind zwei Mineswerte vor der eigentlichen Berechnung aufzusummieren, bei 7 GPUs sind es 7 aufzusummierende Minestwerte
#
# Bei 2 GPUs bestehen die Combinations-"Strings" aus 2 Bestandteilen ("$gpu_idx:$algo_idx,"}, bei 7 GPUs sind es 7 Bestandteile.
#
# Zur Steigerung der Effektivität bekommt der bc alle Werte in Arrays übergeben.
#
# Zwei Arrays pro GPU werden benötigt: Ein Array mit Watt- und eines mit Hash-In-BTC-Mines-Umgewandelt- Werten:
#      wG[algo_idx]  für die Wattwerte und   mG[algo_idx]  für die BTC-Mines-Werte
#      Das "G" in dem Arraynamen steht für den GPU-Index.
#      Dieses "G" ersetzt die bash durch den entsprechenden GPU-Index, wenn sie den Programmcode schreibt, den der bc abarbeiten wird.
#
function _CALCULATE_GV_of_all_TestCombinationGPUs_members () {
    # TestCombinationGPUs enthält echte GPU-Indexes
    MAX_GPU_TIEFE=${#TestCombinationGPUs[@]}

    # ACHTUNG: BESCHRÄNKUNG AUF 10 GPUs im Moment, bis wir wissen, ob das so läuft.
    FN_combi=''
    bc_loop_var=(i j k l m n o p q r)
    total_number_of_loops_str=''
    for_header=''
    for_footer=''
    watts_str="watts_sum="
    mines_str="mines_sum="
    max_watts="max_watts=${MAX_FP_WATTS}"
    gpu_algo_combination_str_best_profit=''
    gpu_algo_combination_str_max_mines=''
    gpu_algo_profit_str=''
    gpu_algo_mines_str=''

    # Der Anfang des bc Programmes:
    bc_prog="scale=8;max_profit=${MAX_PROFIT};max_mines=${MAX_FP_MINES};solar_kosten_btc=${SolarWattAvailable}*${kWhMin};"

    for (( lfdGPU=0; $lfdGPU<${MAX_GPU_TIEFE}; lfdGPU++ )); do
        gpu_idx=${TestCombinationGPUs[${lfdGPU}]}
        FN_combi+="_${gpu_idx}"

        declare -n actAlgoWatt="GPU${gpu_idx}Watts"
        declare -n actAlgoMines="GPU${gpu_idx}Mines"

        exactNumAlgos=${#actAlgoWatt[@]}
        total_number_of_loops_str+="${exactNumAlgos}*"

        if [ ${exactNumAlgos} -gt 150 ]; then
            echo "Mehr als 150 Algos pro GPU können im Moment nicht verarbeitet werden."
            echo "DAS BITTE KURZ EINPROGRAMMIEREN."
            echo "Wir beenden die Berechnungen an dieser Stelle und brechen total ab!"
            exit 77
        fi

        if [ ${#exactNumAlgos} -eq 3 ]; then                             # 3-stellige Anzahl benötigter Arays
            bc_algo_array_str_len=$(( (exactNumAlgos - 100) * 11 + 990 ))
        elif [ ${#exactNumAlgos} -eq 2 ]; then                           # 2-stellige Anzahl benötigter Arays
            bc_algo_array_str_len=$(( (exactNumAlgos -  10) * 10 +  90 ))
        else                                                             # 1-stellige Anzahl benötigter Arays
            bc_algo_array_str_len=$(( (exactNumAlgos      ) *  9       ))
        fi

        # Elegantes Füllen der Array-Strings mit den jeweiligen Werten
        printf -v bc_watts_array[${gpu_idx}] "\n${bc_watts_array_pattern:0:bc_algo_array_str_len}" "${actAlgoWatt[@]}"
        printf -v bc_mines_array[${gpu_idx}] "\n${bc_mines_array_pattern:0:bc_algo_array_str_len}" "${actAlgoMines[@]}"

        # Ebenfalls an den Anfang des bc Programmes gehören die Array-Definitionen, die hier zu einem Stück hintereinander gesammelt werden
        bc_prog+="${bc_watts_array[${gpu_idx}]//G/${gpu_idx}}"
        bc_prog+="${bc_mines_array[${gpu_idx}]//G/${gpu_idx}}"

        # Die for-Schleifenköpfe folgen ebenfalls hitereinander und werden in dieser Variablen gesammelt
        for_header+="
for ("${bc_loop_var[$lfdGPU]}"=0;"${bc_loop_var[$lfdGPU]}"<"${exactNumAlgos}";"${bc_loop_var[$lfdGPU]}"++){"
        # Die entsprechenden for-Schleifen abschließenden Klamern folgen ebenfalls hitereinander und werden in dieser Variablen gesammelt
        for_footer+="}
"
        # Die Aneinanderreihung der Aufsummierung der Watt- und Mines-Werte erfolgt in den folgenden beiden Strings
        watts_str+="w"${gpu_idx}"["${bc_loop_var[$lfdGPU]}"]+"
        mines_str+="m"${gpu_idx}"["${bc_loop_var[$lfdGPU]}"]+"

        # Das hat gut funktioniert mit dem print innerhalb der Schleife
        #     gpu_algo_combination_str+="${gpu_idx}:\",${bc_loop_var[$lfdGPU]},\","

        # Die jeweils neuen hochzufahrenden Kombinationen aus Effizienz- und Maximum Mines- Werten werden in den folgenden Strings festgehalten,
        #     die ein Array mit dem als neuen besten Algo erkannten Algo-Index pro GPU führen
        gpu_algo_combination_str_best_profit+="
        best_profit_algo["${gpu_idx}"]="${bc_loop_var[$lfdGPU]}";"
        gpu_algo_combination_str_max_mines+="
        max_mines_algo["${gpu_idx}"]="${bc_loop_var[$lfdGPU]}";"

        # Und das sind die Strings, die die als Beste erkannten GPU:Algo-Index Arrays am Ende der Berechnung ausgeben
        gpu_algo_profit_str+=${gpu_idx}":\", best_profit_algo["${gpu_idx}"], \","
        gpu_algo_mines_str+=${gpu_idx}":\", max_mines_algo["${gpu_idx}"], \","
    done

    # Für den Aufbau des bc Programmes haben wir nun alle Bestandteile, die nur noch richtig zusammengesetzt werden müssen,
    #     was im folgenden geschieht:
    bc_prog+="
print \"#TOTAL NUMBER OF LOOPS = ${total_number_of_loops_str%\*} = \", ${total_number_of_loops_str%\*}, \"\n\";
${for_header}
    ${watts_str%+};
    ${mines_str%+};
    if (${SolarWattAvailable}>watts_sum) gesamt_kosten = watts_sum * ${kWhMin} \
    else gesamt_kosten = solar_kosten_btc + ( watts_sum - ${SolarWattAvailable} ) * ${kWhMax};
    real_profit = mines_sum - gesamt_kosten * 24 / 1000;
    if (real_profit>max_profit) {
        max_profit=real_profit;${gpu_algo_combination_str_best_profit}
    }
    if (mines_sum  >max_mines ) {
        max_mines=mines_sum;${gpu_algo_combination_str_max_mines}
        max_watts=watts_sum;
    }
${for_footer}
print \"MAX_PROFIT:   \", max_profit, \" ${gpu_algo_profit_str%\"\,} \"\n\";
print \"MAX_FP_MINES: \", max_mines,  \" ${gpu_algo_mines_str%\"\,} \" MAX_FP_WATTS: \", max_watts,  \"\n\";
#quit
"
    # Eventuelle Zeitmessung. Müssen noch überlegen, ob das hioer sionnvoll ist.
    #start[$c]=$(date +%s)

    # Und der Start des bc...
    # vielleicht im Hintergrund, um gleich die nächste GPU-Kombination parallel in Auftrag geben zu können?
    echo "$bc_prog" \
        | tee .bc_prog_GPUs_${MAX_GPU_TIEFE}${FN_combi} \
        | bc >.bc_result_GPUs_${MAX_GPU_TIEFE}${FN_combi} \
    &
    bc_THREAD_PIDS[$!]=".bc_result_GPUs_${MAX_GPU_TIEFE}${FN_combi}"
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
        if [[ ${debug} -eq 1 ]]; then
            echo $(date "+%Y-%m-%d %H:%M:%S" ) $(date +%s)
            echo "_CREATE_AND_CALCULATE_EVERY_AND_ALL_SUBSEQUENT_COMBINATION_CASES maxTiefe ${maxTiefe} erreicht."
            echo "Starte mit den Testkombinationen von iii=${myStart} bis iii < ${myDepth}."
        fi
        
        for (( iii=${myStart}; $iii<${myDepth}; iii++ )); do
            unset TestCombinationGPUs
            declare -ag TestCombinationGPUs
            # Jede Ebene vorher hat ihren aktuelen Indexwert an die Parameterliste gehängt.
            # Das Array TestCombinationGPUs, das die zu untersuchenden GPU-Indexe enthält,
            # wird jetzt komplett für die Berechnungsroutine aufgebaut.
            TestCombinationGPUs=($* ${PossibleCandidateGPUidx[${iii}]})
            if [[ ${debug} -eq 1 ]]; then
                echo $(date "+%Y-%m-%d %H:%M:%S" ) $(date +%s)
                echo "Testkombinationsarray $iii hat ${#TestCombinationGPUs[@]} Member:" ${TestCombinationGPUs[@]}
            fi

            _CALCULATE_GV_of_all_TestCombinationGPUs_members
        done

    else
        # Hier wird eine Schleife begonnen und dann die Funktion selbst wieder gerufen
        # Dies dient dem Initiieren des zweiten bis letzten Zeigers
        #echo "(Weitere) Schleife starten und nächsten \"Pointer\" initiieren"
        for (( iii=${myStart}; $iii<${myDepth}; iii++ )); do
            #echo "Nächste Ebene übergebene Parameter:" ${maxTiefe} $((${iii}+1)) $((${myDepth}+1)) $* ${PossibleCandidateGPUidx[${iii}]}
            _CREATE_AND_CALCULATE_EVERY_AND_ALL_SUBSEQUENT_COMBINATION_CASES \
                ${maxTiefe} $((${iii}+1)) $((${myDepth}+1)) $* ${PossibleCandidateGPUidx[${iii}]}
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
            echo $(date "+%F %H:%M:%S") "Die Karte \"$1\" mit der UUID \"$2\"" >>${FATAL_ERRORS}
            echo "                    hat den GPU-Index von \"$3\" auf \"$4\" gewechselt." >>${FATAL_ERRORS}
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
    #[[ ${debug} -eq 1 ]] && echo "Anzahl GPU's im Array index=${#index[@]}: ${index[@]}"
    for (( idx=0; $idx<${#index[@]}; idx++ )); do
        declare -n actGPUAlgos="GPU${index[$idx]}Algos"
        declare -n actAlgoWatt="GPU${index[$idx]}Watts"
        declare -n actAlgoMines="GPU${index[$idx]}Mines"

        if [ -s ${uuid[${index[$idx]}]}/ALGO_WATTS_MINES.in ]; then
            unset READARR
            readarray -n 0 -O 0 -t READARR <${uuid[${index[$idx]}]}/ALGO_WATTS_MINES.in
            for ((i=0; $i<${#READARR[@]}; i+=3)) ; do
                # Das ist eine sehr elegante Möglichkeit, einen neuen Wert auf ein Array zu pushen.
                # Wir nehmen das jetzt aber alles mal raus und machen es anders und beobachten wieder
                # die Durchlaufzeiten, ob die sich wieder mit der Zeit erhöhen UND ob sich
                # der Speicherbedarf erhöht, OBWOHL alle Arrays immer erst durch UNSET zerstört werden
                actGPUAlgos[${#actGPUAlgos[@]}]="${READARR[$i]}"
                actAlgoWatt[${#actAlgoWatt[@]}]="${READARR[$i+1]}"
                actAlgoMines[${#actAlgoMines[@]}]="${READARR[$i+2]}"
            done
        fi
    done
}
