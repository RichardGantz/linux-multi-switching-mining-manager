#!/bin/bash
###############################################################################
#                           Multi-Mining-Sort und -Calc
# 
# Hier werden die GPU's Algorythmen jeder Karte Sortiert und zusammengefasst.
# 
# Welche Karte "sieger" ist und als erstes z.b. anfangen darf zu minen
#
#
#
#
###############################################################################

# Aktuelle PID der 'multi_mining-controll.sh' ENDLOSSCHLEIFE
echo $$ >$(basename $0 .sh).pid

GPU_SYSTEM_DATA=gpu_system.out
#if [ ! -f $GPU_SYSTEM_DATA ]; then
    ./gpu-abfrage.sh
#fi

###############################################################################
#
# Wie die abbfolge dieses Programm ist und wie es es abfragt
# 1. finde GPU folder
# 1.1. lade 3 arrays mit folgenden Daten "best_algo_netz.out","best_algo_solar","best_algo_solar_akku.out",
#      "gpu_index.in" alle 10 sekunden oder direkt nach "lausche auf" aktualisierung der GPU best* daten
# 1.2. Sortiere jeweils jedes array nach dem besten "profitabelsten" algorytmus
#      Nee. Das macht zu wenig Sinn.
#      Erstens hat gpu_gv-algo.sh bereits den "profitabelsten" Algorithmus ermittelt.
#      Die Punkte 1.1. und 1.2. ENTFALLEN!!!
# 1.3. Gebe jede dieser arrays aus "best_all_netz.out","best_all_solar.out","best_all_solar_akku.out"
#      in diesen outs sind "index(GPU), algo, watt" pro NETZ, SOLAR, AKKU
#
# --->12.Oct.2017<---
# DA IST ZU VIEL UNKLARHEIT DARÜBER, WAS DIESES SCRIPT EIGENTLIVH MACHEN SOLL.
# ES LÄUFT MOMENTAN UND GIBT DIE BESTEN ALGORITHMEN SORTIERT AUS.
# FÜR DEN TATSACHLICHEN SWITCHER ARBEITEN WIR AN EINER DATEI MIT DEM NAMEN multi_mining_switcher.sh WEITER

###############################################################################
# Zu 1. Finde GPU Folder
###############################################################################

# Sortierungsquelldateien
GRID[0]="netz"
GRID[1]="solar"
GRID[2]="solar_akku"
for ((grid=0; $grid<${#GRID[@]}; grid+=1)); do
    best[$grid]=best_all_${GRID[$grid]}.out
    rm -f ${best[$grid]}
    tmpSort[$grid]=.0${GRID[$grid]}_sort
    rm -f ${tmpSort[$grid]}.in
done
unset kwh_BTC; declare -A kwh_BTC

unset READARR
readarray -n 0 -O 0 -t READARR <$GPU_SYSTEM_DATA
# Aus den GPU-Index:Name:Bus:UUID:Auslastung Paaren ein paar Grunddaten 
#     jeder Grafikkarte für den Dispatcher erstellen
declare -a index
declare -a name
#declare -a bus
declare -a uuid
#declare -a auslastung
for ((i=0; $i<${#READARR[@]}; i+=5)) ; do
    j=$(expr $i / 5)
    index[$j]=${READARR[$i]}        # index[] = Grafikkarten-Index für miner
    name[${index[$j]}]=${READARR[$i+1]}
    #bus[${index[$j]}]=${READARR[$i+2]}
    uuid[${index[$j]}]=${READARR[$i+3]}
    #auslastung[${index[$j]}]=${READARR[$i+4]}

    # Was benötigen wir für später noch alles?
    # (Möglicherweise definieren wir das tatsächlich erst später, um übersichtlich zu bleiben?)
    # Pro GPU 3 Arrays mit Variablen Namen. Das ist ein extra Thema,
    # das nicht so leicht zu durchschauen ist.
    # Diese Deklarationen FUNKTIONIEREN jedenfalls erstaunlicherweise und wir haben dann für jede GPU
    # 3 Arrays mit folgenden Namen:
    # GPU#0 Array mit Algonamen heisst GPU0Algos[]
    # GPU#0 Array mit Wattzahlen heisst GPU0Watts[]
    # GPU#0 Array mit Brutto-Mining heisst GPU0Mines[]
    # GPU#1 Array mit Algonamen heisst GPU1Algos[]
    # GPU#1 Array mit Wattzahlen heisst GPU1Watts[]
    # GPU#1 Array mit Brutto-Mining heisst GPU1Mines[]
    # GPU#2 Array mit Algonamen heisst GPU2Algos[]
    # GPU#2 Array mit Wattzahlen heisst GPU2Watts[]
    # GPU#2 Array mit Brutto-Mining heisst GPU2Mines[]
    # usw. ...
    # "GPU${idx}Algos" für die bis zu 3 (GRID) best-Algos,
    # "GPU${idx}Watts" deren Watt-Verbrauch und
    # "GPU${idx}Mines" deren Brutto-Verdienst
    declare -ag "GPU${index[$j]}Algos"
    declare -ag "GPU${index[$j]}Watts"
    declare -ag "GPU${index[$j]}Mines"
    # (23.10.2017) Wir nehmen der Bequemlichkeit halber noch ein Array mit der UUID auf
    declare -ag "GPU${index[$j]}UUID"

    # Quelldateien für Sortierung erstellen
    # sort-key(GV)  algo    WATT   MINES    COST(100%GRID)       + GPU-Index
    #-.00007377 cryptonight 270 .00017384 .00006598        (hier + ${index[$j]})
    for ((grid=0; $grid<${#GRID[@]}; grid+=1)); do
        if [ ! -f ${uuid[${index[$j]}]}/best_algo_${GRID[$grid]}.out ]; then
            echo "-------------------------------------------"
            echo "---           FATAL ERROR               ---"
            echo "-------------------------------------------"
            echo "No file 'best_algo_${GRID[$grid]}.out' available"
            echo "for GPU ${name[${index[$j]}]}"
            echo "Please run '${uuid[${index[$j]}]}/gpu_gv-algo.sh'"
            echo "-------------------------------------------"
        else
            echo $(< ${uuid[${index[$j]}]}/best_algo_${GRID[$grid]}.out ) ${index[$j]} >>${tmpSort[$grid]}.in
        fi
    done
done

# Sortiert ausgeben:
for ((grid=0; $grid<${#GRID[@]}; grid+=1)); do
    if [ -f ${tmpSort[$grid]}.in ]; then
        cat ${tmpSort[$grid]}.in                         \
            | sort -rn                                   \
            | tee ${tmpSort[$grid]}.out                  \
            | gawk -e '{print $NF " " $1 " " $2 " " $3 }' \
            | sed -n '1p' \
            >${best[$grid]}
        if [ 1 == 1 ]; then
            txt=`echo ${tmpSort[$grid]%%_sort}`; txt=${txt:2}
            echo "--------------------------------------"
            echo "           ${txt^^}"
            echo "--------------------------------------"
            gawk -e '{print "GPU " $NF ": " $1 " " $2 " " $3 }' ${tmpSort[$grid]}.out
        fi
    fi
    # ACHTUNG. DAS MUSS AUF JEDEN FALL EIN MAL PRO Preiseermittlungslauf LAUF GEMACHT WERDEN!!!
    # IST NUR DER BEQUEMLICHKEIT HALBER IN DIESE <GRID> SCHLEIFE GEPACKT,
    # WEIL SIE NUR 1x DURCHLÄUFT
    # Die in BTC umgerechneten Strompreise für die Vorausberechnungen später
    kwh_BTC[${GRID[$grid]}]=$(< kWh_${GRID[$grid]}_Kosten_BTC.in)
done
echo "--------------------------------------"

# Diese Überlegungen gelten für den Fall, dass pro Miner MEHRERE GPUs betrieben werden.
# GPU-Index-Datei für miner (==algo ?) erstellen.
# Hier: Komma-getrennt

# Alle GPU-Index-Dateien löschen ?
rm -f cfg_*
for ((grid=0; $grid<${#GRID[@]}; grid+=1)); do
    if [ -f ${best[$grid]} ]; then
        txt=`echo ${tmpSort[$grid]%%_sort}`       # "_sort" vom Namenende entfernen
        gawk -v grid=${txt:2} -e ' \
             $2 > 0 { ALGO[$3]=ALGO[$3] $1 "," } \
             END { for (algo in ALGO) \
                   print substr( ALGO[algo], 1, length(ALGO[algo])-1 ) > "cfg_" grid "_" algo }' \
             ${best[$grid]}
    fi
done

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
    arry[${arrCnt}]=$2
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
    unset GPUINDEXES
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
    # Parameter: $1 = numGPUs, die zu berechnen sind
    #            $2 = maxTiefe
    #            $3 = Beginn Pointer1 bei Index 0
    #            $4 = Ende letzter Pointer 5
    #            $5-  Jede Ebene hängt dann ihren aktuellen Wert in der Schleife hin,
    #                 in der sie sich selbst gerade befindet.
    #                 Dieser Wert ist ein Index in das Array PossibleCandidateGPUidx
    local -i numGPUs=$1
    local -i maxTiefe=$2
    local -i myStart=$3
    local -i myDepth=$4
    shift 4
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
            #echo "Nächste Ebene übergebene Parameter: ${numGPUs} ${maxTiefe} $((${iii}+1)) $((${myDepth}+1)) $* ${iii}"
            _CREATE_AND_CALCULATE_EVERY_AND_ALL_SUBSEQUENT_COMBINATION_CASES \
                ${numGPUs} ${maxTiefe} $((${iii}+1)) $((${myDepth}+1)) $* ${iii}
        done
    fi
}


###############################################################################################
# (17.10.2017)
# Ich glaube, dass hier schon entschieden werden muss, ob es überhaupt gerade "solar" Power gibt.
# Wenn nicht, brauchen wir einfach nur die positiven "netz" Algorithmen laufen zu lassen.
# ...
# (21.10.2017)
# Diese Unterscheidung vom 17.10.2017 hat sich erübrigt.
# Die Berechnungen stimmen auch für den Fall, dass KEINE SolarPower vorhanden ist (SolarWattAvailable=0)
# Dann wird automatisch der beste Algorithmus im reinen Netzbetrieb berechnet!
#
# ABER DAS IST WICHTIG. Und es sollen auch noch generelle Schalter wie GPU_TEMPORARILY_DISBLED
#      oder ALGO_TEMPORARILY DISABLED mit einbezogen werden.
# Welche der System GPUs laufen gerade mit welchem Algorithmus?
# Wir könnten ebenfalls ein Array benutzen, das durch den GPU-Index indexiert ist und
# nur den Algorithmus "equihash" oder "" für gestoppt enthält?
# Und zur Kommunikation mit anderen Prozessen diese Struktur in eine Datei schreiben?

# declare -a GPUs_RUNNING_ALGO     # GPUs_RUNNING_ALGO[$gpu_idx]="equihash" for Running with "equihash"
#                                  # GPUs_RUNNING_ALGO[$gpu_idx]=""         for Not Running
# declare -a GPUs_RUNNING_WATT     # GPUs_RUNNING_WATT[$gpu_idx]=270 (muss gleichzeitig mit _ALGO gesetzt werden!
#
# Die Wattzahlen aller GPUs_RUNNING_ALGO müssen aufsummiert werden in z.B.:
#     ${ActuallyRunningWatts}
# for gpu_idx in ${!GPUs_RUNNING_ALGO[@]}
#
# Irgendwann brauchen wir irgendwoher den aktuellen Powerstand aus dem Smartmeter
# w3m "http://192.168.6.170/solar_api/blabla..." > smartmeter
#          "PowerReal_P_Sum" : 20.0,
# kW=$( grep PowerReal_P_Sum smartmeter | gawk '{print substr($3,1,index($3,".")-1)}' ) ergibt Integer Wattzahl
#
# Jetzt können wir den aktuellen Verbrauch aller Karten von kW abziehen, um zu sehen, ob wir uns
#     im "Einspeisemodus" befinden.
#     (${kW} - ${ActuallyRunningWatts}) < 0 ? SolarWatt=$(expr ${ActuallyRunningWatts} - ${kW} )
#                                           : REINER NETZBETRIEB




##################################################################################
##################################################################################
###                                                                            ###
### FALLS ES ALSO "solar" Power gibt, wird die Variable SolarWattAvailable > 0 ###
### Die Berechnungen stimmen so oder so. Auch für den Fall, dass es keine      ###
### "solar" Power gibt, was durch SolarWattAvailable=0 ausgedrückt wird.       ###
###                                                                            ###
##################################################################################
##################################################################################


declare -i SolarWattAvailable=75   # GPU#1: equihash    - GPU#0: OFF
# Das Programm hat bei mindestens 74W von cryptonight auf equihash umgeschaltet. GUUUUUT!
declare -i SolarWattAvailable=73   # GPU#1: cryptonight - GPU#0: OFF
declare -i SolarWattAvailable=180   # GPU#1: equihash    - GPU#0: OFF

# AUSNAHME BIS GEKLÄRT IST, WAS MIT DEM SOLAR-AKKU ZU TU IST, hier nur diese beiden Berechnungen
kWhMax=${kwh_BTC["netz"]}
kWhMin=${kwh_BTC["solar"]}

###############################################################################################
# (etwa 15.10.2017)
# Jetzt wollen wir die Arrays zur Berechnung des optimalen Algo pro Karte mit den Daten füllen,
# die wir für diese Berechnung brauchen.
#
# ---> ??? <--- Die groben VORAB-Daten kommen aus den best_algo_GRID.out Dateien. <---
# (22.10.2017)
# Diese Vorauswahl über die 3 best_algo_*.out Dateien ist NICHT GANZ SCHLÜSSIG.
# Deshalb berechnen wir JEDEN Algo, den eine GPU kann, auf Gewinn oder Verlust,
# weil nun die realen Verhältnisse ja vorliegen.

# Hier nehmen wir diese Zahlen noch aus den drei best_algo_GRID.out Dateien, was NICHT SCHLÜSSIG ist.
# Wir benötigen den Namen des Algorithmus                  (Feld $2) aus best_algo_GRID.out
#     und die Wattzahlen, die wir aufsummieren müssen      (Feld $3) aus best_algo_GRID.out
#     und die Brutto-BTC "Minen", die der Algo produziert. (Feld $4) aus best_algo_GRID.out

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
# Folgendes ist noch wichtig:
#
# 1. Der Fall "solar_akku" ist überhaupt noch nicht in diese Überlegungen einbezogen worden.
#    Bis her brauchen wir nur aktiv zu werden, wenn "solar" ins Spiel kommt.
#    Wie das dann zu berechnen ist, haben wir tief durchdacht.
#    Nicht aber, wie "solar_akku" da hineinspielt.
#    ---> DESHALB NEHMEN WIR DIE 3. SCHLEIFE EINFACH MAL WEG !!! <---
#
# 2. Beste Algorithmen, die nur etwas kosten (GV<0) lassen wir gleich weg.
#    Das bedeutet, dass die GPU unverzüglich anzuhalten ist,
#    wenn diese GPU nicht mehr durch einen anderen Algo im Array vertreten ist!
#    Der entsprechende Array-Drilling hat dann keinerlei Members, was wir daran erkennen,
#        dass die Anzahl Array-Members oder die "Länge" der Arrays
#        ${#GPU{realer_gpu_index}Algos/Watts/Mines} gleich 0 ist.
#             also z.B.  GPU3Algos[]
#             also z.B.  GPU3Watts[]
#             also z.B.  GPU3Mines[]
#
for (( idx=0; $idx<${#index[@]}; idx++ )); do
    declare -n actGPUAlgos="GPU${index[$idx]}Algos"
    declare -n actAlgoWatt="GPU${index[$idx]}Watts"
    declare -n actAlgoMines="GPU${index[$idx]}Mines"
    declare -n actGPU_UUID="GPU${index[$idx]}UUID"
    actGPU_UUID="${uuid[${index[$idx]}]}"

    if [ ! -f ${uuid[${index[$idx]}]}/ALGO_WATTS_MINES.in ]; then
        # DAS IST DER UNSCHLÜSSIGE FALL, DASS WIR NUR 2 ODER 3 BESTE ALGOS BETRACHTEN,
        # DIE UNTER DER ANNAHME DREI FIXER PREISKONSTELLATIONEN ZUSTANDE KAM

        # sort-key(GV)   algo    WATT  MINES   COST(100%GRID)
        # -.00007377 cryptonight 270 .00017384 .00006598
        for (( grid=0; $grid<${#GRID[@]}-1; grid++ )); do    # Bis zur Klärung von oben (1.) ohne "solar_akku"
            #for (( grid=0; $grid<${#GRID[@]}; grid++ )); do     # Diser Schleifenkopf behandelt alle 3 Powerarten
            #echo "Grid: ${GRID[$grid]}"
            #unset READARR # read -a ARR unsets ARR anyway befor the read
            read -a READARR <${uuid[${index[$idx]}]}/best_algo_${GRID[$grid]}.out

            # Algos mit Verlust interessieren uns nicht und erzeugen keinen
            # Eintrag in dem actGPUAlgos Array
            if [[ $(expr index "${READARR[0]}" "-") == 1 ]]; then continue; fi

            # Wir brauchen jeden Algorithmus nur EIN mal (keine Doppelten)
            for (( algo=0; $algo<${#actGPUAlgos[@]}; algo++ )); do
                if [[ "${actGPUAlgos[$algo]}" == "${READARR[1]}" ]]; then continue 2; fi
            done
            _push_onto_array actGPUAlgos  "${READARR[1]}"
            _push_onto_array actAlgoWatt  "${READARR[2]}"
            _push_onto_array actAlgoMines "${READARR[3]}"
        done
    else
        unset READARR
        readarray -n 0 -O 0 -t READARR <${uuid[${index[$idx]}]}/ALGO_WATTS_MINES.in
        for ((i=0; $i<${#READARR[@]}; i+=3)) ; do
            _push_onto_array actGPUAlgos  "${READARR[$i]}"
            _push_onto_array actAlgoWatt  "${READARR[$i+1]}"
            _push_onto_array actAlgoMines "${READARR[$i+2]}"
        done
    fi
done

# Jetzt geht's los:
# Jetzt brauchen wir alle möglichen Kombinationen aus GPU-Konstellationen:
# Jeder mögliche Algo wird mit allen anderen möglichen Kombinationen berechnet.
# Wir errechnen die jeweilige max. BTC-Generierung pro Kombination
#     und den entsprechenden Gesamtwattverbrauch.
# Anhand des Gesamtwattverbrauchs der Kombination errechnen wir die Gesamtkosten dieser Kombination
#     unter Berücksichtigung eines entsprechenden "solar" Anteils, wodurch die Kosten sinken.
# Die Kombination mit dem besten GV-Verhältnis kann dann leicht
#     durch Vergleich aller Kombinationen ermittelt werden.

# Voraussetzungen, die noch geklärt werden müssen:
# 1. Wir brauchen jetzt natürlich Informationen aus dem SMARTMETER
# 2. Und wir brauchen eine Datenstruktur, anhand der wir erkennen, welche GPU's gerade mit welchem Algo laufen.

# Im Groben brauchen wir folgendes Datenfeld für angenommene 2 Algos pro GPU, die sinnvoll sind:
# (Die Routine ist natürlich so ausgelegt, dass beliebig viele Algos pro GPU möglich sind.
#  Die Anzahl der möglichen Kombinationen steigt mit jeder GPU und jedem weiteren Algo EXPONENTIELL an)
#
# GV-Kombi-0,0,0 ... 0:
# GPU#0:Algo[0]     GPU#1:Algo[0]     GPU#2:Algo[0] ...  GPU#10:Algo[0]
#       Watt[0]  +        Watt[0]  +        Watt[0] ... +       Watt[0]  =  Gesamtwatt-Kombi-0
#       BTCs[0]  +        BTCs[0]  +        BTCs[0] ... +       BTCs[0]  =  GesamtBTCs-Kombi-0
#
# GV-Kombi-0,0,0 ... 1:
# GPU#0:Algo[0]     GPU#1:Algo[0]     GPU#2:Algo[0] ...  GPU#10:Algo[1]
#       Watt[0]  +        Watt[0]  +        Watt[0] ... +       Watt[1]  =  Gesamtwatt-Kombi-1
#       BTCs[0]  +        BTCs[0]  +        BTCs[0] ... +       BTCs[1]  =  GesamtBTCs-Kombi-1
#
# GV-Kombi-0,0 ... 1,0:
# GPU#0:Algo[0]     GPU#1:Algo[0]     GPU#2:Algo[1] ...  GPU#10:Algo[0]
#       Watt[0]  +        Watt[0]  +        Watt[1] ... +       Watt[0]  =  Gesamtwatt-Kombi-2
#       BTCs[0]  +        BTCs[0]  +        BTCs[1] ... +       BTCs[0]  =  GesamtBTCs-Kombi-2
#
# GV-Kombi-0,0 ... 1,1:
# GPU#0:Algo[0]     GPU#1:Algo[0]     GPU#2:Algo[1] ...  GPU#10:Algo[1]
#       Watt[0]  +        Watt[0]  +        Watt[1] ... +       Watt[1]  =  Gesamtwatt-Kombi-3
#       BTCs[0]  +        BTCs[0]  +        BTCs[1] ... +       BTCs[1]  =  GesamtBTCs-Kombi-3
#
# ...
#
# GV-Kombi-1,1 ... 1,0:
# GPU#0:Algo[1]     GPU#1:Algo[1]     GPU#2:Algo[1] ...  GPU#10:Algo[0]
#       Watt[1]  +        Watt[1]  +        Watt[1] ... +       Watt[0]  =  Gesamtwatt-Kombi-2 hoch 11 - 1
#       BTCs[1]  +        BTCs[1]  +        BTCs[1] ... +       BTCs[0]  =  GesamtBTCs-Kombi-2 hoch 11 - 1
#
# GV-Kombi-1,1 ... 1,1:
# GPU#0:Algo[1]     GPU#1:Algo[1]     GPU#2:Algo[1] ...  GPU#10:Algo[1]
#       Watt[1]  +        Watt[1]  +        Watt[1] ... +       Watt[1]  =  Gesamtwatt-Kombi-2 hoch 11
#       BTCs[1]  +        BTCs[1]  +        BTCs[1] ... +       BTCs[1]  =  GesamtBTCs-Kombi-2 hoch 11
#
# Bei 11 GPUs und je 2 Algorithmen sind das 2 hoch 11 Kombinationen: 2048
#

# Wie könnte man das Ganze realisieren?
# Wir setzen vor dem Beginn der Berechnungsorgie die Variable MAX_PROFIT auf 0.0
#     und prüfen nach jeder einzelnen Rechnung, ob der gerade errechnete Wert den bisherigen MAX_PROFIT
#     übertrifft und daher als neuer MAX_PROFIT übernommen wird.
# Die gerade berechnete Kombination aus GPU's:Algos halten wir in einem String fest:
#     MAX_PROFIT_GPU_Algo_Combination="{GPU-Index}:{AlgoIndex},"*
# So wissen wir JEDERZEIT und vor allem natürlich am Ende aller Berechnungen, welche Kombination
#     die mit dem besten Gewinn ist.

# --> DAS IST FÜR SPÄTERES FEINTUNING: <--
# Wir können das auch noch weiter verfeinern, wenn wir Kombinationen mit GLEICHEM Gewinn
#     darauf hin untersuchen, welche "effektiver" ist, welche z.B. bei gleichem Gewinn den minimalsten Strom
#     verbraucht und diesen dann vorziehen.


# Die meisten der folgenden Arrays, die wir erstellen werden, sind nichts weiter als eine Art "View"
# auf die GPU{realer_gpu_index}Algos/Watts/Mines Arrays, die die Rohdaten halten und
#     die diese Rohdaten NUR dort halten.
# Die meisten der folgenden Arrays sind also Hilfs-Arrays oder "Zwischenschritt"-Arrays, die immer
#     irgendwie mit den Rohdaten-Arrays synchron gehalten werden, damit man immer auch sofort
#     auf die Rohdaten zugreifen kann, wenn man sie braucht.
# Meistens enthalten diese Arrays nur den realen GPU-Index, der in dem Namen der Rohdaten-Arrays steckt,
#     z.B. "4"  für  "GPU4Algos"
#
# Ermittlung derjenigen GPU-Indexes, die
# 1. auszuschalten sind in dem Array SwitchOffGPUs[]
#    z.B. hatte das GPU3Algos/Watts/Mines Array-Gespann von oben 0 Member und wäre dann in diesem
#         Array SwitchOffGPUs[] enthalten:
#         SwitchOffGPUs[0]="3"
#
# 2. mit mindestens einem Algo im Gewinn betrieben werden könnten.
#    Der Algo, der letztlich tatsächlich laufen soll, wird durch "Ausprobieren" der Kombinationen mit
#    den Algos der anderen GPUs ermittelt in oder über das Array PossibleCandidateGPUidx[]
#    z.B. hatte das GPU5Algos/Watts/Mines Array-Gespann von oben 3 Member und wäre dann in diesem
#         Array PossibleCandidateGPUidx[] enthalten:
#         PossibleCandidateGPUidx[0]="5"
#
#    Und auf die gewinnbringenden Algos dieser GPU können wir zugreifen, indem wir uns die Index-Nummern
#        der Algorithmen merken, die Gewinn machen; in dem weiteren Hilfs/View-Array
#        PossibleCandidate${ 0 }AlgoIndexes[]
#        z.B. hatte das GPU5Algos/Watts/Mines Array-Gespann von oben die 3 Member
#             GPU5Algos[0]="cryptonight"
#                      [1]="equihash"
#                      [2]="daggerhashimoto"
#        Nehmen wir an, dass nur "cryptonight" keinen Gewinn machen würde, dann wären die gewinnbringenden
#             Algo-Indexes der GPU#5 also
#                      [1]="equihash"
#             und      [2]="daggerhashimoto"
#        Deswegen würden wir uns in dem Hilfs-Array PossibleCandidate${ 0 }AlgoIndexes[] diese beiden
#             Algo-Indexes merken, wodurch es dann so aussehen würde:
#             PossibleCandidate0AlgoIndexes[0]="1"
#             PossibleCandidate0AlgoIndexes[1]="2"
#
#    Und um uns die Arbeit in den späteren Schleifen leichter zu machen, merken wir uns noch die Anzahl
#        der gewinnbringenden Algos dieser GPU in dem
#        (weiteren zu PossibleCandidateGPUidx[0] synchronen Hilfs-) Array
#        exactNumAlgos[0]=2
#
#    Das schöne an den Hilfs-Arrays ist, dass wir sie IMMER in Schleifen von 0 loslaufen lassen können
#        und bis zur Anzahl ihrer Member -1 komplett durchlaufen können. IMMER und LÜCKENLOS!
#        for (( lfdIdx=0; $lfdIdx < ${#HilfsArrayName[@]}; lfdIdx++ ))
#

# Die folgenden beiden Arrays halten nur GPU-Indexnummern als Werte. Nichts weiter!
# Wir bauen diese Arrays jetzt anhand der Kriterien aus den Rohdaten-Arrays in einer
#     alle im System befindlichen GPUs durchgehenden Schleife auf.
declare -a SwitchOffGPUs           # GPUs anyway aus, keine gewinnbringenden Algos zur Zeit
declare -a PossibleCandidateGPUidx # GPUs mit mindestens 1 gewinnbringenden Algo.
                                   # Welcher es werden soll, muss errechnet werden
           # gefolgt von mind. 1x declare -a "PossibleCandidate${pushIdx}AlgoIndexes" ...
declare -a exactNumAlgos  # ... und zur Erleichterung die Anzahl Algos der entsprechenden "PossibleCandidate" GPU's

for (( idx=0; $idx<${#index[@]}; idx++ )); do
    declare -n actGPUAlgos="GPU${index[$idx]}Algos"
    declare -n actAlgoWatt="GPU${index[$idx]}Watts"
    declare -n actAlgoMines="GPU${index[$idx]}Mines"

    numAlgos=${#actGPUAlgos[@]}
    #echo "Anzahl Algos GPU#${index[$idx]}:${numAlgos}"
    case "${numAlgos}" in

        "0")
            # Karte ist auszuschalten. Kein gewinnbringender Algo im Moment
            _push_onto_array SwitchOffGPUs ${index[$idx]}
            ;;

        *)
            # GPU kann mit mindestens einem Algo mit Gewinn laufen.
            # Wir filtern jetzt noch diejenigen Algorithmen raus, die wie oben unter den momentanen Realen
            # Verhältnissen DOCH KEINEN Gewinn machen werden, wenn sie allein, also ohne "Konkrrenz" laufen würden.
            unset profitableAlgoIndexes; declare -a profitableAlgoIndexes

            for (( algoIdx=0; $algoIdx<${numAlgos}; algoIdx++ )); do
                _calculate_ACTUAL_REAL_PROFIT \
                    ${SolarWattAvailable} ${actAlgoWatt[$algoIdx]} "${actAlgoMines[$algoIdx]}"
                # Wenn das NEGATIV ist, muss die Karte übergangen werden. Uns interessieren nur diejenigen,
                # die POSITIV sind und später in Kombinationen miteinander verglichen werden müssen.
                if [[ ! $(expr index "${ACTUAL_REAL_PROFIT}" "-") == 1 ]]; then
                    _push_onto_array profitableAlgoIndexes ${algoIdx}
                fi
            done

            profitableAlgoIndexesCnt=${#profitableAlgoIndexes[@]}
            #echo "profitableAlgoIndexesCnt: ${profitableAlgoIndexesCnt}"
            if [[ ${profitableAlgoIndexesCnt} -gt 0 ]]; then
                # Können wir das noch brauchen?
                pushIdx=${#PossibleCandidateGPUidx[@]}
                PossibleCandidateGPUidx[${pushIdx}]=${index[$idx]}
                exactNumAlgos[${index[$idx]}]=${profitableAlgoIndexesCnt}
                declare -ag "PossibleCandidate${index[$idx]}AlgoIndexes"
                declare -n actCandidatesAlgoIndexes="PossibleCandidate${index[$idx]}AlgoIndexes"
                for (( algoIdx=0; $algoIdx<${profitableAlgoIndexesCnt}; algoIdx++ )); do
                    _push_onto_array actCandidatesAlgoIndexes ${profitableAlgoIndexes[${algoIdx}]}
                done
            else
                # Wenn kein Algo übrigbleiben sollte, GPU aus.
                _push_onto_array SwitchOffGPUs ${index[$idx]}
            fi
            ;;

    esac
done

if [ 1 == 1 ]; then
    # Auswertung zur Analyse
    if [[ "${#SwitchOffGPUs[@]}" -gt "0" ]]; then
        unset gpu_string
        for (( i=0; $i<${#SwitchOffGPUs[@]}; i++ )); do
            gpu_string+="#${SwitchOffGPUs[$i]}, "
        done
        echo "Switch OFF GPU's ${gpu_string%, }"
    fi
    if [[ "${#PossibleCandidateGPUidx[@]}" -gt "0" ]]; then
        unset gpu_string
        for (( i=0; $i<${#PossibleCandidateGPUidx[@]}; i++ )); do
            gpu_string+="#${PossibleCandidateGPUidx[$i]} with ${exactNumAlgos[$i]} Algos, "
        done
        #echo "Candidates for calculating Maximum Earning between Algo combinations of GPU's ${gpu_string%, }"
    fi
fi

echo "=========  Gesamtsystembetrachtung ========="

# Für die Mechanik der systematischen GV-Werte Ermittlung
# Hilfsarray testGPUs, das die "GPU${idx}Algos/Watts/Mines" Algos/Watts/Mines indexiert
unset MAX_GOOD_GPUs; declare -i MAX_GOOD_GPUs  # Wieviele GPUs haben mindestens 1 möglichen Algo

# Die folgenden 3 Variablen werden bei jedem Aufruf von _CALCULATE_GV_of_all_TestCombinationGPUs_members
# neu gesetzt und verwendet. (Vorletzte "Schale")
unset MAX_GPU_TIEFE; declare -i MAX_GPU_TIEFE  # Wieviele dieser GPUs sollen berechnet werden
unset lfdGPU; declare -i lfdGPU                # 
unset testGPUs; declare -A testGPUs

# Diese Nummer bildet die globale, die äusserste, letzte "Schale", von der aus die anderen gestartet/verwendet werden
unset numGPUs; declare -i numGPUs

MAX_GOOD_GPUs=${#PossibleCandidateGPUidx[@]}

if [[ ${MAX_GOOD_GPUs} -gt 0 ]]; then

    # Die Berechnungen schieben gleich den maximalen Gewinn immer höher und merken sich die Kombination
    MAX_PROFIT=".0"
    MAX_PROFIT_GPU_Algo_Combination=''

    # Bei zu wenig Solarpower könnte das ins Minus rutschen...
    #     [ DAS MÜSSEN WIR NOCH CHECKEN, OB DAS WIRKLICH SICHTBAR WIRD ]
    # Deshalb werden wir auch noch Kombinationen mit weniger als der vollen Anzahl an gewinnbringenden GPUs
    #     durchrechnen.
    # Dazu entwickeln wir eine rekursive Funktion, die ALLE möglichen Kombinationen
    #     angefangen mit jeweils EINER laufenden von MAX_GOOD_GPUs
    #     über ZWEI laufende von MAX_GOOD_GPUs
    #     bis hin zu ALLEN laufenden MAX_GOOD_GPUs.
    #
    # numGPUss:        Anzahl zu berechnender GPU-Kombinationen mit numGPUss GPU's
    # Diese Zeile berechnet ALLE ÜBERHAUPT DENKBAREN MÖGLICHEN KOMBINATIONEN
    # for (( numGPUs=1; $numGPUs<${MAX_GOOD_GPUs}; numGPUs++ )); do
    # Testĺauf mit 2 GPUs
    echo "MAX_GOOD_GPUs: ${MAX_GOOD_GPUs} bei SolarWattAvailable: ${SolarWattAvailable}"
    for (( numGPUs=1; $numGPUs<=${MAX_GOOD_GPUs}; numGPUs++ )); do
        # Parameter: $1 = numGPUs, die zu berechnen sind
        #            $2 = maxTiefe
        #            $3 = Beginn Pointer1 bei Index 0
        #            $4 = Ende letzter Pointer 5
        #            $5-  Jede Ebene hängt dann ihren aktuellen Wert in der Schleife hin,
        #                 in der sie sich selbst gerade befindet.
        endStr="GPU von ${MAX_GOOD_GPUs} läuft:"
        if [[ ${numGPUs} -gt 1 ]]; then endStr="GPUs von ${MAX_GOOD_GPUs} laufen:"; fi
        echo "Berechnung aller Kombinationen des Falles, dass nur ${numGPUs} ${endStr}"
        #echo "Übergebene Startparameter: ${numGPUs} ${MAX_GOOD_GPUs} 0 $((${MAX_GOOD_GPUs} - ${numGPUs} + 1))"
        _CREATE_AND_CALCULATE_EVERY_AND_ALL_SUBSEQUENT_COMBINATION_CASES \
            ${numGPUs} ${MAX_GOOD_GPUs} 0 $((${MAX_GOOD_GPUs} - ${numGPUs} + 1))
    done

fi  # if [[ ${MAX_GOOD_GPUs} -gt 0 ]]; then

################################################################################
#
#                Die Auswertung der optimalen Kombination
#
################################################################################

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


echo "=========       Endergebnis        ========="

_decode_MAX_PROFIT_GPU_Algo_Combination_to_GPUINDEXES

# Hier drin halten wir den aktuellen GLOBALEN Status des Gesamtsystems fest
STATUS_FILE="GLOBAL_GPU_ALGO_STATE"
verbose=1

# rm -f ${STATUS_FILE}.lock
#AlgoDisabled:skunk
#AlgoDisabled:sha256

# Wer diese Datei schreiben oder lesen will, muss auf das Verschwinden von *.lock warten...
while [ -f ${STATUS_FILE}.lock ]; do
    echo "Waiting for WRITE access to ${STATUS_FILE}"
    sleep 1
done
# Zum Schreiben reservieren
echo $$ >${STATUS_FILE}.lock

#####################################################
# Einlesen des bisherigen Status
####################################################
if [ -f ${STATUS_FILE} ]; then
    shopt_cmd_before=$(shopt -p lastpipe)
    shopt -s lastpipe

    unset STATUS_FILE_CONTENT
    unset AlgoDisabled; declare -A AlgoDisabled
    unset RunningUUIDs; declare -A RunningUUIDs
    unset WasItEnabled; declare -A WasItEnabled
    unset WhatsRunning; declare -A WhatsRunning
    cat ${STATUS_FILE} | grep -e "^GPU-\|^AlgoDisabled" \
        | readarray -n 0 -O 0 -t STATUS_FILE_CONTENT

    for (( i=0; $i<${#STATUS_FILE_CONTENT[@]}; i++ )); do
        if [[ "${STATUS_FILE_CONTENT[$i]:0:4}" == "GPU-" ]]; then
            read RunningUUID RunningIndex GenerallyEnabled RunningAlgo <<<"${STATUS_FILE_CONTENT[$i]//:/ }"
            RunningUUIDs[${RunningUUID}]=${RunningIndex}
            WasItEnabled[${RunningUUID}]=${GenerallyEnabled}
            WhatsRunning[${RunningUUID}]=${RunningAlgo}
        else
            read muck AlgoName <<<"${STATUS_FILE_CONTENT[$i]//:/ }"
            AlgoDisabled[${AlgoName}]=1
        fi
    done

    ${shopt_cmd_before}

    if [[ ${verbose} == 1 ]]; then
        for n in ${!RunningUUIDs[@]}; do
            echo "GPU-Index      : ${RunningUUIDs[$n]}, UUID=$n"
            echo "War sie Enabled?" $((${WasItEnabled[$n]} == 1))
            echo "Running Algo   : ${WhatsRunning[$n]}"
        done
        echo "---> Temporarily Disabled Algos"
        for n in ${!AlgoDisabled[@]}; do echo $n; done
    fi
fi

#####################################################
# Ausgabe des neuen Status
####################################################

printf 'UUID : GPU-Index : Enabled (1/0) : Running with AlgoName or Stopped if \"\"\n' >${STATUS_FILE}
printf '=========================================================================\n'  >>${STATUS_FILE}

if [[ ${verbose} == 1 ]]; then
    echo "Die optimale Konfiguration besteht aus diesen ${#GPUINDEXES[@]} Karten:"
fi
for (( i=0; $i<${#GPUINDEXES[@]}; i++ )); do
    # Split the "String" at ":" into the 2 variables "gpu_idx" and "algoidx"
    read gpu_idx algoidx <<<"${GPUINDEXES[$i]//:/ }"

    declare -n actGPUalgoName="GPU${gpu_idx}Algos"
    declare -n actGPU_UUID="GPU${gpu_idx}UUID"
    gpu_uuid=${actGPU_UUID}


    if [ ! ${#RunningUUIDs[@]} -eq 0 ]; then
        #############################   CHAOS BEHADLUNG   #############################
        ### Schweres Thema: IST DER GPU-INDEX NOCH DER SELBE ??? <-----------------------
        if [[ "${gpu_idx}" != "${RunningUUIDs[${gpu_uuid}]}" ]]; then
            echo "#############################   CHAOS BEHADLUNG   #############################"
            echo "Das gesamte System muss möglicherweise gestoppt und neu gestartet werden:"
            echo "Wir sind auf die Karte mit der UUID=${gpu_uuid} gestossen."
            echo "Sie lief bisher mit einem Miner, der sie als GPU-Index #${RunningUUIDs[${gpu_uuid}]} angesprochen hat."
            echo "Jetzt soll sie aber ein Miner mit dem Index ${gpu_idx} ansprechen ???"
            echo "Was also ist mit dem Miner, der noch die vorherige GPU-Index-Nummer #${RunningUUIDs[${gpu_uuid}]} bedient?"
            echo "#############################   CHAOS BEHADLUNG   #############################"
            _notify_about_GPU_INDEX_CHANGED_WHILE_RUNNING "${name[${gpu_idx}]}" \
                                                          "${gpu_uuid}" \
                                                          "${RunningUUIDs[${gpu_uuid}]}" \
                                                          "${gpu_idx}"
            exit
        fi
        #############################   CHAOS BEHADLUNG   #############################

        ### Die neue Information holen wir aus der gpu-system.out <---   NOCH ZU IMPLEMENTIEREN
        if [[ ${verbose} == 1 ]]; then
            if [[ ${WasItEnabled[${gpu_uuid}]} == 0 ]]; then
                echo "KARTE ${gpu_uuid} WIEDER GENERELL ENABLED"
            fi
        fi

        printf "${gpu_uuid}:${gpu_idx}:1:" >>${STATUS_FILE}

        # Ist die GPU generell Enabled oder momentan nicht zu behandeln?
        if ((${WasItEnabled[${gpu_uuid}]} == 1)); then
            ### Die neue Information holen wir aus der gpu-system.out <---   NOCH ZU IMPLEMENTIEREN
            if [[ 1 == 1 ]]; then   ### IS IT STILL ENABLED?
                ###       YES
                #printf "1:"

                ########################################################
                ### START- STOP- SWITCHING- Skripte.
                ### Hier ist die richtige Stelle, die Miner zu switchen
                ########################################################
                ### Lief die Karte mit dem selben Algorithmus?
                if [[ "${WhatsRunning[${gpu_uuid}]}" != "${actGPUalgoName[${algoidx}]}" ]]; then
                    if [[ -z ${WhatsRunning[${gpu_uuid}]} ]]; then
                        # MINER- Behandlung
                        echo "GPU#${gpu_idx} EINSCHALTEN mit Algo ${actGPUalgoName[${algoidx}]}"
                    else
                        # MINER- Behandlung
                        echo "GPU#${gpu_idx} Algo wechseln von ${WhatsRunning[${gpu_uuid}]} auf ${actGPUalgoName[${algoidx}]}"
                    fi
                else
                    # Alter und neuer Algo ist gleich, kann weiterlaufen
                    echo "GPU#${gpu_idx} läuft weiterhin auf ${actGPUalgoName[${algoidx}]}"
                fi
                printf "${actGPUalgoName[${algoidx}]}\n" >>${STATUS_FILE}
            else
                ### IS IT STILL ENABLED?
                ###       NO
                #printf "0:"
                echo 1>/dev/null
            fi
        else
            ### WAR NICHT ENABLED
            ### Die neue Information holen wir aus der gpu-system.out <---   NOCH ZU IMPLEMENTIEREN
            ### Soll eingeschaltet werden, ist wieder generell verfügbar
            #printf "1:"
            printf "${actGPUalgoName[${algoidx}]}\n" >>${STATUS_FILE}
            
            ### ANDERFALLS
            #printf "0:"
            echo 4 >/dev/null
        fi
    else
        printf "${gpu_uuid}:${gpu_idx}:1:${actGPUalgoName[${algoidx}]}\n" >>${STATUS_FILE}
    fi

    if [[ ${verbose} == 1 ]]; then
        echo "GPU-Index        #${gpu_idx}"
        echo "GPU-Algo-Index   [${algoidx}]"
        declare -n actCombinedGPU="GPU${gpu_idx}Algos"
        echo "GPU-AlgoName     ${actCombinedGPU[${algoidx}]}"
        declare -n actCombinedGPU="GPU${gpu_idx}Watts"
        algoWatts=${actCombinedGPU[${algoidx}]}
        echo "GPU-AlgoWatt     ${algoWatts}"
        declare -n actCombinedGPU="GPU${gpu_idx}Mines"
        algoMines=${actCombinedGPU[${algoidx}]}
        echo "GPU-AlgoMines    ${algoMines}"
        _calculate_ACTUAL_REAL_PROFIT \
            ${SolarWattAvailable} ${algoWatts} ${algoMines}
        echo "RealGewinnSelbst ${ACTUAL_REAL_PROFIT} (wenn alleine laufen würde)"
    fi
done

if [ ${#SwitchOffGPUs[@]} -gt 0 ]; then
    if [[ ${verbose} == 1 ]]; then
        echo "Die folgenden Karten müssen ausgeschaltet werden:"
    fi
    for (( i=0; $i<${#SwitchOffGPUs[@]}; i++ )); do
        gpu_idx=${SwitchOffGPUs[$i]}
        declare -n actGPU_UUID="GPU${gpu_idx}UUID"
        gpu_uuid=${actGPU_UUID}
        
        ### Die neue Information holen wir aus der gpu-system.out <---   NOCH ZU IMPLEMENTIEREN
        printf "${gpu_uuid}:${gpu_idx}:1:\n" >>${STATUS_FILE}
        if [[ ${verbose} == 1 ]]; then
            echo "GPU-Index        #${gpu_idx}"
        fi
    done
fi
if [[ ${verbose} == 1 ]]; then
    echo "-------------------------------------------------"
fi

for n in ${!AlgoDisabled[@]}; do
    printf "AlgoDisabled:$n\n" >>${STATUS_FILE}
done

echo "Neues globales Switching Sollzustand Kommandofile"
cat ${STATUS_FILE}


# Zugriff auf die Globale Steuer- und Statusdatei wieder zulassen
rm -f ${STATUS_FILE}.lock



################################################################################
#
#                      Vorläufiges ENDE des Skripts
#
################################################################################

# ./miner --cuda_dev cfg_NETZ_equihash --solver $devices --server blablub.com -u btcadrtesse -p x 

# equihash
# ./miner --server server.com --port 7777 --user name --pass secret --cuda_devices 0 1 2 3 --eexit 1

# GLOBALER miner
# -i --intensity=N[,N] GPU intensity 8.0-25.0 (default: auto) Decimals are allowed for fine tuning 
#
# -d, --devices Comma separated list of CUDA devices to use.
#
# ./ccminer -a cryptonight -o stratum+tcp://cryptonight.eu.nicehash.com:3355 -u 12X6Enpg5FBQ332Re3vjU5FAxxQWUioBMg.980ti -p 0
