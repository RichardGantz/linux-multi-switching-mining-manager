Hier sind die scripte und config dateien welche nur zur grafikkarte gehören enthalten, welche dann zu
den jeweiligen Grafikkarten angepasst werden müssen in ihren eigenen verzeichnissen.

Diese Dateien werden von dem script gpu-abfrage.sh aus dem root folder angefasst und dann zu den jeweiligen
gpu folder kopiert.

{
"Name": "neoscrypt",                # Der name des Algos (nur hier zur übersicht)
      "NiceHashID": 8,              # wird "noch" nicht verwendet bzw wird direkt aus der api.json datei von nicehash extrahiert
      "MinerBaseType": 2,           # wird "noch" nicht verwendet bzw überflüssig bisher
      "MinerName": "neoscrypt",     # Minername wird als "algo" variable bisher verwendet
      "BenchmarkSpeed": 896513.0,   # Der Benchmark wwert wird in H/s oder Sol/s angegeben (MH,KH,TH,PH umrechungen findet später statt)
      "ExtraLaunchParameters": "",  # wird demnächst verwendet um dem Miner spezielle optionen mitzuteilen
      "WATT": 320,                  # WATT/h das ist der Watt wert welche die GPU pro stunde brauch
                                    # DIESE ZAHL MUSS EIN INTEGER SEIN!!!
                                    # Also NOTFALLS AUFRUNDEN, bevor sie eingetragen wird.
      "LessThreads": 0              # wird "noch" nicht benutzt ggf kann gelöscht werden
}

Wenn keine WATT zahl bekannt ist muss noch z.b. fikiver wert 1000 eingetragen werden, da die bash sonst probleme macht

-----------------------------

If the best-price-calculating script gpu_gv-algo.sh is updated in this folder
then the scripts, which run in all the other GPU-UUID directories update themselves
automatically at invocation time and - if still running - just before the next calculation has to be done.

