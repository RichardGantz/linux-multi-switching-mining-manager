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
if [ ! -f $GPU_SYSTEM_DATA ]; then
    ./gpu-abfrage.sh
fi

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
    declare -a "GPU${index[$j]}Algos"
    declare -a "GPU${index[$j]}Watts"
    declare -a "GPU${index[$j]}Mines"

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

###############################################################################################
# Jetzt wollen wir die Arrays zur Berechnung des optimalen Algo pro Karte mit den Daten füllen,
# die wir für diese Berechnung brauchen.
# Die Daten kommen aus den best_algo_GRID.out Dateien.
# Wir benötigen den Algorithmus (Feld $2)
#     und die Wattzahlen, die wir aufsummieren müssen (Feld $3)
#     und die Brutto-BTC "Minen", die der Algo produziert.
#
# Folgendes ist noch wichtig:
#
# 1. Der Fall "solar_akku" ist überhaupt noch nicht in diese Überlegungen einbezogen woden.
#    Bis her brauchen wir nur aktiv zu werden, wenn "solar" ins Spiel kommt.
#    Wie das dann zu berechnen ist, haben wir tief durchdacht.
#    Nicht aber, wie "solar_akku" da hineinspielt.
#    ---> DESHALB NEHMEN WIR DIE 3. SCHLEIFE EINFACH MAL WEG !!! <---
#
# 2. Beste Algorithmen, die nur kosten (GV<0) lassen wir gleich weg.
#    Das bedeutet, dass die GPU unverzüglich anzuhalten ist!
#    ---> ABER WIR MÜSSEN UNS DRINGEND NOCH DARUM KÜMMERN !!! <---
#
shopt -s lastpipe                           # IMMER WICHTIG, wenn man Daten in 'readarray' hineinpiped !!!
for (( idx=0; $idx<${#index[@]}; idx++ )); do
    declare -n actGPUAlgos="GPU${index[$idx]}Algos"
    declare -n actAlgoWatt="GPU${index[$idx]}Watts"
    declare -n actAlgoMines="GPU${index[$idx]}Mines"

    # sort-key(GV)   algo    WATT  MINES   COST(100%GRID)
    # -.00007377 cryptonight 270 .00017384 .00006598
    for (( grid=0; $grid<${#GRID[@]}-1; grid++ )); do    # Bis zur Klärung von oben (1.) ohne "solar_akku"
    #for (( grid=0; $grid<${#GRID[@]}; grid++ )); do     # Diser Schleifenkopf behandelt alle 3 Powerarten
        #echo "Grid: ${GRID[$grid]}"
        unset READARR
        cat ${uuid[${index[$idx]}]}/best_algo_${GRID[$grid]}.out \
            | sed -e 's/ /\n/g' \
            | readarray -n 0 -O 0 -t READARR
        echo "GV der GPU #${index[$idx]} bei 100% \"${GRID[$grid]}\": ${READARR[0]}"

        # Algos mit Verlust interessieren uns nicht und erzeugen keinen
        # Eintrag in dem actGPUAlgos Array
        if [[ $(expr index "${READARR[0]}" "-") == 1 ]]; then continue; fi

        # Wir brauchen jeden Algorithmus nur EIN mal (keine Doppelten)
        for (( algo=0; $algo<${#actGPUAlgos[@]}; algo++ )); do
            if [[ "${actGPUAlgos[$algo]}" == "${READARR[1]}" ]]; then continue 2; fi
        done
        actGPUAlgos[${#actGPUAlgos[@]}]="${READARR[1]}"
        actAlgoWatt[${#actAlgoWatt[@]}]="${READARR[2]}"
        actAlgoMines[${#actAlgoMines[@]}]="${READARR[3]}"
    done
done

if [ 1 == 0 ]; then
    # Ausgabetest zur Analyse
    for (( idx=0; $idx<${#index[@]}; idx++ )); do
        declare -n actGPUAlgos="GPU${index[$idx]}Algos"
        declare -n actAlgoWatt="GPU${index[$idx]}Watts"
        declare -n actAlgoMines="GPU${index[$idx]}Mines"
        #declare -p actGPUAlgos
        echo "Anzahl Algos GPU #${index[$idx]}: ${#actGPUAlgos[@]}"
        echo "\${actGPUAlgos[0]}: ${actGPUAlgos[0]}"
        echo "\${actGPUAlgos[1]}: ${actGPUAlgos[1]}"
        echo "Die zugehörigen Watt-Werte: ${#actAlgoWatt[@]}"
        echo "\${actAlgoWatt[0]}: ${actAlgoWatt[0]}"
        echo "\${actAlgoWatt[1]}: ${actAlgoWatt[1]}"
        echo "Die zugehörigen BTC-Erzeugnisse: ${#actAlgoMines[@]}"
        echo "\${actAlgoMines[0]}: ${actAlgoMines[0]}"
        echo "\${actAlgoMines[1]}: ${actAlgoMines[1]}"
    done
fi

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

# Erkennen wir anhand der SMARTMETER Daten unter Abzug der Leistung der gerade laufenden GPUs,
#    dass gar kein "solar" zur Verfügung steht, brauchen wir diese Berechnungen überhaupt nicht zu machen!

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
# Mal sehen, wie lange es dauert, die zu berechnen.
# Schätzungsweise liegt eine Berechnung weit unter einer ms.
# Schätzen wir 1 ms pro Durchlauf, dann sind das etwa 2 Sekunden insgesamt.
#
# Wie könte man das Ganze realisieren?
# Wir können einen String aufbauen, den wir dann als Index eines assoziativen Arrays verwenden.
# Jede Stelle im String repräsentiert eine GPU, so dass der String bei 11 GPU's 11 Stellen lang wäre.
# Eine GPU, die nicht laufen darf könnte durch ein "-" eingetragen werden.
# Ansonsten stehen die Ziffern 0-n für den Index des Algo's der GPU
#
# Ein Beispiel mit 3 GPUs und nur 2 GPUs mit 2 Algorithmen:
#
#                  GPU#1:Algo#0 (kein Algo#1)
#                  |           
# GV-Kombi       "000"
#                 ^ ^
#                 | |
# GPU#0:Algo#0 ---   --- und GPU#2:Algo#0
#
#                  GPU#1:Algo#0 (kein Algo#1)
#                  |           
# GV-Kombi       "001"
#                 ^ ^
#                 | |
# GPU#0:Algo#0 ---   --- und GPU#2:Algo#1
#
#                  GPU#1:Algo#0 (kein Algo#1)
#                  |           
# GV-Kombi       "100"
#                 ^ ^
#                 | |
# GPU#0:Algo#1 ---   --- und GPU#2:Algo#0
#
#                  GPU#1:Algo#0 (kein Algo#1)
#                  |           
# GV-Kombi       "101"
#                 ^ ^
#                 | |
# GPU#0:Algo#1 ---   --- und GPU#2:Algo#1
#
# Das wars dan hier schon. Mehr Kombinationen gibt es hier nicht.
# Wir erhalten also das folgende assoziative Array:
#
# GV_KOMBI_MINES["000"]=.00123456 (z.B.)
# GV_KOMBI_MINES["001"]=.00123457 (z.B.)
# GV_KOMBI_MINES["100"]=.00113457 (z.B.)
# GV_KOMBI_MINES["101"]=.00133457 (z.B.)
#
# Der Beste Wert ist nun schnell ermittelt und durch den Index ["101"] ist die Kombination der Algos auch bekannt:
# GPU#0 muss laufen mit Algo#1, GPU#1 mit Algo#0 und GPU#2 mit Algo#1.
#

# Ermittlung derjenigen GPU-Indexes, die
# 1. auszuschalten sind in dem Array SwitchOffGPUs[]
# 2. nur EINEN Algo als Alternative haben und deshalb nicht in die Endberechnung
#    mit einbezogen werden müssen in dem Array RunGPUwithKnownAlgo[]
# 3. mit mehr als einem Algo im Gewinn betrieben werden könnten, bei
#    denen man den optimalen Algo aber erst durch "Ausprobieren" der Kombinationen mit
#    den Algos der anderen GPUs ermitteln muss in dem Array CalcOptimumAlgos[]
#
declare -a SwitchOffGPUs
declare -a RunGPUwithKnownAlgo
declare -a CalcOptimumAlgos

for (( idx=0; $idx<${#index[@]}; idx++ )); do
    declare -n actGPUAlgos="GPU${index[$idx]}Algos"
    #declare -n actAlgoWatt="GPU${index[$idx]}Watts"
    #declare -n actAlgoMines="GPU${index[$idx]}Mines"

    case "${#actGPUAlgos[@]}" in
        "0")
            # Karte ist auszuschalten. Kein Gewinnbringender Algo im Moment
            SwitchOffGPUs[${#SwitchOffGPUs[@]}]=${index[$idx]}
            ;;
        "1")
            # Karte kann so oder so mit dem einzigen Algo im Moment laufen
            RunGPUwithKnownAlgo[${#RunGPUwithKnownAlgo[@]}]=${index[$idx]}
            ;;
        *)
            # GPU kann mit mehr als einem Algo mit Gewinn laufen.
            # Die optimale Kombination all dieser Algos muss
            # anschließend ermittelt werden.
            CalcOptimumAlgos[${#CalcOptimumAlgos[@]}]=${index[$idx]}
            ;;
    esac
done

if [ 1 == 1 ]; then
    # Auswertung zur Analyse
    for (( i=0; $i<${#SwitchOffGPUs[@]}; i++ )); do
        echo "Switch OFF GPU #${SwitchOffGPUs[$i]}"
    done
    for (( i=0; $i<${#RunGPUwithKnownAlgo[@]}; i++ )); do
        declare -n actGPUAlgos="GPU${RunGPUwithKnownAlgo[$i]}Algos"
        echo "GPU #${RunGPUwithKnownAlgo[$i]} can run with ${actGPUAlgos[0]}"
    done
    if [[ "${#CalcOptimumAlgos[@]}" -gt "0" ]]; then
        unset gpu_string
        for (( i=0; $i<${#CalcOptimumAlgos[@]}; i++ )); do
            gpu_string+="#${CalcOptimumAlgos[$i]}, "
        done
        echo "Calculate Maximum Earnings between Algo combinations of GPU's ${gpu_string%, }"
    fi
fi




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
