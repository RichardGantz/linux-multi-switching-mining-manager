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

GRID[0]="netz"
GRID[1]="solar"
GRID[2]="solar_akku"

###############################################################################
#
# WELCHE ALGOS DA
#
# Abfrage welche Algorithmen gibt es  ... muss nur selten abgefragt werden ggf. 
# einmal die stunde vielleicht
#
# Wir brauchen: "name", "speed_text" und "algo"
#"down_step":"-0.0001","min_diff_working":"0.1","min_limit":"0.2","speed_text":"GH","min_diff_initial":"0.04","name":"Skunk","algo":29,"multi":"1"
#
#
SYNCFILE="you_can_read_now.sync"

function _On_Exit () {
    # Wir könnten auch alle GPUs stoppen...
    rm -f ${ALGO_NAMES_ARR} ${algoID_KURSE_ARR} BTC_EUR_kurs.in kWh_*_Kosten_BTC.in ${SYNCFILE} $(basename $0 .sh).pid
}
trap _On_Exit EXIT

ALGO_NAMES_WEB="ALGO_NAMES.json"
ALGO_NAMES_ARR="ALGO_NAMES.in"

_notify_about_NO_VALID_ALGO_NAMES_kMGTP_JSON()
{
    # $1 = Webdateiname, z.B. ${ALGO_NAMES_WEB}, ${algoID_KURSE_WEB}
    # $2 = Einlesedatei, z.B. ${ALGO_NAMES_ARR}, ${algoID_KURSE_ARR}
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
    #else
        # Damit wird nur bei jedem 2. Aufruf der Funktion ein notify-send gemacht
        # Geplant ist, dass das etwa jede Minute stattfindet (31s-Abfrage-Intervall*2)
        # Für den Sonderfall, dass noch nie eine Datei da war und beim Versuch des Abrufs
        #     ausgerechnet keine Daten kommen, weil die Seite spinnt,
        #     passiert das allerdings alle 2 Sekunden.
        #     Das ist aber nur beim Programmstart der Fall und sollte so gut wie nie vorkommen.
        #
        # Aber es gibt noch einen Falle, den wir bedenken müssen:
        # Wenn der stündliche Update der Datei fällig wird und es kommt nicht saus dem Web,
        #     dann ist diese Datei noch viel älter.
        # Aber halt: So oft wie die Kurse ändert diese Datei ja nicht ihren Inhalt.
        # Das heisst, dass ein einmaliger Hinweis eigentlich genug sein sollte.
        # Die Kurse kommen in diesem Fall ja auch nicht und die werden sowieso alle 31s abgerufen.
        #
        # ERGO: Wir switchen doch nicht auf 0, wodurch nur 1x eine Meldung abgesetzt wird.
        # NoAlgoNames_notified=0
    fi
}

_create_ALGOS_in()
{
    echo "------------------   Algonames/ID und Speed   ----------------------"
    # Neue Algos aus dem Netz
    # Gültiges Ergebnis .json File fängt so an:
    # {"result":{"algorithms":[
    # und muss genau 1 mal gefunden werden
    searchPattern='^[{]"result":[{]"algorithms":\['
    algoPageDown=$( curl "https://api.nicehash.com/api?method=buy.info" \
                          | tee $ALGO_NAMES_WEB \
                          | grep -c -e "$searchPattern" )

    if [[ "${algoPageDown}" != "1" ]]; then
        _notify_about_NO_VALID_ALGO_NAMES_kMGTP_JSON "${ALGO_NAMES_WEB}" "${ALGO_NAMES_ARR}" "$searchPattern"
    else
        echo "--------------------------------------------------------------------"
        # Fehler scheint behoben, Benachrichtigung wieder scharf machen
        unset NoAlgoNames_notified NoAlgoNames_recorded
        # Algoname:kMGTP-Faktor:Algo-ID Paare extrahieren nach ALGO_NAMES.in
        num_algos_with_name=$(expr $(gawk -e 'BEGIN { RS=":[\[]{|},{|}\],"; \
                   f["k"]=1; f["M"]=2; f["G"]=3; f["T"]=4; f["P"]=5 } \
             match( $0, /"name":"[[:alnum:]]*/ )\
                  { M=substr($0, RSTART, RLENGTH); print tolower( substr(M, index(M,":")+2 ) ) }  \
             match( $0, /"speed_text":"[[:alpha:]]*/ )\
                  { M=substr($0, RSTART, RLENGTH); print 1024 ** f[substr(M, index(M,":")+2, 1 )] }  \
             match( $0, /"algo":[0-9]*/ )\
                  { M=substr($0, RSTART, RLENGTH); print substr(M, index(M,":")+1 ) }' \
             $ALGO_NAMES_WEB 2>/dev/null \
           | tee $ALGO_NAMES_ARR \
           | wc -l ) / 3 )
        algo_names_arr_modified=$(date --utc --reference=$ALGO_NAMES_ARR +%s)
    fi
}

declare -i num_algos_with_name=0
declare -i algo_names_arr_modified=0
if [ -s ${ALGO_NAMES_ARR} ]; then
    num_algos_with_name=$(expr $(cat ${ALGO_NAMES_ARR} | wc -l ) / 3 )
    algo_names_arr_modified=$(date --utc --reference=${ALGO_NAMES_ARR} +%s)
fi
while [[ ${num_algos_with_name} -eq 0 ]]; do
    _create_ALGOS_in
    if [[ ${num_algos_with_name} -eq 0 ]]; then
        echo "Waiting for a valid File ${ALGO_NAMES_WEB}"
        sleep 1
    fi
done

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

###############################################################################
# 1. curl "https://api.nicehash.com/api?method=stats.global.current&location=0"
# 2. Die eine .json-Zeile bei "},{" in einzelne Zeilen aufspalten
# 3. Zuerst /"algo":[0-9*]/ suchen und alles nach dem ":" ausgeben
# 4. Dann   /
#    So sieht der Anfang der Datei aus, wenn RS angewendet wurde:
#{"result":{"stats"
#"profitability_above_ltc":"44.99","price":"0.0122","profitability_ltc":"0.0084","algo":0,"speed":"3913.40252248"
#"price":"0.2632","profitability_btc":"0.2279","profitability_above_btc":"15.48","algo":1,"speed":"58787556.32539999"
#...
#"price":"0.0124","algo":20,"speed":"3137.82488726","profitability_eth":"0.0072","profitability_above_eth":"71.20"
#
# 5. Ausgabe von ALGO-index und PREIS in Datei KURSE.in, die dann so aussieht:
#0
#0.0107
#1
#0.2821
#2
# ...
# ---
#28
#0.0724
#29
#0.0108
#
# 6. Einlesen der Datei KURSE.in in das Array READARR
# 7. READARR durchgehen und das assoziative Array KURSE aufbauen:
#    Der erste Wert [$i=0,2,4,6,etc.] ist der ALGO-index,
#        der als Index für Array ALGOs[] dient und den NAMEN auswirft.
#    Der NAME wiederum dient als Index für das Array KURSE[algoname],
#        der den PREIS aus der nächsten Zeile [$i+1 =1,3,5,7,etc.] aufnimmt.

algoID_KURSE_WEB="KURSE.json"
algoID_KURSE_ARR="KURSE.in"
while [ 1 -eq 1 ] ; do
    # Algos nur stündlich prüfen
    declare -i algo_age=$(expr $(date --utc +%s) - $algo_names_arr_modified )
    if [[ ${algo_age} -ge 3600 ]]; then
        echo "###---> Hourly Update of $ALGO_NAMES_ARR"
        _create_ALGOS_in
    fi
    
    # kurs abfrage btc als json datei
    #
    # ACHTUNG FEHLERQUELLE:
    #         Wenn VOR Ablauf des nächsten stündlichen Einlesens der ALGO-Namen ein neuer Algo
    #         hinzukommt, gibt es eine weitere ID und einen weiteren Algonamen,
    #         DIE IN DEN KURSEN BEREITS AUFTAUCHEN KÖNNTEN!!!
    #
    # Strenggenommen müssen wir also nach jedem Einlesen eines Kurses nachsehen, ob sich die IDs
    # irgendwie verändert haben oder wenigstens ob es mehr geworden sind !!!
    #
    # Folgendes ist heute passiert, was in eine Endlosschleife an Einlesevorgängen gemündet ist:
    # "Web frontend is currently down for maintenance.
    #  We expect to be back in a couple minutes. Thanks for your patience.
    #  Stratum servers should be running as usual."

    echo "------------------   Nicehash-Kurse           ----------------------"
    # Neue Kurse aus dem Netz
    # Gültiges Ergebnis .json File fängt so an:
    # {"result":{"stats":[
    # {"result":{"simplemultialgo":[
    # und muss genau 1 mal gefunden werden
    # searchPattern='^[{]"result":[{]"stats":\['
    # pageDown=$( curl "https://api.nicehash.com/api?method=stats.global.current&location=0" \
    searchPattern='^[{]"result":[{]"simplemultialgo":\['
    pageDown=$(curl "https://api.nicehash.com/api?method=simplemultialgo.info" \
        | tee $algoID_KURSE_WEB \
        | grep -c -e "$searchPattern" )

    if [[ "${pageDown}" != "1" ]]; then
        _notify_about_NO_VALID_ALGO_NAMES_kMGTP_JSON "${algoID_KURSE_WEB}" "${algoID_KURSE_ARR}" "$searchPattern"
    else
        echo "--------------------------------------------------------------------"
        unset NoAlgoNames_notified NoAlgoNames_recorded

        #num_algos_with_price=$(expr $(gawk -e 'BEGIN { RS="},{|:[\[]{" } \
        #     /"algo":[0-9]*/ && /"price":"[0-9.]*"/ { \
        #         if (match( $0, /"algo":[0-9]*/     )) \
        #            { M=substr($0, RSTART, RLENGTH);   print substr(M, index(M,":")+1 ) }  \
        #         if (match( $0, /"price":"[0-9.]*"/ )) \
        #            { M=substr($0, RSTART, RLENGTH-1); print substr(M, index(M,":")+2 ) } }'  \
        #      $algoID_KURSE_WEB 2>/dev/null \
        #    | tee $algoID_KURSE_ARR \
        #    | wc -l ) / 2 )
        num_algos_with_price=$(expr $(gawk -e 'BEGIN { RS=":[\[]{|},{|}\],"} \
            match( $0, /"algo":[[:digit:]]*/ )\
                 { M=substr($0, RSTART, RLENGTH); print substr(M, index(M,":")+1 ) } \
            match( $0, /"paying":"[.[:digit:]]*/ )\
                 { M=substr($0, RSTART, RLENGTH); print tolower( substr(M, index(M,":")+2 ) ) }'  \
              $algoID_KURSE_WEB 2>/dev/null \
            | tee $algoID_KURSE_ARR \
            | wc -l ) / 2 )
        if [[ ! $num_algos_with_price == $num_algos_with_name ]]; then
            notify-send "###---> MAYBE A NEW ALGORITHM DETECTED !!! <---###"
            echo "###---> MAYBE A NEW ALGORITHM DETECTED !!! <---###"
            echo "###---> FORCED Update of $ALGO_NAMES_ARR   <---###"
            _create_ALGOS_in
            continue
        fi
    fi
    
##############################################
##############################################

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

    # Das ist ein zu grosser Sicherheitspuffer.
    # Die Berechnungen müssen losgehen, nachdem alle GPUs ihre best-Werte ermittelt haben!
    # multi_mining_calc.sh wartet nach der Berechnung des aktuellen SolarWattAvailable darauf,
    # dass alle ENABLED GPUs ihre Dateien ALGO_WATTS_MINES.in geschrieben haben.
    # Erstaunlicherweise kommt es oft vor, dass das manche noch in der selben Sekunde machen,
    # in der auch $SYNCFILE getouched wurde.
    # (29.10.2017)
    # Hier rausgenommen, weil multi_mining_calc.sh so umgeschrieben wurde,
    #      dass sie die ganze Kontrolle übernimmt und alles ordnungsgemäß
    #      startet und beendet.
    #./multi_mining_calc.sh &

    sleep 31
done
