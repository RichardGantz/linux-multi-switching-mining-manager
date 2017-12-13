#!/bin/bash
############################################################################### 
# 
# Einlesen der Ports und mehr (Server fehlen noch)
#
# WICHTIG für die Miner-Starts zum Abliefern und Abrechnen der Hashes
# 
# Hier fragen wir die "simplemultialgo" API ab und erhalten die folgenden Informationen:
# {"paying":"0.00569102","port":3333,"name":"scrypt","algo":0},
# und lesen sie in die folgenden Arrays ein:
#    ALGOs[ $algo_ID ]
#    KURSE[ $algo ]
#    PORTs[ $algo ]
# ALGO_IDs[ $algo ]
################################################################################

_ALGOINFOS_INCLUDED=1

# Als Alarm, dass Webseite nicht abgerufen werden kann
_notify_about_NO_VALID_ALGO_NAMES_kMGTP_JSON()
{
    # $1 = Webdateiname, z.B. ${algoID_KURSE_PORTS_WEB}
    # $2 = Einlesedatei, z.B. ${algoID_KURSE_PORTS_ARR}
    # Tja, was machen wir in dem Fall also?
    # Die Stratum-Server laufen und nehmen offensichtlich generierten Goldstaub entgegen.
    # Und die Karten, die wir vor 31s eingeschaltet haben, liefen ja mit Gewinn.
    # Wie lange kann man die Karten also mit den "alten" Preisen weiterlaufen lassen?
    # "A couple of Minutes..."
    # Wir setzen eine Desktopmeldung ab... jede Minute... und machen einen Eintrag
    #     in eine Datei FATAL_ERRORS.log, damit man nicht vergisst,
    #     sich langfristig um das Problem zu kümmern.
    if [[ ! "$NoAlgoNames_notified" == "1" ]]; then
        notify-send -t 10000 -u critical "### Es gibt zur Zeit keine Datei $1 aus dem Web ###" \
                 "Die Datei $2 bleibt unverändert oder ist nicht vorhanden. \
                 Entscheide bitte, wie lange Du die gerade laufenden Miner \
                 mit den immer mehr veraltenden Zahlpreisen laufen lassen möchtest!"
        if [[ ! "$NoAlgoNames_recorded" == "1" ]]; then
            echo $(date "+%F %H:%M:%S") "curl - $1 hatte anderen Inhalt als erwartet." >>FATAL_ERRORS.log
            echo "                    Suchmuster $3 wurde nicht gefunden." >>FATAL_ERRORS.log
            NoAlgoNames_recorded=1
        fi
        NoAlgoNames_notified=1
    else
        # Damit wird nur bei jedem 2. Aufruf der Funktion ein notify-send gemacht
        # Geplant ist, dass das etwa jede Minute stattfindet (31s-Abfrage-Intervall*2)
        # Für den Sonderfall, dass noch nie eine Datei da war und beim Versuch des Abrufs
        #     ausgerechnet keine Daten kommen, weil die Seite spinnt,
        #     passiert das allerdings alle 2 Sekunden.
        #     Das ist aber nur beim Programmstart der Fall und sollte so gut wie nie vorkommen.
        NoAlgoNames_notified=0
    fi
}

# Die folgenden Variablen müssen korrekt gesetzt sein:
# algoID_KURSE_PORTS_WEB="KURSE.json"     oder "../KURSE.json",     je nachdem, wer die Funktion ruft
# algoID_KURSE_PORTS_ARR="KURSE_PORTS.in" oder "../KURSE_PORTS.in", je nachdem, wer die Funktion ruft
function _prepare_ALGO_PORTS_KURSE_from_the_Web () {
    declare -i jsonValid=0
    searchPattern='^[{]"result":[{]"simplemultialgo":\['
    jsonValid=$(curl "https://api.nicehash.com/api?method=simplemultialgo.info" \
                       | tee ${algoID_KURSE_PORTS_WEB} \
                       | grep -c -e "$searchPattern" )
    if [ ${jsonValid} -eq 0 ]; then
        _notify_about_NO_VALID_ALGO_NAMES_kMGTP_JSON \
            "${algoID_KURSE_PORTS_WEB}" "${algoID_KURSE_PORTS_ARR}" "$searchPattern"
        return 1
    fi
    unset NoAlgoNames_notified NoAlgoNames_recorded
    # Auswertung und Erzeugung der ARR-Datei, die bequemer von anderen eingelesen werden kann
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
        >${algoID_KURSE_PORTS_ARR}
}

# Die folgenden Variablen müssen korrekt gesetzt sein:
# algoID_KURSE_PORTS_WEB="KURSE.json"     oder "../KURSE.json",     je nachdem, wer die Funktion ruft
# algoID_KURSE_PORTS_ARR="KURSE_PORTS.in" oder "../KURSE_PORTS.in", je nachdem, wer die Funktion ruft
function _read_in_ALGO_PORTS_KURSE () {

    # Algoname:Algo-ID:Algo-Port:Paying Paare extrahieren nach READARR
    unset READARR
    unset ALGOs;    declare -ag ALGOs
    unset KURSE;    declare -Ag KURSE
    unset PORTs;    declare -Ag PORTs
    unset ALGO_IDs; declare -Ag ALGO_IDs

    readarray -n 0 -O 0 -t READARR <${algoID_KURSE_PORTS_ARR}
    for ((i=0; $i<${#READARR[@]}; i+=4)) ; do
        ALGOs[${READARR[$i+3]}]=${READARR[$i]}
        KURSE[${READARR[$i]}]=${READARR[$i+1]}
        PORTs[${READARR[$i]}]=${READARR[$i+2]}
        ALGO_IDs[${READARR[$i]}]=${READARR[$i+3]}
    done
}

# In der Zeit nach der Attacke auf NiceHash waren die länger offline und es ist aufgefallen, dass das Array ALGO_IDs am Rande
#    mitgepflegt wurde, jetzt aber plötzlich leer war.
#    Das hat zu falsch-Eintragungen in den benchmark.JSON Dateien geführt.
# Deshalb hier eien Funktion, die das Array auf einen Stand initialisiert, wie er am 19.10.2017 bekannt war.
function _set_ALGO_IDs_in_Offline_Mode () {
    unset ALGO_IDs; declare -Ag ALGO_IDs

    ALGO_IDs[scrypt]=0
    ALGO_IDs[sha256]=1
    ALGO_IDs[scryptnf]=2
    ALGO_IDs[x11]=3
    ALGO_IDs[x13]=4
    ALGO_IDs[keccak]=5
    ALGO_IDs[x15]=6
    ALGO_IDs[nist5]=7
    ALGO_IDs[neoscrypt]=8
    ALGO_IDs[lyra2re]=9
    ALGO_IDs[whirlpoolx]=10
    ALGO_IDs[qubit]=11
    ALGO_IDs[quark]=12
    ALGO_IDs[axiom]=13
    ALGO_IDs[lyra2rev2]=14
    ALGO_IDs[scryptjanenf16]=15
    ALGO_IDs[blake256r8]=16
    ALGO_IDs[blake256r14]=17
    ALGO_IDs[blake256r8vnl]=18
    ALGO_IDs[hodl]=19
    ALGO_IDs[daggerhashimoto]=20
    ALGO_IDs[decred]=21
    ALGO_IDs[cryptonight]=22
    ALGO_IDs[lbry]=23
    ALGO_IDs[equihash]=24
    ALGO_IDs[pascal]=25
    ALGO_IDs[x11gost]=26
    ALGO_IDs[sia]=27
    ALGO_IDs[blake2s]=28
    ALGO_IDs[skunk]=29
}

# Die folgenden Variablen werden in globals.inc gesetzt:
# COIN_PRICING_WEB="WhatToMine.json"
# COIN_PRICING_ARR="WhatToMine.in"
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

# Die folgenden Variablen müssen korrekt gesetzt sein:
# COIN_PRICING_WEB="WhatToMine.json"     oder "../WhatToMine.json",     je nachdem, wer die Funktion ruft
# COIN_PRICING_ARR="WhatToMine.in" oder "../WhatToMine.in", je nachdem, wer die Funktion ruft
function _read_in_COIN_PRICING () {

    #  Paare extrahieren nach READARR
    unset READARR
    unset CoinTags;    declare -ag CoinTags
    unset CoinNames;   declare -Ag CoinNames
    unset COIN_IDs;    declare -Ag COIN_IDs
    unset CoinAlgo;    declare -Ag CoinAlgo
    unset BlockTime;   declare -Ag BlockTime
    unset BlockReward; declare -Ag BlockReward
    unset CoinHash;    declare -Ag CoinHash

    readarray -n 0 -O 0 -t READARR <${COIN_PRICING_ARR}
    for ((i=0; $i<${#READARR[@]}; i+=7)) ; do
        CoinTags[${READARR[$i+2]}]=${READARR[$i+1]}
        CoinNames[${READARR[$i+1]}]=${READARR[$i]}
        CoinAlgo[${READARR[$i+1]}]=${READARR[$i+3]}
        COIN_IDs[${READARR[$i+1]}]=${READARR[$i+2]}
        BlockTime[${READARR[$i+1]}]=${READARR[$i+4]}
        BlockTime[${READARR[$i+1]}]=${READARR[$i+5]}
        CoinHash[${READARR[$i+1]}]=${READARR[$i+6]}
    done
}

