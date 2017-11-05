In diesem Verzeichnis sammeln wir die Informationen über die Miner.

Jede Miner Version ist hier vertreten mit einer Datei, in der all die Algos drin sind, die sie berechnen kann:
{miner_name}#{miner_version}.algos

Einfach in Form einer Liste, z.B. ein Auszug vom ccminer:
...
scrypt
sha256
scryptnf
x11
...

Bei Dual-Algo-fähigen Minern, die zwei Algos gleichzeitig berechnen können, beachten wir den folgenden Dateiaufbau:
...
daggerhashimoto                     <--- Wahrscheinlich sinnvoll, den Algo auch im "Alleingang" zu testen
daggerhashimoto:decred              <--- Die gleichzeitig laufenden Agos durch ":" getrennt
daggerhashimoto:lbry                <----|
daggerhashimoto:pascal              <----|
daggerhashimoto:sia                 <----|
...

Konvertierungstabellen von NiceHash Algonamen nach {miner_name} Algonamen werde in einer Datei mit folgendem Dateinamen gespeichert und können kommentare nach "#" enthalten:
NiceHash#{miner_name}.names

z.B. NiceHash#ccminer.names
...
# NH Algo Name  CCminer Algo Name
blake256r8      blakecoin
blake256r8vnl   vanilla
...

