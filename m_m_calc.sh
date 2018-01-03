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

# GLOBALE VARIABLEN, nützliche Funktionen
[[ ${#_GLOBALS_INCLUDED} -eq 0 ]] && source globals.inc

SolarWattAvailable="$1"
[[ ${#2} -gt 1 ]] && performanceTest=${2:1} || performanceTest=0
[[ ${#3} -gt 1 ]] && verbose=${3:1} || verbose=0
[[ ${#4} -gt 1 ]] && debug=${4:1} || debug=0

# Ein paar Funktionen zur Verwaltung der Algos, die für alle oder nur für bestimmte GPU-UUIDs disabled sind.
# Es gibt die Funktionen
#    _read_in_SYSTEM_FILE_and_SYSTEM_STATEin
source gpu-abfrage.inc

source multi_mining_calc.inc

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
_reserve_and_lock_file ${SYSTEM_STATE}          # Zum Lesen und Bearbeiten reservieren...
_read_in_SYSTEM_FILE_and_SYSTEM_STATEin
rm -f ${SYSTEM_STATE}.lock                      # ... und wieder freigeben

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
echo "Jede GPU für sich betrachtet, wenn sie als Einzige laufen würde UND Beginn der Ermittlung und des Hochfahrens von MAX_PROFIT !"
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
            SwitchOffGPUs[${#SwitchOffGPUs[@]}]=${index[$idx]}
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
                # Achtung: actGPUAlgos[$algoIdx] ist ein String und besteht aus 5 Teilen:
                #          "$coin#$pool#$miningAlgo#$miner_name#$miner_version"
                # Wenn uns davon etwas interessiert, können wir es so in Variablen einlesen.
                # Einst war die folgende Zeile hier aktiv, aber actAlgoName ist nirgends abgefragt oder verwendet worden.
                # Deshalb wurde es am 24.12.2017 herausgenommen. Nach der großen Trennung von $algo in $coin und $miningAlgo
                #read actAlgoName muck <<<"${actGPUAlgos[$algoIdx]//#/ }"

                # ---> Ist der AlgoDisabled? <---
                # ---> Ist der AlgoDisabled? <---
                # ---> Ist der AlgoDisabled? <---
                # An dieser Stelle haben wir den alten Code rausgeworfen.
                # Wahrscheinlich muss auch kein Neuer rein, weil die GPUs die Disabeld Algos gar nicht erst zur Berechnung anbieten.
                #
                #_valid_algo_="yes"
                #if [[ ${_valid_algo_} == "yes" ]]; then
                _calculate_ACTUAL_REAL_PROFIT_and_set_MAX_PROFIT \
                    ${SolarWattAvailable} ${actAlgoWatt[$algoIdx]} "${actAlgoMines[$algoIdx]}"
                # Wenn das NEGATIV ist, muss der Algo dieser Karte übergangen werden. Uns interessieren nur diejenigen,
                # die POSITIV sind und später in Kombinationen miteinander verglichen werden müssen.
                if [[ ! $(expr index "${ACTUAL_REAL_PROFIT}" "-") == 1 ]]; then
                    profitableAlgoIndexes[${#profitableAlgoIndexes[@]}]=${algoIdx}
                fi
                if [[ ! "${MAX_PROFIT}" == "${OLD_MAX_PROFIT}" ]]; then
                    MAX_PROFIT_GPU_Algo_Combination="${index[$idx]}:${algoIdx},"
                    msg="New Maximum Profit ${MAX_PROFIT} with GPU:AlgoIndexCombination ${MAX_PROFIT_GPU_Algo_Combination}"
                    MAX_PROFIT_MSG_STACK[${#MAX_PROFIT_MSG_STACK[@]}]=${msg}
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
                    msg="New FULL POWER Profit ${MAX_FP_MINES} with GPU:AlgoIndexCombination ${MAX_FP_GPU_Algo_Combination} and ${MAX_FP_WATTS}W"
                    MAX_FP_MSG_STACK[${#MAX_FP_MSG_STACK[@]}]=${msg}
                fi
                #fi
            done

            profitableAlgoIndexesCnt=${#profitableAlgoIndexes[@]}
            if [[ ${profitableAlgoIndexesCnt} -gt 0 ]]; then
                PossibleCandidateGPUidx[${#PossibleCandidateGPUidx[@]}]=${index[$idx]}
                exactNumAlgos[${index[$idx]}]=${profitableAlgoIndexesCnt}
                # Hilfsarray für AlgoIndexe vor dem Neuaufbau immer erst löschen
                declare -n deleteIt="PossibleCandidate${index[$idx]}AlgoIndexes";    unset deleteIt
                declare -ag "PossibleCandidate${index[$idx]}AlgoIndexes"
                declare -n actCandidatesAlgoIndexes="PossibleCandidate${index[$idx]}AlgoIndexes"
                # Array kopieren
                actCandidatesAlgoIndexes=(${profitableAlgoIndexes[@]})
            else
                # Wenn kein Algo übrigbleiben sollte, GPU aus.
                SwitchOffGPUs[${#SwitchOffGPUs[@]}]=${index[$idx]}
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
    
# Sind überhaupt irgendwelche Date eingelesen worden und prüfbare GPU's ermittelt worden?
# Wenn nicht, gabe es keine Einzelberechnung und dann ist auch keine Gesamtberechnung nötig.
if [[ ${#PossibleCandidateGPUidx[@]} -gt 0 ]]; then

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
            echo "Berechnung aller Kombinationen des Falles, dass nur ${numGPUs} GPUs von ${MAX_GOOD_GPUs} laufen:"
            _CREATE_AND_CALCULATE_EVERY_AND_ALL_SUBSEQUENT_COMBINATION_CASES \
                ${MAX_GOOD_GPUs} 0 $((${MAX_GOOD_GPUs} - ${numGPUs} + 1))
        done
    else
        echo "Keine Gesamtberechnung nötig. Es ist nur 1 GPU aktiv und die wurde schon berechnet."
    fi  # if [[ ${MAX_GOOD_GPUs} -gt 0 ]]; then

    echo "=========    Berechnungsverlauf    ========="
    for msg in ${!MAX_PROFIT_MSG_STACK[@]}; do
        echo ${MAX_PROFIT_MSG_STACK[$msg]}
    done
    if [[ "${MAX_PROFIT_GPU_Algo_Combination}" != "${MAX_FP_GPU_Algo_Combination}" \
                && "${MAX_FP_MINES}" > "${MAX_PROFIT}" ]]; then
        echo "FULL POWER MINES ${MAX_FP_MINES} wären mehr als die EFFIZIENZ Mines ${MAX_PROFIT}"
        FP_echo="FULL POWER MODE wäre möglich bei ${SolarWattAvailable}W SolarPower"
        FP_echo+=" und maximal ${MAX_FP_WATTS}W GPU-Verbrauch:"
        if [[ ${MAX_FP_WATTS} -lt ${SolarWattAvailable} ]]; then
            echo ${FP_echo}
            for msg in ${!MAX_FP_MSG_STACK[@]}; do
                echo ${MAX_FP_MSG_STACK[$msg]}
            done
        else
            echo "KEIN(!)" ${FP_echo}
        fi
    fi
else
    echo "ACHTUNG: Keine Berechnungsdaten verfügbar oder alle GPU's Disabled. Es finden im Moment keine Berechnungen statt."
    echo "ACHTUNG: GPU's, die sich selbst für ein Benchmarking aus dem System genommen haben, kommen auch von selbst wieder zurück"
    echo "ACHTUNG: und beginnen damit, wieder Daten zu liefern."
fi

# Die folgenden Variablen müssen dann in Dateien gepiped werden, damit die Auswertung funktioniert:
# 
# ${MAX_PROFIT_GPU_Algo_Combination}  wegen der besten GPU/Algo Kombination
# ${MAX_FP_GPU_Algo_Combination}      FULL POWER Mode, NOCH NICHT VOLLSTÄNDIG IMPLEMENTIERT!
# ${PossibleCandidateGPUidx[@]        um die restlichen Abzuschaltenden zu erhalten
# ${SwitchOffGPUs[@]                  Die, die bisher schon angefallen sind und die im Anschluss erweitert werden

echo "${MAX_PROFIT_GPU_Algo_Combination}"         >MAX_PROFIT_DATA.out       # 0:24,1:15,3:16,5:11,       # das letzte Komma fällt bei der Auswertung eh weg
echo "${MAX_FP_GPU_Algo_Combination}"            >>MAX_PROFIT_DATA.out       # 0:24,1:31,2:8,3:12,4:24,5:16,  # das letzte Komma fällt bei der Auswertung eh weg
PossibleCandidateGPUidxArrayString=''
for (( i=0; $i<${#PossibleCandidateGPUidx[@]}; i++ )); do
    PossibleCandidateGPUidxArrayString+="${PossibleCandidateGPUidx[$i]} "
done
echo "${PossibleCandidateGPUidxArrayString/% /}" >>MAX_PROFIT_DATA.out       # 0 1 3 4 5       # Die 4 wird im Anschluss vom Multiminer auf den
SwitchOffGPUsArrayString=''
for (( i=0; $i<${#SwitchOffGPUs[@]}; i++ )); do
    SwitchOffGPUsArrayString+="${SwitchOffGPUs[$i]} "
done
echo "${SwitchOffGPUsArrayString/% /}"           >>MAX_PROFIT_DATA.out       # 2               # Stack für die abzuschaltenden GPUs gelegt werden
echo "${GLOBAL_GPU_COMBINATION_LOOP_COUNTER}"    >>MAX_PROFIT_DATA.out       # 369             # Wenigstens 0
echo "${GLOBAL_MAX_PROFIT_CALL_COUNTER}"         >>MAX_PROFIT_DATA.out       # 402             # Wenigstens 0
echo "${MAX_FP_WATTS}"                           >>MAX_PROFIT_DATA.out       # 1168            # Wenigstens 0
