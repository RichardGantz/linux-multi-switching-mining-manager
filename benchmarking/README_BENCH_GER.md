Beschreibung
------------
Das Benchmarking bzw. die Leistungsmessungen sind wie folgt aufgebaut.

Das Script hat verschiedene start Optionen

"./bench_30s_2.sh -h"

-w default is 30 seconds
	normal eingestellt sind 30 Sekunden zum Testen der verschiedenen Algos


-m default is 20 hashes
	die Messung brauch mindestens 30 hash werte
 

-t runs the script infinitely, ignores -w / -m, prepared for EFFICENCY tuning mode via tweak_commands.sh
	
	diese option ignoriert die standart optionen -w und -m und läuft durchgängig in einer schleife,
	damit per "twaek_commands.sh" feintuning gemacht werden kann. In der regel zum besten effiziens
	H/W Wert, welcher direkt nach jeder Änderung neu berechnet wird.


-p runs the script infinitely. ignores -w / -m, prepared for FULL POWER Mode via tweak_commands.sh
   If both -t and -p are present then only the last one comes into effect.
	
	Diese option ist wie die Option "-t" doch ist sie dazu da aus den Graffikkarten den MAX Hash Wert
	heraus zu kitzen, der Watt wert spielt in dieser option keine rolle mehr. (wird gesondert behandelt)


-d keeps temporary files for debugging purposes
	Diese Option dient dazu um später zu kontrolieren falls irgendwo ein fehler passiert damit man diesen 
	dann nachvollziehen kann .
