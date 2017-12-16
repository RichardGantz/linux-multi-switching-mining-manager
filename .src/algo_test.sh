#!/bin/bash
############################################################################### 
# 

# GLOBALE VARIABLEN, nützliche Funktionen
[[ ${#_GLOBALS_INCLUDED} -eq 0 ]] && source globals.inc

function _prepare_COIN_PRICING_from_the_Web () {
    declare -i jsonValid=0
    searchPattern='^[{]"coins":[{]'
    jsonValid=$(curl "https://whattomine.com/coins.json" \
                       | tee ${COIN_PRICING_WEB} \
                       | grep -c -e "$searchPattern" )
    if [ ${jsonValid} -eq 0 ]; then
        _notify_about_NO_VALID_ALGO_NAMES_kMGTP_JSON \
            "${COIN_PRICING_WEB}" "${COIN_PRICING_ARR}" "$searchPattern"
        return 1
    fi
    unset NoAlgoNames_notified NoAlgoNames_recorded
    # Auswertung und Erzeugung der ARR-Datei, die bequemer von anderen eingelesen werden kann
    gawk -e 'BEGIN { RS=":{|}," }
          FNR == 1 { next }
          { print substr( $0, 2, length($0)-2 ); getline
          if (match( $0, /"tag":"[[:alnum:]]*/ ))
               { M=substr($0, RSTART, RLENGTH); print tolower( substr(M, index(M,":")+2 ) ) }
          if (match( $0, /"id":[[:digit:]]*/ ))
               { M=substr($0, RSTART, RLENGTH); print substr(M, index(M,":")+1 ) }
          if (match( $0, /"algorithm":"[[:alnum:]]*/ ))
               { M=substr($0, RSTART, RLENGTH); print tolower( substr(M, index(M,":")+2 ) ) }
          if (match( $0, /"block_time":"[.[:digit:]]*/ ))
               { M=substr($0, RSTART, RLENGTH); print tolower( substr(M, index(M,":")+2 ) ) }
          if (match( $0, /"block_reward":[.[:digit:]]*/ ))
               { M=substr($0, RSTART, RLENGTH); print substr(M, index(M,":")+1 ) }
          if (match( $0, /"nethash":[[:digit:]]*/ ))
               { M=substr($0, RSTART, RLENGTH); print substr(M, index(M,":")+1 ) } }' \
         ${COIN_PRICING_WEB} \
        >${COIN_PRICING_ARR}
}

_prepare_COIN_PRICING_from_the_Web
exit

# Die folgenden Variablen werden in globals.inc gesetzt:
# COIN_TO_BTC_EXCHANGE_WEB="BittrexSummaries.json"
# COIN_TO_BTC_EXCHANGE_ARR="BittrexSummaries.in"
function _read_in_COIN_TO_BTC_EXCHANGE () {

    #  Paare extrahieren nach READARR
    unset READARR
    unset Coin2BTC;    declare -Ag Coin2BTC

    readarray -n 0 -O 0 -t READARR <${COIN_TO_BTC_EXCHANGE_ARR}
    for ((i=0; $i<${#READARR[@]}; i+=2)) ; do
        Coin2BTC[${READARR[$i]}]=${READARR[$i+1]}
    done
}

_read_in_COIN_TO_BTC_EXCHANGE
for coin in ${!Coin2BTC[@]}; do
    echo 1 $coin is ${Coin2BTC[$coin]} BTC
done
