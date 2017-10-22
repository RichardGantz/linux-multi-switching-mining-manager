#!/bin/bash
###############################################################################
#
# Erstellung der Benchmarkwerte mit hielfe des ccminers
#
#
#
#  
#
# drei verschiedene Benchmark Methoden einmal das Benchmark prog vom miner
# und die direkten hash werte aus stdin oder log herrauslesen "langszeit" benchmark
# über 5 - 15 minuten und 2 minuten benchmark
#
#
#
#
# ## benchmark aufruf vom ccminer mit allen algoryhtmen welcher dieser kann
#   Vor--benchmark um einen ersten überblick zu bekommen über algos und hashes
#
# ./ccminer --no-color --benchmark --devices 0 >>980ti_bench_log
#
#
# ### am ende steht eine zusammenfassung --- > 
# [2017-10-15 18:01:41]      vanilla :     873955.7 kH/s,     1 MB,  1048576 thr.
#
#
# ## filter per grep ist da dann "MB," so das wir nur den schluss bekommen
# ## awk fileseperator ist das "leerzeichen"
#
# cat 980ti_bench_log |grep MB, |gawk -M -e 'BEGIN {FS=" "} {print $3}{print $5*1000}'
#
# "algo" $1
#"speed" $2
# "algo"
#"speed"
# "algo"
#"speed"
# 
###################################
# ## ACHTUNG im ccminer können algo namen anders heißen als wir sie benennen "Vannilla = Blake2s-vnl" z.b.
#   ggf. für jeden miner eine liste erstellen welche algos wie angesprochen werden müssen um den
#   richtigen algo zusuweisen zu können
# ###################################




## Benchmark Datei bearbeiten "wenn diese schon besteht"(wird erstmal von ausgegangen) und die zeilennummer ausgeben.
# cat benchmark_GPU-742cb121-baad-f7c4-0314-cfec63c6ec70.json |grep -n -A 4 equihash | grep BenchmarkSpeed
# 80-      "BenchmarkSpeed": 469.765087,


algo="equihash" 
bechchmarkfile="benchmark_GPU-742cb121-baad-f7c4-0314-cfec63c6ec70.json"
cat $bechchmarkfile |grep -n -A 4 $algo | grep BenchmarkSpeed | gawk -e 'BEGIN {FS=" "} {print $1}' | sed 's/-//' > temp


# ## in der temp steht die zeilen nummer zum editieren des hashwertes
temp=$(cat "temp")
#echo "$temp"
sed -i -e ''$temp's/[0-9.]\+/1111/' $bechchmarkfile
# 
# 
#
#
# 
# 
#
#
# Benchmark test ist nur für den ccminer ($3) ## "MinerName" (wird später folder bezogen da es mehrere miner gibt ... noch nicht ganz klar)
# Ein algo können mit xx verschiedenen minern betrieben werden 
#
# Block_empty
#    {
#      "Name": "$1",
#      "NiceHashID": 0,
#      "MinerBaseType": 0,
#      "MinerName": "$3",       #$3 wird am anfang dann vom miner xyz gesetzt bzw von hand eingetragen
#      "BenchmarkSpeed": $2,
#      "ExtraLaunchParameters": "",
#      "WATT": 0,
#      "LessThreads": 0
#    },
#
#
#
#
#
##### old
#cat miner.out |gawk -e 'BEGIN {FS=", "} {print $2}' |grep -E -o -e '[0-9.]*'
## nur die mit "yes!" zur berechnung des hashes nehmen bei "threading"