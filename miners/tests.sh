#!/bin/bash

[[ ${#_GLOBALS_INCLUDED} -eq 0   ]] && source ../globals.inc
[[ ${#_MINERFUNC_INCLUDED} -eq 0 ]] && source ${LINUX_MULTI_MINING_ROOT}/miner-func.inc

_read_in_minerFees_to_MINER_FEES

for key in "${!MINER_FEES[@]}"; do
    echo "$key = ${MINER_FEES[${key}]}"
done

<<COMMENT
test.sh::
###---> Updating all Miner Fees from disk.
t-rex#0.19.12:octopus = 2
miner#2.51:ethash = 0.65
t-rex#0.19.14:octopus = 2
t-rex#0.19.14 = 1
miner#2.51:kawpow = 1
t-rex#0.19.12 = 1
miner#2.51:cuckatoo31 = 2
miner#2.51:cuckatoo32 = 2
zm#0.6.2 = 2
miner#2.51:beamhash = 2
COMMENT

