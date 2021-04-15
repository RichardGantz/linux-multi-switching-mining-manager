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
- PHP5.6 (Bei Jessie scheinbar standardmäßig installiert)
- su -c "apt-get install libphp-jpgraph"
- [ su -c "apt-get install libphp-jpgraph-examples" ]
- GNU screen
- Miner "zm" wegen des Kommandos "zm --list-devices" (ist ansonsten veraltet und hat Probleme mit dem connect zu Nicehash)
- Miner:
  t-rex (ccminer)
  gminer

- Vor dem ersten Lauf des MM:
  $ su -
  # cd $LMMS_ROOT
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
