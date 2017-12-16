#!/bin/bash
###############################################################################
#
# Diese Datei ist der eigentliche Herzschlag des gesamten Organismus, nach dem
# jeweils neue Entscheidungen zu berechnen und zu treffen sind.
# 
# Alle 31s werden aktuellste Daten aus dem Netz bezogen und so aufbereitet, dass
# alle Beteiligten neue Berechnungen anstellen können, ja MÜSSEN!
# Nachdem SYNCFILE=you_can_read_now.sync touched wurde steht fest:
# Diese Daten sind für die nächsten 30s FIXIERT und UNVERÄNDERBAR:
#    ALGO_NAMES.in    (ändert sich nicht so oft und wird daher nur beim Start und
#                      danach etwa jede Stunde erstellt.
#                      Allerdings wäre zu überlegen, ob man nicht doch auch jedes mal
#                      diese Daten einliest, um neue Algorithmen NICHT ZU VERPASSEN ??)
#    KURSE.in
#    BTC_EUR_kurs.in
#
###############################################################################

# GLOBALE VARIABLEN, nützliche Funktionen
[[ ${#_GLOBALS_INCLUDED} -eq 0 ]] && source globals.inc

# Aktuelle PID der 'algo_multi_abfrage.sh' ENDLOSSCHLEIFE
echo $$ >$(basename $0 .sh).pid

###############################################################################
#
# Kandidaten für GLOBALE STATISCHE VARIABLEN, die wir durch eine Installationsroutine
# in die Login-Shell-Umgebung bringen könnten oder in eine Shell, die diese
# exportiert und dann alle anderen Skripte aufruft und so sichergestellt ist,
# dass alle darauf Zugriff haben und sie nicht jedesmal selbst definieren müssen
#
###############################################################################

# Funktionen zum Abruf der KURSE/PORTS/AlgoNAmes/AlgoIDs aus dem Web incl. Aufbereiten der .in Datei
# und zum Einlesen aus der aufbereiteten .in Datei mittels readarray
[[ ${#_ALGOINFOS_INCLUDED} -eq 0 ]] && source ${LINUX_MULTI_MINING_ROOT}/algo_infos.inc

function _On_Exit () {
    # WhatToMine.* \
    rm -f ${algoID_KURSE_PORTS_WEB} ${algoID_KURSE_PORTS_ARR} BTC_EUR_kurs.in kWh_*_Kosten_BTC.in ${SYNCFILE} \
       KURSE.in ALGO_NAMES.json ALGO_NAMES.in \
       I_n_t_e_r_n_e_t__C_o_n_n_e_c_t_i_o_n__L_o_s_t \
       $(basename $0 .sh).pid
}
trap _On_Exit EXIT


_notify_about_NO_BTC_KURS()
{
    # Tja, was machen wir in dem Fall also?
    # Die Stratum-Server laufen und nehmen offensichtlich generierten Goldstaub entgegen.
    # Und die Karten, die wir vor 31s eingeschaltet haben, liefen ja mit Gewinn.
    # Wie lange kann man die Karten also mit den "alten" Preisen weiterlaufen lassen?
    # "A couple of Minutes..."
    # Wir setzen eine Desktopmeldung ab... jede Minute... und machen einen Eintrag
    #     in eine Datei FATAL_ERRORS.log, damit man nicht vergisst,
    #     sich langfristig um das Problem zu kümmern.
    if [[ ! "$ERROR_notified" == "1" ]]; then
        notify-send -t 10000 -u critical "### Es gibt zur Zeit keine Datei $1 aus dem Web ###" \
                 "Die Datei $2 bleibt unverändert oder ist nicht vorhanden. \
                 Entscheide bitte, wie lange Du die gerade laufenden Miner \
                 mit den immer mehr veraltenden Zahlpreisen laufen lassen möchtest!"
        if [[ ! "$ERROR_recorded" == "1" ]]; then
            echo $(date "+%F %H:%M:%S") "curl - BTC Kurs-Abfrage hatte anderen Inhalt als erwartet." >>FATAL_ERRORS.log
            echo "                    Hier: Down wegen Wartungsarbeiten" >>FATAL_ERRORS.log
            ERROR_recorded=1
        fi
        ERROR_notified=1
    else
        ERROR_notified=0
    fi
}

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
    echo "${detected} $msg1" | tee -a ${ERRLOG} >>.InternetConnectionLost.log
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
    printf "\n$(date \"+%F %H:%M:%S\") Internet Connection established\n" | tee -a ${ERRLOG} >>.InternetConnectionLost.log
    rm -f I_n_t_e_r_n_e_t__C_o_n_n_e_c_t_i_o_n__L_o_s_t
}

_check_InternetConnection
declare -i SECS=31 nowSecs
while :; do

    # Webabfrage für supernova
    #_prepare_COIN_PRICING_from_the_Web

    # Neue Algo Kurse aus dem Netz
    # Gültiges Ergebnis .json File fängt so an:
    # {"result":{"simplemultialgo":[
    # und muss genau 1 mal gefunden werden
    echo "------------------   Nicehash-Kurse           ----------------------"
    _prepare_ALGO_PORTS_KURSE_from_the_Web; RC=$?
    echo "--------------------------------------------------------------------"
    [[ $RC -ne 0 ]] && echo "$(basename $0): $(date "+%Y-%m-%d %H:%M:%S" ) $(date +%s) api-Abruf nicht erfolgreich." | tee -a ${ERRLOG}
    
    # abfrage des BTC-EUR Kurs von bitcoin.de (html)

    BTC_EUR_KURS_WEB="BTCEURkurs"

    echo "------------------   BTC-EUR-KURS-Abfrage     ----------------------"
    curl "https://www.bitcoin.de/de" -o ${BTC_EUR_KURS_WEB}
    #
    # Folgende <title> der Webseite kennen wir bisher:
    #
    # <title>bitcoin.de - Wartungsarbeiten/Maintenance</title>
    # <title>Bitcoins kaufen, Bitcoin Kurs bei Bitcoin.de!</title>
    #
    btcPageValid=$(cat ${BTC_EUR_KURS_WEB} \
        | grep -i -c -m 1 -e '<title>Bitcoins kaufen, Bitcoin Kurs bei Bitcoin.de!</title>' )
    echo "--------------------------------------------------------------------"      
        
    if [[ "${btcPageValid}" != "1" || ! -s ${BTC_EUR_KURS_WEB} ]]; then
        _notify_about_NO_BTC_KURS "${BTC_EUR_KURS_WEB}" "BTC_EUR_kurs.in"
        echo "###########################################################################"
        echo "------------> ACHTUNG: Nicht aktualisierter BTC Kurs: $(<BTC_EUR_kurs.in) <------------"
        echo "###########################################################################"
    else
        # Fehler scheint behoben, Benachrichtigung wieder scharf machen
        unset ERROR_notified ERROR_recorded

        #aussehen der html zeile -->
        #Aktueller Bitcoin Kurs: <img alt="EUR" class="ticker_arrow mbm3 g90" src="/images/s.gif" /> <strong \
        #  id="ticker_price">3.163,11 €</strong>

        # BTC Kurs extrahieren und umwandeln, dass dieser dann als Variable verwendbar und zum Rechnen geeignet ist
        btcEUR=$(gawk -e '/id="ticker_price">[0-9.,]* €</ \
                      { sub(/\./,"",$NF); sub(/,/,".",$NF); print $NF; exit }' \
                      ${BTC_EUR_KURS_WEB} \
               | grep -E -m 1 -o -e '[0-9.]*' \
               | tee BTC_EUR_kurs.in )

        # Einmal für alle gleich die fixen kWh-Preise in BTC umwandeln
        for ((grid=0; $grid<${#GRID[@]}; grid++)) ; do
            # Kosten in EUR
            kwh_EUR=$(< kwh_${GRID[$grid]}_kosten.in)
            # Kosten Umrechnung in BTC
            echo $(echo "scale=8; ${kwh_EUR}/${btcEUR}" | bc) >kWh_${GRID[$grid]}_Kosten_BTC.in
        done
    fi  ### if [[ ! "${btcPageValid}" == "1" ]]; then

    # Alle Daten stabil in den Dateien. Startschuss für die anderen Prozesse
    touch $SYNCFILE

##############################################
##############################################

    # Die Berechnungen müssen losgehen, nachdem alle GPUs ihre best-Werte ermittelt haben!
    # multi_mining_calc.sh wartet nach der Berechnung des aktuellen SolarWattAvailable darauf,
    # dass alle ENABLED GPUs ihre Dateien ALGO_WATTS_MINES.in geschrieben haben.
    # Erstaunlicherweise kommt es oft vor, dass das manche noch in der selben Sekunde machen,
    # in der auch $SYNCFILE getouched wurde.

    # Anstatt nur 31s lang zu schlafen, prüfen wir sekündlich ie Internetverbindung...
    # sleep 31
    SleepingStart=$(date --utc --reference=${SYNCFILE} +%s)

    while :; do
        _check_InternetConnection
        nowSecs=$(date +%s)
        [[ $(( ${nowSecs} - ${SleepingStart} )) -ge ${SECS} ]] && sleep 1 || break
    done
done
