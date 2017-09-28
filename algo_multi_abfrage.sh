#!/bin/bash
###############################################################################
#
# Multi Abfrage der algos nicehash und bitcoin und starten der Solar"schleife"
# starten der Solar-AKKU-"schleife"
# 
#
#
#
#
#
###############################################################################

# Aktuelle PID der 'algo_multi_abfrage.sh' ENDLOSSCHLEIFE
echo $$ >algo_multi_abfrage.pid
###############################################################################
#
# START SOLAR SCHLEIFE
#
# solarschleife abgekoppelt da sie alle 10 sec abfragt ggf. auch 5 sekunden 
# abfrage möglich ggf. hier per eigener schleife einbauen mit counter und 
# sleep command ... oder halt extern
#
#

# solarschleife.sh

###############################################################################
#
# START SOLAR AKKU SCHLEIFE
#
# solarschleife abgekoppelt da sie alle 10 sec abfragt ggf. auch 5 sekunden 
# abfrage möglich ggf. hier per eigener schleife einbauen mit counter und 
# sleep command ... oder halt extern
#
#

# solar-akku-schleife.sh


###############################################################################
#
# WELCHE ALGOS DA
#
# Abfrag ewelche Algorithmen gibt es  ... muss nur selten abgefragt werden ggf. 
# einmal die stunde vielleicht
#
# Wir brauchen: "name", "speed_text" und "algo"
#"down_step":"-0.0001","min_diff_working":"0.1","min_limit":"0.2","speed_text":"GH","min_diff_initial":"0.04","name":"Skunk","algo":29,"multi":"1"
#
#
ALGO_NAMES="ALGO_NAMES.json"
#curl https://api.nicehash.com/api?method=buy.info -o $ALGO_NAMES

# KURSe extrahieren in ALGO_NAMES.in
gawk -e 'BEGIN { RS=":[\[]{|},{|}\],"; \
               f["k"]=1; f["M"]=2; f["G"]=3; f["T"]=4; f["P"]=5 } \
         match( $0, /"name":"[[:alnum:]]*/ )\
              { M=substr($0, RSTART, RLENGTH); print tolower( substr(M, index(M,":")+2 ) ) }  \
         match( $0, /"speed_text":"[[:alpha:]]*/ )\
              { M=substr($0, RSTART, RLENGTH); print 1024 ** f[substr(M, index(M,":")+2, 1 )] }  \
         match( $0, /"algo":[0-9]*/ )\
              { M=substr($0, RSTART, RLENGTH); print substr(M, index(M,":")+1 ) }' \
                 $ALGO_NAMES 2>/dev/null >ALGO_NAMES.in

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

ALGOFILE="KURSE.json"
while [ 1 -eq 1 ] ; do
    # kurs abfrage btc als json datei
    #curl https://api.nicehash.com/api?method=stats.global.current -o $ALGOFILE
    echo ---------------------Nicehash-Kurse---------------------------------
    curl "https://api.nicehash.com/api?method=stats.global.current&location=0" -o $ALGOFILE
    echo --------------------------------------------------------------------

    gawk -e 'BEGIN { RS="},{|:[\[]{" } \
         match( $0, /"algo":[0-9]*/ )\
              { M=substr($0, RSTART, RLENGTH);   print substr(M, index(M,":")+1 ) }  \
         match( $0, /"price":"[0-9.]*"/ )\
              { M=substr($0, RSTART, RLENGTH-1); print substr(M, index(M,":")+2 ) }'  \
                 $ALGOFILE 2>/dev/null >KURSE.in
    
##############################################
##############################################

    # abfrage des BTC-EUR Kurs von bitcoin.de (html)
    #aussehen der html zeile -->
    #Aktueller Bitcoin Kurs: <img alt="EUR" class="ticker_arrow mbm3 g90" src="/images/s.gif" /> <strong \
    #  id="ticker_price">3.163,11 €</strong>

    ALGOFILE_btcEUR="BTCEURkurs"
    #http abfrage
    echo -------------------------BTC-EUR-KURS-Abfrage-----------------------
    curl "https://www.bitcoin.de/de" -o $ALGOFILE_btcEUR
    echo --------------------------------------------------------------------        
        
    #BTC kurs extrahieren und umwandeln, das dieser dann als variable verwendbar und zum rechnen geeignet ist
    gawk -e '/id="ticker_price">[0-9.,]* €</ \
        { sub(/\./,"",$NF); sub(/,/,".",$NF); print $NF; exit }' $ALGOFILE_btcEUR \
    | grep -E -m 1 -o -e '[0-9.]*' \
	   > BTC_EUR_kurs.in
    echo BTC good >you_can_read_now.sync

##############################################
##############################################

    sleep 31s
done
