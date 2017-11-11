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
# Alle Algos aller Miner- und Versionsnummern werden in alle Internal_${m_name}_${m_version//\./_}_Algos eingelesen
#
_set_ALLE_MINER_from_path () {
    local workdir=$(pwd)
    cd $1
    ALLE_MINER=$(ls *.algos)

    shopt -s lastpipe
    unset NH_CC_Algos
    unset i;   declare -i i=0
    for minerName in ${ALLE_MINER}; do
        read m_name m_version <<<"${minerName//#/ }"
        m_version=${m_version%.algos}
        #
        # Hier der "." ist in Variablennamen nicht erlaubt.
        # Deshalb wandeln wir für die interne Indexierung der assoziativen Arrays alle "." in "_".
        # Damit können wir die Bestandteile des Strings sicher auch später wieder indentifizieren
        #
        declare -n         deleteIt="Internal_${m_name}_${m_version//\./_}_Algos";     unset deleteIt
        declare -Ag                 "Internal_${m_name}_${m_version//\./_}_Algos"
        declare -n actInternalAlgos="Internal_${m_name}_${m_version//\./_}_Algos"

        # Erst die Ausnahme-Namen, wenn es welche gibt...
        internalAlgoNames=$(ls NiceHash#${m_name}.names 2>/dev/null)
        if [ ${#internalAlgoNames} -gt 0 ]; then
            cat ${internalAlgoNames} | grep -v -e '^#' | readarray -n 0 -O 0 -t NH_CC_Algos
            # Aufbau des Arrays Internal_${miner_name}_${miner_version}_Algos
            # Die KEYS   sind die $algo NH_AlgoNamen !!!
            # Die VALUES sind die Internen CC_Namen  !!!
            for algoPair in "${NH_CC_Algos[@]}"; do
                read  nh_algo  cc_algo  <<<"${algoPair}"
                actInternalAlgos[${nh_algo}]="${cc_algo}"
            done
        fi

        # .. dann kommen die restlichen NiceHash-Algonamen dazu,
        #    falls es noch welche gibt, die nicht schon erfasst wurden.
        miner_algos=$(< ${m_name}#${m_version}.algos) &>/dev/null
        for nh_algo in ${miner_algos}; do
            # 
            # Für die speziellen Miner, die zwei Algorithmen laufen lassen können.
            # Der primäre und sekundäre Algo sind in der Datei durch ":" getrennt.
            # ---> Diese Art von Miner ist noch nicht implementiert. Nur vorbereitet! <---
            # ---> Diese Art von Miner ist noch nicht implementiert. Nur vorbereitet! <---
            # ---> Diese Art von Miner ist noch nicht implementiert. Nur vorbereitet! <---
            #
            # Hier der ":" ist in Variablennamen nicht erlaubt... Moment mal...
            # ---> Die Combined Algos kommen nicht in Variablennamen vor, nur als "Key" von Assoziativen Arrays.
            # ---> Und da schadet der ":" gar nicht. Deshalb lassen wir das mal so.
            #nh_algo=${nh_algo//:/SOS}
            if [ "${actInternalAlgos[${nh_algo}]}" == "" ]; then
                actInternalAlgos[${nh_algo}]="${nh_algo}"
            fi
        done

        i+=1
    done  ## for minerName in ${ALLE_MINER}
    cd ${workdir} >/dev/null
}

# Hat eine bestimmte Berechtigung, aber es könnten Miner ohne Versionsangabe dabei "übrig" bleiben.
# Das ist prinzipiell in Ordnung. Es gibt eben nur 1 Version dieses Miners und die ist der Nullstring ""
# In den Strings sieht das dann so aus: "${algo}#${miner_name}#" ??? <--- Glaube nicht, dass das stimmt!
#    --->   Muss erst überprüft werden. Das abschließende "#" könnte fehlen.
#    --->   Und wie der "read" auf reine Spaces am Ende reagiert, muss auch sichergestellt sein
_set_ALLE_MINER_from_path_no_longer () {
    rm -f t_a_$$
    cd $1
    ls *.algos *.names \
        | tee >(grep \.algos | grep -o -e '^[^#]*' >>t_a_$$) \
        | grep -e NiceHash# | sed -e 's/NiceHash#//;s/\.names$//' >>t_a_$$
    ALLE_MINER=$(sort t_a_$$ | uniq)
    cd - >/dev/null
    rm -f t_a_$$
}

#
# ${miner_name} und ${miner_version} müssen schon gesetzt sein.
# $IMPORTANT_BENCHMARK_JSON muss gesetzt sein
#
_split_into_Available_and_Missing_Miner_Algo_Arrays () {
    declare -n  actInternalAlgos="Internal_${miner_name}_${miner_version//\./_}_Algos"

    declare -n          deleteIt="Missing_${miner_name}_${miner_version//\./_}_Algos";     unset deleteIt
    declare -ag                  "Missing_${miner_name}_${miner_version//\./_}_Algos"
    declare -n   actMissingAlgos="Missing_${miner_name}_${miner_version//\./_}_Algos"

    declare -n          deleteIt="Available_${miner_name}_${miner_version//\./_}_Algos";     unset deleteIt
    declare -ag                  "Available_${miner_name}_${miner_version//\./_}_Algos"
    declare -n actAvailableAlgos="Available_${miner_name}_${miner_version//\./_}_Algos"

    unset algos
    declare -a algos=( "${!actInternalAlgos[@]}" )
    if [ ${#algos[@]} -gt 0 ]; then
        for lfdAlgo in ${algos[@]}; do
            sed -n -e '/"Name": "'${lfdAlgo}'",/{
                 N;N;N;/"MinerName": "'${miner_name}'",/{
                     N;/"MinerVersion": "'${miner_version}'",/{Q100}}};
                 ${Q99}' \
                ${IMPORTANT_BENCHMARK_JSON}
            found=$?
            if [ $found -eq 99 ]; then
                actMissingAlgos=( ${actMissingAlgos[@]} ${lfdAlgo} )
            else
                actAvailableAlgos=( ${actAvailableAlgos[@]} ${lfdAlgo} )
            fi
        done
    fi
    if [ ${#_test_} -gt 0 ]; then
        declare -p actInternalAlgos
        echo "${#actInternalAlgos[@]} Members in Internal Array"
        echo "${#actAvailableAlgos[@]} Members in Available Array"
        echo "${#actMissingAlgos[@]} Members in Missing Array"
    fi
}

# Hier muss das Verzeichnis zu miners mitgegeben werden, z.B. ../miners
#
# Alle Algos aller Miner- und Versionsnummern werden in alle Internal_${m_name}_${m_version//\./_}_Algos eingelesen
#
# $IMPORTANT_BENCHMARK_JSON muss gesetzt sein !!!!!!!!!
#
_read_in_ALL_Internal_Available_and_Missing_Miner_Algo_Arrays () {
    _set_ALLE_MINER_from_path "$1"

    # Dann gleich Bereitstellung zweier Arrays mit AvailableAlgos und MissingAlgos.
    # Die MissingAlgos könnte man in einer automatischen Schleife benchmarken lassen,
    # bis es keine MissingAlgos mehr gibt.

    for minerName in ${ALLE_MINER}; do
        read miner_name miner_version <<<"${minerName//#/ }"
        miner_version=${miner_version%.algos}
        declare -n actInternalAlgos="Internal_${miner_name}_${miner_version//\./_}_Algos"
        _split_into_Available_and_Missing_Miner_Algo_Arrays
    done

}
