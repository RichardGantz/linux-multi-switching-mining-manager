#!/bin/bash
############################################################################### 
# 
# Einlesen der Ports und mehr (Server fehlen noch)
#
# WICHTIG für die Miner-Starts zum Abliefern und Abrechnen der Hashes
# 

function _read_in_ALGO_NAMES () {
    declare -i jsonValid=0
    searchPattern='^[{]"result":[{]"algorithms":\['
    while [ ${jsonValid} -eq 0 ]; do
        if [ -s "${ALGO_NAMES_WEB}" ]; then
            jsonValid=$(cat ${ALGO_NAMES_WEB} | grep -c -e "$searchPattern" )
        fi
        if [ ${jsonValid} -eq 0 ]; then
            jsonValid=$(curl "https://api.nicehash.com/api?method=buy.info" \
                               | tee ${ALGO_NAMES_WEB} \
                               | grep -c -e "$searchPattern" )
        fi
        if [ ${jsonValid} -eq 0 ]; then
	    echo "Waiting for valid File ${ALGO_NAMES_WEB} from the Web..."
	    sleep 1
	fi
    done

    # Algoname:kMGTP-Faktor:Algo-ID Paare extrahieren nach READARR
    shopt -s lastpipe
    unset READARR; declare -a READARR
    gawk -e 'BEGIN { RS=":[\[]{|},{|}\],"; \
                f["k"]=1; f["M"]=2; f["G"]=3; f["T"]=4; f["P"]=5 } \
          match( $0, /"name":"[[:alnum:]]*/ )\
               { M=substr($0, RSTART, RLENGTH); print tolower( substr(M, index(M,":")+2 ) ) }  \
          match( $0, /"speed_text":"[[:alpha:]]*/ )\
               { M=substr($0, RSTART, RLENGTH); print 1024 ** f[substr(M, index(M,":")+2, 1 )] }  \
          match( $0, /"algo":[0-9]*/ )\
               { M=substr($0, RSTART, RLENGTH); print substr(M, index(M,":")+1 ) }' \
         ${ALGO_NAMES_WEB} 2>/dev/null \
        | readarray -n 0 -O 0 -t READARR

    unset kMGTP ALGOs ALGO_IDs
    declare -Ag kMGTP ALGO_IDs
    for ((i=0; $i<${#READARR[@]}; i+=3)) ; do
        kMGTP[${READARR[$i]}]=${READARR[$i+1]}
        ALGOs[${READARR[$i+2]}]=${READARR[$i]}
        ALGO_IDs[${READARR[$i]}]=${READARR[$i+2]}
    done
}

function _read_in_ALGO_PORTS () {
    declare -i jsonValid=0
    searchPattern='^[{]"result":[{]"simplemultialgo":\['
    while [ ${jsonValid} -eq 0 ]; do
        if [ -s "${ALGO_PORTS_WEB}" ]; then
            jsonValid=$(cat ${ALGO_PORTS_WEB} | grep -c -e "$searchPattern" )
        fi
        if [ ${jsonValid} -eq 0 ]; then
            jsonValid=$(curl "https://api.nicehash.com/api?method=simplemultialgo.info" \
                               | tee ${ALGO_PORTS_WEB} \
                               | grep -c -e "$searchPattern" )
        fi
        if [ ${jsonValid} -eq 0 ]; then sleep 1; fi
    done

    # Algoname:Algo-ID:Algo-Port Paare extrahieren nach READARR
    shopt -s lastpipe
    unset READARR; declare -a READARR
    gawk -e 'BEGIN { RS=":[\[]{|},{|}\],"} \
          match( $0, /"name":"[[:alnum:]]*/ )\
               { M=substr($0, RSTART, RLENGTH); print tolower( substr(M, index(M,":")+2 ) ) }  \
          match( $0, /"port":[[:digit:]]*/ )\
               { M=substr($0, RSTART, RLENGTH); print substr(M, index(M,":")+1 ) } \
          match( $0, /"algo":[[:digit:]]*/ )\
               { M=substr($0, RSTART, RLENGTH); print substr(M, index(M,":")+1 ) }' \
         ${ALGO_PORTS_WEB} 2>/dev/null \
        | readarray -n 0 -O 0 -t READARR

    unset PORTs; declare -Ag PORTs
    algo_array_exists=${#ALGOs}
    if [ ${algo_array_exists} -eq 0 ]; then
        unset ALGOs; declare -ag ALGOs
    fi
    algoid_array_exists=${#ALGO_IDs}
    if [ ${algoid_array_exists} -eq 0 ]; then
        unset ALGO_IDs; declare -Ag ALGO_IDs
    fi
    for ((i=0; $i<${#READARR[@]}; i+=3)) ; do
        PORTs[${READARR[$i]}]=${READARR[$i+1]}
        if [ ${algo_array_exists} -eq 0 ]; then
            ALGOs[${READARR[$i+2]}]=${READARR[$i]}
        fi
        if [ ${algoid_array_exists} -eq 0 ]; then
            ALGO_IDs[${READARR[$i]}]=${READARR[$i+2]}
        fi
    done
}
