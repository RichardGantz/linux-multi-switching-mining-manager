In diesem Verzeichnis sammeln wir die Informationen über die Miner.

Jede Miner Version ist hier vertreten mit einer Datei, in der all die Algos drin sind, die sie berechnen kann:
{miner_name}#{miner_version}.algos

Einfach in Form einer Liste, z.B. ein Auszug vom ccminer:

# suprnova COIN   MiningAlgo Name
# NiceHash ALGO   MiningAlgo Name
# More Products   MiningAlgo Name
...
lyra2re
whirlpoolx        whirlpool
qubit
quark
sha256            sha256d
...

Bei Dual-Algo-fähigen Minern, die zwei Algos gleichzeitig berechnen können, beachten wir den folgenden Dateiaufbau:
...
daggerhashimoto                     <--- Wahrscheinlich sinnvoll, den Algo auch im "Alleingang" zu testen
daggerhashimoto:decred              <--- Die gleichzeitig laufenden Agos durch ":" getrennt
daggerhashimoto:lbry                <----|
daggerhashimoto:pascal              <----|
daggerhashimoto:sia                 <----|
...

