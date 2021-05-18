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
function _notify_about_NO_VALID_DATA_FROM_THE_WEB () {
    # $1 = Webdateiname, z.B. ${algoID_KURSE_PORTS_WEB}
    # $2 = Einlesedatei, z.B. ${algoID_KURSE_PORTS_ARR}
    # $3 = Das Suchmuster, das gültigen Inhalt signalisiert

    # Tja, was machen wir in dem Fall also?
    # Die Stratum-Server laufen und nehmen offensichtlich generierten Goldstaub entgegen.
    # Und die Karten, die wir vor 31s eingeschaltet haben, liefen ja mit Gewinn.
    # Wie lange kann man die Karten also mit den "alten" Preisen weiterlaufen lassen?
    # "A couple of Minutes..."
    # Wir setzen eine Desktopmeldung ab... jede Minute... und machen einen Eintrag
    #     in eine Datei FATAL_ERRORS.log, damit man nicht vergisst,
    #     sich langfristig um das Problem zu kümmern.
    if [[ ! "$NoAlgoNames_notified" == "1" ]]; then
        notify-send -u critical "### Es gibt zur Zeit keine Datei $1 aus dem Web ###" \
                 "Die Datei $2 bleibt unverändert oder ist nicht vorhanden. \
                 Entscheide bitte, wie lange Du die gerade laufenden Miner \
                 mit den immer mehr veraltenden Daten laufen lassen möchtest!"
        if [[ ! "$NoAlgoNames_recorded" == "1" ]]; then
            echo $(date "+%F %H:%M:%S") "curl/w3m - $1 hatte anderen Inhalt als erwartet." >>${FATAL_ERRORS}
            echo "                    Suchmuster \'$3\' wurde nicht gefunden." >>${FATAL_ERRORS}
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

# Die folgenden Variablen werden in globals.inc gesetzt:
# algoID_KURSE_PORTS_WEB="NH_PORTS.json"
# algoID_KURSE__PAY__WEB="NH_PAYINGS.json"
# algoID_KURSE_PORTS_ARR="NH_PORTS.in"
# algoID_KURSE_PORTS_PAY="NH_PAYINGS.in"
function _prepare_ALGO_PORTS_KURSE_from_the_Web () {
    declare -i jsonValid=0
    searchPattern='^[{]"miningAlgorithms":\['

    _reserve_and_lock_file ${algoID_KURSE__PAY__WEB}
    # PAYING muss aus dieser Datei geholt werden.
    # https://api2.nicehash.com/main/api/v2/public/simplemultialgo/info
    jsonValid=$(curl "https://api2.nicehash.com/main/api/v2/public/simplemultialgo/info" \
                       | tee ${algoID_KURSE__PAY__WEB} \
                       | grep -c -e "$searchPattern" )
    if [ ${jsonValid} -eq 0 ]; then
        _notify_about_NO_VALID_DATA_FROM_THE_WEB \
            "${algoID_KURSE__PAY__WEB}" "${algoID_KURSE_PORTS_PAY}" "$searchPattern"
        return 1
    fi

    # PORTS müssen aus dieser Datei geholt werden.
    # https://api2.nicehash.com/main/api/v2/mining/algorithms
    # Da sich die Ports wohl kaum ändern, genügt es, jede Stunde abzurufen
    Pay_Time=$(date --reference=${algoID_KURSE__PAY__WEB} +%s)
    if [ -s ${algoID_KURSE_PORTS_WEB} ]; then
	PortTime=$(date --reference=${algoID_KURSE_PORTS_WEB} +%s)
    else
	PortTime=0
    fi
    if [ $((${Pay_Time}-3600)) -gt ${PortTime} ]; then
	jsonValid=$(curl "https://api2.nicehash.com/main/api/v2/mining/algorithms" \
			| tee ${algoID_KURSE_PORTS_WEB} \
			| grep -c -e "$searchPattern" )
	if [ ${jsonValid} -eq 0 ]; then
            _notify_about_NO_VALID_DATA_FROM_THE_WEB \
		"${algoID_KURSE_PORTS_WEB}" "${algoID_KURSE_PORTS_ARR}" "$searchPattern"
            return 1
	fi
	# Auswertung und Erzeugung der ARR-Datei, aus der die Arrays ALGOs, PORTs und ALGO_IDs eingelesen werden
	gawk -e 'BEGIN { RS=":[\[]{|},{|}\],"} \
          match( $0, /"algorithm":"[[:alnum:]]*/ )\
               { M=substr($0, RSTART, RLENGTH); print tolower( substr(M, index(M,":")+2 ) ) }  \
          match( $0, /"port":[[:digit:]]*/ )\
               { M=substr($0, RSTART, RLENGTH); print substr(M, index(M,":")+1 ) } \
          match( $0, /"order":[[:digit:]]*/ )\
               { M=substr($0, RSTART, RLENGTH); print substr(M, index(M,":")+1 ) }' \
             ${algoID_KURSE_PORTS_WEB} 2>/dev/null \
             >${algoID_KURSE_PORTS_ARR}
	# Das Flag für _read_in_ALGO_PORTS_KURSE, die Arrays aus der eben erstellten Datei einzulesen
    fi
    _remove_lock                             # ... und wieder freigeben

    unset NoAlgoNames_notified NoAlgoNames_recorded
    # Auswertung und Erzeugung der PAY-Datei, aus der das Array KURSE eingelesen wird
    gawk -e 'BEGIN { RS=":[\[]{|},{|}\],"} \
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
         ${algoID_KURSE__PAY__WEB} 2>/dev/null \
        >${algoID_KURSE_PORTS_PAY}
}

# Die folgenden Variablen werden in globals.inc gesetzt:
# algoID_KURSE_PORTS_WEB="NH_PORTS.json"
# algoID_KURSE__PAY__WEB="NH_PAYINGS.json"
# algoID_KURSE_PORTS_ARR="NH_PORTS.in"
# algoID_KURSE_PORTS_PAY="NH_PAYINGS.in"
function _read_in_ALGO_PORTS_KURSE () {

    # Algoname:Algo-ID:Algo-Port:Paying Paare extrahieren nach READARR
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

    unset SPEED;    declare -Ag SPEED
    unset KURSE;    declare -Ag KURSE
    unset READARR
    readarray -n 0 -O 0 -t READARR <${algoID_KURSE_PORTS_PAY}
    for ((i=0; $i<${#READARR[@]}; i+=3)) ; do
        SPEED[${READARR[$i]}]=${READARR[$i+1]}
        KURSE[${READARR[$i]}]=${READARR[$i+2]}
    done

    if [ 1 -eq 0 ]; then
	for ALGO in ${ALGOs[@]}; do
	    echo ${ALGO}
	    echo ${PORTs[${ALGO}]}
	    echo ${KURSE[${ALGO}]}
	done
    fi
}

function _prepare_Strompreise_in_BTC_from_the_Web () {
    declare -i jsonValid=0
    searchPattern='<title>Bitcoins kaufen, Bitcoin Kurs bei Bitcoin.de!</title>'
    jsonValid=$(curl "https://www.bitcoin.de/de" -o ${BTC_EUR_KURS_WEB}; \
                grep -i -c -m 1 -e "$searchPattern" ${BTC_EUR_KURS_WEB})
    if [ ${jsonValid} -eq 0 ]; then
        _notify_about_NO_VALID_DATA_FROM_THE_WEB \
            "${BTC_EUR_KURS_WEB}" "BTC_EUR_kurs.in" "$searchPattern"
        echo   "###########################################################################"
        printf "------------> ACHTUNG: Nicht aktualisierter BTC Kurs: $(<BTC_EUR_kurs.in)  <------------\n" 2>/dev/null
        echo   "------------>          Nicht aktualisierte Strompreise in BTC <------------"
        echo   "###########################################################################"
        return 1
    fi
    unset NoAlgoNames_notified NoAlgoNames_recorded
    #aussehen der html zeile -->
    #Aktueller Bitcoin Kurs: <img alt="EUR" class="ticker_arrow mbm3 g90" src="/images/s.gif" /> <strong \
    #  id="ticker_price">3.163,11 €</strong>

    # BTC Kurs extrahieren und umwandeln, dass dieser dann als Variable verwendbar und zum Rechnen geeignet ist
    btcEUR=$(gawk -e '/id="ticker_price"[^>]*>[0-9.,]*/ \
          	     { if (match( $NF, />[0-9.,]*/ )) {\
               	          M=substr( $NF, RSTART, RLENGTH); M = substr( M, 2 ); \
			  sub(/\./,"",M); sub(/,/,".",M); print M; exit } \
		     }' \
                  ${BTC_EUR_KURS_WEB} \
		 | grep -E -m 1 -o -e '[0-9.]*' \
		 | tee BTC_EUR_kurs.in )

    # Einmal für alle gleich die fixen kWh-Preise in BTC umwandeln
    for ((grid=0; $grid<${#GRID[@]}; grid++)) ; do
        # Kosten in EUR
        kwh_EUR=$(< kwh_${GRID[$grid]}_kosten.in)
        # Kosten Umrechnung in BTC
        echo $(echo "scale=10; ${kwh_EUR}/${btcEUR}" | bc) >kWh_${GRID[$grid]}_Kosten_BTC.in
    done
}

# Die folgenden Variablen werden in globals.inc gesetzt:
# COIN_PRICING_WEB="WhatToMine.json"
# COIN_PRICING_ARR="WhatToMine.in"
function _prepare_COIN_PRICING_from_the_Web () {
    declare -i jsonValid=0
    searchPattern='^[{]"coins":[{]'
    jsonValid=$(w3m -dump "https://whattomine.com/coins.json" \
                       | tee ${COIN_PRICING_WEB} \
                       | grep -c -e "$searchPattern" )
    if [ ${jsonValid} -eq 0 ]; then
        _notify_about_NO_VALID_DATA_FROM_THE_WEB \
            "${COIN_PRICING_WEB}" "${COIN_PRICING_ARR}" "$searchPattern"
        return 1
    fi
    unset NoAlgoNames_notified NoAlgoNames_recorded
    # Auswertung und Erzeugung der ARR-Datei, die bequemer von anderen eingelesen werden kann
    gawk -e 'BEGIN { RS=":{|}," }
          FNR == 1 { next }
          /^"Nicehash-/ { getline; next }
          { print substr( $0, 2, length($0)-2 ); getline                                         # CoinNames
          if (match( $0, /"tag":"[[:alnum:]]*/ ))
               { M=substr($0, RSTART, RLENGTH); print tolower( substr(M, index(M,":")+2 ) ) }    # COINS
          if (match( $0, /"id":[[:digit:]]*/ ))
               { M=substr($0, RSTART, RLENGTH); print substr(M, index(M,":")+1 ) }               # COIN_IDs
          if (match( $0, /"algorithm":"[[:alnum:]]*/ ))
               { M=substr($0, RSTART, RLENGTH); print tolower( substr(M, index(M,":")+2 ) ) }    # CoinAlgo
          if (match( $0, /"block_time":"[.[:digit:]]*/ ))
               { M=substr($0, RSTART, RLENGTH); print tolower( substr(M, index(M,":")+2 ) ) }    # BlockTime
          if (match( $0, /"block_reward":[.[:digit:]]*/ ))
               { M=substr($0, RSTART, RLENGTH); print substr(M, index(M,":")+1 ) }               # BlockReward
          if (match( $0, /"nethash":[[:digit:]]*/ ))                                             # CoinHash
               { M=substr($0, RSTART, RLENGTH); print substr(M, index(M,":")+1 ) } }' \
         ${COIN_PRICING_WEB} \
        >${COIN_PRICING_ARR}
}

# Die folgenden Variablen werden in globals.inc gesetzt:
# COIN_PRICING_WEB="WhatToMine.json"
# COIN_PRICING_ARR="WhatToMine.in"
function _read_in_COIN_PRICING () {

    #  Paare extrahieren nach READARR
    unset READARR
    unset COINS;       declare -ag COINS
    unset CoinNames;   declare -Ag CoinNames
    unset COIN_IDs;    declare -Ag COIN_IDs
    unset CoinAlgo;    declare -Ag CoinAlgo
    unset BlockTime;   declare -Ag BlockTime
    unset BlockReward; declare -Ag BlockReward
    unset CoinHash;    declare -Ag CoinHash

    # i=0: CoinNames
    # i=1: COINS
    # i=2: COIN_IDs
    # i=3: CoinAlgo
    # i=4: BlockTime
    # i=5: BlockReward
    # i=6: CoinHash
    readarray -n 0 -O 0 -t READARR <${COIN_PRICING_ARR}
    for ((i=0; $i<${#READARR[@]}; i+=7)) ; do
        ccoin=${READARR[$i+1]}
        ccoinId=${READARR[$i+2]}
        COINS[${ccoinId}]=${ccoin}
        COIN_IDs[${ccoin}]=${ccoinId}
        CoinNames[${ccoin}]=${READARR[$i]}
        CoinAlgo[${ccoin}]=${READARR[$i+3]}
        BlockTime[${ccoin}]=${READARR[$i+4]}
        BlockReward[${ccoin}]=${READARR[$i+5]}
        CoinHash[${ccoin}]=${READARR[$i+6]}
    done
}

# Die folgenden Variablen werden in globals.inc gesetzt:
# COIN_TO_BTC_EXCHANGE_WEB="BittrexSummaries.json"
# COIN_TO_BTC_EXCHANGE_ARR="BittrexSummaries.in"
function _prepare_COIN_TO_BTC_EXCHANGE_from_the_Web () {
    declare -i jsonValid=0
    searchPattern='^[{]"success":true,"message":"","result":\['
    jsonValid=$(w3m -dump "https://bittrex.com/api/v1.1/public/getmarketsummaries" \
                       | tee ${COIN_TO_BTC_EXCHANGE_WEB} \
                       | grep -c -e "$searchPattern" )
    if [ ${jsonValid} -eq 0 ]; then
        _notify_about_NO_VALID_DATA_FROM_THE_WEB \
            "${COIN_TO_BTC_EXCHANGE_WEB}" "${COIN_TO_BTC_EXCHANGE_ARR}" "$searchPattern"
        return 1
    fi
    unset NoAlgoNames_notified NoAlgoNames_recorded
    # Auswertung und Erzeugung der ARR-Datei, die bequemer von anderen eingelesen werden kann
    gawk -e 'BEGIN { RS=":[\[]{|},{|}\]" }
          match( $0, /"MarketName":"BTC-[[:alnum:]]*/ ) {
                 M=substr($0, RSTART, RLENGTH); print tolower( substr(M, index(M,"-")+1 ) )
                 if (match( $0, /"Last":[.[:digit:]]*/ ))\
                      { M=substr($0, RSTART, RLENGTH); print tolower( substr(M, index(M,":")+1 ) ) }
          }' \
         ${COIN_TO_BTC_EXCHANGE_WEB} 2>/dev/null \
        >${COIN_TO_BTC_EXCHANGE_ARR}
}

# Die folgenden Variablen werden in globals.inc gesetzt:
# COIN_TO_BTC_EXCHANGE_WEB="BittrexSummaries.json"
# COIN_TO_BTC_EXCHANGE_ARR="BittrexSummaries.in"
function _read_in_COIN_TO_BTC_EXCHANGE_FACTOR () {

    #  Paare extrahieren nach READARR
    unset READARR
    unset Coin2BTC_factor;    declare -Ag Coin2BTC_factor

    readarray -n 0 -O 0 -t READARR <${COIN_TO_BTC_EXCHANGE_ARR}
    for ((i=0; $i<${#READARR[@]}; i+=2)) ; do
        Coin2BTC_factor[${READARR[$i]}]=${READARR[$i+1]}
    done
}

