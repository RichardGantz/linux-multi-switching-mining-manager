#!/bin/bash
########################################################################
#
#               _push_onto_array
#
#
# Um die Berechnungs-Mechaniken besser verstehen zu können, ist es wichtig, den Sinn von Arrays
# tief zu verstehen.
# Diese Funktion legt auf ein vorhandenes Indexiertes Array in lückenloser Manier einen Wert
# oben drauf oder initialisiert es mit einem Wert bei Index 0, wenn es noch nicht vorhanden sein sollte.
# Nach diesem Push gibt es das Array auf jeden Fall und es hat mindestens 1 Member.
# Und alle Member können lückenlos von 0 bis zur "Anzahl Member - 1" in einer Schleife angesteuert werden.
#
function _push_onto_array () {
    declare -n arry="$1"
    arrCnt=${#arry[@]}
    arry[${arrCnt}]="$2"
}

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
    gesamtFormel="$3 - ( ${gesamtKostenBTC} ) * 24 / 1000"
    ACTUAL_REAL_PROFIT=$(echo "scale=8; ${gesamtFormel} " | bc )
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

    _calculate_ACTUAL_REAL_PROFIT $1 $2 "$3"

    # Da MAX_PROFIT eine Dezimalzahl und kein Integer ist, kann die bash nicht damit rechnen.
    # Wir lassen das also von bc berechnen.
    # Dazu merken wir uns den alten Wert in ${OLD_MAX_PROFIT} und geben MAX_PROFIT an bc rein
    # und bekommen es als zweite Zeile wieder raus, wenn der aktuell errechnete Wert größer ist
    # als OLD_MAX_PROFIT
    OLD_MAX_PROFIT=${MAX_PROFIT}

    # Da ist was schief gegangen. Aus ".0" ist plötzlich "0" geworden, was eigentlich für die
    # Berechnung egal ist, aber der Vergleich OLD_MAX_PROFIT == ${MAX_PROFIT} geht dann schief,
    # weil "0" != ".0" ist!    Kann eigentlich gelöscht werden
    #if [[ ${#ACTUAL_REAL_PROFIT} == 0 ]]; then
    #    echo "\$1:$1, \$2:$2, \$3:$3"
    #fi

    shopt_cmd_before=$(shopt -p lastpipe)
    shopt -s lastpipe
    echo "scale=8; if ( ${ACTUAL_REAL_PROFIT} > ${MAX_PROFIT} ) \
                        { print ${ACTUAL_REAL_PROFIT}, \" \", ${ACTUAL_REAL_PROFIT} } \
                   else { print ${ACTUAL_REAL_PROFIT}, \" \", \"${MAX_PROFIT}\" }" \
        | bc \
        | read ACTUAL_REAL_PROFIT MAX_PROFIT
    ${shopt_cmd_before}
    #   | tee bc_DEBUG_STRING.log \
    #   | tee bc_ERGEBNIS.log \
    #   | tee bc_NACH_sed.log \
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
        algosCombinationKey=''
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
        if [[ ! ${MAX_PROFIT} == ${OLD_MAX_PROFIT} ]]; then
            MAX_PROFIT_GPU_Algo_Combination=${algosCombinationKey}
            # Hier könnten wir eigentlich schon ausgeben, welche GPU mit welchem Algo
            echo "New Maximum Profit ${MAX_PROFIT} with GPU:AlgoIndexCombination ${MAX_PROFIT_GPU_Algo_Combination}"
            _decode_MAX_PROFIT_GPU_Algo_Combination_to_GPUINDEXES
            echoString="Exactly: "
            for (( i=0; $i<${#GPUINDEXES[@]}; i++ )); do
                declare -i pos=$(expr index "${GPUINDEXES[$i]}" ":")
                declare -i len=$(($pos-1))
                gpu_idx=${GPUINDEXES[$i]:0:$len}
                algoidx=${GPUINDEXES[$i]:$pos}
                #echoString+="GPU#${PossibleCandidateGPUidx[${i}]}:Algo#"
                echoString+="GPU#${gpu_idx}:Algo#"
                declare -n actCombinedGPU="GPU${gpu_idx}Algos"
                echoString+="${actCombinedGPU[${algoidx}]},"
            done
            #echo "${echoString%%?}"
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
            while [[ $# -gt 0 ]]; do
                # Zuerst alle bisherigen GPUs dieser Kombination aus GPUs ...
                _push_onto_array TestCombinationGPUs ${PossibleCandidateGPUidx[$1]}
                shift
            done
            # ... und dann die momentan letzte, die eigene, oben drauf.
            _push_onto_array TestCombinationGPUs ${PossibleCandidateGPUidx[${iii}]}
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

#####################################################
# Einlesen des bisherigen Status laufender GPUs
####################################################
function _read_in_actual_RUNNING_STATE () {
    if [ -f ${RUNNING_STATE} ]; then
        shopt_cmd_before=$(shopt -p lastpipe)
        shopt -s lastpipe

        unset RUNNING_STATE_CONTENT
        unset AlgoDisabled; declare -Ag AlgoDisabled
        unset RunningGPUid; declare -Ag RunningGPUid
        unset WasItEnabled; declare -Ag WasItEnabled
        unset RunningWatts; declare -Ag RunningWatts
        unset WhatsRunning; declare -Ag WhatsRunning
        cat ${RUNNING_STATE} \
            | grep -e "^GPU-\|^AlgoDisabled" \
            | readarray -n 0 -O 0 -t RUNNING_STATE_CONTENT

        for (( i=0; $i<${#RUNNING_STATE_CONTENT[@]}; i++ )); do
            if [[ "${RUNNING_STATE_CONTENT[$i]:0:4}" == "GPU-" ]]; then
                read RunningUUID RunningGPUidx GenerallyEnabled Watt RunningAlgo <<<"${RUNNING_STATE_CONTENT[$i]//:/ }"
                RunningGPUid[${RunningUUID}]=${RunningGPUidx}
                WasItEnabled[${RunningUUID}]=${GenerallyEnabled}
                RunningWatts[${RunningUUID}]=${Watt}
                WhatsRunning[${RunningUUID}]=${RunningAlgo}
            else
                read muck AlgoName <<<"${RUNNING_STATE_CONTENT[$i]//:/ }"
                AlgoDisabled[${AlgoName}]=1
            fi
        done

        ${shopt_cmd_before}

        if [[ ${verbose} == 1 ]]; then
            if [[ ${#RunningGPUid[@]} -gt 0 ]]; then
                echo "---> Alledgedly Running GPUs/Algos"
                for lfdUUID in ${!RunningGPUid[@]}; do
                    echo "GPU-Index      : ${RunningGPUid[$lfdUUID]}, UUID=$lfdUUID"
                    echo "War sie Enabled? $((${WasItEnabled[$lfdUUID]} == 1))"
                    echo "Wieviel Watt   : ${RunningWatts[$lfdUUID]}"
                    echo "Running Algo   : ${WhatsRunning[$lfdUUID]}"
                done
            fi
            if [[ ${#AlgoDisabled[@]} -gt 0 ]]; then
                echo "---> Temporarily Disabled Algos"
                for algoName in ${!AlgoDisabled[@]}; do echo $algoName; done
            fi
        fi

        # Sichern der alten Datei. Vielleicht brauchen wir sie bei einem Abbruch zur Analyse
        cp -f ${RUNNING_STATE} ${RUNNING_STATE}.BAK
    fi  ### if [ -f ${RUNNING_STATE} ]; then
}
