#!/bin/bash
###############################################################################
#
# Funktionen zur Beschaffung der Infos über die Miner und deren Algos in Arrays hinein
# 
#
#
# Hier muss das Verzeichnis zu miners mitgegeben werden, z.B. ../miners
#

_MINERFUNC_INCLUDED=1

function _read_in_minerFees_to_MINER_FEES () {
    local miner

    _reserve_and_lock_file all.miner.fees
    declare -i act_miner_fees_epoch=$(date --reference=${LINUX_MULTI_MINING_ROOT}/miners/all.miner.fees +%s)

    [ -z "${all_miner_fees_epoch}" ] && declare -ig all_miner_fees_epoch=0
    if [[  ${act_miner_fees_epoch} > ${all_miner_fees_epoch} ]]; then
        echo "$(basename $0):${gpu_idx}: ###---> Updating all Miner Fees from disk."
        unset READARR
        unset MINER_FEES; declare -Ag MINER_FEES

        for miner in ${ALLE_MINER[@]}; do
            MINER_FEES[${miner}]=0
        done

        cat ${LINUX_MULTI_MINING_ROOT}/miners/all.miner.fees \
            | grep -E -v -e "^#|^$"  \
            | readarray -n 0 -O 0 -t READARR
        for ((i=0; $i<${#READARR[@]}; i++)) ; do
            #echo ${READARR[$i]}
            MINER_FEES[${READARR[$i]%:*}]=${READARR[$i]#*:}
        done
        all_miner_fees_epoch=${act_miner_fees_epoch}
    fi
    _remove_lock
}

# Alle Algos aller Miner- und Versionsnummern werden in alle Mining_${m_name}_${m_version//\./_}_Algos eingelesen
#
function _set_ALLE_MINER_from_path () {
    local workdir=$(pwd) RC=0
    cd ${LINUX_MULTI_MINING_ROOT}/miners

    _reserve_and_lock_file any_miner_algos_changed
    ls -l *.algos >.act_miner_algos
    [[ ! -f .all_miner_algos         ]] && touch .all_miner_algos
    diff -q .act_miner_algos .all_miner_algos &>/dev/null
    [[ $? -gt 0 ]] && touch .any_miner_algos_changed
    cp -f .act_miner_algos .all_miner_algos
    declare -i act_miner_algos_epoch=$(date --reference=.any_miner_algos_changed +%s)

    [[ -z "${old_miner_algos_epoch}" ]] && declare -ig old_miner_algos_epoch=0
    if [ ${act_miner_algos_epoch} -gt ${old_miner_algos_epoch} ]; then
        echo "$(basename $0):${gpu_idx}: ###---> Updating ALLE_MINER Algo structures from disk."

        unset ALLE_MINER MINER_IS_AVAILABLE
        declare -Ag MINER_IS_AVAILABLE
        ALLE_MINER=($(ls *.algos))
        ALLE_MINER=(${ALLE_MINER[@]%%[.]algos})

        shopt -s lastpipe
        for minerName in ${ALLE_MINER[@]}; do
            # gpu-bENCH.inc liest nur $algorithm-Objekte aus der benchmark_UUID.json, wenn es den Miner aktuell gibt.
            # In der JSON können nämlich auch ältere Werte drin sein von Minern, die ausrangiert wurden.
            # Natürlich sollte man ab und zu auch die JSON säubern.
            MINER_IS_AVAILABLE[${minerName}]=1
            [ "${_test_}" == "2" ] && echo "\$minerName: $minerName"
            read m_name m_version <<<"${minerName//#/ }"
            #
            # Hier der "." ist in Variablennamen nicht erlaubt.
            # Deshalb wandeln wir für die interne Indexierung der assoziativen Arrays alle "." in "_".
            # Damit können wir die Bestandteile des Strings sicher auch später wieder indentifizieren
            #
            declare -n       deleteIt="Mining_${m_name}_${m_version//\./_}_Algos";     unset deleteIt
            declare -Ag               "Mining_${m_name}_${m_version//\./_}_Algos"
            declare -n actMiningAlgos="Mining_${m_name}_${m_version//\./_}_Algos"

            unset COINS_MiningAlgos
            # Erst die Ausnahme-Namen, wenn es welche gibt...
            cat ${minerName}.algos | grep -E -v -e '^#|^$' | readarray -n 0 -O 0 -t COINS_MiningAlgos
            # Aufbau des Arrays Mining_${miner_name}_${miner_version}_Algos
            # Die KEYS   sind die $algo NH_AlgoNamen !!!
            # Die VALUES sind die Internen CC_Namen  !!!
            for algoPair in "${COINS_MiningAlgos[@]}"; do
                read  algo_coin  mining_algo  <<<"${algoPair}"
                [ -z "${mining_algo}" ] && mining_algo=${algo_coin}
                # ---> Die Combined Produktionsstätten MiningAlgos müssen noch implementiert werden
                # ---> Im Moment sind Haupt- und Neben-MiningAlgo durch ":" getrennt.
                #algo_coin=${algo_coin//:/SOS}
                actMiningAlgos[${algo_coin}]="${mining_algo}"
            done

        done  ## for minerName in ${ALLE_MINER[@]}
        old_miner_algos_epoch=${act_miner_algos_epoch}
        RC=1
    fi
    _remove_lock

    _read_in_minerFees_to_MINER_FEES

    cd ${workdir} >/dev/null
    return $RC
}

# Alle Algos aller Miner- und Versionsnummern werden in alle Mining_${m_name}_${m_version//\./_}_Algos eingelesen
#
function _set_ALLE_LIVE_MINER () {
    local workdir=$(pwd) MINER
    _set_ALLE_MINER_from_path
    cd ${LINUX_MULTI_MINING_ROOT}/miners

    _reserve_and_lock_file any_live_miner_changed

    ${LINUX_MULTI_MINING_ROOT}/set_live_miners.sh "${ALLE_MINER[@]}"
    [ ! -s live_miners ] && echo "First Call" >live_miners

    diff -q live_miners .act_live_miners &>/dev/null
    RC=$?
    if [[ $RC -gt 0 || ${#ALLE_LIVE_MINER[@]} -eq 0 ]]; then
        local msg="###--->"
        echo "$(basename $0):${gpu_idx}: ${msg} Updating  ALLE_LIVE_MINER  from disk."
        cp -f .act_live_miners live_miners
        unset ALLE_LIVE_MINER alle_live_miner
        declare -Ag ALLE_LIVE_MINER
        read -a alle_live_miner <<<$(< live_miners)
        for MINER in ${alle_live_miner[@]}; do
            msg+=" ${MINER}"
            ALLE_LIVE_MINER[${MINER}]=1
        done
        echo "$(basename $0):${gpu_idx}: ${msg}"
    fi

    _remove_lock

    cd ${workdir} >/dev/null
    return $RC
}

#
# ${miner_name} und ${miner_version} müssen als Parameter $1 und $2 übergeben werden!!!
# $IMPORTANT_BENCHMARK_JSON muss gesetzt sein
#
function _split_into_Available_and_Missing_Miner_Algo_Arrays () {
    declare -n          deleteIt="Missing_${1}_${2//\./_}_Algos";   unset deleteIt
    declare -ag                  "Missing_${1}_${2//\./_}_Algos"
    declare -n   actMissingAlgos="Missing_${1}_${2//\./_}_Algos"

    declare -n          deleteIt="Available_${1}_${2//\./_}_Algos"; unset deleteIt
    declare -ag                  "Available_${1}_${2//\./_}_Algos"
    declare -n actAvailableAlgos="Available_${1}_${2//\./_}_Algos"

    for lfdMiningAlgo in ${actMiningAlgos[@]}; do
        #echo "\$lfdMiningAlgo $lfdMiningAlgo"
        found=0
        # Wurde die IMPORTANT_BENCHMARK_JSON vielleicht schon eingelesen?
        if [ ${#bENCH[@]} -gt 0 ]; then
            [ ${#bENCH[${lfdMiningAlgo}#${1}#${2}]} -eq 0 ] && found=99 || found=100
        else
            # Da in der JSON sehr wohl zwei Einträge pro MinigAlgo sein können (Effektiv- und FullPower-Mode),
            #    müssen wir sicherstellen, dass nur das Effektiv-Objekt in den MissingAlgos landet.
            # Wenn wir also auf 888 stossen, suchen wir weiter.
            # Ist das 888 nicht da, brechen wir ab
            sed -n -e '/"Name": "'${lfdMiningAlgo}'",/{               # if found ${miningAlgo}
                         N;/"MinerName": "'${1}'",/{                  # appe(N)d 1 line;  if found $1 == ${miner_name}
                         N;/"MinerVersion": "'${2}'",/{               # appe(N)d 1 line;  if found $2 == ${miner_version}
                            N;N;N;N;N;N;N;/"BENCH_KIND": 888,/d;{     # appe(N)d 7 lines; if found 888, (d)elete and continue
                     Q100}}}};                                        # otherwise Quit and set $?=100
                     ${Q99}' \
                ${IMPORTANT_BENCHMARK_JSON}
            found=$?
        fi
        if [ $found -eq 99 ]; then
            actMissingAlgos[${#actMissingAlgos[@]}]=${lfdMiningAlgo}
        else
            actAvailableAlgos[${#actAvailableAlgos[@]}]=${lfdMiningAlgo}
        fi
    done
    # Doppelt brauchen wir sie nicht. Ist nur sinnvoll in actMiningAlgos
    actMissingAlgos=(  $(echo ${actMissingAlgos[@]}   | tr ' ' '\n' | sort -u ))
    actAvailableAlgos=($(echo ${actAvailableAlgos[@]} | tr ' ' '\n' | sort -u ))
    if [ "${_test_}" == "1" ]; then
        declare -p actMiningAlgos
        echo "${#actMiningAlgos[@]} Members in Mining Array"
        echo "${#actAvailableAlgos[@]} Members in Available Array"
        echo "${#actMissingAlgos[@]} Members in Missing Array"
    fi
}

# Hier muss das Verzeichnis zu miners mitgegeben werden, z.B. ../miners
#
# Alle Algos aller Miner- und Versionsnummern werden in alle Mining_${m_name}_${m_version//\./_}_Algos eingelesen
#
# $IMPORTANT_BENCHMARK_JSON muss gesetzt sein !!!!!!!!!
#
function _read_in_ALL_Mining_Available_and_Missing_Miner_Algo_Arrays () {
    _set_ALLE_MINER_from_path
    #_ALL_MINERS_DATA_CHANGED_ON_DISK_=$?

    # Dann gleich Bereitstellung zweier Arrays mit AvailableAlgos und MissingAlgos.
    # Die MissingAlgos könnte man in einer automatischen Schleife benchmarken lassen,
    # bis es keine MissingAlgos mehr gibt.

    for minerName in "${ALLE_MINER[@]}"; do
        read m_name m_version <<<"${minerName//#/ }"
        if [ "${_test_}" == "1" ]; then
            echo "\$minerName: $minerName"
            echo "\$m_name: $m_name, \$m_version: $m_version"
        fi
        declare -n actMiningAlgos="Mining_${m_name}_${m_version//\./_}_Algos"
        if [ ${#actMiningAlgos[@]} -gt 0 ]; then
            _split_into_Available_and_Missing_Miner_Algo_Arrays ${m_name} ${m_version}
        fi
    done
}

##################################################################################
#
# Nach dem Aufruf dieser Funktion haben wir alle Infos aus den all.nh/sn/mh/etc Dateien
# in jeweils 3 Arrays pro Pool (der Pool ist Teil des Array-Namens)
# Die Arrays sagen uns alle Coins                    des Pools,
#                       die Servernamen zu den Coins des Pools und
#                       die Ports       zu den Coins des Pools und
#
function _read_in_static_COIN_MININGALGO_SERVERNAME_PORT_from_Pool_Info_Array () {
    local pool coin miningAlgo server_name algo_port workdir=$(pwd)
    cd ${LINUX_MULTI_MINING_ROOT}

    _reserve_and_lock_file UniqueMiningAlgoArray
    ls -l all.* >.act_all_pool_infos
    [[ ! -f .all_all_pool_infos ]] && touch .all_all_pool_infos
    diff -q .act_all_pool_infos .all_all_pool_infos &>/dev/null
    [[ $? -gt 0 ]] && touch .any_all_pool_infos_changed
    cp -f .act_all_pool_infos .all_all_pool_infos
    declare -i act_all_pool_infos_epoch=$(date --reference=.any_all_pool_infos_changed +%s)

    [[ -z "${old_all_pool_infos_epoch}" ]] && declare -ig old_all_pool_infos_epoch=0
    if [ ${act_all_pool_infos_epoch} -gt ${old_all_pool_infos_epoch} ]; then
        echo "$(basename $0):${gpu_idx}: ###---> Updating UniqueMiningAlgo-CoinMiningAlgoServerPort-Array structures from Offline files all.*"

        unset UniqueMiningAlgoArray
        declare -Ag UniqueMiningAlgoArray

        for pool in ${!OfflineInfo[@]}; do
            declare -n                   deleteIt="CoinsOfPool_${pool}";            unset deleteIt
            declare -ag                           "CoinsOfPool_${pool}"
            declare -n             actCoinsOfPool="CoinsOfPool_${pool}"

            declare -n                   deleteIt="MiningAlgosOfPool_${pool}";      unset deleteIt
            declare -ag                           "MiningAlgosOfPool_${pool}"
            declare -n             actMiningAlgosOfPool="MiningAlgosOfPool_${pool}"

            #declare -n                   deleteIt="ServerNameOfPool_${pool}";       unset deleteIt
            #declare -Ag                           "ServerNameOfPool_${pool}"
            #declare -n        actServerNameOfPool="ServerNameOfPool_${pool}"

            #declare -n                   deleteIt="PortsOfPool_${pool}";            unset deleteIt
            #declare -Ag                           "PortsOfPool_${pool}"
            #declare -n             actPortsOfPool="PortsOfPool_${pool}"

            unset Coin_MiningAlgo_ServerName_Port
            declare -ag Coin_MiningAlgo_ServerName_Port
            cat ${LINUX_MULTI_MINING_ROOT}/${OfflineInfo[${pool}]} \
                | grep -E -v -e "^#|^$" \
                | readarray -n 0 -O 0 -t Coin_MiningAlgo_ServerName_Port
            for ((i=0; $i<${#Coin_MiningAlgo_ServerName_Port[@]}; i++)) ; do
                read coin miningAlgo server_name algo_port <<<${Coin_MiningAlgo_ServerName_Port[$i]//:/ }
                actCoinsOfPool[$i]=${coin}
                actMiningAlgosOfPool[$i]=${miningAlgo}
                #actServerNameOfPool[${coin}]=${server_name}
                #actPortsOfPool[${coin}]=${algo_port}

                UniqueMiningAlgoArray[${miningAlgo}]+="${coin}#${pool}#${server_name}#${algo_port} "
            done
        done
        #declare -p UniqueMiningAlgoArray

        for miningAlgo in ${!UniqueMiningAlgoArray[@]}; do
            mining_Algo=${miningAlgo//-/_}
            declare -n                   deleteIt="CoinsPoolsOfMiningAlgo_${mining_Algo}"; unset deleteIt
            declare -ag                           "CoinsPoolsOfMiningAlgo_${mining_Algo}"
            declare -n  actCoinsPoolsOfMiningAlgo="CoinsPoolsOfMiningAlgo_${mining_Algo}"

            read -a actCoinsPoolsOfMiningAlgo <<<${UniqueMiningAlgoArray[${miningAlgo}]}
            #declare -p ${!actCoinsPoolsOfMiningAlgo}
        done

        old_all_pool_infos_epoch=${act_all_pool_infos_epoch}
    fi
    _remove_lock

    cd ${workdir} >/dev/null
}

function _set_Miner_Device_to_Nvidia_GpuIdx_maps () {
    _set_ALLE_MINER_from_path
    _ALL_MINERS_DATA_CHANGED_ON_DISK_=$?

    if [ ${#miner_gpu_idx[@]} -eq 0 -o ${_ALL_MINERS_DATA_CHANGED_ON_DISK_} -ne 0 ]; then
        echo "$(basename $0):${gpu_idx}: ###---> Updating Table \"<Miner Device-Num> to <Nvidia gpu_idx>\"."

        # Key/index dieses Assoziativen Arrays ist eine Kombination aus ${MINER}#${gpu_idx}
        # ${gpu_idx} ist die Nvidia GPU-Indexnummer.
        # In dieser Funktion finden wir heraus, welche Nummer wir dem Miner beim MinerStart übergeben müssen.
        #    damit er die richtige, von uns auch ausgewählte Nividia ${gpu_idx} minet.
        unset miner_gpu_idx;    declare -Ag miner_gpu_idx

        for MinerFullName in "${ALLE_MINER[@]}"; do

            case "${MinerFullName}" in

                # Die Ausnahmen hier oben
                # "xmrMiner#0.2.1")
                #   miner_gpu_idx["${MinerFullName}#0"]=
                #   miner_gpu_idx["${MinerFullName}#1"]=
                #   miner_gpu_idx["${MinerFullName}#2"]=
                #   miner_gpu_idx["${MinerFullName}#3"]=
                #   miner_gpu_idx["${MinerFullName}#4"]=
                #   miner_gpu_idx["${MinerFullName}#5"]=
                #   miner_gpu_idx["${MinerFullName}#6"]=
                #   ;;

                *)
                    # miner_gpu_idx[  ${MINER}#${gpu_idx}  ] = miner_dev
                    miner_gpu_idx["${MinerFullName}#0"]=1          # Bisher sind nur die ersten beiden vertauscht.
                    miner_gpu_idx["${MinerFullName}#1"]=0
                    miner_gpu_idx["${MinerFullName}#2"]=2
                    miner_gpu_idx["${MinerFullName}#3"]=3
                    miner_gpu_idx["${MinerFullName}#4"]=4
                    miner_gpu_idx["${MinerFullName}#5"]=5
                    miner_gpu_idx["${MinerFullName}#6"]=6
                    ;;
            esac
        done
    fi
}

