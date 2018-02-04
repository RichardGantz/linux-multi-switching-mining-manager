#!/bin/bash
###############################################################################

declare -Ag start_msg diff_msg

#ccminer#2.2.2
#[2018-01-27 04:07:28] 1 miner thread started, using 'nist5' algorithm.
#[2018-01-27 04:07:28] Starting on stratum+tcp://nist5.eu.nicehash.com:3340
#[2018-01-27 04:07:28] Stratum difficulty set to 0.1
#[2018-01-27 04:07:28] nist5 block 51202, diff 27894.044
#[2018-01-27 04:07:28] GPU #5: Intensity set to 20, 1048576 cuda threads
#[2018-01-27 04:07:31] GPU #5: GeForce GTX 1080 Ti, 61.44 MH/s
#[2018-01-27 04:07:31] accepted: 1/1 (diff 0.253), 54.48 MH/s (yes!)

start_msg[ccminer#2.2.2]="^.*cuda threads"
start_msg[ccminer#2.2.3]="^.*cuda threads"
start_msg[ccminer#2.2.4]="^.*cuda threads"

diff_msg[ccminer#2.2.2]="^.*Stratum difficulty set to [[:digit:].]+"
diff_msg[ccminer#2.2.3]="^.*Stratum difficulty set to [[:digit:].]+"
diff_msg[ccminer#2.2.4]="^.*Stratum difficulty set to [[:digit:].]+"

#2018-01-26 21:08:07|#  zm 0.5.8
#2018-01-26 21:08:07|#  GPU0 - GeForce GTX 1080 Ti      MB: 11172 PCI: 2:0
#2018-01-26 21:08:07|#  GPU1 - GeForce GT 710           MB: 980   PCI: 1:0
#2018-01-26 21:08:07|#  GPU2 - GeForce GTX 1060 3GB     MB: 3013  PCI: 3:0
#2018-01-26 21:08:07|#  GPU3 - GeForce GTX 1070         MB: 8114  PCI: 4:0
#2018-01-26 21:08:08|#  GPU4 - GeForce GTX 1080 Ti      MB: 11172 PCI: 8:0
#2018-01-26 21:08:08|#  GPU5 + GeForce GTX 1080 Ti      MB: 11172 PCI: 11:0
#2018-01-26 21:08:08|#  GPU6 - GeForce GTX 1080 Ti      MB: 11172 PCI: 12:0
#2018-01-26 21:08:08|#  GPU7 - GeForce GTX 1080 Ti      MB: 11172 PCI: 13:0
#2018-01-26 21:08:08|
#2018-01-26 21:08:08|#  connected to: equihash.br.nicehash.com:3357
#2018-01-26 21:08:10|#  server supports extranonce
#2018-01-26 21:08:20|#  server set difficulty to: 0003c3c3c3c0000000000000...
#2018-01-26 21:08:40|>  GPU5  66C  Sol/s: 711.1  Sol/W: 3.10  Avg: 711.1  I/s: 383.1  Sh: 8.98   1.00 447 +++

start_msg[zm#0.5.6]="^.*server set difficulty to: [[:xdigit:]]+"
start_msg[zm#0.5.7]="^.*server set difficulty to: [[:xdigit:]]+"
start_msg[zm#0.5.8]="^.*server set difficulty to: [[:xdigit:]]+"
diff_msg[zm#0.5.6]="^.*server set difficulty to: [[:xdigit:]]+"
diff_msg[zm#0.5.7]="^.*server set difficulty to: [[:xdigit:]]+"
diff_msg[zm#0.5.8]="^.*server set difficulty to: [[:xdigit:]]+"


# Miner übergreifende Difficulty Erkennung (Am Ende, als letztes Feld, muss die Difficulty im Suchergebnis sein)
#DIFFEXPR=$(pos_join '|' "${diff_msg[@]}")
