#!/bin/bash
###############################################################################
# 
# Hier sollen die Logdateien auf Fehler untersucht werden oder Merkmale,
# die besondere Aktionen auslösen sollen.
#

_LOGANALYSIS_INCLUDED=1

# Wir könnte zum Beispiel ein Array mit Logile-Meldungen pflegen,
# das uns sagt, das wir den Algo vorübergehend meiden sollten.
# Das könnte uns vielleicht auch dazu veranlassen, die "Country" zu wechseln ("eu" bzw. "us")

# Regexp Patterns, die den Abbruch oder das nicht Zustandekommen der Verbindung
# mit dem Server signalisieren und sofortige Aktion erfordern
#     (meist für grep, evtl. auch sed, wo manche Meta-Zeichen geschützt werden müssen)
NOT_CONNECTED_MSGs=(
    # "ccminer"
    # [2017-11-20 15:36:59] Starting on stratum+tcp://nist5.eu.nicehash.com:3340
    # [2017-11-20 15:36:59] retry after 30 seconds
    # [2017-11-20 15:36:59] NVML GPU monitoring enabled.
    # [2017-11-20 15:36:59] 4 miner threads started, using 'nist5' algorithm.
    'retry after 30 seconds$'
    # equihash "miner"
    'Lost connection with the server'
    # equihash "zm"
    '#  connection closed by server '
    '#  server not responding - retrying'
    'SSL_connect failed '
    # cryptonight "xmrMiner" (Windows-Name "xmr-stak")
    ' : SOCKET ERROR - '
)

OVERCLOCKING_MSGs=(
    # equihash "zm"
    #2018-01-18 21:50:05|gpu_id 0 76 3 the launch timed out and was terminated
    #2018-01-18 21:50:05|gpu 0 unresponsive - check overclocking
    #2018-01-18 21:50:05|cudaMemcpy 1 failed
    'gpu_id[ [:digit:]]*the launch timed out and was terminated'
    'gpu [[:digit:]]+ unresponsive - check overclocking'
)

# Regexp Patterns, die gezählt werden müssen und erst nach einer bestimmten Anzahl eine Aktion erfordern
# (meist für gawk)
# Hier: "ABGELEHNT" - Meldungen
NOT_ACCEPTED_MSGs=(
    # "ccminer"
    #2017-11-20 18:00:37] accepted: 0/1 (diff 9.171), 1608.05 MH/s (booooo)
    #[2017-11-20 18:00:37] reject reason: Invalid extranonce2 size.
    #[2017-11-20 18:00:39] GPU #0: Zotac GTX 980 Ti, 1576.93 MH/s
    #[2017-11-20 18:00:39] accepted: 0/2 (diff 46.701), 1597.67 MH/s (booooo)
    #[2017-11-20 18:00:39] reject reason: Invalid extranonce2 size.
    #"^.*accepted.*\(booooo\)$"
    'accepted.*[(]booooo[)]$'
    # equihash "miner"
    #INFO 16:09:23: GPU0 Rejected share 870ms [A:16576, R:41] <-- ist der not accept vom equihash
    'GPU[[:digit:]] Rejected share '
    # equihash "zm"
    '  GPU[[:digit:]]  rejected share: \\['
    # cryptonight "xmrMiner" (Windows-Name "xmr-stak")
    ' : Result rejected by the pool[.]$'
)

# Regexp Patterns, die gezählt werden müssen und erst nach einer bestimmten Anzahl eine Aktion erfordern
# (meist für gawk, daher kein Schützen verschiedener Meta-Zeichen nötig)
# Hier: "ANGENOMMEN" - Meldungen
YES_ACCEPTED_MSGs=(
    # "ccminer"
    #[2017-11-17 19:31:25] GPU #0: Zotac GTX 980 Ti, 6884.15 MH/s
    #[2017-11-17 19:31:27] accepted: 16/16 (diff 63.041), 6806.88 MH/s (yes!)
    #[2017-11-17 19:31:29] GPU #0: Zotac GTX 980 Ti, 6852.19 MH/s
    'accepted.*[(]yes![)]$'
    # equihash "miner"
    #INFO 19:41:25: GPU0 Accepted share 47ms [A:17909, R:41]
    #INFO 19:41:27: GPU0 Accepted share 50ms [A:17910, R:41]
    #INFO 19:41:35: GPU0 Accepted share 51ms [A:17911, R:41]
    'GPU[[:digit:]] Accepted share '
    # equihash "zm"
    ' [+*]+$'
    # cryptonight "xmrMiner" (Windows-Name "xmr-stak")
    ' : Result accepted by the pool[.]$'
)

# So kriegen wir alle Member eines Arrays in einen Regexp-String,
# der die einzelnen Strings mit OR verbindet und daher alle gleichzeitig abfrägt.
# Also können wir alle Reconnect- oder Not Connected Meldungen verschiedener Miner in einem Array stapeln
#      und die Logfiles damit abfragen und so wissen, dass der Miner zu killen und mit dem nächsten Server
#      zu testen ist.
# Und alle boooos-Meldungen können wir auch auf einen Stapel legen, wenn sie sich unterscheiden, denn die
#      Aktion, die bei einem Fund durchzuführen ist, ist bei allen die Gleiche:
#      Nach 10x Algo Disablen für 5 Minuetn oder so...

# Joining all Arraymembers by '|'...
OVREXPR=$(pos_join '|' "${OVERCLOCKING_MSGs[@]}")
CONEXPR=$(pos_join '|' "${NOT_CONNECTED_MSGs[@]}")
BOOEXPR=$(pos_join '|' "${NOT_ACCEPTED_MSGs[@]}")
YESEXPR=$(pos_join '|' "${YES_ACCEPTED_MSGs[@]}")

# ... then protecting the '|' by backslash befor giving to ...
#     GREP, maybe SED, but NOT gawk
#grep or sed ${CONEXPR//[|]/\\|}
#grep or sed ${BOOEXPR//[|]/\\|}
#grep or sed ${YESEXPR//[|]/\\|}

function _well_connected () {
    return $(grep -c -m1 -e "${CONEXPR//[|]/\\|}")
}

if [ 1 -eq 0 ]; then

function _detect_all () {
    rm -f ${algo}_retry
    boo_count=$(cat booos \
	| tee >(grep -c -m1 -e "${CONEXPR}" >${algo}_retry) \
	| gawk -v boo="${BOOEXPR}" -v yes="${YESEXPR}" -e '
            $0 ~ boo { boos = boos + 1; next }
            $0 ~ yes { boos = 0 }
            END { print boos }
        ')
    no_connection=$(< ${algo}_retry)
    echo "\$boo_count=$boo_count; \$no_connection=$no_connection"
}

    # Infos über die Algos abrufen zur Bildung der Server-Adressen
    algoID_KURSE_PORTS_WEB="KURSE.json"
    algoID_KURSE_PORTS_ARR="KURSE_PORTS.in"
    [[ ${#_ALGOINFOS_INCLUDED} -eq 0 ]] && source ${LINUX_MULTI_MINING_ROOT}/algo_infos.inc
    _prepare_ALGO_PORTS_KURSE_from_the_Web
    while [ $? -eq 1 ]; do
        declare -i secs=1
        echo "Keine Kurse, Sekunde Pause... $secs"
        sleep 1
        let secs++
        _prepare_ALGO_PORTS_KURSE_from_the_Web
    done
    _read_in_ALGO_PORTS_KURSE

    # Die folgende Schleife in eine Datei z.B. "ping_Runde.log" pipen und dann ...
    # ein paar Statistiken, die in der else-Klausel getestet wurden

    # Das war das Ergebnis vom Lauf am 21.11.2017 17:51 Uhr
    # eu:   31.4093ms
    # usa: 181.08ms    losses: 1x 100%, 1x 80%, 4x 40%, 4x 20% (5 pings are 100%)
    # br:  248.587ms
    # in:  283.094ms
    # jp:  284.958ms
    # hk:  290.249ms

    # Das wäre die zu bevorzugende Reihenfolge, wenn man die losses als ungünstigst ansieht.
    LOCATION=( "eu" "br" "in" "jp" "hk" "usa" )

    for continent in ${LOCATION[@]}; do
        for algo in ${ALGOs[@]}; do
            ping -c 5 ${algo}.${continent}.nicehash.com
        done
    done

#else
    # In Datei z.B. "ping_Runde.log" pipen und dann ein paar Statistiken:

    #Wo gingen ping Pakete verloren?
#    grep -e statistics -e '% packet loss,' ping_Runde.log \
#        | gawk -e '{server=$2; getline; if (length($6)>2) {print server; print}}'

    grep -e statistics -e '^rtt' ping_Runde.log \
        | gawk -e '
BEGIN {FS="[ /.]"}
/---/ {
  act_loc = $3
  if (act_loc != old_loc && length(old_loc) > 0) {
    avgs[old_loc]=sum/cnt
    locs[i++]=old_loc
    old_loc = act_loc
    cnt=0
    sum=0
  } else { old_loc = act_loc }
  getline
  sum=sum+("" $9 "." $10)
  cnt++
}
END{ avgs[old_loc]=sum/cnt
     locs[i]=old_loc
     print "Gesamtdurchschnitt pro Continent"
for (;i>=0;i--) {print locs[i] ": " avgs[locs[i]] "ms"} }'
fi

