#!/bin/bash
[[ ${#_GLOBALS_INCLUDED}     -eq 0 ]] && source globals.inc
[[ ${#_GPU_ABFRAGE_INCLUDED} -eq 0 ]] && source ${LINUX_MULTI_MINING_ROOT}/gpu-abfrage.sh
#source ./multi_mining_calc.inc
#[[ ${#_GPU_ABFRAGE_INCLUDED} -eq 0 ]] && source ${LINUX_MULTI_MINING_ROOT}/gpu-abfrage.inc
#[[ ${#_ALGOINFOS_INCLUDED}   -eq 0 ]] && source ${LINUX_MULTI_MINING_ROOT}/algo_infos.inc
#[[ ${#_MINERFUNC_INCLUDED}   -eq 0 ]] && source ${LINUX_MULTI_MINING_ROOT}/miner-func.inc
#[[ ${#_NVIDIACMD_INCLUDED}   -eq 0 ]] && source ${LINUX_MULTI_MINING_ROOT}/benchmarking/nvidia-befehle/nvidia-query.inc
#[[ ${#_LOGANALYSIS_INCLUDED} -eq 0 ]] && source ${LINUX_MULTI_MINING_ROOT}/logfile_analysis.inc
#    [[ ${#_GPU_BENCH_INCLUDED}   -eq 0 ]] && source ${LINUX_MULTI_MINING_ROOT}/GPU-skeleton/gpu-bENCH.inc
#[[ ${#_GPU_BENCH_INCLUDED}   -eq 0 ]] && source ${LINUX_MULTI_MINING_ROOT}/${gpu_uuid}/gpu-bENCH.inc
#source ${LINUX_MULTI_MINING_ROOT}/miners/${miner_name}#${miner_version}.starts
#source ${LINUX_MULTI_MINING_ROOT}/multi_mining_calc.inc
#source ${LINUX_MULTI_MINING_ROOT}/estimate_delays.inc
#source ${LINUX_MULTI_MINING_ROOT}/estimate_yeses.inc

msg="New Maximum Profit ${MAX_PROFIT} with GPU:AlgoIndexCombination ${MAX_PROFIT_GPU_Algo_Combination}"
MAX_PROFIT_MSG_STACK+=( "${msg}" )
msg="New FULL POWER Profit ${MAX_FP_MINES} with GPU:AlgoIndexCombination ${MAX_FP_GPU_Algo_Combination} and ${MAX_FP_WATTS}W"
MAX_FP_MSG_STACK+=( "${msg}" )
for msg in ${!MAX_PROFIT_MSG_STACK[@]}; do
    echo ${MAX_PROFIT_MSG_STACK[$msg]}
done
for msg in "${MAX_PROFIT_MSG_STACK[@]}"; do
    echo ${msg}
done
exit

# Die mm_calc.c Tests
source ./multi_mining_calc.inc
verbose=1
debug=1
SolarWattAvailable=0
GLOBAL_MAX_PROFIT_CALL_COUNTER=0
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

    echo 'scale=10;
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

function _read_in_Validated_ALGO_WATTS_MINESin () {
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

    local UUID idx
    for UUID in "${!ALGO_WATTS_MINES_delivering_GPUs[@]}"; do
        if [ -s ${UUID}/ALGO_WATTS_MINES.in ]; then
            idx=${ALGO_WATTS_MINES_delivering_GPUs[${UUID}]}
            declare -n actGPUAlgos="GPU${idx}Algos"
            declare -n actAlgoWatt="GPU${idx}Watts"
            declare -n actAlgoMines="GPU${idx}Mines"

            unset READARR
            readarray -n 0 -O 0 -t READARR <${UUID}/ALGO_WATTS_MINES.in
            for ((i=0; $i<${#READARR[@]}; i+=3)) ; do
                # Das ist eine sehr elegante Möglichkeit, einen neuen Wert auf ein Array zu pushen.
                # Wir nehmen das jetzt aber alles mal raus und machen es anders und beobachten wieder
                # die Durchlaufzeiten, ob die sich wieder mit der Zeit erhöhen UND ob sich
                # der Speicherbedarf erhöht, OBWOHL alle Arrays immer erst durch UNSET zerstört werden
                actGPUAlgos+=( "${READARR[$i]}" )
                actAlgoWatt+=( "${READARR[$i+1]}" )
                actAlgoMines+=( "${READARR[$i+2]}" )
            done
        fi
    done
}

_read_in_SYSTEM_FILE_and_SYSTEM_STATEin
#echo "$NumEnabledGPUs GPUs insgesamt"
NumValidatedGPUs=${NumEnabledGPUs}

#_read_in_kWhMin_kWhMax_kWhAkk
kWhMin=.0000036064
kWhMax=.0000090161
kWhAkk=.0000064190

#echo "${!uuidEnabledSOLL[@]}"
#echo ${index[@]}
#echo ${GPU_idx[@]}
declare -Ag ALGO_WATTS_MINES_delivering_GPUs
for UUID in "${!uuidEnabledSOLL[@]}"; do
    ALGO_WATTS_MINES_delivering_GPUs[${UUID}]=${GPU_idx[${UUID}]}
done
#echo ${ALGO_WATTS_MINES_delivering_GPUs[@]}

_read_in_Validated_ALGO_WATTS_MINESin

MAX_PROFIT=".0"
OLD_MAX_PROFIT=".0"
MAX_PROFIT_GPU_Algo_Combination=''
MAX_FP_MINES=".0"
OLD_MAX_FP_MINES=".0"
MAX_FP_WATTS=0
MAX_FP_GPU_Algo_Combination=''
declare -ig GLOBAL_GPU_COMBINATION_LOOP_COUNTER=0
declare -ig GLOBAL_MAX_PROFIT_CALL_COUNTER=0
unset MAX_PROFIT_MSG_STACK MAX_FP_MSG_STACK

# Die folgenden beiden Arrays halten nur GPU-Indexnummern als Werte. Nichts weiter!
# Wir bauen diese Arrays jetzt anhand der Kriterien aus den Rohdaten-Arrays in einer
#     alle im System befindlichen GPUs durchgehenden Schleife auf.
unset SwitchOffGPUs
declare -a SwitchOffGPUs           # GPUs anyway aus, keine gewinnbringenden Algos zur Zeit
unset SwitchNotGPUs
declare -a SwitchNotGPUs           # GPUs, die durchzuschleifen sind, weil sie beim Abliefern von Werten aufgehalten wurden.
unset PossibleCandidateGPUidx
declare -a PossibleCandidateGPUidx # GPUs mit mindestens 1 gewinnbringenden Algo.
# Welcher es werden soll, muss errechnet werden
# gefolgt von mind. 1x declare -a "PossibleCandidate${gpu_index}AlgoIndexes" ...
unset exactNumAlgos
declare -a exactNumAlgos  # ... und zur Erleichterung die Anzahl Algos der entsprechenden "PossibleCandidate" GPU's

WATTS_Parameter_String_for_mm_calC=""
MINES_Parameter_String_for_mm_calC=""

for (( idx=0; $idx<${#index[@]}; idx++ )); do
    gpu_idx=${index[$idx]}
    declare -n actGPUAlgos="GPU${gpu_idx}Algos"
    declare -n actAlgoWatt="GPU${gpu_idx}Watts"
    declare -n actAlgoMines="GPU${gpu_idx}Mines"
    declare -n actAlgoProfit="GPU${gpu_idx}Profit"
    declare -n dstAlgoWatts="GPU${gpu_idx}WATTS"
    declare -n dstAlgoMines="GPU${gpu_idx}MINES"
    declare -n actSortedProfits="SORTED${gpu_idx}PROFITs"

#    echo ${actAlgoWatt[@]}
#    echo ${actAlgoMines[@]}
    
    numAlgos=${#actGPUAlgos[@]}
    if [ 0 -eq 1 -a ${verbose} -eq 1 ]; then
	echo "Anzahl aktueller Algos von GPU#${gpu_idx}: ${numAlgos}" 
    fi
    # Wenn die GPU seit neuestem generell DISABLED ist, pushen wir sie hier auf den
    # SwitchOffGPUs Stack, indem wir die numAlgos künslich auf 0 setzen:
    if [[ "${uuidEnabledSOLL[${uuid[${gpu_idx}]}]}" == "0" ]]; then
        numAlgos=0
    fi
    case "${numAlgos}" in

        "0")
            # Karte ist auszuschalten. Kein (gewinnbringender) Algo im Moment.
            # Es kam offensichtlich nichts aus der Datei ALGO_WATTS_MINES.in.
            # Vielleicht wegen einer Vorabfilterung durch gpu_gv-algo.sh (unwahrscheinlich aber machbar)
            # ---> ARRAYPUSH 2 <---
            SwitchOffGPUs+=( ${gpu_idx} )
            ;;

        *)
            # Es werden nur diejenigen GPUs berücksichtigt, die erklärt haben, dass gültige Werte in der ALGO_WATTS_MINES.in waren
            if [ ${#ALGO_WATTS_MINES_delivering_GPUs[${uuid[${gpu_idx}]}]} -gt 0 ]; then
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

                    _calculate_ACTUAL_REAL_PROFIT_and_set_MAX_PROFIT \
                        ${SolarWattAvailable} ${actAlgoWatt[$algoIdx]} "${actAlgoMines[$algoIdx]}"
		    [ "${MAX_PROFIT}"   == "0" ] && MAX_PROFIT=".0"
		    [ "${MAX_FP_MINES}" == "0" ] && MAX_FP_MINES=".0"

                    # Wenn das NEGATIV ist, muss der Algo dieser Karte übergangen werden. Uns interessieren nur diejenigen,
                    # die POSITIV sind und später in Kombinationen miteinander verglichen werden müssen.
                    # if [[ ! $(expr index "${ACTUAL_REAL_PROFIT}" "-") == 1 ]]; then
                    # Punkt raus und gucken, ob > 0, sonst interessiert uns das ebenfalls nicht
                    _octal_=${ACTUAL_REAL_PROFIT//\.}
                    _octal_=${_octal_//0}
		    if [ 1 -eq 0 -a ${debug} -eq 1 ]; then
			echo "\${ACTUAL_REAL_PROFIT}: ${ACTUAL_REAL_PROFIT}"
		    fi
                    if [[ "${ACTUAL_REAL_PROFIT:0:1}" != "-" && ${#_octal_} -gt 0 ]]; then
                        profitableAlgoIndexes+=( ${algoIdx} )
                        actAlgoProfit[${algoIdx}]=${ACTUAL_REAL_PROFIT}
                    fi
                done

                profitableAlgoIndexesCnt=${#profitableAlgoIndexes[@]}
                if [[ ${profitableAlgoIndexesCnt} -gt 0 ]]; then

                    ###
                    ### Jetzt steht fest, dass diese GPU mindestens 1 Algo hat, der mit Gewinn rechnet.
                    ###
                    PossibleCandidateGPUidx+=( ${gpu_idx} )

                    # Hilfsarray für AlgoIndexe vor dem Neuaufbau immer erst löschen
                    declare -n deleteIt="PossibleCandidate${gpu_idx}AlgoIndexes";    unset deleteIt
                    declare -ag "PossibleCandidate${gpu_idx}AlgoIndexes"
                    declare -n actCandidatesAlgoIndexes="PossibleCandidate${gpu_idx}AlgoIndexes"

                    ###
                    ### Bevor wir das Array nun endgültig freigeben, sortieren wir es und packen nur die BEST_ALGO_CNT=5 Stück drauf.
                    ###
                    ### profitableAlgoIndexes+=( ${algoIdx} )
                    ### actAlgoProfit[${algoIdx}]=${ACTUAL_REAL_PROFIT}
                    rm -f .sort_profit_algoIdx_${gpu_idx}.in
                    for ((sortIdx=0; $sortIdx<${profitableAlgoIndexesCnt}; sortIdx++)); do
                        algoIdx=${profitableAlgoIndexes[${sortIdx}]}
                        echo ${actAlgoProfit[${algoIdx}]} ${algoIdx} >>.sort_profit_algoIdx_${gpu_idx}.in
                    done
                    unset SORTED_PROFITS
                    sort -n -r .sort_profit_algoIdx_${gpu_idx}.in \
                        | tee .sort_profit_algoIdx_${gpu_idx}.out \
                        | readarray -n 0 -O 0 -t SORTED_PROFITS
                    [ ${profitableAlgoIndexesCnt} -gt ${BEST_ALGO_CNT} ] && profitableAlgoIndexesCnt=${BEST_ALGO_CNT}
                    if [ ! : ]; then
                        for ((sortIdx=0; $sortIdx<${profitableAlgoIndexesCnt}; sortIdx++)); do
                            dstIdx=$((${profitableAlgoIndexesCnt}-${sortIdx}-1))
                            actSortedProfits[${dstIdx}]=${SORTED_PROFITS[${sortIdx}]}
                            algoIdx=${SORTED_PROFITS[${sortIdx}]#* }
                            actCandidatesAlgoIndexes[${dstIdx}]=${algoIdx}
                            dstAlgoWatts[${dstIdx}]=${actAlgoWatt[${algoIdx}]}
                            dstAlgoMines[${dstIdx}]=${actAlgoMines[${algoIdx}]}
                        done
                    else
			#echo "RICHTIG!"
                        for ((sortIdx=0; $sortIdx<${profitableAlgoIndexesCnt}; sortIdx++)); do
                            actSortedProfits[${sortIdx}]=${SORTED_PROFITS[${sortIdx}]}
                            algoIdx=${SORTED_PROFITS[${sortIdx}]#* }
                            actCandidatesAlgoIndexes[${sortIdx}]=${algoIdx}
                            dstAlgoWatts[${sortIdx}]=${actAlgoWatt[${algoIdx}]}
                            dstAlgoMines[${sortIdx}]=${actAlgoMines[${algoIdx}]}
                        done
                    fi
                    exactNumAlgos[${gpu_idx}]=${profitableAlgoIndexesCnt}

		    WATTS_Parameter_String_for_mm_calC+="${dstAlgoWatts[@]} "
		    MINES_Parameter_String_for_mm_calC+="${dstAlgoMines[@]} "
                else
                    # Wenn kein Algo übrigbleiben sollte, GPU aus.
		    SwitchOffGPUs+=( ${gpu_idx} )
                fi
            else
                SwitchNotGPUs+=( ${gpu_idx} )
            fi
            ;;
    esac
#    printf "Wattwerte #%2i: %s\n" ${gpu_idx} "${dstAlgoWatts[*]}"
#    printf "Minewerte #%2i: %s\n" ${gpu_idx} "${dstAlgoMines[*]}"
#    printf "Profits   #%2i: %s\n" ${gpu_idx} "${actSortedProfits[*]}"
done

#echo "${PossibleCandidateGPUidx[@]}" "${exactNumAlgos[@]}"
#echo "${WATTS_Parameter_String_for_mm_calC}"
#echo "${MINES_Parameter_String_for_mm_calC}"

MAX_GOOD_GPUs=${#PossibleCandidateGPUidx[@]}
MIN_GOOD_GPUs=2
BEST_ALGO_CNT=3
MAX_PROFIT=.0000965496
MAX_FP_MINES=.0001231651

# TESTWERTE
WATTS_Parameter_String_for_mm_calC="118 123 123 166 167 167 202 202 202 202 202 202 202 202 202 123 123 123 202 202 202 123 123 123 123 123 123 123 123 123 123 123 123 123 123 123 202 202 202"
MINES_Parameter_String_for_mm_calC=".0000881206 .0001004522 .0001007585 .0000680249 .0000888380 .0000888402 .0001230404 .0001230783 .0001231061 .0001230404 .0001230783 .0001231061 .0001230404 .0001230783 .0001231061 .0001085930 .0001219336 .0001231651 .0001230404 .0001230783 .0001231061 .0001085930 .0001219336 .0001231651 .0001085930 .0001219336 .0001231651 .0001085930 .0001219336 .0001231651 .0001085930 .0001219336 .0001231651 .0001085930 .0001219336 .0001231651 .0001230404 .0001230783 .0001231061"

.CUDA/mm_calc ${MIN_GOOD_GPUs} ${MAX_GOOD_GPUs} ${BEST_ALGO_CNT} ${SolarWattAvailable} \
	  ${kWhMin} ${kWhMax} ${MAX_PROFIT} ${MAX_FP_MINES} \
          "${PossibleCandidateGPUidx[*]}" "${exactNumAlgos[*]}" \
          "${WATTS_Parameter_String_for_mm_calC%% }" "${MINES_Parameter_String_for_mm_calC%% }"
exit

#for gpu_idx in {22..0}; do
for gpu_idx in {0..22}; do
    # Wie am schnellsten einen bestimmten gpu_idx herausschneiden?
    PossibleCandidateGPUidx=( {0..22} )

    # Das funktioniert
    # p=$(echo ${PossibleCandidateGPUidx[@]})

    # Das funktioniert auch
    p="${PossibleCandidateGPUidx[@]}"

    # Das funktioniert auch
    p=${PossibleCandidateGPUidx[@]}
    PossibleCandidateGPUidx=( ${p/@(${gpu_idx})} )

    echo ${gpu_idx}: ${PossibleCandidateGPUidx[@]}
done

exit
for p in ${PossibleCandidateGPUidx[@]}; do
done
exit
    
_func_gpu_abfrage_sh
[ -n "${NVIDIA_SMI_PM_LAUNCHED_string}" ] && {
    read -a arr_indexes <_func_gpu_abfrage_sh.test
    for arr_index in ${arr_indexes[@]}; do
	NVIDIA_SMI_PM_LAUNCHED[${arr_index}]=1
    done
}
declare -p NVIDIA_SMI_PM_LAUNCHED
exit

#rm _func_gpu_abfrage_sh.test
if [ ! -f _func_gpu_abfrage_sh.test ]; then
    _func_gpu_abfrage_sh
    NVIDIA_SMI_PM_LAUNCHED_string=$(echo ${!NVIDIA_SMI_PM_LAUNCHED[@]} | tee _func_gpu_abfrage_sh.test )
fi
read -a arr_indexes <_func_gpu_abfrage_sh.test
for arr_index in ${arr_indexes[@]}; do
    NVIDIA_SMI_PM_LAUNCHED[${arr_index}]=1
done
declare -p NVIDIA_SMI_PM_LAUNCHED

NVIDIA_SMI_PM_LAUNCHED_string=${!NVIDIA_SMI_PM_LAUNCHED[@]}
echo ${NVIDIA_SMI_PM_LAUNCHED_string}

exit

function _get_SYSTEM_STATE_in_old {
    unset SYSTEM_STATE_CONTENT
    unset uuidEnabledSOLL;  declare -Ag uuidEnabledSOLL
    unset NumEnabledGPUs;   declare -ig NumEnabledGPUs
    if [ -s ${SYSTEM_STATE}.in ]; then
        cp -f ${SYSTEM_STATE}.in ${SYSTEM_STATE}.BAK
        cat ${SYSTEM_STATE}.in  \
            | grep -e "^GPU-"   \
            | readarray -n 0 -O 0 -t SYSTEM_STATE_CONTENT

        for (( i=0; $i<${#SYSTEM_STATE_CONTENT[@]}; i++ )); do
            echo ${SYSTEM_STATE_CONTENT[$i]} \
                | cut -d':' --output-delimiter=' ' -f1,3 \
                | read UUID GenerallyEnabled
            declare -ig uuidEnabledSOLL[${UUID}]=${GenerallyEnabled}
            NumEnabledGPUs+=${GenerallyEnabled}
        done
    fi
}

function _get_SYSTEM_STATE_in {
    unset SYSTEM_STATE_CONTENT
    unset uuidEnabledSOLL;  declare -Ag uuidEnabledSOLL
    unset NumEnabledGPUs;   declare -ig NumEnabledGPUs
    if [ -s ${SYSTEM_STATE}.in ]; then
        cp -f ${SYSTEM_STATE}.in ${SYSTEM_STATE}.BAK
        cat ${SYSTEM_STATE}.in  \
            | grep -e "^GPU-"   \
            | cut -d':' --output-delimiter=' ' -f1,3 \
            | readarray -n 0 -O 0 -t SYSTEM_STATE_CONTENT

        for (( i=0; i<${#SYSTEM_STATE_CONTENT[@]}; i++ )); do
            read UUID GenerallyEnabled <<<${SYSTEM_STATE_CONTENT[$i]}
            declare -ig uuidEnabledSOLL[${UUID}]=${GenerallyEnabled}
            NumEnabledGPUs+=${GenerallyEnabled}
        done
    fi
}

_get_SYSTEM_STATE_in_old
echo ${uuidEnabledSOLL[@]}, ${NumEnabledGPUs}
_get_SYSTEM_STATE_in
echo ${uuidEnabledSOLL[@]}, ${NumEnabledGPUs}
exit

echo $(date "+%Y-%m-%d %H:%M:%S" ) $(date +%s) "Going to wait for all GPUs to calculate their ALGO_WATTS_MINES.in"
echo $(date "+%Y-%m-%d %H:%M:%S %s" ) "Going to wait for all GPUs to calculate their ALGO_WATTS_MINES.in"
exit

function _prepare_ALGO_PORTS_KURSE_from_the_Web_old () {
    # Auswertung und Erzeugung der PAY-Datei, aus der das Array KURSE eingelesen wird
    gawk -e 'BEGIN { RS=":[[]{|},{|}[]],"} \
          match( $0, /"algorithm":"[[:alnum:]]*/ )\
               { M=substr($0, RSTART, RLENGTH); print tolower( substr(M, index(M,":")+2 ) ) }  \
          match( $0, /"speed":[.[:digit:]]*/ )\
               { M=substr($0, RSTART, RLENGTH); print substr(M, index(M,":")+1 ) } \
          match( $0, /"paying":[.[:digit:]E\-]*/ )\
               { M=substr($0, RSTART, RLENGTH); print substr(M, index(M,":")+1 ) }' \
         ${algoID_KURSE__PAY__WEB}
}

function _prepare_ALGO_PORTS_KURSE_from_the_Web () {
    gawk -e 'BEGIN { RS=":[[]{|},{|}[]],"} \
          match( $0, /"algorithm":"[[:alnum:]]*/ )\
               { M=substr($0, RSTART, RLENGTH); print tolower( substr(M, index(M,":")+2 ) ) }  \
          match( $0, /"speed":[.[:digit:]]*/ )\
               { M=substr($0, RSTART, RLENGTH); print substr(M, index(M,":")+1 ) } \
          match( $0, /"paying":[.[:digit:]E\-]*/ )\
               { M=substr($0, RSTART, RLENGTH)
	       	 M=substr(M, index(M,":")+1 )
	       	 if (split( M, pay, "E" ) == 1) {
		    print M
		 } else {
		    print "(" pay[1] "*10^" pay[2] ")"
		 }
	       }' \
         ${algoID_KURSE__PAY__WEB}
}

diff <(_prepare_ALGO_PORTS_KURSE_from_the_Web_old) <(_prepare_ALGO_PORTS_KURSE_from_the_Web)
exit

read muck MAX_PROFIT   MAX_PROFIT_GPU_Algo_Combination <<<$(< .MAX_PROFIT.in)   #${_MAX_PROFIT_in}
read muck MAX_FP_MINES MAX_FP_GPU_Algo_Combination     muck2 MAX_FP_WATTS <<<$(< .MAX_FP_MINES.in) #${_MAX_FP_MINES_in}
if [[ "${MAX_PROFIT_GPU_Algo_Combination}" != "${MAX_FP_GPU_Algo_Combination}" \
          && "${MAX_FP_MINES}" > "${MAX_PROFIT}" ]]; then
    echo "FULL POWER MINES ${MAX_FP_MINES} wären mehr als die EFFIZIENZ Mines ${MAX_PROFIT}"
fi
exit

#_read_in_SYSTEM_FILE_and_SYSTEM_STATEin
RUNNING_STATE=xyz
read RunSecs  RunFrac <<<$(_get_file_modified_time_ ${RUNNING_STATE})
echo $RunSecs
if [[ ${RunSecs} > 0 ]]; then
    echo "Time got"
fi
exit

# Die führenden Nulen müssen von der Fraction, um nicht als Octalzahlen interpretiert zu werden
#     und wenn zufälligerweise 0 sein sollte, muss es auf 1 gesetzt werden.
_fraction_=000092600000
#_fraction_=000000000
_fraction_=${_fraction_##*(0)}
_fraction_=${_fraction_:-1}
echo $_fraction_
exit

#cat $(ls .bc_result_GPUs_3_0_1_4)
cat $(ls .bc_result_GPUs_*) \
    | tee >(grep -E -e '^#TOTAL '  | awk -e 'BEGIN {sum=0} {sum+=$NF} END {print sum}' >.GLOBAL_GPU_COMBINATION_LOOP_COUNTER) \
	  >(grep -e '^MAX_PROFIT:' | sort -g -k2 | tail -n 1 >.MAX_PROFIT.in) \
	  >(grep -e '^FP_M:'       | sort -g -k2 | tail -n 1 >.MAX_FP_MINES.in) \
	  >/dev/null
while [[ ! -s .MAX_PROFIT.in || ! -s .MAX_FP_MINES.in || ! -s .GLOBAL_GPU_COMBINATION_LOOP_COUNTER ]]; do sleep .05; done
echo "I'm out now"
cat .GLOBAL_GPU_COMBINATION_LOOP_COUNTER
cat .MAX_PROFIT.in
cat .MAX_FP_MINES.in
	    
	    
exit

# Läuft gut.
cat $(ls .bc_result_GPUs_*) \
    | tee >(grep -E -e '^#TOTAL '  | awk -e 'BEGIN {sum=0} {sum+=$NF} END {print sum}') \
	  >(grep -e '^MAX_PROFIT:' | sort -g -k2 | tail -n 1 ) \
	  >(grep -e '^FP_M:'       | sort -g -k2 | tail -n 1 ) \
	  >/dev/null
exit

cat $(ls .bc_result_GPUs_*) \
    | tee >(grep -E -e '#TOTAL ' | awk -e 'BEGIN {sum=0} {sum+=$NF} END {print sum}' >.GLOBAL_GPU_COMBINATION_LOOP_COUNTER; \
            rm -f .GLOBAL_GPU_COMBINATION_LOOP_COUNTER.lock) \
    | grep -E -v -e '^#|^$' \
    | tee >(grep -e '^MAX_PROFIT:'   | sort -g -r -k2 | grep -E -m1 '.*' >.MAX_PROFIT.in; \
            rm -f .MAX_PROFIT.in.lock) \
          >(grep -e '^FP_M:' | sort -g -r -k2 | grep -E -m1 '.*' >.MAX_FP_MINES.in; \
            rm -f .MAX_FP_MINES.in.lock) \
          >/dev/null

exit

#./algo_multi_abfrage.sh
_read_in_ALGO_PORTS_KURSE
exit

source ./gpu-abfrage.sh
ATTENTION_FOR_USER_INPUT=1
_func_gpu_abfrage_sh

debug=2
GPU_DIR=GPU-c6467c28-be24-03ad-e7ea-9bc0e989488f
lfdUuid=GPU-c6467c28-be24-03ad-e7ea-9bc0e989488f
gpu_uuid="${GPU_DIR}"
cd ${lfdUuid}
${LINUX_MULTI_MINING_ROOT}/${lfdUuid}/gpu_gv-algo.sh | tee tests.log
exit

GPU_DIR=GPU-c6467c28-be24-03ad-e7ea-9bc0e989488f
gpu_uuid="${GPU_DIR}"
IMPORTANT_BENCHMARK_JSON=${GPU_DIR}"/benchmark_${gpu_uuid}.json"
_read_in_SYSTEM_FILE_and_SYSTEM_STATEin
_set_Miner_Device_to_Nvidia_GpuIdx_maps
_test_=1
_read_in_ALL_Mining_Available_and_Missing_Miner_Algo_Arrays
echo Mining_t_rex_0_19_12_Algos: ${!Mining_t_rex_0_19_12_Algos[@]}:${Mining_t_rex_0_19_12_Algos[@]}
# output: Mining_t_rex_0_19_12_Algos: daggerhashimoto:ethash
exit

_read_in_static_COIN_MININGALGO_SERVERNAME_PORT_from_Pool_Info_Array
echo -e Coin_MiningAlgo_ServerName_Port: ${!Coin_MiningAlgo_ServerName_Port[@]}:${Coin_MiningAlgo_ServerName_Port[@]} "\n"
echo -e UniqueMiningAlgoArray: ${!UniqueMiningAlgoArray[@]}:${UniqueMiningAlgoArray[@]} "\n"
echo -e CoinsOfPool_nh: ${!CoinsOfPool_nh[@]}:${CoinsOfPool_nh[@]} "\n"
echo -e MiningAlgosOfPool_nh: ${!MiningAlgosOfPool_nh[@]}:${MiningAlgosOfPool_nh[@]} "\n"
#echo ${!miner_gpu_idx[@]}:${miner_gpu_idx[@]}

#_set_ALLE_LIVE_MINER
#echo ${!ALLE_LIVE_MINER[@]}:${ALLE_LIVE_MINER[@]}
exit

_set_ALLE_MINER_from_path
echo ALLE_MINER: key: ${!ALLE_MINER[@]} val: ${ALLE_MINER[@]}
echo ${COINS_MiningAlgos[@]}
echo ${actMiningAlgos[@]}

exit

<<COMMENT
date ist die schnellste Variante, Fractions möglich.
stat ist um etwa 18% langsamer als date,  Fractions möglich.
find ist mehr als doppelt so langsam wie stat, hat aber gleich die fraction mit dabei:

count=10000

find:
Pay_Time=$(find . -name ${algoID_KURSE_PORTS_PAY##*/} -printf '%T@')
PortTime=$(find . -name ${algoID_KURSE_PORTS_ARR##*/} -printf '%T@')

real	0m54,996s
user	0m31,402s
sys	0m23,806s
1618312974.2800629310, 1618312907.3279139210

stat:
Pay_Time=$(stat -c %Y ${algoID_KURSE_PORTS_PAY})
PortTime=$(stat -c %Y ${algoID_KURSE_PORTS_ARR})

real	0m24,763s
user	0m18,242s
sys	0m7,114s
1618312974, 1618312907

date:
Pay_Time=$(date --reference=${algoID_KURSE_PORTS_PAY} +%s)
PortTime=$(date --reference=${algoID_KURSE_PORTS_ARR} +%s)

real	0m20,291s
user	0m15,092s
sys	0m5,792s
1618312974, 1618312907

count=100 #0000
time while ((count--)); do
    unset ALGOs;    declare -ag ALGOs
    unset PORTs;    declare -Ag PORTs
    unset ALGO_IDs; declare -Ag ALGO_IDs
    unset READARR
    readarray -n 0 -O 0 -t READARR <${algoID_KURSE_PORTS_ARR}
    for ((i=0; $i<${#READARR[@]}; i+=3)) ; do
        ALGOs[${READARR[$i+2]}]=${READARR[$i]}
        PORTs[${READARR[$i]}]=${READARR[$i+1]}
        ALGO_IDs[${READARR[$i]}]=${READARR[$i+2]}
    done
    #count=${count}
done

Die zwei date Abfragen, zwei gleiche Läufe
real	0m20,455s
user	0m15,224s
sys	0m5,942s

real	0m20,219s
user	0m14,904s
sys	0m6,032s

Das einlesen der Datei in die Arrays, zwei gleiche Läufe
real	0m5,667s
user	0m5,501s
sys	0m0,100s

real	0m5,643s
user	0m5,512s
sys	0m0,060s
COMMENT

exit

