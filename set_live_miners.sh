#!/bin/bash
###############################################################################
#
# Prüfung aller übergebenen MinerName#MinerVersion Miner,
#         ob sie überhaupt ein LIVE_START_CMD haben.
#
# Das war beim XmrMiner lange nicht der Fall. Er konnte Offline benchmarken und Werte in die JSON schreiben.
# Wenn er dann aber vom MultiMiner eingesetzt werden sollte, versagte dieser, weil kein LIVE_START_CMD da war.
# 
#
# WIR MÜSSEN UNS SCHON IM ../miners Verzeichnis befinden !!!!!!

rm -f .act_live_miners

while [[ $# -gt 0 ]]; do
    MINER="$1"
    unset LIVE_START_CMD
    source ${MINER}.starts
    [ ${#LIVE_START_CMD} -gt 0 ] && echo ${MINER} >>.act_live_miners
    shift
done
