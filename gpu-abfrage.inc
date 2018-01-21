#!/bin/bash
#
# Ein paar Funktionen und auch Überlegungen und Dokumentation zur GPU Systemabfrage und deren Abbild im Arbeitsspeicher
#

_GPU_ABFRAGE_INCLUDED=1

# SYSTEM_STATE muss natürlich gesetzt sein.
# Und alle anderen Systemarrays ebenfalls, sonst sind wir total aufgeschmissen.
# Diese Funktion sollte nur nach einem frischen Aufbau aller Assoziativen Arrays gerufen werden.
#
function _update_SYSTEM_STATEin_if_necessary () {
    # Im Moment keine Echo's, wenn mit Parameter gerufen...
    local verbose=$1
    local _WORKDIR_=$(pwd)
    cd ${LINUX_MULTI_MINING_ROOT}

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

    cd ${_WORKDIR_} >/dev/null
}

function _read_in_SYSTEM_FILE_and_SYSTEM_STATEin () {
    local UUID
    unset READARR
    readarray -n 0 -O 0 -t READARR <${SYSTEM_FILE}

    # Die Daten der GPUs in Arrays einlesen, die durch den GPU-Grafikkarten-Index indexiert werden können
    unset index;      declare -ag index       # gpu_row 0 or 1
    unset name;       declare -ag name        # gpu_row 1 or 2
    unset bus;        declare -ag bus         # gpu_row 2 or 3
    unset uuid;       declare -ag uuid        # gpu_row 3 or 4
    unset auslastung; declare -ag auslastung  # gpu_row 4 or 5
    unset defPowLim;  declare -ag defPowLim   # gpu_row 5 or 6

    unset GPU_idx;    declare -Ag GPU_idx
    # Diese Felder sind ziemlich wichtig, so dass wir deren Anzahl in globals.inc hinterlegen
    #declare -ig num_gpu_rows=6

    for ((i=0; $i<${#READARR[@]}; i+=num_gpu_rows)) ; do
        j=$(expr $i / ${num_gpu_rows})
        index[$j]=${READARR[$i]}        # index[] = Grafikkarten-Index für miner
        act_gpu_idx=${index[$j]}
        name[${act_gpu_idx}]=${READARR[$i+1]}
        bus[${act_gpu_idx}]=${READARR[$i+2]}
        UUID=${READARR[$i+3]}
        uuid[${act_gpu_idx}]=${UUID}
        auslastung[${act_gpu_idx}]=${READARR[$i+4]}
        defPowLim[${act_gpu_idx}]=${READARR[$i+5]}

        GPU_idx[${UUID}]=${act_gpu_idx}
        # EXTREM WICHTIGE Deklarationen!
        # Seitdem dieser Teil am Anfang einer Endlosschleife enthalten ist, müssen wir die Arrays erst mal löschen!
        declare -n deleteIt="GPU${act_gpu_idx}Algos";     unset deleteIt
        declare -n deleteIt="GPU${act_gpu_idx}Watts";     unset deleteIt
        declare -n deleteIt="GPU${act_gpu_idx}Mines";     unset deleteIt
        declare -n deleteIt="GPU${act_gpu_idx}Profit";    unset deleteIt
        declare -n deleteIt="GPU${act_gpu_idx}WATTS";     unset deleteIt
        declare -n deleteIt="GPU${act_gpu_idx}MINES";     unset deleteIt
        declare -ag "GPU${act_gpu_idx}Algos"
        declare -ag "GPU${act_gpu_idx}Watts"
        declare -ag "GPU${act_gpu_idx}Mines"
        declare -ag "GPU${act_gpu_idx}Profit"
        declare -ag "GPU${act_gpu_idx}WATTS"
        declare -ag "GPU${act_gpu_idx}MINES"
    done

    # Die folgende Datei GLOBAL_GPU_SYSTEM_STATE.in (${SYSTEM_STATE}.in) bearbeiten wir manuell.
    # Sie wird, wenn nicht vorhanden vom Skript erstellt, damit wir die UUID's und Namen haben.
    # Und wenn sie vorhanden ist, merken wir uns die manuell gesetzten Enabled-Zustände,
    #     BEVOR wir die Datei neu schreiben.
    # Warum muss sie neu geschrieben werden?
    #     Weil möglicherweise in der Zwischenzeit Karten ein- oder ausgebaut wurden,
    #     die dazugenommen werden müssen mit einem Default-Wert ENABLED
    #     oder ganz rausfliegen können, weil sie eh nicht mehr im System sind
    unset SYSTEM_STATE_CONTENT
    unset uuidEnabledSOLL;  declare -Ag uuidEnabledSOLL
    unset NumEnabledGPUs;   declare -ig NumEnabledGPUs
    if [ -s ${SYSTEM_STATE}.in ]; then
        cp -f ${SYSTEM_STATE}.in ${SYSTEM_STATE}.BAK
        cat ${SYSTEM_STATE}.in               \
            | grep -v "^#"                   \
            | grep -e "^GPU-" \
            | readarray -n 0 -O 0 -t SYSTEM_STATE_CONTENT

        for (( i=0; $i<${#SYSTEM_STATE_CONTENT[@]}; i++ )); do
            if [ "${SYSTEM_STATE_CONTENT[$i]:0:4}" == "GPU-" ]; then
                echo ${SYSTEM_STATE_CONTENT[$i]} \
                    | cut -d':' --output-delimiter=' ' -f1,3 \
                    | read UUID GenerallyEnabled
                declare -ig uuidEnabledSOLL[${UUID}]=${GenerallyEnabled}
                NumEnabledGPUs+=${GenerallyEnabled}
            fi
        done
    fi
}

# Die folgenden beiden Funktionen können gerufen werden, um eine GPU in der Datei GLOBAL_GPU_SYSTEM_STATE.in
# disablen ode enablen zu können.
# Das kann von der gpu_gv-algo.sh genutzt werden, um ein automatisches Benchmarking einleiten zu können,
# indem die GPU als disabled eingetragen ist und damit nicht auf sie gewartet wird, bis sie rechenergebnisse abliefert.
# Der Multiminer wartet auf alle enabled GPU's, bis sie die Datei ALGO_WATTS_MINES.in geschrieben haben.
function _disable_GPU_UUID_GLOBALLY () {
    _reserve_and_lock_file ${SYSTEM_STATE}                   # Zum Lesen reservieren

    REGEXPAT='s/^\('${gpu_uuid}':.*\):[[:digit:]]$/\1:0/g'
    sed -i -e "${REGEXPAT}" ${SYSTEM_STATE}.in

    _remove_lock                                             # ... und wieder freigeben
}

function _enable_GPU_UUID_GLOBALLY () {
    _reserve_and_lock_file ${SYSTEM_STATE}                   # Zum Lesen reservieren

    REGEXPAT='s/^\('${gpu_uuid}':.*\):[[:digit:]]$/\1:1/g'
    sed -i -e "${REGEXPAT}" ${SYSTEM_STATE}.in

    _remove_lock                                             # ... und wieder freigeben
}

