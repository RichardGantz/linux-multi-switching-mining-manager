#!/bin/bash
###############################################################################
#
# Die Variablen   $IMPORTANT_BENCHMARK_JSON,
#                 $bENCH_SRC   (=="bENCH.in")
#                 $gpu_idx
#                 $LINUX_MULTI_MINING_ROOT
#     müssen gesetzt sein für den Include von gpu-bENCH.inc
#
# Von letzterer werden 2 Funktionen zur Verfügung gestellt:
#     1. Das Update und die Strukturanpassung der JSON-Datei
#     2. Ein Funktion zum Einlesen der gesamten Struktur und die Erzeugung der Variablen
#                 $IMPORTANT_BENCHMARK_JSON_last_age_in_seconds
#     und jede Menge Assoziativer Arrays, die über
#     $algorithm   (== algo#miner_name#miner_version)
#     angesprochen werden können.
#

_UpdateIt_=0

# Wo befinden wir uns eigentlich?
PWD=$(pwd | gawk -e 'BEGIN {FS="/"} { print $NF }')
if [ "$PWD" == "GPU-skeleton" ]; then
    #
    echo "Befinde mich im Verteilungsverzeichnis" >/dev/null
    # Hier drin machen wir den 
    #     touch -r benchmark_skeleton.json gpu-bENCH.inc
    # wenn das Skript gpu-bENCH.inc bzw. die Funktionen darin stabil funktionieren.
    #
elif [ "${PWD:0:4}" == "GPU-" ]; then
    #
    #echo "Befinde mich in einem GPU-Unterverzeichnis"
    # Hier sind wir immer dann drin, wenn konsistente Daten gelesen werden sollen
    # ODER wenn ein geordneter Änderungsvorgang an der JSON ansteht.
    #
    if   [ ! -f gpu-bENCH.inc   ]; then
        # Dieser Fall ist ein bisschen Chaotisch. Könnte sein, dass gpu-abfrage.sh nicht reinkopiert hat
        # oder dass GitKraken wieder was gelöscht hat.
        # Na ja, wir holen sie auf jeden Fall mal.
        cp -f ../GPU-skeleton/gpu-bENCH.inc .
    fi
    #
    # ABER: damit wir das Folgende, die STRUKTURANPASSUNG nicht immer wieder und wieder tun, schauen wir, ob wir die
    #       momentane gpu-bENCH.inc nicht schon geholt haben:
    if [ ! $(stat -c %Y ../GPU-skeleton/gpu-bENCH.inc) -eq $(stat -c %Y gpu-bENCH.inc) ]; then
        #
        # Quell-bENCH ist seit dem Runterkopieren verändert worden, aber möglicherweise INKONSISTENT
        # Deshalb haben wir vereinbart, dass dieser Zustand so lang als INKONSISTENT anzusehen ist,
        # bis die beiden Dateien benchmark_skeleton.json und gpu-bENCH.inc absichtlich auf das selbe Datum gesetzt werden.
        #     touch -r benchmark_skeleton.json gpu-bENCH.inc
        # Das setzt das Editierungsdatum der gpu-bENCH.inc im letztlichen Erfolgsfall zwar VORAUS,
        #     aber das spielt ja keine Rolle. Sie wäre so oder so der GPU-eigenen gpu-bENCH.inc voraus.
        #
        if [ $(stat -c %Y ../GPU-skeleton/benchmark_skeleton.json) -eq $(stat -c %Y ../GPU-skeleton/gpu-bENCH.inc ) ]; then
            #
            # Quell-bENCH ist seit dem Runterkopieren verändert worden, aber jetzt als KONSISTENT signalisiert!
            # Diese Bedingung sagt aus, dass ein konsistenter gpu-bENCH.inc Zustand hergestellt wurde und
            # die benchmark_skeleton.json im Verteilungsverzeichnis GPU-skeleton damit bearbeitet wurde.
            # Das heisst, dass der Zustand aller Dateien auf die neue Datenstruktur vorbereitet ist
            # UND dass die neue gpu-bENCH.inc nun ins eigene Verzeichnis geholt werden kann
            # UND dass die eigene benchmark_${gpu_uuid}.json nun angepasst werden kann.
            #
            cp -f -p ../GPU-skeleton/gpu-bENCH.inc .   # Option -p ist WICHTIG, damit die Dateien die selbe Zeit haben.
            source gpu-bENCH.inc
            _expand_IMPORTANT_BENCHMARK_JSON
        else
            #
            # Quell-bENCH ist seit dem Runterkopieren verändert worden und eher INKONSISTENT.
            # Deshalb verwenden wir nach wie vor die alte, die auch zu der alten benchmark_*.json passt
            #
            source gpu-bENCH.inc
        fi
    else
        #
        # Quell-bENCH ist seit dem Runterkopieren NICHT verändert worden und nach wie vor gültig
        #
        source gpu-bENCH.inc
    fi
else
    echo "Weiss nicht genau... müsste weiter untersuchen... " >/dev/null
fi

