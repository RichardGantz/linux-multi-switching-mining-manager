#!/bin/bash
[[ ${#_GLOBALS_INCLUDED}     -eq 0 ]] && source globals.inc
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

function _calculate_GV_of_all_TestCombinationGPUs_members () {
    # TestCombinationGPUs enthält echte GPU-Indexes
    MAX_GPU_TIEFE=${#TestCombinationGPUs[@]}

    # ACHTUNG: BESCHRÄNKUNG AUF 18 GPUs im Moment.
    FN_combi=''

    for (( lfdGPU=0; $lfdGPU<${MAX_GPU_TIEFE}; lfdGPU++ )); do
        gpu_idx=${TestCombinationGPUs[${lfdGPU}]}
        FN_combi+="_${gpu_idx}"
    done

    <<COMMENT
#TOTAL NUMBER OF LOOPS = 3*3*3*3*3*3*3*3 = 6561
MAX_PROFIT: .00092321650243234937 0:0,1:0,2:0,3:0,5:0,7:0,9:0,10:0
FP_M: .00111953990566304552 0:0,1:2,2:0,3:0,5:0,7:0,9:0,10:0 FP_W: 1339
COMMENT

    read muck MAX_PROFIT   MAX_PROFIT_GPU_Algo_Combination                <<<$(grep -E '^MAX_PROFIT:' .bc_result_GPUs_${MAX_GPU_TIEFE}${FN_combi})
    read muck MAX_FP_MINES MAX_FP_GPU_Algo_Combination muck2 MAX_FP_WATTS <<<$(grep -E '^FP_M:'       .bc_result_GPUs_${MAX_GPU_TIEFE}${FN_combi})
    bc_prog="scale=10;max_profit=${MAX_PROFIT};old_max_profit=${OLD_MAX_PROFIT};max_mines=${MAX_FP_MINES};old_max_mines=${OLD_MAX_FP_MINES};
if (max_profit>old_max_profit) old_max_profit=max_profit;
if (max_mines>old_max_mines) old_max_mines=max_mines;
print old_max_profit, \" \", old_max_mines;
"
    read MAX_PROFIT MAX_FP_MINES  <<<$(echo "$bc_prog" | bc)

    if [ "$MAX_PROFIT" != "$OLD_MAX_PROFIT" ]; then
	echo "New Maximum Profit ${MAX_PROFIT} with GPU:AlgoIndexCombination ${MAX_PROFIT_GPU_Algo_Combination}"
	OLD_MAX_PROFIT=$MAX_PROFIT
    fi
    if [ "$MAX_FP_MINES" != "$OLD_MAX_FP_MINES" ]; then
        echo "New FULL POWER Profit ${MAX_FP_MINES} with GPU:AlgoIndexCombination ${MAX_FP_GPU_Algo_Combination} and ${MAX_FP_WATTS}W"
	OLD_MAX_FP_MINES=$MAX_FP_MINES
    fi
}

function _create_AND_CALCULATE_EVERY_AND_ALL_SUBSEQUENT_COMBINATION_CASES () {
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
        #if [[ ${debug} -eq 1 ]]; then
        #    echo $(date "+%Y-%m-%d %H:%M:%S" ) $(date +%s)
        #    echo "_create_AND_CALCULATE_EVERY_AND_ALL_SUBSEQUENT_COMBINATION_CASES maxTiefe ${maxTiefe} erreicht."
        #    echo "Starte mit den Testkombinationen von iii=${myStart} bis iii < ${myDepth}."
        #fi
        
        for (( iii=${myStart}; $iii<${myDepth}; iii++ )); do
            unset TestCombinationGPUs
            declare -ag TestCombinationGPUs
            # Jede Ebene vorher hat ihren aktuelen Indexwert an die Parameterliste gehängt.
            # Das Array TestCombinationGPUs, das die zu untersuchenden GPU-Indexe enthält,
            # wird jetzt komplett für die Berechnungsroutine aufgebaut.
            TestCombinationGPUs=($* ${PossibleCandidateGPUidx[${iii}]})
            #if [[ ${debug} -eq 999 ]]; then
            #    echo $(date "+%Y-%m-%d %H:%M:%S" ) $(date +%s)
            #    echo "Testkombinationsarray $iii hat ${#TestCombinationGPUs[@]} Member:" ${TestCombinationGPUs[@]}
            #fi

            _calculate_GV_of_all_TestCombinationGPUs_members
        done

    else
        # Hier wird eine Schleife begonnen und dann die Funktion selbst wieder gerufen
        # Dies dient dem Initiieren des zweiten bis letzten Zeigers
        #echo "(Weitere) Schleife starten und nächsten \"Pointer\" initiieren"
        for (( iii=${myStart}; $iii<${myDepth}; iii++ )); do
            #echo "Nächste Ebene übergebene Parameter:" ${maxTiefe} $((${iii}+1)) $((${myDepth}+1)) $* ${PossibleCandidateGPUidx[${iii}]}
            _create_AND_CALCULATE_EVERY_AND_ALL_SUBSEQUENT_COMBINATION_CASES \
                ${maxTiefe} $((${iii}+1)) $((${myDepth}+1)) $* ${PossibleCandidateGPUidx[${iii}]}
        done
    fi
}

start[$c]=$(date +%s)
PossibleCandidateGPUidx=( {0..10} )
MAX_GOOD_GPUs=${#PossibleCandidateGPUidx[@]}

MAX_PROFIT=".0"
OLD_MAX_PROFIT=".0"
MAX_FP_MINES=".0"
OLD_MAX_FP_MINES=".0"

MIN_GOOD_GPUs=2
[ ${MAX_GOOD_GPUs} -ge 8 ] && MIN_GOOD_GPUs=8

for (( numGPUs=${MIN_GOOD_GPUs}; $numGPUs<=${MAX_GOOD_GPUs}; numGPUs++ )); do
    # Parameter: $1 = maxTiefe
    #            $2 = Beginn Pointer1 bei Index 0
    #            $3 = Ende letzter Pointer 5
    #            $4-  Jede Ebene hängt dann ihren aktuellen Wert in der Schleife hin,
    #                 in der sie sich selbst gerade befindet.
    echo "Einlesen aller Kombinationen des Falles, dass nur ${numGPUs} GPUs von ${MAX_GOOD_GPUs} laufen:"
    _create_AND_CALCULATE_EVERY_AND_ALL_SUBSEQUENT_COMBINATION_CASES \
        ${MAX_GOOD_GPUs} 0 $((${MAX_GOOD_GPUs} - ${numGPUs} + 1))
done

ende[$c]=$(date +%s)
echo "Benötigte Zeit zur Anzeige dieses Berechnungsverlaufs:" $(( ${ende[$c]} - ${start[$c]} )) Sekunden
