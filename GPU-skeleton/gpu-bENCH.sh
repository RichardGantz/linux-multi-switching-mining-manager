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

# GLOBALE VARIABLEN, nützliche Funktionen
[[ ${#_GLOBALS_INCLUDED} -eq 0 ]] && source ../globals.inc

# Wo befinden wir uns eigentlich?
act_pwd=$(pwd)
act_pwd=${act_pwd##*/}
if [ "$act_pwd" == "GPU-skeleton" ]; then
    echo ""
    echo "Befinde mich im Verteilungsverzeichnis"
    echo "Hier drin machen wir nach der Strukturänderung und Validierung den"
    echo "     touch -r benchmark_skeleton.json gpu-bENCH.inc"
    echo "wenn das Skript gpu-bENCH.inc bzw. die Funktionen darin stabil funktionieren."
    echo "Das bitte vor der Bestätigung gleich prüfen! Sonst fällt das ganze System der Reihe nach auf den Bauch..."
    echo ""

    IMPORTANT_BENCHMARK_JSON=benchmark_skeleton.json
    source gpu-bENCH.inc
    _expand_IMPORTANT_BENCHMARK_JSON
    while :; do
        read -p "IST DIE benchmark_skeleton.json IN ORDUNG ? (j oder n) : " ok
        REGEXPAT="[jn]"
        [[ "${ok}" =~ ${REGEXPAT} ]] && break
    done
    if [ "${ok}" == "j" ]; then
        touch -r ${IMPORTANT_BENCHMARK_JSON} gpu-bENCH.inc
        echo ""
        echo "Der Trigger zur Übernahme der neuen gpu-bENCH.inc in die GPU-UUID-Verzeichnisse wurde gesetzt!"
        echo "Die gpu_gv-algo.sh's sollten nun alle den Struktur-Update vor dem nächsten Einlesen machen"
        echo "und damit den aktuellsten Datenbestand zur Verfügung haben."
    fi
elif [ "${act_pwd:0:4}" == "GPU-" ]; then
    #
    #echo "Befinde mich in einem GPU-Unterverzeichnis"
    # Hier sind wir immer dann drin, wenn konsistente Daten gelesen werden sollen
    # ODER wenn ein geordneter Änderungsvorgang an der JSON ansteht.
    #
    if   [ ! -f gpu-bENCH.inc   ]; then
        # Dieser Fall ist ein bisschen Chaotisch. Könnte sein, dass gpu-abfrage.sh nicht reinkopiert hat
        # oder dass GitKraken wieder was gelöscht hat.
        # Na ja, wir holen sie auf jeden Fall mal.
        cp -f -p ../GPU-skeleton/gpu-bENCH.inc .
    fi
    #
    # ABER: damit wir das Folgende, die STRUKTURANPASSUNG nicht immer wieder und wieder tun, schauen wir, ob wir die
    #       momentane gpu-bENCH.inc nicht schon geholt haben:
    _structure_change=0
    if [ !     $(date --utc --reference=../GPU-skeleton/gpu-bENCH.inc +%s) \
           -eq $(date --utc --reference=gpu-bENCH.inc +%s) ]; then
        #
        # Quell-bENCH ist seit dem Runterkopieren verändert worden, aber möglicherweise INKONSISTENT
        # Deshalb haben wir vereinbart, dass dieser Zustand so lang als INKONSISTENT anzusehen ist,
        # bis die beiden Dateien benchmark_skeleton.json und gpu-bENCH.inc
        # absichtlich auf das selbe Datum gesetzt werden, z.B. über:
        #     touch -r benchmark_skeleton.json gpu-bENCH.inc
        # Das setzt das Editierungsdatum der gpu-bENCH.inc im letztlichen Erfolgsfall zwar VORAUS,
        #     aber das spielt ja keine Rolle. Sie wäre so oder so der GPU-eigenen gpu-bENCH.inc voraus.
        #
	if [       $(date --utc --reference=../GPU-skeleton/benchmark_skeleton.json +%s) \
	       -eq $(date --utc --reference=../GPU-skeleton/gpu-bENCH.inc +%s) ]; then
            #
            # Quell-bENCH ist seit dem Runterkopieren verändert worden, aber jetzt als KONSISTENT signalisiert!
            # Diese Bedingung sagt aus, dass ein konsistenter gpu-bENCH.inc Zustand hergestellt wurde und
            # die benchmark_skeleton.json im Verteilungsverzeichnis GPU-skeleton damit bearbeitet wurde.
            # Das heisst, dass der Zustand aller Dateien auf die neue Datenstruktur vorbereitet ist
            # UND dass die Funktion _expand_IMPORTANT_BENCHMARK_JSON gerufen werden kann/muss,
            # dass die eigene benchmark_${gpu_uuid}.json nun angepasst wird.
            #
            _structure_change=1
        fi
        cp -f -p ../GPU-skeleton/gpu-bENCH.inc .   # Option -p ist WICHTIG, damit die Dateien die selbe Zeit haben.
    fi
    source gpu-bENCH.inc
    [ ${_structure_change} -eq 1 ] && _expand_IMPORTANT_BENCHMARK_JSON
else
    echo "$(basename $0): Weiss nicht genau... müsste weiter untersuchen... Aktueller Pfad: ${act_pwd} " | tee -a ${FATAL_ERRORS} ${ERRLOG} >/dev/null
fi
