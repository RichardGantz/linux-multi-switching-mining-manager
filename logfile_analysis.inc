#!/bin/bash
###############################################################################
# 
# Hier sollen die Logdateien auf Fehler untersucht werden oder Merkmale,
# die besondere Aktionen auslösen sollen.
#

_LOGANALYSIS_INCLUDED=1

prepare_hashes_for_bc='BEGIN {out="0"}
{ hash=NF-1; einheit=NF
  switch ($einheit) {
    case /^Sol\/s *$|^H\/s *$|^G\/s *$/: faktor=1      ; break
    case /^k/:                           faktor=kBase  ; break
    case /^M/:                           faktor=kBase^2; break
    case /^G/:                           faktor=kBase^3; break
    case /^T/:                           faktor=kBase^4; break
    case /^P/:                           faktor=kBase^5; break
  }
  out=out "+" $hash "*" faktor
}
END {print out}
'

# In dem ${BENCHLOGFILE} steht hinter den Hashwerten, auf die wir scharf sind, manchmal (bei gewissen miniern)
# noch etwas, das weg muss, damit der Hashwert (z.B.: 32.61) das vorletzte und die Einheit (z.B: MH/s) das letzte Feld in der Zeile sind.
# Der gawk wertet jeweils die letzten beiden Felder dieser zeile aus, deshalb muss vorher alles nach der Einheit entfernt werden.
# Beim "ccminer" ist das z.B. der String ' (yes!)', der entfernt werden muss.
# Und beim "t-rex" ist das der String ', 54ms ... GPU #0grep -Er --include=\*.{sh,inc} --exclude-dir="GPU-[^s]*" ', der entfernt werden muss.
sed_Cut_YESmsg_after_hashvalue='s/\s*[(]yes![)]$//g;s/, [[:digit:]]+.*GPU #[[:digit:]]+$//g;'
# Wir ändern da mal 1. die Reihenfolge, damit der t-rex als erstes abgefragt wid und
# 2. nach erfolgreicher Ersetzung suchen wir nicht mehr weiter.
sed_Cut_YESmsg_after_hashvalue='s/, [[:digit:]]+.*GPU #[[:digit:]]+$//g;t;s/\s*[(]yes![)]$//g;'
# Und weil wir auch keinen ccminer mehr verwenden, lassen wir auch das zweite Suchmuster weg.
sed_Cut_YESmsg_after_hashvalue='s/, [[:digit:]]+.*GPU #[[:digit:]]+$//g;'

######################################################################
# Für die bech_30s_2.sh und MinerShell.sh zum Zählen der hashCount's #
######################################################################
# Der Output des "zm" Equihash Miners sieht so aus:
#2017-11-28 17:20:15|>  GPU0  68C  Sol/s: 493.9  Sol/W: 1.87  Avg: 493.9  I/s: 267.3  Sh: 0.00   . .   
#2017-11-28 17:20:55|   GPU0  70C  Sol/s: 496.0  Sol/W: 1.86  Avg: 494.1  I/s: 265.3  Sh: 0.00   . .   
#2017-11-28 17:21:15|>  GPU0  69C  Sol/s: 497.5  Sol/W: 1.86  Avg: 495.0  I/s: 264.5  Sh: 0.75   1.00 52  +
#2017-11-28 17:21:35|   GPU0  69C  Sol/s: 498.9  Sol/W: 1.87  Avg: 495.8  I/s: 264.9  Sh: 1.19   1.00 53  +
#2017-11-28 17:21:55|   GPU0  69C  Sol/s: 496.7  Sol/W: 1.87  Avg: 495.9  I/s: 264.4  Sh: 1.49   1.00 49  +
#
#$1         $2          $3    $4   $5     $6     $7     $8    $9   $10    $11  $12    $13 $14    $15  $16 $NF
#
# Und dieser Filter macht aus den o.g. Zeilen die folgenden:
# Das Feld Nr. 10 (hash) ist der "Avg:"-Wert
#493.9 Sol/s
#494.1 Sol/s
#495.0 Sol/s
#495.8 Sol/s
#495.9 Sol/s
#
detect_zm_hash_count='BEGIN { hash=10 }
/GPU[[:digit:]] +[[:digit:]]+C +Sol\/s: [[:digit:].]+ +Sol\/W: [[:digit:].]+ +Avg: [[:digit:].]+ +I\/s: [[:digit:].]+ +Sh: [[:digit:].]+/ \
    { print $hash " Sol/s"; next }
{ print }
'
# 2021-04-21: zm haben wir im Moment nicht mehr, deshalb nur mal der
# gminer 2.51 - Output:
#
# '16:03:20 New Job: 00000000c62d6c0a Epoch: #407 Diff: 858.22M
# '+---+-------+----+---+-----------+------+----+---+-----+-----------+
# '| ID   GPU   Temp Fan    Speed    Shares Core Mem Power Efficiency |
# '+---+-------+----+---+-----------+------+----+---+-----+-----------+
# '|  1 Unknown  N/A 0 %  22.07 MH/s  0/0/0    0   0   N/A        N/A |
# '+---+-------+----+---+-----------+------+----+---+-----+-----------+
# '16:03:20 Pool: daggerhashimoto.eu-west.nicehash.com:3353 Shares/Minute: 0.00
# '16:03:20 Uptime: 0d 00:00:30
# '16:03:23 New Job: 00000000c62d6c0b Epoch: #407 Diff: 858.22M
# '16:03:24 GPU1: Share #1 verified on CPU, difficulty: 3.00G
# '16:03:24 GPU1: Share #1 accepted 37 ms
detect_zm_hash_count='BEGIN { hash=7; speed=-1; einheit=""; unknownCnt=0; FirstSpeed=-1; FirstEinheit="" }
/^\|[ ]+[[:digit:]]+[ ]+[[:alnum:]]+[ ]+[^%]+%[ ]+[[:digit:].]+[ ]+[^|]+\|$/ \
    { speed=$hash; einheit=$(hash+1); next; }
/ GPU[[:digit:]]+: Share #[[:digit:]]+ accepted [[:digit:]]+ .s$/ \
    {   if ( speed < 0 ) {
	    unknownCnt++
	} else {
	    if ( FirstSpeed < 0 ) { FirstSpeed = speed; FirstEinheit = einheit }
            print speed " " einheit;
	}
	next;
    }
{ print; }
END { for ( i=unknownCnt; i>0; i--) { print FirstSpeed " " FirstEinheit; } }
'

# miniZ outputs
# Jetzt gibt es ganz neue Bedingungen: Die Shares werden nicht mehr Einzeln ausgegeben, sondern ein "*" und die Gesamtanzahl
#
# ethash / kawpow:
# [WARNING] Bad share: Share above target.
# [ 0d 0h 0m40s] S:  3/0/1 0>RTX 3070  100% [0.C/ 0%]* 52.62(52.62)MH/s   0(  0.0)W clk=1815MHz mclk=7001MHz MH/W=inf
#
# zhash / beamhash / (equihash):
# [ 0d 0h 1m00s] S:  4/0/0 0>RTX 3070  100% [0.C/ 0%]*61.51 I/s 126.39(126.39)Sol/s   0(  0.0)W clk=1815MHz mclk=7001MHz Sol/W=inf
# [ 0d 0h 1m10s] S:  5/0/0 0>RTX 3070  100% [0.C/ 0%]*61.49 I/s 125.40(125.40)Sol/s   0(  0.0)W clk=1815MHz mclk=7001MHz Sol/W=inf
#
# Fehlen noch:
# ERREXPR
# OVREXPR
# CONEXPR
#
detect_miniZ_hash_count='BEGIN { yeses=0; booos=0; seq_booos=0; last_shares=0 }
/[[]WARNING[]] (Bad|Stale) share:/ { booos++; seq_booos++; next }
match( $0, /S:.*[]][*].*(Sol|H)\/s/ ) {
   yeses++; seq_booos=0;
   S1 = substr( $0, RSTART+2, RLENGTH )
   SN = split( S1, SA )
   if (match( SA[ SN ], /\([[:digit:].]+\).*(Sol|H)\/s/ )) {
       M = substr( SA[ SN ], RSTART+1, RLENGTH );
       speed   = substr( M, 1, index(M,")")-1 )
       einheit = substr( SA[ SN ], index( SA[ SN ], ")" )+1 )
       shares  = substr( SA[ 1 ], 1, index(SA[ 1 ],"/")-1 )
       if (length(_BC_)) {
       	  delta = shares - last_shares
	  last_shares = shares
	  print delta "*" speed " " einheit
       } else if (length(EINHEIT)) {
       	      if (einheit ~ /H\/s\s*$/) {einheit = "H/s"; exit}
	      einheit = "Sol/s"
       	      exit
	 }
   }
}
END {
    if (length(BOOFILE)) print seq_booos " " booos " >" yeses >BOOFILE
    if (length(_BC_)==0) print shares " " speed " " einheit
}
'

# Wir könnte zum Beispiel ein Array mit Logile-Meldungen pflegen,
# das uns sagt, das wir den Algo vorübergehend meiden sollten.
# Das könnte uns vielleicht auch dazu veranlassen, die "Country" zu wechseln ("eu" bzw. "us")
# 2021-04-14:
# Miner startet erst gar nicht, weil Out of Memory
FATAL_ERROR_MSGs=(
    # gminer "miner":
    # '15:10:31 Failed to initialize miner on GPU0: NVIDIA Quadro RTX 4000 8GB [0000:01:00.0]: out of memory
    # '15:10:31 No devices for mining
    'Failed to initialize miner on GPU[[:xdigit:]]+:.*: out of memory$'
    ' No devices for mining'
    # '17:04:17 Connection Error: Malformed server message
    ' Connection Error: Malformed server message'
    # '17:04:59 Connection Error: End of file
    ' Connection Error: End of file'
    # '16:14:00 Error on GPU0: out of memory
    # '16:14:00 Stopped Mining on GPU0
    # '16:14:04 Miner terminated, watchdog will restart process after 10 seconds
    ' Error on GPU[[:xdigit:]]+: out of memory'
    ' Stopped Mining on GPU[[:xdigit:]]+'
)

# Regexp Patterns, die den Abbruch oder das nicht Zustandekommen der Verbindung
# mit dem Server signalisieren und sofortige Aktion erfordern
# SEHR GENAU AUSPASSEN MIT *, DA EIN STRING MITTELS printf DARAUS GEBILDET WIRD, DER DIE EINZELNEN zEILEN DURCH EIN '|' VERBINDET.
#      Unter Umständen (und das wurde mit 'echo' statt 'printf' erlebt) fügt .* den Dateiinhalt ein!!!
#   Wird im Moment nur von grep -E ${CONEXPR} verwendet
NOT_CONNECTED_MSGs=(
    # gminer "miner":
    'MUSS_ERST_NOCH_ERUIERT_WERDEN'

    # "t-rex":
    # URL : stratum+tcp://octopus.eu-west.nicehash.com:NotNeeded
    # USER: 12X6Enpg5FBQ332Re3vjU5FAxxQWUioBMg.01000bdf
    # PASS: x
    # 
    # Starting on: octopus.eu-west.nicehash.com:NotNeeded
    # ERROR: No connection, retry after 10 seconds
    # WARN: shutdown t-rex, signal [2] received
    # Main loop finished. Cleaning up resources...
    # WARN: GPU #2(000200): Zotac Graphics Device, intensity set to 22
    # T-Rex finished.
    #
    # "Wait on data is timed out, 300 seconds have passed, 0 bytes in socket remained
    # "WARN: Connection with pool timed out. Trying to reconnect..."
    #'Wait on data is timed out'
    ### 2021-04-14: MOMENTAN RAUSGENOMMEN,
    ### MUSS ERST NOCHMAL ÜBERDACHT WERDEN. ES SIND BEREITS 5 MINUTEN VERGANGEN
    ### UND DER RECONNECT HATTE IN DIESEM FALL GEKLAPPT.
    ### EIN ABBRUCH UND ANSCHLIESSENDER CONTINENT-WECHSEL WÄRE ALSO ÜBERFLÜSSIG GEWESEN
    ### 'WARN: [[:alpha:] ]*\. Trying to reconnect\.\.\.$'

    # "ccminer"
    # [2017-11-20 15:36:59] Starting on stratum+tcp://nist5.eu.nicehash.com:3340
    # [2017-11-20 15:36:59] retry after 30 seconds
    # [2017-11-20 15:36:59] NVML GPU monitoring enabled.
    # [2017-11-20 15:36:59] 4 miner threads started, using 'nist5' algorithm.
    ### 2021-04-13: MOMENTAN RAUSGENOMMEN, DA ccminer NICHT VERWENDET WIRD
    ### 'retry after 30 seconds$'

    # equihash "miner"
    ### 2021-04-13: MOMENTAN RAUSGENOMMEN, DA dieser "miner" NICHT VERWENDET WIRD
    ### 'Lost connection with the server'

    # equihash "zm"
    ### 2021-04-13: MOMENTAN RAUSGENOMMEN, DA zm NICHT VERWENDET WIRD
    ### '#  connection closed by server '
    ### '#  server not responding - retrying'
    ### 'stratum subscribe failed'
    ### 'connect failed'
    # 'SSL_connect failed '

    # cryptonight "xmrMiner" (Windows-Name "xmr-stak")
    ### 2021-04-13: MOMENTAN RAUSGENOMMEN, DA xmrMiner NICHT VERWENDET WIRD
    ### ' : SOCKET ERROR - '
)

# SEHR GENAU AUSPASSEN MIT *, DA EIN STRING MITTELS printf DARAUS GEBILDET WIRD, DER DIE EINZELNEN zEILEN DURCH EIN '|' VERBINDET.
#      Unter Umständen (und das wurde mit 'echo' statt 'printf' erlebt) fügt .* den Dateiinhalt ein!!!
#   Wird im Moment nur von grep -E ${OVREXPR} verwendet
OVERCLOCKING_MSGs=(
    # "t-rex":
    # ' WARN: NVML: can't get GPU #3, error code 15   <----  ACHTUNG: single-quote (') im Wort can't !!!!
    # ' WARN: GPU #3: Quadro RTX 4000 is idle, last activity was 32 secs ago'
    'WARN: GPU #[[:xdigit:]+:[[:alnum:] ]+, last activity was [[:digit:]]+ secs ago$'
    
    # equihash "zm"
    #2018-01-18 21:50:05|gpu_id 0 76 3 the launch timed out and was terminated
    #2018-01-18 21:50:05|gpu 0 unresponsive - check overclocking
    #2018-01-18 21:50:05|cudaMemcpy 1 failed
    ### 2021-04-13: MOMENTAN RAUSGENOMMEN, DA zm NICHT VERWENDET WIRD
    ### 'gpu_id[ [:xdigit:]]*the launch timed out and was terminated'
    ### 'gpu [[:xdigit:]]+ unresponsive - check overclocking'
)

# Regexp Patterns, die gezählt werden müssen und erst nach einer bestimmten Anzahl eine Aktion erfordern
# SEHR GENAU AUSPASSEN MIT *, DA EIN STRING MITTELS printf DARAUS GEBILDET WIRD, DER DIE EINZELNEN zEILEN DURCH EIN '|' VERBINDET.
#      Unter Umständen (und das wurde mit 'echo' statt 'printf' erlebt) fügt .* den Dateiinhalt ein!!!
# Wird im Moment nur von gawk ${BOOEXPR} verwendet
# Hier: "ABGELEHNT" - Meldungen
#
# ACHTUNG: Auf dem Weg zum gawk verschwinden zwei BACKSLASHES, weil der String durch zwei zusätzliche Funktionen läuft.
#          DAS BITTE IMMER BEDENKEN!
# Ein '\' geht bei der Zusammensetzung zum String {YES|NO}EXPR "verloren"
# Der nächste durch die Sub-Shell, die die Kommandozeile für den gawk aufbereitet.
NOT_ACCEPTED_MSGs=(
    # "miniZ":
    # '[WARNING] Bad share: Share above target.
    # 2021-05-06 - Wir bauen diese Abfragen ebenfalls in das awk-Script ein, das sowieso bemüht werden muss.
    #'[[]WARNING[]] Bad share: Share above target.'

    # gminer "miner":
    # '17:01:47 Started Mining on GPU1: ZOTAC Graphics Device 12GB [0000:02:00.0]
    # '17:02:04 GPU1: Share #1 rejected: Invalid solution size.
    # '17:02:07 GPU1: Share #2 rejected: Invalid solution size.
    ' GPU[[:xdigit:]]+: Share #[[:digit:]]+ rejected'

    # "t-rex":
    # " [FAIL] 13216/13229 - Job not found., 98ms ... GPU #0
    # '[FAIL] 16256/16273 - Share validation error., 5170ms ... GPU #4
    # '[FAIL] 15318/15331 - Share above target., 67ms ... GPU #4
    '^\\\s?[[]FAIL[]] [[:digit:]/ -]*(Job not found|Share validation error|Share above target)'

    # "ccminer"
    #2017-11-20 18:00:37] accepted: 0/1 (diff 9.171), 1608.05 MH/s (booooo)
    #[2017-11-20 18:00:37] reject reason: Invalid extranonce2 size.
    #[2017-11-20 18:00:39] GPU #0: Zotac GTX 980 Ti, 1576.93 MH/s
    #[2017-11-20 18:00:39] accepted: 0/2 (diff 46.701), 1597.67 MH/s (booooo)
    #[2017-11-20 18:00:39] reject reason: Invalid extranonce2 size.
    #"^.*accepted.*\(booooo\)$"
    ### 2021-04-13: MOMENTAN RAUSGENOMMEN, DA ccminer NICHT VERWENDET WIRD
    ### 'accepted.*[(]booooo[)]$'

    # equihash "miner"
    #INFO 16:09:23: GPU0 Rejected share 870ms [A:16576, R:41] <-- ist der not accept vom equihash
    ### 2021-04-13: MOMENTAN RAUSGENOMMEN, DA dieser "miner" NICHT VERWENDET WIRD
    ### 'GPU[[:xdigit:]] Rejected share '

    # equihash "zm"
    ### 2021-04-13: MOMENTAN RAUSGENOMMEN, DA zm NICHT VERWENDET WIRD
    ### '[ ][ ]GPU[[:xdigit:]][ ][ ]rejected share: [[]'

    # cryptonight "xmrMiner" (Windows-Name "xmr-stak")
    ### 2021-04-13: MOMENTAN RAUSGENOMMEN, DA xmrMiner NICHT VERWENDET WIRD
    ### ' : Result rejected by the pool[.]$'
)

# Regexp Patterns, die gezählt werden müssen und erst nach einer bestimmten Anzahl eine Aktion erfordern
# SEHR GENAU AUSPASSEN MIT *, DA EIN STRING MITTELS printf DARAUS GEBILDET WIRD, DER DIE EINZELNEN zEILEN DURCH EIN '|' VERBINDET.
#      Unter Umständen (und das wurde mit 'echo' statt 'printf' erlebt) fügt .* den Dateiinhalt ein!!!
# Wird im Moment von gawk ${YESEXPR} verwendet.
# und in 'estimate_yeses.sh' auch von grep, ALSO BITTE TESTEN und nach Erfolg diesen Kommentar zur Aufforderung des Testens entfernen.
# Hier: "ANGENOMMEN" - Meldungen
#
# ACHTUNG: Auf dem Weg zum gawk verschwinden zwei BACKSLASHES, weil der String durch zwei zusätzliche Funktionen läuft.
#          DAS BITTE IMMER BEDENKEN!
# Ein '\' geht bei der Zusammensetzung zum String {YES|NO}EXPR "verloren"
# Der nächste durch die Sub-Shell, die die Kommandozeile für den gawk aufbereitet.
YES_ACCEPTED_MSGs=(
    # "miniZ":
    # '[WARNING] Bad share: Share above target.
    # Jetzt gibt es ganz neue Bedingungen: Die Shares werden nicht mehr Einzeln ausgegeben, sondern ein "*" und die Gesamtanzahl
    # [ 0d 0h 0m40s] S:  3/0/0 0>RTX 3070  100% [0.C/ 0%]* 52.62(52.62)MH/s   0(  0.0)W clk=1815MHz mclk=7001MHz MH/W=inf
    # [ 0d 0h 1m10s] S:  5/0/0 0>RTX 3070  100% [0.C/ 0%]* 52.73(52.73)MH/s   0(  0.0)W clk=1815MHz mclk=7001MHz MH/W=inf
    # 2021-05-06 - Wir bauen diese Abfragen ebenfalls in das awk-Script ein, das sowieso bemüht werden muss.
    # '[]][*] ?[[:digit:].]+'

    # '+---+-------+----+---+-----------+------+----+---+-----+-----------+
    # '| ID   GPU   Temp Fan    Speed    Shares Core Mem Power Efficiency |
    # '+---+-------+----+---+-----------+------+----+---+-----+-----------+
    # '|  1 Unknown  N/A 0 %  22.05 MH/s 74/0/0    0   0   N/A        N/A |
    # '+---+-------+----+---+-----------+------+----+---+-----+-----------+
    # '16:17:20 Pool: daggerhashimoto.eu-west.nicehash.com:3353 Shares/Minute: 5.10
    # '16:17:20 Uptime: 0d 00:14:30
    # '16:17:23 GPU1: Share #75 verified on CPU, difficulty: 611.18M
    # '16:17:23 GPU1: Share #75 accepted 64 ms
    # '16:17:25 GPU1: Share #76 verified on CPU, difficulty: 674.62M
    # '16:17:25 GPU1: Share #76 accepted 61 ms
    ' GPU[[:digit:]]+: Share #[[:digit:]]+ accepted [[:digit:]]+ .s$'

    # "t-rex .12":
    # " [ OK ] 13216/13228 - 37.28 MH/s, 56ms ... GPU #0
    # " [FAIL] 13216/13229 - Job not found., 98ms ... GPU #0
    # " [ OK ] 13217/13230 - 37.28 MH/s, 54ms ... GPU #0
    # " [ OK ] 13218/13231 - 37.28 MH/s, 51ms ... GPU #0
    # "t-rex .14":
    #   octopus epoch: 21, block: 11505283, diff: 1.53 G
    #  "[ OK ] 1/1 - 39.45 MH/s, 63ms ... GPU #2
    #   WARN: ApiServer: failed to bind socket 127.0.0.1:4067 (Address already in use), next attempt in 5 seconds.
    #   octopus epoch: 21, block: 11505284, diff: 1.53 G
    '^\\\s?[[] OK []] [[:digit:]/ ]*- [[:digit:].]* '

    # "ccminer"
    #[2017-11-17 19:31:25] GPU #0: Zotac GTX 980 Ti, 6884.15 MH/s
    #[2017-11-17 19:31:27] accepted: 16/16 (diff 63.041), 6806.88 MH/s (yes!)
    #[2017-11-17 19:31:29] GPU #0: Zotac GTX 980 Ti, 6852.19 MH/s
    ### 2021-04-13: MOMENTAN RAUSGENOMMEN, DA ccminer NICHT VERWENDET WIRD
    ### 'accepted.*[(]yes![)]$'

    # equihash "miner"
    #INFO 19:41:25: GPU0 Accepted share 47ms [A:17909, R:41]
    #INFO 19:41:27: GPU0 Accepted share 50ms [A:17910, R:41]
    #INFO 19:41:35: GPU0 Accepted share 51ms [A:17911, R:41]
    ### 2021-04-13: MOMENTAN RAUSGENOMMEN, DA dieser "miner" NICHT VERWENDET WIRD
    ### 'GPU[[:xdigit:]]+ Accepted share [[:digit:]]+'

    # equihash "zm"
    ### 2021-04-13: MOMENTAN RAUSGENOMMEN, DA zm NICHT VERWENDET WIRD
    ### ' [+*]+$'

    # cryptonight "xmrMiner" (Windows-Name "xmr-stak")
    ### 2021-04-13: MOMENTAN RAUSGENOMMEN, DA xmrMiner NICHT VERWENDET WIRD
    ### ' : Result accepted by the pool[.]$'
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
ERREXPR=$(pos_join '|' "${FATAL_ERROR_MSGs[@]}")
OVREXPR=$(pos_join '|' "${OVERCLOCKING_MSGs[@]}")
CONEXPR=$(pos_join '|' "${NOT_CONNECTED_MSGs[@]}")
BOOEXPR=$(pos_join '|' "${NOT_ACCEPTED_MSGs[@]}")
YESEXPR=$(pos_join '|' "${YES_ACCEPTED_MSGs[@]}")

