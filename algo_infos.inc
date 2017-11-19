#!/bin/bash
############################################################################### 
# 
# Einlesen der Ports und mehr (Server fehlen noch)
#
# WICHTIG für die Miner-Starts zum Abliefern und Abrechnen der Hashes
# 

# >>>>>>>>>> DAS IST MOMENTAN EINE LEICHE.
# >>>>>>>>>> WIR BEKOMMEN ALLE WERTE FÜR'S BENCHMARKING AUCH ÜBER DIE "simplemultialgo" API-Abfrage
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

################################################################################
# Hier fragen wir die "simplemultialgo" API ab und erhalten die folgenden Informationen:
# {"paying":"0.00569102","port":3333,"name":"scrypt","algo":0},
# und lesen sie in die folgenden Arrays ein:
#    ALGOs[ $algo_ID ]
#    KURSE[ $algo ]
#    PORTs[ $algo ]
# ALGO_IDs[ $algo ]
function _read_in_ALGO_PORTS_KURSE () {
    declare -i jsonValid=0
    searchPattern='^[{]"result":[{]"simplemultialgo":\['
    while [ ${jsonValid} -eq 0 ]; do
        jsonValid=$(curl "https://api.nicehash.com/api?method=simplemultialgo.info" 2>/dev/null \
                           | tee ${algoID_KURSE_PORTS_WEB} \
                           | grep -c -e "$searchPattern" )
        if [ ${jsonValid} -eq 0 ]; then
            echo "Waiting for valid File ${algoID_KURSE_PORTS_WEB} from the Web..."
            sleep 1
        fi
    done

    # Algoname:Algo-ID:Algo-Port:Paying Paare extrahieren nach READARR
    shopt -s lastpipe
    unset READARR; declare -a READARR
    gawk -e 'BEGIN { RS=":[\[]{|},{|}\],"} \
          match( $0, /"name":"[[:alnum:]]*/ )\
               { M=substr($0, RSTART, RLENGTH); print tolower( substr(M, index(M,":")+2 ) ) }  \
          match( $0, /"paying":"[.[:digit:]]*/ )\
               { M=substr($0, RSTART, RLENGTH); print tolower( substr(M, index(M,":")+2 ) ) }  \
          match( $0, /"port":[[:digit:]]*/ )\
               { M=substr($0, RSTART, RLENGTH); print substr(M, index(M,":")+1 ) } \
          match( $0, /"algo":[[:digit:]]*/ )\
               { M=substr($0, RSTART, RLENGTH); print substr(M, index(M,":")+1 ) }' \
         ${algoID_KURSE_PORTS_WEB} 2>/dev/null \
        | tee $algoID_KURSE_PORTS_ARR \
        | readarray -n 0 -O 0 -t READARR

    unset ALGOs;    declare -ag ALGOs
    unset KURSE;    declare -Ag KURSE
    unset PORTs;    declare -Ag PORTs
    unset ALGO_IDs; declare -Ag ALGO_IDs
    for ((i=0; $i<${#READARR[@]}; i+=4)) ; do
        ALGOs[${READARR[$i+3]}]=${READARR[$i]}
        KURSE[${READARR[$i]}]=${READARR[$i+1]}
        PORTs[${READARR[$i]}]=${READARR[$i+2]}
        ALGO_IDs[${READARR[$i]}]=${READARR[$i+3]}
    done
}
