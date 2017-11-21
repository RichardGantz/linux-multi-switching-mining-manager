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
    jsonValid=$(curl "https://api.nicehash.com/api?method=simplemultialgo.info" 2>/dev/null \
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
