#!/bin/bash
###############################################################################
#
# Diese Datei ist der eigentliche Herzschlag des gesamten Organismus, nach dem
# jeweils neue Entscheidungen zu berechnen und zu treffen sind.
# 
# Alle 31s werden aktuellste Daten aus dem Netz bezogen und so aufbereitet, dass
# alle Beteiligten neue Berechnungen anstellen können, ja MÜSSEN!
# Nachdem SYNCFILE=you_can_read_now.sync touched wurde steht fest:
# Diese Daten sind für mindestens ${SECS} (31s) FIXIERT und UNVERÄNDERBAR:
#    NH_PAYINGS.json  ${algoID_KURSE__PAY__WEB} Nicehash API-Abruf
#    NH_PAYINGS.in    ${algoID_KURSE_PORTS_PAY} Aufbereitet zum Einlesen in Arrays
#    NH_PORTS.json    ${algoID_KURSE_PORTS_WEB} Nicehash API-Abruf
#                     (ändert sich nicht so oft und wird daher nur beim Start und
#                      danach etwa jede Stunde erstellt.)
#    NH_PORTS.in      ${algoID_KURSE_PORTS_ARR} Aufbereitet zum Einlesen in Arrays
#    BTC_EUR_kurs.in
#
###############################################################################

# GLOBALE VARIABLEN, nützliche Funktionen
[[ ${#_GLOBALS_INCLUDED} -eq 0  ]]  && source globals.inc

# Funktionen zum Abruf der KURSE/PORTS/AlgoNAmes/AlgoIDs aus dem Web incl. Aufbereiten der .in Datei
# und zum Einlesen aus der aufbereiteten .in Datei mittels readarray
[[ ${#_ALGOINFOS_INCLUDED} -eq 0 ]] && source ${LINUX_MULTI_MINING_ROOT}/algo_infos.inc

debug=1

# Aktuelle PID der 'algo_multi_abfrage.sh' ENDLOSSCHLEIFE
This=$(basename $0 .sh)
echo $$ >${This}.pid

function _On_Exit () {
    # WhatToMine.* \
    [[ ${debug} -eq 0 ]] \
        && rm -f ${algoID_KURSE_PORTS_WEB} ${algoID_KURSE__PAY__WEB} ${algoID_KURSE_PORTS_ARR} ${algoID_KURSE_PORTS_PAY} ${BTC_EUR_KURS_WEB} \
	      BTC_EUR_kurs.in kWh_*_Kosten_BTC.in ${SYNCFILE} \
              ${COIN_PRICING_ARR} ${COIN_TO_BTC_EXCHANGE_ARR} \
              I_n_t_e_r_n_e_t__C_o_n_n_e_c_t_i_o_n__L_o_s_t \
              ${This}.err
    rm -f ${This}.pid
}
trap _On_Exit EXIT

[ -z "${ERRLOG}" ] && ERRLOG=${This}.err

_check_InternetConnection () {
    local detected=$(date "+%F %H:%M:%S")
    for ipaddr in ${InetPingStack[@]}; do
        ping -q -c 1 -W 1 $ipaddr &>/dev/null
        [[ $? -eq 0 ]] && return
    done
    # Solange diese Datei existiert, kann jeder wissen, dass die Internet-Verbindung unterbrochen ist.
    touch I_n_t_e_r_n_e_t__C_o_n_n_e_c_t_i_o_n__L_o_s_t
    msg1="### INTERNET CONNECTION LOST ###"
    msg2="Waiting for response from one of the 4 choosen IP-Addresses..."
    notify-send -u critical "$msg1" "$msg2"
    echo "${detected} $msg1" | tee -a ${ERRLOG} .InternetConnectionLost.log
    local -i secs=1
    while :; do
        echo "${msg2}, Ping-Cycle Nr. $secs"
        for ipaddr in ${InetPingStack[@]}; do
            printf "$ipaddr... "
            ping -c 1 -W 1 $ipaddr &>/dev/null
            [[ $? -eq 0 ]] && break 2
        done
        printf "\n"
        let secs++
    done
    detected=$(date "+%F %H:%M:%S")
    printf "${detected} Internet Connection established\n" | tee -a ${ERRLOG} .InternetConnectionLost.log
    rm -f I_n_t_e_r_n_e_t__C_o_n_n_e_c_t_i_o_n__L_o_s_t
}

_check_InternetConnection
declare -i SECS=31
while :; do

    # Wir warten mit dem Abruf, bis die Datei RUNNING_STATE 10s älter ist als SYNCFILE.
    # Nach dem SYNCFILE touch haben die GPU's losgelegt, ...
    #      der Multiminer hat auf deren Daten gewartet, ...
    #      der Multiminer hat die Effizienz-Berechnungen durchgeführt, ...
    read RunSecs  RunFrac <<<$(_get_file_modified_time_ ${RUNNING_STATE})
    if [[ ${RunSecs} > 0 ]]; then
        until (( ${RunSecs}  >= ${SleepingStart} )); do
            sleep 1
            _check_InternetConnection
            read RunSecs  RunFrac <<<$(_get_file_modified_time_ ${RUNNING_STATE})
        done
        # der Multiminer hat die neue RUNNING_STATE geschrieben. Jetzt nicht zu früh abrufen und Startschuss geben.
        # Die GPUs sollen erst mal Gelegenheit haben, die Miner zu stoppen und zu starten... (z.B. 5s)
        sleep ${RUN_SYNC_delay}
    fi

    if [ ${PoolActive["sn"]} -eq 1 ]; then
        echo "------------------   WhatToMine BLOCK_REWARD  ----------------------"
        _prepare_COIN_PRICING_from_the_Web; RC=$?
        echo "--------------------------------------------------------------------"
        [[ $RC -ne 0 ]] && echo "${This}.sh: $(date "+%Y-%m-%d %H:%M:%S" ) $(date +%s) BLOCK_REWARD Abruf nicht erfolgreich." | tee -a ${ERRLOG}

        echo "------------------   Bittrex COIN-BTC-Faktor  ----------------------"
        _prepare_COIN_TO_BTC_EXCHANGE_from_the_Web; RC=$?
        echo "--------------------------------------------------------------------"
        [[ $RC -ne 0 ]] && echo "${This}.sh: $(date "+%Y-%m-%d %H:%M:%S" ) $(date +%s) COIN-BTC-Faktor Abruf nicht erfolgreich." | tee -a ${ERRLOG}
    fi

    if [ ${PoolActive["nh"]} -eq 1 ]; then
        echo "------------------   Nicehash-Kurse           ----------------------"
        _prepare_ALGO_PORTS_KURSE_from_the_Web; RC=$?
        echo "--------------------------------------------------------------------"
        [[ $RC -ne 0 ]] && echo "${This}.sh: $(date "+%Y-%m-%d %H:%M:%S" ) $(date +%s) NiceHash api-Abruf nicht erfolgreich." | tee -a ${ERRLOG}
    fi
    
    echo "------------------   BTC-EUR-KURS-Abfrage     ----------------------"
    _prepare_Strompreise_in_BTC_from_the_Web; RC=$?
    echo "--------------------------------------------------------------------"      
    [[ $RC -ne 0 ]] && echo "${This}.sh: $(date "+%Y-%m-%d %H:%M:%S" ) $(date +%s) Strompreise in BTC Aktualisierung nicht erfolgreich." | tee -a ${ERRLOG}

    # Alle Daten stabil in den Dateien. Startschuss für die anderen Prozesse
    _reserve_and_lock_file ${SYNCFILE}
    touch ${SYNCFILE}
    _remove_lock

##############################################
##############################################

    # Die Berechnungen müssen losgehen, nachdem alle GPUs ihre best-Werte ermittelt haben!
    # multi_mining_calc.sh wartet nach der Berechnung des aktuellen SolarWattAvailable darauf,
    # dass alle ENABLED GPUs ihre Dateien ALGO_WATTS_MINES.in geschrieben haben.
    # Erstaunlicherweise kommt es oft vor, dass das manche noch in der selben Sekunde machen,
    # in der auch $SYNCFILE getouched wurde.

    # Anstatt nur 31s lang zu schlafen, prüfen wir sekündlich die Internetverbindung...
    # sleep 31
    SleepingStart=$(date --reference=${SYNCFILE} +%s)

    while :; do
        _check_InternetConnection
        (( $(date +%s) - ${SleepingStart} <= ${SECS} )) && sleep 1 || break
    done
done
