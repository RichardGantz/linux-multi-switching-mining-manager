#!/bin/bash

TREXLOGPATH="/home/avalon/miner/t-rex"

#-rw-r--r-- 1 avalon avalon 3514878 Apr 22 17:57 t-rex-0-daggerhashimoto-[1619107726].log
#-rw-r--r-- 1 avalon avalon 1424426 Apr 23 18:32 t-rex-0-daggerhashimoto-[1619196773].log
#-rw-r--r-- 1 avalon avalon 1074885 Apr 24 13:47 t-rex-0-daggerhashimoto-[1619264974].log
#-rw-r--r-- 1 avalon avalon 2758402 Apr 26 09:04 t-rex-0-daggerhashimoto-[1619420865].log
#-rw-r--r-- 1 avalon avalon 3765183 Apr 28 18:39 t-rex-0-daggerhashimoto-[1619678217]-Startschwierigkeiten.log

done_epochs=(
    1619107726
    1619196773
    1619264974
    1619420865
    1619678217
)
#epochs=( )

miner_name=t-rex
miner_version=0.19.14
miner_devices=( {0..9} )
coins=( daggerhashimoto octopus )

function _to_grab {
    for epoch in ${epochs[@]}; do
	for miner_device in ${miner_devices[@]}; do
	    for coin in ${coins[@]}; do
		file_to_grab="${TREXLOGPATH}/t-rex-${miner_device}-${coin}-\[${epoch}\]*.log"
		[ -f $file_to_grab ] && echo $file_to_grab
	    done
	done
    done
}

function arr_join2str { local IFS="#"; declare -n arr="$1"; echo "${arr[*]}"; }
arch_name="${miner_name}#${miner_version}#$(arr_join2str epochs)-logs.tar"

tar -cvjf ${arch_name}.bz2 $(_to_grab)
