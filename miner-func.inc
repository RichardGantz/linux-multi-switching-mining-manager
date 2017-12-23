#!/bin/bash
###############################################################################
#
# Funktionen zur Beschaffung der Infos über die Miner und deren Algos in Arrays hinein
# 
#
#
# Hier muss das Verzeichnis zu miners mitgegeben werden, z.B. ../miners
#
# Dabei sind auch Miner, zu denen es keine Versionsinformationen gibt.
# Das ist eigentlich nicht, was wir wollen.

_MINERFUNC_INCLUDED=1

# Hier muss das Verzeichnis zu miners mitgegeben werden, z.B. ../miners
#
# Alle Algos aller Miner- und Versionsnummern werden in alle Mining_${m_name}_${m_version//\./_}_Algos eingelesen
#
_set_ALLE_MINER_from_path () {
    local workdir=$(pwd)
    cd $1
    unset ALLE_MINER
    ALLE_MINER=($(ls *.algos))
    ALLE_MINER=(${ALLE_MINER[@]%%[.]algos})

    shopt -s lastpipe
    for minerName in ${ALLE_MINER[@]}; do
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
        cat ${minerName}.algos | grep -v -e '^#' | readarray -n 0 -O 0 -t COINS_MiningAlgos
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
    cd ${workdir} >/dev/null
}

#
# ${miner_name} und ${miner_version} müssen als Parameter $1 und $2 übergeben werden!!!
# $IMPORTANT_BENCHMARK_JSON muss gesetzt sein
#
_split_into_Available_and_Missing_Miner_Algo_Arrays () {
    declare -n    actMiningAlgos="Mining_${1}_${2//\./_}_Algos"

    declare -n          deleteIt="Missing_${1}_${2//\./_}_Algos";     unset deleteIt
    declare -ag                  "Missing_${1}_${2//\./_}_Algos"
    declare -n   actMissingAlgos="Missing_${1}_${2//\./_}_Algos"

    declare -n          deleteIt="Available_${1}_${2//\./_}_Algos";     unset deleteIt
    declare -ag                  "Available_${1}_${2//\./_}_Algos"
    declare -n actAvailableAlgos="Available_${1}_${2//\./_}_Algos"

    if [ ${#actMiningAlgos[@]} -gt 0 ]; then
        for lfdMiningAlgo in ${actMiningAlgos[@]}; do
            # Wurde die IMPORTANT_BENCHMARK_JSON vielleicht schon eingelesen?
            if [ ${#bENCH[@]} -gt 0 ]; then
                if [ ${#bENCH["${lfdMiningAlgo}#${1}#${2}"]} -eq 0 ]; then
                    actMissingAlgos=( ${actMissingAlgos[@]} ${lfdMiningAlgo} )
                else
                    actAvailableAlgos=( ${actAvailableAlgos[@]} ${lfdMiningAlgo} )
                fi
            else
                # Da in der JSON sehr wohl zwei Einträge pro MinigAlgo sein können (Effektiv- und FullPower-Mode),
                #    müssen wir sicherstellen, dass nur das Effektiv-Objekt in den MissingAlgos landet.
                # Wenn wir also auf 888 stossen, suchen wir weiter.
                # Ist das 888 nicht da, brechen wir ab
                sed -n -e '/"Name": "'${lfdMiningAlgo}'",/{           # if found ${miningAlgo}
                         N;/"MinerName": "'${1}'",/{                  # appe(N)d 1 line;  if found $1 == ${miner_name}
                         N;/"MinerVersion": "'${2}'",/{               # appe(N)d 1 line;  if found $2 == ${miner_version}
                            N;N;N;N;N;N;N;/"BENCH_KIND": 888,/d;{     # appe(N)d 7 lines; if found 888, (d)elete and continue
                     Q100}}}};                                        # otherwise Quit and set $?=100
                     ${Q99}' \
                    ${IMPORTANT_BENCHMARK_JSON}
                found=$?
                if [ $found -eq 99 ]; then
                    actMissingAlgos=( ${actMissingAlgos[@]} ${lfdMiningAlgo} )
                else
                    actAvailableAlgos=( ${actAvailableAlgos[@]} ${lfdMiningAlgo} )
                fi
            fi
        done
        # Doppelt brauchen wir sie nicht. Ist nur sinnvoll in actMiningAlgos
        actMissingAlgos=(  $(echo ${actMissingAlgos[@]}   | sed -e 's/ /\n/g' | sort -u ))
        actAvailableAlgos=($(echo ${actAvailableAlgos[@]} | sed -e 's/ /\n/g' | sort -u ))
    fi
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
_read_in_ALL_Mining_Available_and_Missing_Miner_Algo_Arrays () {
    _set_ALLE_MINER_from_path "$1"

    # Dann gleich Bereitstellung zweier Arrays mit AvailableAlgos und MissingAlgos.
    # Die MissingAlgos könnte man in einer automatischen Schleife benchmarken lassen,
    # bis es keine MissingAlgos mehr gibt.

    [ "${_test_}" == "1" ] && declare -p ALLE_MINER
    for minerName in "${ALLE_MINER[@]}"; do
        read m_name m_version <<<"${minerName//#/ }"
        if [ "${_test_}" == "1" ]; then
            echo "\$minerName: $minerName"
            echo "\$m_name: $m_name, \$m_version: $m_version"
        fi
        _split_into_Available_and_Missing_Miner_Algo_Arrays ${m_name} ${m_version}
    done
}
