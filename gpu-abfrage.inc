#!/bin/bash
#
# Ein paar Funktionen und auch Überlegungen und Dokumentation zur GPU Systemabfrage und deren Abbild im Arbeitsspeicher
#

# Der Eintrag AlgoDisabled[${algo}] enthält immer und zu jeder Zeit den Inhalt
#     der auch die in die Datei ${SYSTEM_STATE}.in auszugebenden Zeile als String
#
# Dieser String ist folgendermaßen aufgebaut:
#     "^AlgoDisabled:$NH_AlgoName  und optional dahinter [ ":*" ] [ ":${gpu_uuid}" ]..."
#     z.B.   "AlgoDisabled:equihash:GPU-7...:*:GPU-4..."
#            Was bedeuten würde:
#            Im Moment ist der Algo "equihash" generell für alle GPUs diabled, weil z.B. die Server nicht erreichbar sind.
#            Sollten die Server wieder verfügbar sein, ist es der Wunsch von "GPU-7..." und "GPU-4..."
#                den equihash immer noch nicht bearbeiten zu wollen und disabled zu belassen.
#            Jede GPU kann hier definitiv für sich Algos ein- oder ausschalten.
#
# Übergeben werden müssen:
#     $1 : $algo
#     $2 : $uuid oder * oder nichts für Alle GPUs, also Generell Disabled wegen Serverausfall, etc.
# Der * steht für generell disabled und wird auch im Falle $2 == "" angenommen.
#

# HINZUFÜGEN eines Algo zu dem AlgoDisabled[${algo}] STRING
_add_entry_into_AlgoDisabled () {
    local algo=$1
    local gpu_uuid=$2
    if [ ${#2} -eq 0 ]; then gpu_uuid='*'; fi
    strEntry=":${gpu_uuid}"
    if [ -n ${AlgoDisabled[${algo}]} ]; then
        # Erst sicher entfernen...
        AlgoDisabled[${algo}]=${AlgoDisabled[${algo}]//"${strEntry}"/}
        # ... dann einfach anfügen
        AlgoDisabled[${algo}]+="${strEntry}"
    else
        AlgoDisabled[${algo}]="AlgoDisabled:${algo}:${gpu_uuid}"
    fi
}

# ENTFERNEN eines Algo aus dem AlgoDisabled[${algo}] STRING
_remove_entry_from_AlgoDisabled () {
    local algo=$1
    local gpu_uuid=$2
    if [ ${#2} -eq 0 ]; then gpu_uuid='*'; fi
    strEntry=":${gpu_uuid}"
    if [ -n "${AlgoDisabled[${algo}]}" ]; then
        # Erst sicher entfernen...
        AlgoDisabled[${algo}]="${AlgoDisabled[${algo}]//"${strEntry}"/}"
        if [ "${AlgoDisabled[${algo}]}" == "AlgoDisabled:${algo}" ]; then
            unset AlgoDisabled[${algo}]
        fi
    fi
}

# Abfrage, ob algo für spezielle oder alle GPUs gesperrt ist
# Die Antwort von $( _is_algo_disabled_for_gpu_uuid ) ist "yes" oder "no" !!!
_is_algo_disabled_for_gpu_uuid () {
    local algo=$1
    local gpu_uuid=$2
    local found
    local returnMessage="no"
    if [ ${#2} -eq 0 ]; then gpu_uuid='*'; fi
    if [ -n "${AlgoDisabled[${algo}]}" ]; then
        found=$(echo "${AlgoDisabled[${algo}]}" | grep -c ":${gpu_uuid//\*/\*}" )
        if [ $found -gt 0 ]; then
            returnMessage="yes"
        fi
    fi
    echo $returnMessage
}

# SYSTEM_STATE muss natürlich gesetzt sein.
# Und alle anderen Systemarrays ebenfalls, sonst sind wir total aufgeschmissen.
# Diese Funktion sollte nur nach einem frischen Aufbau aller Assoziativen Arrays gerufen werden.
#
_update_SYSTEM_STATEin_if_necessary () {
    # Im Moment keine Echo's, wenn mit Parameter gerufen...
    local verbose=$1

    echo '# Über diese Datei schalten wir GPUs MANUELL gezielt ein oder aus.'                   >${SYSTEM_STATE}.out
    echo '# 1 (== EIN == ENABLED)  ist der Default für jede GPU, die noch nicht erfasst war.'  >>${SYSTEM_STATE}.out
    echo '# 0 (== AUS == DISABLED) können wir manuell editieren und nach dem Abspeichern wird' >>${SYSTEM_STATE}.out
    echo '#                        diese Karte dann abgestellt, falls sie noch laufen sollte,' >>${SYSTEM_STATE}.out
    echo '#                        wird nicht mehr in den Berechnungen berücksichtigt'         >>${SYSTEM_STATE}.out
    echo '#                        und wird als GloballyDisabled geführt...'                   >>${SYSTEM_STATE}.out
    echo '# ... bis sie MANUELL wieder auf 1 (== EIN == ENABLED) gesetzt wird.\n'              >>${SYSTEM_STATE}.out
    echo ''                                                                                    >>${SYSTEM_STATE}.out
    echo 'UUID : GrakaName : 1/0 (Enabled/Disabled)'                                           >>${SYSTEM_STATE}.out
    echo '========================================='                                           >>${SYSTEM_STATE}.out

    if [ ${#verbose} -gt 0 ]; then
        echo "Diese GPU's gibt es:"
    fi
    for ((i=0; $i<${#index[@]}; i+=1)) ; do
        if [ ${#verbose} -gt 0 ]; then
            echo "GPU #${index[$i]} ist ${name[${index[$i]}]} auf port ${bus[${index[$i]}]}"
            echo "       und hat die UUID ${uuid[${index[$i]}]} und ist zu ${auslastung[${index[$i]}]} % ausgelastet"
        fi

        # Mehr GPUs muss es auch in der ${SYSTEM_STATE}.out Datei nicht geben.
        # Wir geben sie hier mit eingelesenem oder Default-Status aus...
        enabledState=1
        if [ -n "${uuidEnabledSOLL[${uuid[${index[$i]}]}]}" ]; then
            enabledState=${uuidEnabledSOLL[${uuid[${index[$i]}]}]}
        fi
        echo "${uuid[${index[$i]}]}:${name[${index[$i]}]}:${enabledState}"                    >>${SYSTEM_STATE}.out
    done

    # Wir pflegen AlgoDisabled hier drin MANUELL und deshalb
    # müssen wir diejenigen auch wieder mit ausgeben, die wir eingelesen haben.
    # Bei jeder Neuerzeugung der Datei SYSTEM_STATE müssen die hinten angehängt werden.
    echo ''                                                                                    >>${SYSTEM_STATE}.out
    echo '# Algorithmen können hier MANUELL ausgeschaltet werden, was gefährlich sein kann,' >>${SYSTEM_STATE}.out
    echo '#    wenn man vergisst, dass man sie hier ausgeschaltet hat!'                      >>${SYSTEM_STATE}.out
    echo '# Für jeden disabled Algorithmus gibt es NUR 1 ZEILE!'                             >>${SYSTEM_STATE}.out
    echo '# Die einzelnen FELDER sind durch DOPPELPUNKTE getrennt.'                          >>${SYSTEM_STATE}.out
    echo '# Das 1. Feld MUSS IMMER lauten: "AlgoDisabled" (ohne Anführungsstriche)'          >>${SYSTEM_STATE}.out
    echo '# Das 2. Feld MUSS IMMER der ALGONAME sein.'                                       >>${SYSTEM_STATE}.out
    echo '# Dann folgen die GPU-UUIDs und/oder "*" (ohne Anführungsstriche) für ALLE'        >>${SYSTEM_STATE}.out
    echo '# Der "*" kann auch zusammen mit GPUs gelistet sein.'                              >>${SYSTEM_STATE}.out
    echo '# Der "*" kommt ins Spiel, wenn ein Algorithmus generell nicht abgeliefert werden kann'>>${SYSTEM_STATE}.out
    echo '# Er sollte hier also nur drin sein, wenn man ihn generell nicht mehr minen möchte'>>${SYSTEM_STATE}.out
    echo '# Ein Beispiel:'                                                                   >>${SYSTEM_STATE}.out
    echo '# AlgoDisabled:scrypt:GPU-84f7ca95-d215-185d-7b27-a7f017e776fb'                    >>${SYSTEM_STATE}.out
    echo ''                                                                                    >>${SYSTEM_STATE}.out
    echo '"AlgoDisabled" : AlgoName : * oder GPU-UUID : * oder GPU-UUID : * oder GPU-UUID'   >>${SYSTEM_STATE}.out
    echo '============================================================================='     >>${SYSTEM_STATE}.out
    for algoName in ${!AlgoDisabled[@]}; do
        echo "${AlgoDisabled[$algoName]}"                                                    >>${SYSTEM_STATE}.out
    done

    # Sollten die Dateien ${SYSTEM_STATE}.out und ${SYSTEM_STATE}.in sich jetzt unterscheiden,
    # DANN HAT ES TATSÄCHLICH EINE ÄNDERUNG IM SYSTEM GEGEBEN.
    # Entweder durch Einbau, Ausbau, oder Wechsel von Karten nach einem Shutdown oder durch Abschmieren
    # einer GPU und Ausfall während der Runtime.
    # Nur dann ist .out tatsächlich die aktuellere Datei und muss .in überschreiben.
    # Ansonsten unterscheiden sie sich ja nicht und wir können uns das Schreiben sparen.
    # Zu Diagnose-Zwecken haben wir eine .BAK Kopie von der .in gemacht.

    diff -q ${SYSTEM_STATE}.out ${SYSTEM_STATE}.in &>/dev/null \
        || cp -f ${SYSTEM_STATE}.out ${SYSTEM_STATE}.in
    rm -f ${SYSTEM_STATE}.out
}

_read_in_SYSTEM_FILE_and_SYSTEM_STATEin () {
    readarray -n 0 -O 0 -t READARR <${SYSTEM_FILE}

    # Die Daten der GPUs in Arrays einlesen, die durch den GPU-Grafikkarten-Index indexiert werden können
    unset index;      declare -ag index
    unset name;       declare -ag name
    unset bus;        declare -ag bus
    unset uuid;       declare -ag uuid
    unset auslastung; declare -ag auslastung
    for ((i=0; $i<${#READARR[@]}; i+=5)) ; do
        j=$(expr $i / 5)
        index[$j]=${READARR[$i]}        # index[] = Grafikkarten-Index für miner
        name[${index[$j]}]=${READARR[$i+1]}
        bus[${index[$j]}]=${READARR[$i+2]}
        uuid[${index[$j]}]=${READARR[$i+3]}
        auslastung[${index[$j]}]=${READARR[$i+4]}
        # EXTREM WICHTIGE Deklarationen!
        # Seitdem dieser Teil am Anfang einer Endlosschleife enthalten ist, müssen wir die Arrays erst mal löschen!
        declare -n deleteIt="GPU${index[$j]}Algos";     unset deleteIt
        declare -n deleteIt="GPU${index[$j]}Watts";     unset deleteIt
        declare -n deleteIt="GPU${index[$j]}Mines";     unset deleteIt
        declare -ag "GPU${index[$j]}Algos"
        declare -ag "GPU${index[$j]}Watts"
        declare -ag "GPU${index[$j]}Mines"
    done

    # Die folgende Datei GLOBAL_GPU_SYSTEM_STATE.in (${SYSTEM_STATE}.in) bearbeiten wir manuell.
    # Sie wird, wenn nicht vorhanden vom Skript erstellt, damit wir die UUID's und Namen haben.
    # Und wenn sie vorhanden ist, merken wir uns die manuell gesetzten Enabled-Zustände,
    #     BEVOR wir die Datei neu schreiben.
    # Warum muss sie neu geschrieben werden?
    #     Weil möglicherweise in der Zwischenzeit Karten ein- oder ausgebaut wurden,
    #     die dazugenommen werden müssen mit einem Default-Wert ENABLED
    #     oder ganz rausfliegen können, weil sie eh nicht mehr im System sind
    # Eventuell können wir hier auch die temporär disabelten Algos (automatisch?) eintragen lassen
    #     und durchschleifen. DARUM KÜMMERN WIR UNS ABER, WENN ES SOWEIT IST.
    #     (Hier ist erst mal nur das Einlesen mitgemacht, weil der Code schon im multi_mining_calc.sh so drin war.)
    unset SYSTEM_STATE_CONTENT
    unset uuidEnabledSOLL;  declare -Ag uuidEnabledSOLL
    unset AlgoDisabled;     declare -Ag AlgoDisabled
    unset NumEnabledGPUs;   declare -ig NumEnabledGPUs
    if [ -s ${SYSTEM_STATE}.in ]; then
        cp -f ${SYSTEM_STATE}.in ${SYSTEM_STATE}.BAK
        shopt_cmd_before=$(shopt -p lastpipe)
        shopt -s lastpipe
        cat ${SYSTEM_STATE}.in               \
            | grep -v "^#"                   \
            | grep -e "^GPU-\|^AlgoDisabled" \
            | readarray -n 0 -O 0 -t SYSTEM_STATE_CONTENT

        for (( i=0; $i<${#SYSTEM_STATE_CONTENT[@]}; i++ )); do
            if [ "${SYSTEM_STATE_CONTENT[$i]:0:4}" == "GPU-" ]; then
                echo ${SYSTEM_STATE_CONTENT[$i]} \
                    | cut -d':' --output-delimiter=' ' -f1,3 \
                    | read UUID GenerallyEnabled
                declare -ig uuidEnabledSOLL[${UUID}]=${GenerallyEnabled}
                NumEnabledGPUs+=${GenerallyEnabled}
            elif [ "${SYSTEM_STATE_CONTENT[$i]:0:12}" == "AlgoDisabled" ]; then
                unset AlgoName
                read -a AlgoName <<<"${SYSTEM_STATE_CONTENT[$i]//:/ }"
                if [ ${#AlgoName[@]} -eq 2 ] && [ "${AlgoName[0]}" == "AlgoDisabled" ]; then
                    # Bestimmt den * vergessen oder nicht mal ein echter Algoname?
                    AlgoDisabled[${AlgoName[1]}]="AlgoDisabled:${AlgoName[1]}:*"
                else
                    AlgoDisabled[${AlgoName[1]}]="${SYSTEM_STATE_CONTENT[$i]}"
                fi
            fi
        done
        ${shopt_cmd_before}
    fi
}

