#!/bin/bash
###############################################################################
#
# Entgegennehmen, absetzen und protokollieren von TWEAK-Kommandos
#
#

function _On_Exit () {
    # CCminer stoppen
    if [ -s bench_30s_2.pid ]; then kill $(cat "bench_30s_2.pid"); fi
}
trap _On_Exit EXIT

WISHED_LOGFILES=$(< tweak_to_these_logs)
read OWN_LOGFILE WATT_LOGFILE HASH_LOGFILE <<<${WISHED_LOGFILES}

echo "Benchmark is actually running for the following GPU:"
echo "GPU #$(cat bensh_gpu_30s_.index) with UUID: $(cat uuid)"

echo "Die gewünschte Logdatei für die Tweaking-Kommandos lautet: $OWN_LOGFILE"
echo "Zusätzlich muss das Kommando in die folgenden Dateien geschrieben werden:"
echo "Wattwerte: $WATT_LOGFILE und Hashwerte: $HASH_LOGFILE"

while :; do

    read -p "Welches Kommando für diese GPU? " cmd

    case "$cmd" in
        quit|break|ende|stop)
            exit 0
            ;;
    esac
    
    echo "${cmd}" | tee -a ${WATT_LOGFILE} ${HASH_LOGFILE} >>${OWN_LOGFILE}
    ${cmd}
done
