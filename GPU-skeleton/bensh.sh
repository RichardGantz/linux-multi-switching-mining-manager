#!/bin/bash
###############################################################################
#
#Berechnung der Durchschnittlichen Verbrauches
#
#cat miner.out |gawk -e 'BEGIN {FS=", "} {print $2}' |grep -E -o -e '[0-9.]*'
#
#  ## nur die mit "yes!" zur berechnung des hashes nehmen bei "threading"
#
# drei verschiedene Benchmark Methoden einmal das Benchmark prog vom miner
# und die direkten hash werte aus stdin oder log herrauslesen "langszeit" benchmark
# über 5 - 15 minuten und 2 minuten benchmark
#