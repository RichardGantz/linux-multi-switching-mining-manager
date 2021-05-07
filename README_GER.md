Beschreibung
---------
Überblick des Projektes:
- Einbeziehung der Solar Energie
- Einbeziheung der Energiekosten Solarstrom(Einspeisevergütung), (Solar_Akku_Strom) und Netzstrom
- Berechnung der Energie Kosten der einzelnen Grafikkarten zu den jeweiligen möglichen Algorythmen
- Feststellung der Leistung der Graffikkarten normal-,unter- und übertaktet und dazugehörigen Verbrauch zu jedem Algorythmus
- Berechnung des Gewinns unter Einbeziehung sämtlicher faktoren und kombinationen
- Starten/Stoppen der Berechnung von Algorythmen je Graffikkarte einzelnd für sich


Nötige System Programme
---------
- Debian Jessie (oder gleichwertig)
- gawk
- Curl
- w3m
- Nvidia Cuda 8.0 Treiber
- su -c "apt_get update ; apt-get install libnotify-bin"
- ( su -c "apt-get install apt-transport-https" ... sollte vor einer PHP7.0 Installation gemacht werden ???)
- >= PHP5.6 (Bei Jessie scheinbar standardmäßig installiert), Voraussetzung für jpgraph
- jpgraph
  Und das funktioniert leider überhaupt nicht. Da kommen hoffnungslos veraltete Versionen runter, die NICHT zum Laufen zu bringen sind:
  $ su -c "apt-get install libphp-jpgraph"
  [$ su -c "apt-get install libphp-jpgraph-examples" ]
  Stattdessen ist folgendermaßen vorzugehen:
  1. Herunterladen der aktuellsten Version von der Seite https://jpgraph.net/download/, z.B. die Version 4.3.4 (2020-11-11), Dateiname jpgraph-4.3.4.tar.gz ins Verzeichnis ${DL}
  2. md5 Checksum prüfen: md5sum --tag ${DL}/jpgraph-4.3.4.tar.gz
  3. Entpacken          : tar xzf ${DL}/jpgraph-4.3.4.tar.gz ${DL}/jpgraph-4.3.4
  4. Eventuell in einen PHP Include-Path kopieren, meist gut ist "/usr/share/php/":
     sudo cp -r ${DL}/jpgraph-4.3.4 /usr/share/php/
  5. Auf jeden Fall in einem PHP Include-Path den folgenden Symbolischen Link erstellen,
     damit z.B. über den PHP-Befehl "include ("jpgraph/jpgraph.php");" oder "require_once" versionsunabhängig darauf zugegriffen werden kann:
     sudo ln -s /usr/share/php/jpgraph-4.3.4/src /usr/share/php/jpgraph
- GNU screen
- Miner "zm" wegen des Kommandos "zm --list-devices" (ist ansonsten veraltet und hat Probleme mit dem connect zu Nicehash)
- Miner:
  t-rex (ccminer)
  gminer

- Vor dem ersten Lauf des MM:
  (LMMS_SRC_ROOT und LMMS_RUN_ROOT können in der ~/.bashrc definiert werden für Entwicklungspfad respektive Produktionspfad)
  $ su -
  # cd ${LMMS_RUN_ROOT}
  # cp /usr/bin/nvidia-smi (Binary) benchmarking/nvidia-befehle/smi
  # cp /usr/bin/chrt .#rtprio#
  # cp /usr/bin/nice .#nice#
  # chmod 4755 benchmarking/nvidia-befehle/smi
  # chmod 4755 .#rtprio#
  # chmod 4755 .#nice#
  # exit

Handhabung der Sripte und Dateien
--------
Dataien:
- 1$ kwh_netz_kosten.in
- 2$ kwh_solar_kosten.in
- 3$ kwh_solar_akku_kosten.in
- 4$ GPU*/benchmark_*.json

Scripte:
- 1# algo_multi_abfrage.sh
        > ausgabe Dateien:
                BTC_EUR.in | KURSE.in | ALGO_NAMES.in | "you_can_read_now"
- 2# gpu-abfrage.sh
        > ausgabe Daten
                GPU Verzeichnisse | gpu_index.in
- 3# GPU*/gpu_gv-algo.sh
        < zu lesende Dateien
                von 1# BTC_EUR.in | KURSE.in | ALGO_NAMES.in | "you_can_read_now"
                von 1$,2$,3$
        > ausgabe Daten
                best_algo_netz.out | best_algo_solar.out | best_algo_solar_akku.out
- 4# multi_mining_calc.sh
        < liest Dateien aus GPU Verzeichnissen
                best_algo_netz.out | best_algo_solar.out | best_algo_solar_akku.out
        > ausgebende Dateien
                cfg_Netz_*(algo).txt | cfg_SOLAR_*(algo).txt | cfg_AKKU_*(algo).txt

Handhabung:

Script 1#
Hier werden die Algorythmen von NH heruntergeladen und dazu die Tages Preise ausgegeben. Darüber hinaus wird
der Bitcoin EUR kurs von Bitcoin.de extrahiert und ausgegeben. 

Script 2#
Hier werden die nvidia GPU's abgefragt und Verzeichnisse erstellt. Dazu werden eine lehre Datei 4$ und
das script 3# in das entsprechende GPU Verzeichniss kopiert.

Script 3#
Dieses horcht auf die Datei "you_can_read_now" so das diese erst danach die ausgabe Dateien von 1# einliest.
Dann liest sie die 4$ Datei ein und rechnet den gewinn oder verlust jedes algorythmuses aus anhand des
eigenen Watt verbrauchs und schreibt diese in 3 unterschiedliche Dateien in dieser steht der beste Algorythmus
zur jeweiligen verbrauchsumgebung drin.

Script 4#
Dies Script holt sämtliche best_algo*.out dateien aus den GPU Verzeichnissen und Sortiert diese welche GPU
die beste ist und stellt diese nach oben mit der "GPU_index NR" welche nicht im negativen bereich sind.
Alle welche im Negativen bereich sind fallen weg.

PAYINGS:
--------
Die Umrechnungsformel für die Bezahlung der minings lautet:

BenchmarkSpeed * payings(web) / 100 000 000 * FEES

ACHTUNG: Diese Zahl 100000000 haben wir aus dem SourceCode eines Windows-Miners:
https://github.com/nicehash/NiceHashMiner/blob/edc6a78141d896bd6296009b0ad426e27d0d6063/src/NHMCore/Mining/MiningDataStats.cs:

// update stat
            stat.PowerUsageAPI = (double)apiData.PowerUsageTotal / 1000d;
     foreach (var speedInfo in apiData.AlgorithmSpeedsTotal())
           {
           stat.Speeds.Add(speedInfo);
           if (payingRates.TryGetValue(speedInfo.type, out var paying) == false) continue;
           var payingRate = paying * speedInfo.speed * 0.000000001;
           stat.Rates.Add((speedInfo.type, payingRate));
    }

Der rechnet allerdings mit 9 Stellen, also mit 1 000 000 000 bzw. 0.000000001 !!!

Keiner weiß im Moment warum, aber mit 8 Stellen scheint alles zu passen.
Der Switcher verwendet allerdings auch NICHT dieselbe API, von der wir abrufen:

var response = await client.PostAsync("https://api2.nicehash.com/api/v2/organization/nhmqr", content);
var resp = await client.GetAsync("https://api2.nicehash.com/api/v2/organization/nhmqr/{_uuid}");

2021-05-03 - Tweaking-Werte mit dem Desktop-Tool erfolgreich abgesetzt.
die profi karte "quadro" konnte ich nicht über die gui tweaken .... Ram Mhz clock offset bei den 3070er ist auf 1400 und bei der 3060 bei 1000