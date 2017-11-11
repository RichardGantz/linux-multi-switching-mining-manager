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
    echo "Befinde mich im Verteilungsverzeichnis" >/dev/null
elif [ "${PWD:0:4}" == "GPU-" ]; then
    #echo "Befinde mich in einem GPU-Unterverzeichnis"
    # Hier sind wir immer dann drin, wenn konsistente Daten gelesen werden sollen
    # ODER wenn ein geordneter Änderungsvorgang an der JSON ansteht.
    if   [ ! -f gpu-bENCH.inc   ]; then
        cp -f ../GPU-skeleton/gpu-bENCH.inc .
    elif [ $(stat -c %Y ../GPU-skeleton/gpu-bENCH.inc) -gt $(stat -c %Y gpu-bENCH.inc) ]; then
        cp -f ../GPU-skeleton/gpu-bENCH.inc .
    fi
    source gpu-bENCH.inc
    if [ $(stat -c %Y ../GPU-skeleton/benchmark_skeleton.json) -gt $(stat -c %Y ../GPU-skeleton/gpu-bENCH.inc ) ]; then
        _expand_IMPORTANT_BENCHMARK_JSON
    fi
else
    echo "Weiss nicht genau... müsste weiter untersuchen... " >/dev/null
fi

