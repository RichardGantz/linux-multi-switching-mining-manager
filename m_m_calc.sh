#!/bin/bash
###############################################################################
#                           Multi-Mining-Calc
# 
# Hier werden ALLE GPU's Algorithmen ALLER Karten eingelesen und berechnet.
# 
# Ergebnis ist eine Datei mit der besten GPU/Algo-Kombination
#
# Zu übergebende Parameter:
#    $1   ${SolarWattAvailable}
#    $2   "p" + "${performanceTest}"
#    $3   "v" + "${verbose}"
#
#
###############################################################################

SolarWattAvailable="$1"
[[ ${#2} -gt 1 ]] && performanceTest=${2:1} || performanceTest=0
[[ ${#3} -gt 1 ]] && verbose=${3:1} || verbose=0

# Wegen der verschiedenen "push onto Array"-Verfahren
arrayRedeclareTest=0

GRID[0]="netz"
GRID[1]="solar"
GRID[2]="solar_akku"

# SICHERHEITSHALBER die selben Variablem setzen wie in gpu-abfrage.sh,
#                   damit die Funktionen in .inc auch alle Voraussetzungen erfüllt sehen.
# Wenn keine Karten da sind, dürfen verschiedene Befehle nicht ausgeführt werden
# und müssen sich auf den Inhalt fixer Dateien beziehen.
if [ $HOME == "/home/richard" ]; then NoCards=true; fi

### ERSTER Start und Erstellung der Grundkonfig 
SYSTEM_FILE="gpu_system.out"
SYSTEM_STATE="GLOBAL_GPU_SYSTEM_STATE"

# Ein paar Funktionen zur Verwaltung der Algos, die für alle oder nur für bestimmte GPU-UUIDs disabled sind.
# Es gibt die Funktionen
#    _add_entry_into_AlgoDisabled                      $algo [$gpu_uuid]
#    _remove_entry_from_AlgoDisabled                   $algo [$gpu_uuid]
#    "yes" or "no" = $( _is_algo_disabled_for_gpu_uuid $algo [$gpu_uuid] )
#    _read_in_SYSTEM_FILE_and_SYSTEM_STATEin
source gpu-abfrage.inc

source ./multi_mining_calc.inc

# Die folgenden Arrays stehen nach dem Aufruf von _read_in_SYSTEM_FILE_and_SYSTEM_STATEin zur Verfügung:
#    index[ 0- ]=gpu_idx
#    name[ $gpu_idx ]=
#    bus[ $gpu_idx ]=
#    uuid[ $gpu_idx ]=gpu_uuid
#    auslastung[ $gpu_idx ]=
#    GPU{ $gpu_idx }Algos[]=            Platz für alle Algonamen
#    GPU{ $gpu_idx }Watts[]=            Platz für alle Wat-Angaben
#    GPU{ $gpu_idx }Mines[]=            Platz für alle Mines
#    uuidEnabledSOLL[ $gpu_uuid ]=      1 oder 0 für ENABLED oder DISABLED
#    NumEnabledGPUs=                    Anzahl aller ENABLED GPUs
#    AlgoDisabled[$algo]=               STRING mit GPU-UUIDs und/oder * für momentan für Alle GPUs disabled
_read_in_SYSTEM_FILE_and_SYSTEM_STATEin

###############################################################################################
#
#     EINLESEN der STROMPREISE in BTC
#
# In algo_multi_abfrage.sh, die vor Kurzem gelaufen sein muss,
# werden die EUR-Strompreise in BTC-Preise umgewandelt.
# Diese Preise brauchen wir in BTC, um die Kosten von den errechneten "Mines" abziehen zu können.
#
_read_in_kWhMin_kWhMax_kWhAkk

MAX_PROFIT=".0"
MAX_PROFIT_GPU_Algo_Combination=''
MAX_FP_MINES=".0"
MAX_FP_WATTS=0
MAX_FP_GPU_Algo_Combination=''
declare -ig GLOBAL_GPU_COMBINATION_LOOP_COUNTER=0
declare -ig GLOBAL_MAX_PROFIT_CALL_COUNTER=0

###############################################################################################
#
#    EINLESEN ALLER ALGORITHMEN, WATTS und MINES, AUF DIE WIR GERADE GEWARTET HABEN
#
_read_in_All_ALGO_WATTS_MINESin

echo "=========  GPU Einzelberechnungen  ========="
echo "Ermittlung aller gewinnbringenden Algorithmen durch Berechnung:"
echo "Jede GPU für sich betrachtet, wenn sie als Einzige laufen würde"
echo "UND Beginn der Ermittlung und des Hochfahrens von MAX_PROFIT !"
if [ ${verbose} == 1 ]; then
    echo "Damit sparen wir uns später den Fall '1 GPU aus MAX_GOOD möglichen GPUs' und können gleich mit 2 beginnen!"
fi

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
unset SwitchOffGPUs
declare -a SwitchOffGPUs           # GPUs anyway aus, keine gewinnbringenden Algos zur Zeit
unset PossibleCandidateGPUidx
declare -a PossibleCandidateGPUidx # GPUs mit mindestens 1 gewinnbringenden Algo.
                                   # Welcher es werden soll, muss errechnet werden
                                   # gefolgt von mind. 1x declare -a "PossibleCandidate${gpu_index}AlgoIndexes" ...
unset exactNumAlgos
declare -a exactNumAlgos  # ... und zur Erleichterung die Anzahl Algos der entsprechenden "PossibleCandidate" GPU's

for (( idx=0; $idx<${#index[@]}; idx++ )); do
    declare -n actGPUAlgos="GPU${index[$idx]}Algos"
    declare -n actAlgoWatt="GPU${index[$idx]}Watts"
    declare -n actAlgoMines="GPU${index[$idx]}Mines"

    numAlgos=${#actGPUAlgos[@]}
    # Wenn die GPU seit neuestem generell DISABLED ist, pushen wir sie hier auf den
    # SwitchOffGPUs Stack, indem wir die numAlgos künslich auf 0 setzen:
    if [[ "${uuidEnabledSOLL[${uuid[${index[$idx]}]}]}" == "0" ]]; then
        numAlgos=0
    fi
    case "${numAlgos}" in

        "0")
            # Karte ist auszuschalten. Kein (gewinnbringender) Algo im Moment.
            # Es kam offensichtlich nichts aus der Datei ALGO_WATTS_MINES.in.
            # Vielleicht wegen einer Vorabfilterung durch gpu_gv-algo.sh (unwahrscheinlich aber machbar)
            # ---> ARRAYPUSH 2 <---
            if [[ ${arrayRedeclareTest} -eq 1 ]]; then
                SwitchOffGPUs=(${SwitchOffGPUs[@]} ${index[$idx]})
            else
                SwitchOffGPUs[${#SwitchOffGPUs[@]}]=${index[$idx]}
            fi
            ;;

        *)
            # GPU kann mit mindestens einem Algo laufen.
            # Wir filtern jetzt noch diejenigen Algorithmen raus, die unter den momentanen Realen
            # Verhältnissen KEINEN GEWINN machen werden, wenn sie allein, also ohne "Konkrrenz" laufen würden.
            # Gleichzeitig halten wir von denen, die Gewinn machen, denjenigen Algo fest,
            # der den grössten Gewinn macht.
            # Wir lassen jetzt schon MAX_PROFIT und die entsprechende Kombiantion aus GPU und Algo hochfahren.
            # Damit sparen wir uns später diesen Lauf mit 1 GPU, weil der auch kein anderes Ergebnis
            # bringen wird!
            unset profitableAlgoIndexes; declare -a profitableAlgoIndexes

            for (( algoIdx=0; $algoIdx<${numAlgos}; algoIdx++ )); do
                # Achtung: actGPUAlgos[$algoIdx] ist ein String und besteht aus 3 Teilen:
                #          "$algo#$miner_name#$miner_version"
                # Uns interessiert nur der NH-AlgoName $algo:
                read actAlgoName muck <<<"${actGPUAlgos[$algoIdx]//#/ }"
                # Ist der AlgoDisabled?
                _valid_algo_="yes"
                if [ ${#AlgoDisabled[${actAlgoName}]} -gt 0 ]; then
                    #echo "Untersuche Algo: ${actAlgoName}"
                    #echo "AlgoDisbled-STRING: " ${AlgoDisabled[${actAlgoName}]}
                    # Ist ein "*" enthalten oder die aktuelle gpu_uuid?
                    if [[ "${AlgoDisabled[${actAlgoName}]}" =~ ^.*(\*) && ${#BASH_REMATCH[1]} -gt 0 ]] \
                    || [[ "${AlgoDisabled[${actAlgoName}]}" =~ ^.*(${uuid[${index[$idx]}]}) && ${#BASH_REMATCH[1]} -gt 0 ]]; then     
                        ACTUAL_REAL_PROFIT="-"
                        _valid_algo_="no"
                        echo "------------------------------> Algo: ${actAlgoName} IST GERADE DISABLED !!!"
                    fi
                fi
                if [[ ${_valid_algo_} == "yes" ]]; then
                    _calculate_ACTUAL_REAL_PROFIT_and_set_MAX_PROFIT \
                        ${SolarWattAvailable} ${actAlgoWatt[$algoIdx]} "${actAlgoMines[$algoIdx]}"
                    # Wenn das NEGATIV ist, muss der Algo dieser Karte übergangen werden. Uns interessieren nur diejenigen,
                    # die POSITIV sind und später in Kombinationen miteinander verglichen werden müssen.
                    if [[ ! $(expr index "${ACTUAL_REAL_PROFIT}" "-") == 1 ]]; then
                        # ---> ARRAYPUSH 3 <---
                        if [[ ${arrayRedeclareTest} -eq 1 ]]; then
                            profitableAlgoIndexes=(${profitableAlgoIndexes[@]} ${algoIdx})
                        else
                            profitableAlgoIndexes[${#profitableAlgoIndexes[@]}]=${algoIdx}
                        fi
                    fi
                    if [[ ! "${MAX_PROFIT}" == "${OLD_MAX_PROFIT}" ]]; then
                        MAX_PROFIT_GPU_Algo_Combination="${index[$idx]}:${algoIdx},"
                        echo "New Maximum Profit ${MAX_PROFIT} with GPU:AlgoIndexCombination ${MAX_PROFIT_GPU_Algo_Combination}"
                    fi

                    # (17.11.2017)
                    # Wir halten jetzt auch die MAX_FP_MINES und die dabei verbrauchten Watt in MAX_FP_WATTS fest
                    # Das sind Daten, die wir "nebenbei" festhalten für den Fall,
                    #     dass IM MOMENT (für den kommenden Zyklus) GARANTIERT KEINE NETZPOWER BEZOGEN WERDEN MUSS
                    OLD_MAX_FP_MINES=${MAX_FP_MINES}
                    MAX_FP_MINES=$(echo "scale=8; if ( ${actAlgoMines[$algoIdx]} > ${MAX_FP_MINES} ) \
                                               { print ${actAlgoMines[$algoIdx]} } \
                                          else { print ${MAX_FP_MINES} }" \
                                          | bc )
                    if [[ ! "${MAX_FP_MINES}" == "${OLD_MAX_FP_MINES}" ]]; then
                        MAX_FP_WATTS=${actAlgoWatt[$algoIdx]}
                        MAX_FP_GPU_Algo_Combination="${index[$idx]}:${algoIdx},"
                        echo "New FULL POWER Profit ${MAX_FP_MINES} with GPU:AlgoIndexCombination ${MAX_FP_GPU_Algo_Combination} and ${MAX_FP_WATTS}W"
                    fi
                fi
            done

            profitableAlgoIndexesCnt=${#profitableAlgoIndexes[@]}
            if [[ ${profitableAlgoIndexesCnt} -gt 0 ]]; then
                # ---> ARRAYPUSH 4 <---
                if [[ ${arrayRedeclareTest} -eq 1 ]]; then
                    PossibleCandidateGPUidx=(${PossibleCandidateGPUidx[@]} ${index[$idx]})
                else
                    PossibleCandidateGPUidx[${#PossibleCandidateGPUidx[@]}]=${index[$idx]}
                fi
                exactNumAlgos[${index[$idx]}]=${profitableAlgoIndexesCnt}
                # Hilfsarray für AlgoIndexe vor dem Neuaufbau immer erst löschen
                declare -n deleteIt="PossibleCandidate${index[$idx]}AlgoIndexes";    unset deleteIt
                declare -ag "PossibleCandidate${index[$idx]}AlgoIndexes"
                declare -n actCandidatesAlgoIndexes="PossibleCandidate${index[$idx]}AlgoIndexes"
                # Array kopieren
                actCandidatesAlgoIndexes=(${profitableAlgoIndexes[@]})
            else
                # Wenn kein Algo übrigbleiben sollte, GPU aus.
                # ---> ARRAYPUSH 5 <---
                if [[ ${arrayRedeclareTest} -eq 1 ]]; then
                    SwitchOffGPUs=(${SwitchOffGPUs[@]} ${index[$idx]})
                else
                    SwitchOffGPUs[${#SwitchOffGPUs[@]}]=${index[$idx]}
                fi
            fi
            ;;

    esac
done

if [ ${verbose} == 1 ]; then
    # Auswertung zur Analyse
    if [[ ${#PossibleCandidateGPUidx[@]} -gt 0 ]]; then
        unset gpu_string
        for (( i=0; $i<${#PossibleCandidateGPUidx[@]}; i++ )); do
            gpu_string+="#${PossibleCandidateGPUidx[$i]} with ${exactNumAlgos[${PossibleCandidateGPUidx[$i]}]} Algos, "
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
    if [[ ${verbose} == 1 ]]; then
        echo "Summe SwitchOffGPUs + PossibleCandidateGPUidx = $((${#PossibleCandidateGPUidx[@]}+${#SwitchOffGPUs[@]}))"
        echo "Anzahl System-GPUs                            = ${#index[@]}"
    fi
fi

[[ ${performanceTest} -ge 1 ]] && echo "$(date --utc +%s): >6.< Beginn mit der Gesamtsystemberechnung" >>perfmon.log
    
echo "=========  Gesamtsystemberechnung  ========="

# Für die Mechanik der systematischen GV-Werte Ermittlung
# Hilfsarray testGPUs, das die "GPU${idx}Algos/Watts/Mines" Algos/Watts/Mines indexiert
unset MAX_GOOD_GPUs; declare -i MAX_GOOD_GPUs  # Wieviele GPUs haben mindestens 1 möglichen Algo

# Die folgenden 3 Variablen werden bei jedem Aufruf von _CALCULATE_GV_of_all_TestCombinationGPUs_members
# neu gesetzt und verwendet. (Vorletzte "Schale")
unset MAX_GPU_TIEFE; declare -i MAX_GPU_TIEFE  # Wieviele dieser GPUs sollen berechnet werden
unset lfdGPU; declare -i lfdGPU                # Laufender Zähler analog dem meist verwendeten $i
unset testGPUs; declare -A testGPUs            # Test-Zähler-Stellwerk

# Diese Nummer bildet die globale, die äusserste, letzte "Schale", von der aus die anderen gestartet/verwendet werden
unset numGPUs; declare -i numGPUs

MAX_GOOD_GPUs=${#PossibleCandidateGPUidx[@]}

if [[ ${MAX_GOOD_GPUs} -gt 1 ]]; then      # Den Fall für 1 GPU allein haben wir ja schon ermittelt.

    # Bei zu wenig Solarpower könnte das ins Minus rutschen...
    #     [ DAS MÜSSEN WIR NOCH CHECKEN, OB DAS WIRKLICH SICHTBAR WIRD ]
    # Deshalb werden wir auch noch Kombinationen mit weniger als der vollen Anzahl an gewinnbringenden GPUs
    #     durchrechnen.
    # Dazu entwickeln wir eine rekursive Funktion, die ALLE möglichen Kombinationen
    #     angefangen mit jeweils ZWEI laufenden GPUs von MAX_GOOD_GPUs
    #                           (EINE laufende GPU haben wir oben schon durchgerechnet)
    #     über DREI laufende GPUs von MAX_GOOD_GPUs
    #     bis hin zu ALLEN laufenden MAX_GOOD_GPUs.
    #
    # numGPUs:        Anzahl zu berechnender GPU-Kombinationen mit numGPUs GPU's
    #
    echo "MAX_GOOD_GPUs: ${MAX_GOOD_GPUs} bei SolarWattAvailable: ${SolarWattAvailable}"
    for (( numGPUs=2; $numGPUs<=${MAX_GOOD_GPUs}; numGPUs++ )); do
        # Parameter: $1 = maxTiefe
        #            $2 = Beginn Pointer1 bei Index 0
        #            $3 = Ende letzter Pointer 5
        #            $4-  Jede Ebene hängt dann ihren aktuellen Wert in der Schleife hin,
        #                 in der sie sich selbst gerade befindet.
        endStr="GPUs von ${MAX_GOOD_GPUs} laufen:"
        echo "Berechnung aller Kombinationen des Falles, dass nur ${numGPUs} ${endStr}"
        _CREATE_AND_CALCULATE_EVERY_AND_ALL_SUBSEQUENT_COMBINATION_CASES \
            ${MAX_GOOD_GPUs} 0 $((${MAX_GOOD_GPUs} - ${numGPUs} + 1))
    done

fi  # if [[ ${MAX_GOOD_GPUs} -gt 0 ]]; then

# Die folgenden Variablen müssen dann in Dateien gepiped werden, damit die Auswertung funktioniert:
# 
# ${MAX_PROFIT_GPU_Algo_Combination}  wegen der besten GPU/Algo Kombination
# ${MAX_FP_GPU_Algo_Combination}      FULL POWER Mode, NOCH NICHT VOLLSTÄNDIG IMPLEMENTIERT!
# ${PossibleCandidateGPUidx[@]        um die restlichen Abzuschaltenden zu erhalten
# ${SwitchOffGPUs[@]                  Die, die bisher schon angefallen sind und die im Anschluss erweitert werden

echo "${MAX_PROFIT_GPU_Algo_Combination}"         >MAX_PROFIT_DATA.out
echo "${MAX_FP_GPU_Algo_Combination}"            >>MAX_PROFIT_DATA.out
PossibleCandidateGPUidxArrayString=''
for (( i=0; $i<${#PossibleCandidateGPUidx[@]}; i++ )); do
    PossibleCandidateGPUidxArrayString+="${PossibleCandidateGPUidx[$i]} "
done
echo "${PossibleCandidateGPUidxArrayString/% /}" >>MAX_PROFIT_DATA.out
SwitchOffGPUsArrayString=''
for (( i=0; $i<${#SwitchOffGPUs[@]}; i++ )); do
    SwitchOffGPUsArrayString+="${SwitchOffGPUs[$i]} "
done
echo "${SwitchOffGPUsArrayString/% /}"           >>MAX_PROFIT_DATA.out
echo "${GLOBAL_GPU_COMBINATION_LOOP_COUNTER}"    >>MAX_PROFIT_DATA.out
echo "${GLOBAL_MAX_PROFIT_CALL_COUNTER}"         >>MAX_PROFIT_DATA.out
