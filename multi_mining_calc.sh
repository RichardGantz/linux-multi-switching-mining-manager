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

# Für die Ausgabe von mehr Zwischeninformationen auf 1 setzen.
# Null, Empty String, oder irgendetwas andere bedeutet AUS.
verbose=0

SYSTEM_FILE="gpu_system.out"
# ACHTUNG: Hier muss das .in in der Variable SYSTEM_STATE enthalten sein.
#          In dem Skript gpu-abfrage.sh ist die Variable ohne ".in" !!!
SYSTEM_STATE="GLOBAL_GPU_SYSTEM_STATE.in"
# Hier drin halten wir den aktuellen GLOBALEN Status des Gesamtsystems fest
RUNNING_STATE="GLOBAL_GPU_ALGO_RUNNING_STATE"

GRID[0]="netz"
GRID[1]="solar"
GRID[2]="solar_akku"

# Funktionen Definitionen ausgelagert
source ./multi_mining_calc.inc



# Diese Abfrage erzeugt die beiden o.g. Dateien.
./gpu-abfrage.sh

# In der Datei "GLOBAL_GPU_SYSTEM_STATE.in" können die Enabled-Flags am Ende jeder Zeile
#    manuell auf 0 geändert werden für DISABLED oder wieder auf 1 für ENABLED.
#    Wir merken uns den globalen Enabled SOLL-Status gleich
#    in dem Assoziativen Array IsItEnabled[$uuid] der entsprechenden UUID
unset ENABLED_UUIDs
declare -A uuidEnabledSOLL
if [ -f ${SYSTEM_STATE} ]; then
    shopt_cmd_before=$(shopt -p lastpipe)
    shopt -s lastpipe
    cat ${SYSTEM_STATE} \
        | grep -e "^GPU-" \
        | readarray -n 0 -O 0 -t ENABLED_UUIDs

    for (( i=0; $i<${#ENABLED_UUIDs[@]}; i++ )); do
        echo ${ENABLED_UUIDs[$i]} \
            | cut -d':' --output-delimiter=' ' -f1,3 \
            | read UUID GenerallyEnabled
        uuidEnabledSOLL[${UUID}]=${GenerallyEnabled}
    done
    ${shopt_cmd_before}
fi
    
unset READARR
readarray -n 0 -O 0 -t READARR <${SYSTEM_FILE}
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

done

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

###############################################################################################
#
# Irgendwann brauchen wir irgendwoher den aktuellen Powerstand aus dem Smartmeter
# w3m "http://192.168.6.170/solar_api/blabla..." > smartmeter
#          "PowerReal_P_Sum" : 20.0,
# kW=$( grep PowerReal_P_Sum smartmeter | gawk '{print substr($3,1,index($3,".")-1)}' ) ergibt Integer Wattzahl
#
# Jetzt können wir den aktuellen Verbrauch aller Karten von kW abziehen, um zu sehen, ob wir uns
#     im "Einspeisemodus" befinden.
#     (${kW} - ${ActuallyRunningWatts}) < 0 ? SolarWatt=$(expr ${ActuallyRunningWatts} - ${kW} )
#
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
declare -i SolarWattAvailable=350   # GPU#1: equihash    - GPU#0: OFF

###############################################################################################
# (etwa 15.10.2017)
# Jetzt wollen wir die Arrays zur Berechnung des optimalen Algo pro Karte mit den Daten füllen,
# die wir für diese Berechnung brauchen.
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

    if [ -s ${actGPU_UUID}/ALGO_WATTS_MINES.in ]; then
        unset READARR
        readarray -n 0 -O 0 -t READARR <${actGPU_UUID}/ALGO_WATTS_MINES.in
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
# Die Kombination mit dem besten GV-Verhältnis merken wir uns jeweils in MAX_PROFIT und MAX_PROFIT_GPU_Algo_Combination

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
#        PossibleCandidate${ "5" }AlgoIndexes[]
#        z.B. hatte das GPU5Algos/Watts/Mines Array-Gespann von oben die 3 Member
#             GPU5Algos[0]="cryptonight"
#                      [1]="equihash"
#                      [2]="daggerhashimoto"
#        Nehmen wir an, dass nur "cryptonight" keinen Gewinn machen würde, dann wären die gewinnbringenden
#             Algo-Indexes der GPU#5 also
#                      [1]="equihash"
#             und      [2]="daggerhashimoto"
#        Deswegen würden wir uns in dem Hilfs-Array PossibleCandidate${ "5" }AlgoIndexes[] diese beiden
#             Algo-Indexes merken, wodurch es dann so aussehen würde:
#             PossibleCandidate5AlgoIndexes[0]="1"
#             PossibleCandidate5AlgoIndexes[1]="2"
#
#    Und um uns die Arbeit in den späteren Schleifen leichter zu machen, merken wir uns noch die Anzahl
#        der gewinnbringenden Algos dieser GPU in dem
#        (weiteren zu PossibleCandidateGPUidx[0] synchronen Hilfs-) Array
#        exactNumAlgos[5]=2
#

# Die folgenden beiden Arrays halten nur GPU-Indexnummern als Werte. Nichts weiter!
# Wir bauen diese Arrays jetzt anhand der Kriterien aus den Rohdaten-Arrays in einer
#     alle im System befindlichen GPUs durchgehenden Schleife auf.
declare -a SwitchOffGPUs           # GPUs anyway aus, keine gewinnbringenden Algos zur Zeit
declare -a PossibleCandidateGPUidx # GPUs mit mindestens 1 gewinnbringenden Algo.
                                   # Welcher es werden soll, muss errechnet werden
           # gefolgt von mind. 1x declare -a "PossibleCandidate${gpu_index}AlgoIndexes" ...
declare -a exactNumAlgos  # ... und zur Erleichterung die Anzahl Algos der entsprechenden "PossibleCandidate" GPU's

for (( idx=0; $idx<${#index[@]}; idx++ )); do
    declare -n actGPUAlgos="GPU${index[$idx]}Algos"
    declare -n actAlgoWatt="GPU${index[$idx]}Watts"
    declare -n actAlgoMines="GPU${index[$idx]}Mines"
    declare -n actGPU_UUID="GPU${index[$idx]}UUID"

    numAlgos=${#actGPUAlgos[@]}
    # Wenn die GPU seit neuestem generell DISABLED ist, pushen wir sie hier auf den
    # SwitchOffGPUs Stack, indem wir die numAlgos künslich auf 0 setzen:
    if [[ "${uuidEnabledSOLL[${actGPU_UUID}]}" == "0" ]]; then
        numAlgos=0
    fi
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

if [ ${verbose} == 1 ]; then
    # Auswertung zur Analyse
    if [[ ${#PossibleCandidateGPUidx[@]} -gt 0 ]]; then
        unset gpu_string
        for (( i=0; $i<${#PossibleCandidateGPUidx[@]}; i++ )); do
            gpu_string+="#${PossibleCandidateGPUidx[$i]} with ${exactNumAlgos[$i]} Algos, "
        done
        echo "GPU Kandidaten mit Gewinn bringenden Algos: ${gpu_string%, }"
    fi
    if [[ ${#SwitchOffGPUs[@]} -gt 0 ]]; then
        unset gpu_string
        for (( i=0; $i<${#SwitchOffGPUs[@]}; i++ )); do
            gpu_string+="#${SwitchOffGPUs[$i]}, "
        done
        echo "Switch OFF GPU's ${gpu_string%, }"
    fi
fi

echo "=========  Gesamtsystemberechnung  ========="

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
    #
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
        _CREATE_AND_CALCULATE_EVERY_AND_ALL_SUBSEQUENT_COMBINATION_CASES \
            ${numGPUs} ${MAX_GOOD_GPUs} 0 $((${MAX_GOOD_GPUs} - ${numGPUs} + 1))
    done

fi  # if [[ ${MAX_GOOD_GPUs} -gt 0 ]]; then

################################################################################
#
#                Die Auswertung der optimalen Kombination
#
################################################################################

printf "=========       Endergebnis        =========\n"

_decode_MAX_PROFIT_GPU_Algo_Combination_to_GPUINDEXES

# Wer diese Datei schreiben oder lesen will, muss auf das Verschwinden von *.lock warten...
while [ -f ${RUNNING_STATE}.lock ]; do
    echo "Waiting for WRITE access to ${RUNNING_STATE}"
    sleep 1
done
# Zum Schreiben reservieren
echo $$ >${RUNNING_STATE}.lock

#####################################################
# Einlesen des bisherigen Status
####################################################
if [ -f ${RUNNING_STATE} ]; then
    shopt_cmd_before=$(shopt -p lastpipe)
    shopt -s lastpipe

    unset RUNNING_STATE_CONTENT
    unset AlgoDisabled; declare -A AlgoDisabled
    unset RunningGPUid; declare -A RunningGPUid
    unset WasItEnabled; declare -A WasItEnabled
    unset WhatsRunning; declare -A WhatsRunning
    cat ${RUNNING_STATE} \
        | grep -e "^GPU-\|^AlgoDisabled" \
        | readarray -n 0 -O 0 -t RUNNING_STATE_CONTENT

    for (( i=0; $i<${#RUNNING_STATE_CONTENT[@]}; i++ )); do
        if [[ "${RUNNING_STATE_CONTENT[$i]:0:4}" == "GPU-" ]]; then
            read RunningUUID RunningGPUidx GenerallyEnabled RunningAlgo <<<"${RUNNING_STATE_CONTENT[$i]//:/ }"
            RunningGPUid[${RunningUUID}]=${RunningGPUidx}
            WasItEnabled[${RunningUUID}]=${GenerallyEnabled}
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
            for uuid in ${!RunningGPUid[@]}; do
                echo "GPU-Index      : ${RunningGPUid[$uuid]}, UUID=$uuid"
                echo "War sie Enabled? $((${WasItEnabled[$uuid]} == 1))"
                echo "Running Algo   : ${WhatsRunning[$uuid]}"
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

#####################################################
# Ausgabe des neuen Status
####################################################

printf 'UUID : GPU-Index : Enabled (1/0) : Running with AlgoName or Stopped if \"\"\n' >${RUNNING_STATE}
printf '=========================================================================\n'  >>${RUNNING_STATE}

# Man könnte noch gegenchecken, dass die Summe aus laufenden und abgeschalteten
#     GPU's die Anzahl GPU's ergeben muss, die im System sind.
# Es gibt ja ${MAX_GOOD_GPUs}, ${SwitchOnCnt}, ${SwitchOffCnt} und ${GPUsCnt}
# Es müsste gelten: ${MAX_GOOD_GPUs} + ${SwitchOffCnt} == ${GPUsCnt}
#              und: ${MAX_GOOD_GPUs} >= ${SwitchOnCnt},
#                   da möglicherweise die beste Kombination aus weniger als ${MAX_GOOD_GPUs} besteht.
# Dann hätten wir diejenigen ${MAX_GOOD_GPUs} - ${SwitchOnCnt} noch zu überprüfen und zu stoppen !?!?
declare -i SwitchOnCnt=${#GPUINDEXES[@]}
declare -i SwitchOffCnt=${#SwitchOffGPUs[@]}
declare -i GPUsCnt=${#index[@]}
if [ $((${SwitchOffCnt} + ${SwitchOnCnt})) -ne ${GPUsCnt} ]; then
    echo "---> ??? Oh je, ich glaube fast, wir haben da ein paar GPU's vergessen abzuschalten ??? <---"
fi

if [[ ${verbose} == 1 ]]; then
    echo "Die optimale Konfiguration besteht aus diesen ${SwitchOnCnt} Karten:"
fi
###                                                             ###
#   Zuerst die am Gewinn beteiligten GPUs, die laufen sollen...   #
###                                                             ###
for (( i=0; $i<${SwitchOnCnt}; i++ )); do
    # Split the "String" at ":" into the 2 variables "gpu_idx" and "algoidx"
    read gpu_idx algoidx <<<"${GPUINDEXES[$i]//:/ }"

    declare -n actGPUalgoName="GPU${gpu_idx}Algos"
    declare -n actGPU_UUID="GPU${gpu_idx}UUID"
    gpu_uuid=${actGPU_UUID}


    if [ ! ${#RunningGPUid[@]} -eq 0 ]; then
        #############################   CHAOS BEHADLUNG Anfang  #############################
        ### Schweres Thema: IST DER GPU-INDEX NOCH DER SELBE ??? <-----------------------
        if [[ "${gpu_idx}" != "${RunningGPUid[${gpu_uuid}]}" ]]; then
            echo "#############################   CHAOS BEHADLUNG   #############################"
            echo "Das gesamte System muss möglicherweise gestoppt und neu gestartet werden:"
            echo "Wir sind auf die Karte mit der UUID=${gpu_uuid} gestossen."
            echo "Sie lief bisher mit einem Miner, der sie als GPU-Index #${RunningGPUid[${gpu_uuid}]} angesprochen hat."
            echo "Jetzt soll sie aber ein Miner mit dem Index ${gpu_idx} ansprechen ???"
            echo "Was also ist mit dem Miner, der noch die vorherige GPU-Index-Nummer #${RunningGPUid[${gpu_uuid}]} bedient?"
            echo "#############################   CHAOS BEHADLUNG   #############################"
            _notify_about_GPU_INDEX_CHANGED_WHILE_RUNNING "${name[${gpu_idx}]}" \
                                                          "${gpu_uuid}" \
                                                          "${RunningGPUid[${gpu_uuid}]}" \
                                                          "${gpu_idx}"
            exit
        fi
        #############################   CHAOS BEHADLUNG  Ende  #############################

        # Der Soll-Zustand kommt aus der manuell bearbeiteten Systemdatei ganz am Anfang
        # Wir schalten auf jeden Fall den gewünschten Soll-Zustand.
        # Eventuell müssen wir mit dem letzten Run-Zustand vergleichen, um etwas zu stoppen...
        printf "${gpu_uuid}:${gpu_idx}:${uuidEnabledSOLL[${gpu_uuid}]}:" >>${RUNNING_STATE}

        # Ist die GPU generell Enabled oder momentan nicht zu behandeln?
        if ((${WasItEnabled[${gpu_uuid}]} == 1)); then
            #
            # Die Karte WAR generell ENABLED
            #
            if [[ ${uuidEnabledSOLL[${gpu_uuid}]} == 1 ]]; then

                #
                # Die Karte BLEIBT generell ENABLED
                #
                ########################################################
                ### START- STOP- SWITCHING- Skripte.
                ### Hier ist die richtige Stelle, die Miner zu switchen
                ########################################################

                ### Lief die Karte mit dem selben Algorithmus?
                if [[ "${WhatsRunning[${gpu_uuid}]}" != "${actGPUalgoName[${algoidx}]}" ]]; then
                    if [[ -z "${WhatsRunning[${gpu_uuid}]}" ]]; then
                        # MINER- Behandlung
                        echo "---> SWITCH-CMD: GPU#${gpu_idx} EINSCHALTEN mit Algo \"${actGPUalgoName[${algoidx}]}\""
                    else
                        # MINER- Behandlung
                        echo "---> SWITCH-CMD: GPU#${gpu_idx} Algo WECHSELN von \"${WhatsRunning[${gpu_uuid}]}\" auf \"${actGPUalgoName[${algoidx}]}\""
                    fi
                else
                    # Alter und neuer Algo ist gleich, kann weiterlaufen
                    echo "---> SWITCH-NOT: GPU#${gpu_idx} BLEIBT weiterhin auf \"${actGPUalgoName[${algoidx}]}\""
                fi
                printf "${actGPUalgoName[${algoidx}]}\n" >>${RUNNING_STATE}
            else
                #
                # Die Karte ist NUN generell DISABLED!
                #
                # GERADE SEHEN WIR, DASS DIE TATSACHE, DASS DIESE KARTE MIT IN DIE BERECHNUNGEN
                # EINBEZOGEN WURDE, SINNLOS WAR!
                # Wir müssen im Anschluss überlegen, wo wir das abzuchecken haben, BEVOR
                # wir mit den Berechnungen beginnen.
                # Dann wird dieser Fall hier GAR NICHT MEHR VORKOMMEN <---   NOCH ZU IMPLEMENTIEREN
                # MINER- Behandlung
                echo "---> SWITCH-OFF: GPU#${gpu_idx} wurde generell DISABLED und ist abzustellen!"
                echo "---> SWITCH-OFF: Sie läuft noch mit \"${WhatsRunning[${gpu_uuid}]}\""
                printf "\n" >>${RUNNING_STATE}
            fi
        else
            #
            # Die Karte WAR generell DISABLED
            #
            if [[ "${uuidEnabledSOLL[${gpu_uuid}]}" == "1" ]]; then
                #
                # Die Karte IST NUN generell ENABLED
                #
                ########################################################
                ### START- STOP- SWITCHING- Skripte.
                ### Hier ist die richtige Stelle, die Miner zu switchen
                ########################################################
                # MINER- Behandlung
                echo "---> SWITCH-CMD: GPU#${gpu_idx} EINSCHALTEN mit Algo \"${actGPUalgoName[${algoidx}]}\""
                printf "${actGPUalgoName[${algoidx}]}\n" >>${RUNNING_STATE}
            else
                #
                # Die Karte BLEIBT generell DISABLED
                #
                # Zeile abschliessen
                echo "---> SWITCH-NOT: GPU#${gpu_idx} BLEIBT weiterhin DISABLED"
                printf "\n" >>${RUNNING_STATE}
            fi
        fi
    else
        ### IM ${RUNNING_STATE} WAREN KEINERLEI EINTRÄGE.
        ### Wahrscheinlich existierte sie noch nie. Jetzt kommen AUF JEDEN FALL Einträge hinein.
        ### Wir wisseen also nichts über den laufenden Zustand und schalten deshalb einfach alles nur ein,
        ###     falls nicht eine GPU Generell DISABLED ist.
        # Den SOLL-Zustand über Generell ENABLED/DISABLED haben wir am Anfang ja eingelesen.

        if [[ "${uuidEnabledSOLL[${gpu_uuid}]}" == "1" ]]; then
            #
            # Die Karte IST generell ENABLED
            #
            ########################################################
            ### START- STOP- SWITCHING- Skripte.
            ### Hier ist die richtige Stelle, die Miner zu switchen
            ########################################################

            # MINER- Behandlung
            echo "---> SWITCH-CMD: GPU#${gpu_idx} EINSCHALTEN mit Algo \"${actGPUalgoName[${algoidx}]}\""
            printf "${gpu_uuid}:${gpu_idx}:${uuidEnabledSOLL[${gpu_uuid}]}:${actGPUalgoName[${algoidx}]}\n" >>${RUNNING_STATE}
        else
            #
            # Die Karte IST generell DISABLED
            #
            # MINER- Behandlung
            echo "---> SWITCH-OFF: GPU#${gpu_idx} wurde generell DISABLED und ist abzustellen!"
            printf "${gpu_uuid}:${gpu_idx}:${uuidEnabledSOLL[${gpu_uuid}]}:\n" >>${RUNNING_STATE}
        fi
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

###                                                             ###
#   ... dann die GPU's, die abgeschaltet werden sollen            #
###                                                             ###

# Auch hier kann es natürlich vorkommen, dass sich eine Indexnummer geändert hat
#      und dass dann die CHAOS-BEHANDLUNG durchgeführt werden muss.
if [ ${SwitchOffCnt} -gt 0 ]; then
    if [[ ${verbose} == 1 ]]; then
        echo "Die folgenden Karten müssen ausgeschaltet werden:"
    fi

    for (( i=0; $i<${SwitchOffCnt}; i++ )); do
        gpu_idx=${SwitchOffGPUs[$i]}
        declare -n actGPU_UUID="GPU${gpu_idx}UUID"
        gpu_uuid=${actGPU_UUID}

        if [ ! ${#RunningGPUid[@]} -eq 0 ]; then
            #############################   CHAOS BEHADLUNG Anfang  #############################
            ### Schweres Thema: IST DER GPU-INDEX NOCH DER SELBE ??? <-----------------------
            if [[ "${gpu_idx}" != "${RunningGPUid[${gpu_uuid}]}" ]]; then
                echo "#############################   CHAOS BEHADLUNG   #############################"
                echo "Das gesamte System muss möglicherweise gestoppt und neu gestartet werden:"
                echo "Wir sind auf die Karte mit der UUID=${gpu_uuid} gestossen."
                echo "Sie lief bisher mit einem Miner, der sie als GPU-Index #${RunningGPUid[${gpu_uuid}]} angesprochen hat."
                echo "Jetzt soll sie aber ein Miner mit dem Index ${gpu_idx} ansprechen ???"
                echo "Was also ist mit dem Miner, der noch die vorherige GPU-Index-Nummer #${RunningGPUid[${gpu_uuid}]} bedient?"
                echo "#############################   CHAOS BEHADLUNG   #############################"
                _notify_about_GPU_INDEX_CHANGED_WHILE_RUNNING "${name[${gpu_idx}]}" \
                                                          "${gpu_uuid}" \
                                                          "${RunningGPUid[${gpu_uuid}]}" \
                                                          "${gpu_idx}"
                exit
            fi
            #############################   CHAOS BEHADLUNG  Ende  #############################

            if ((${WasItEnabled[${gpu_uuid}]} == 1)); then
                #
                # Die Karte WAR generell ENABLED
                #
                if [[ -n "${WhatsRunning[${gpu_uuid}]}" ]]; then
                    # MINER- Behandlung
                    echo "---> SWITCH-OFF: GPU#${gpu_idx} ist ABZUSTELLEN!"
                    echo "---> SWITCH-OFF: GPU#${gpu_idx} läuft noch mit \"${WhatsRunning[${gpu_uuid}]}\""
                fi
            fi
        fi
        printf "${gpu_uuid}:${gpu_idx}:${uuidEnabledSOLL[${gpu_uuid}]}:\n" >>${RUNNING_STATE}
    done
fi
if [[ ${verbose} == 1 ]]; then
    echo "-------------------------------------------------"
fi

for algoName in ${!AlgoDisabled[@]}; do
    printf "AlgoDisabled:$algoName\n" >>${RUNNING_STATE}
done

echo "Neues globales Switching Sollzustand Kommandofile"
cat ${RUNNING_STATE}


# Zugriff auf die Globale Steuer- und Statusdatei wieder zulassen
rm -f ${RUNNING_STATE}.lock



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
