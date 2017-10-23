#!/bin/bash
###############################################################################
#
# Erstellung der Benchmarkwerte mit hielfe des ccminers
#
# Erstüberblick der möglichen Algos zum Berechnen + hash werte (nicht ganz aussagekräftig)
#
#  
#
# 
#
#
#
#
# ## benchmark aufruf vom ccminer mit allen algoryhtmen welcher dieser kann
#   Vor--benchmark um einen ersten überblick zu bekommen über algos und hashes
#
#
#
# Devices auflisten welches einen benchmark durchführen soll
# list devices
nvidia-smi --query-gpu=index,gpu_name,gpu_uuid --format=csv,noheader
 
# auswahl des devices "eingabe wartend"
read -p "Für welches GPU device soll ein Benchmark druchgeführt werden: " var

echo $var > watt_bensh_1.id


# mit ausgewählten device fortfahren 
nvidia-smi --id=$var --query-gpu=index,gpu_name,gpu_uuid --format=csv,noheader | gawk -e 'BEGIN {FS=", | %"} {print $3}' > uuid

uuid=$(cat "uuid")


### Starten der WATT Messung über den ganzen benchmark um ein ersten wert zu bekommen
# wird überall mit eingetragen (ist der gleiche)

echo "starten des Wattmessens"
echo "./watt_bensh_1.sh &"
rm COUNTER
rm WATT_bensh_1.out
rm WATT_bensh_1_max.out
./watt_bensh_1.sh &
echo $! > watt_bensh_1.pid

# miner wird ausgeführt mit device und schreiben der log datei (mehrere minuten)
# CUDA export .. wo das Cuda verzeichnis ist und ggf version
export LD_LIBRARY_PATH=/usr/local/cuda-8.0/lib64/:$LD_LIBRARY_PATH

#wo der Miner ist und welcher benutzt wird
minerfolder="/media/avalon/dea6f367-2865-4032-8c39-d2ca4c26f5ce/ccminer-windows"

echo " ./ccminer --no-color --benchmark --devices $var >> benchmark_$uuid.log"
$minerfolder/ccminer --no-color --benchmark --devices $var >> benchmark_$uuid.log

echo "beenden des Wattmessens"
echo "kill -15 $watt_bensh_1.pid"
watt_bensh_1=$(cat "watt_bensh_1.pid")
kill -15 $watt_bensh_1
sleep 2

###############################################################################
#
#Berechnung der Durchschnittlichen Verbrauches
#
COUNTER=$(cat "COUNTER")

sort WATT_bensh_1.out |tail -1 > WATT_bensh_1_max.out

WATT=$(cat "WATT_bensh_1.out")
MAXWATT=$(cat "WATT_bensh_1_max.out")
sum=0

for i in $WATT ; do 

	sum=$(echo "$sum + $i" | bc)
done

avgWATT=$(echo "$sum / $COUNTER" | bc)
echo " Summe: $sum "
echo " Durchschnitt: $avgWATT "
echo " Max WATT wert: $MAXWATT "

###############################################################################


# ### am ende steht eine zusammenfassung --- > 
# [2017-10-15 18:01:41]      vanilla :     873955.7 kH/s,     1 MB,  1048576 thr.
#
#
# ## filter per grep ist da dann "MB," so das wir nur den schluss bekommen
# ## awk fileseperator ist das "leerzeichen"
#
# cat 980ti_bench_log |grep MB, |gawk -M -e 'BEGIN {FS=" "} {print $3}{print $5*1000}' ### noch fehle rdrin bei 0.4 dann ausgabe 0
#
cat benchmark_$uuid.log |grep MB, |gawk -M -e 'BEGIN {FS=" "} {print $3}{print $5*1000}'
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


#### kann dannin eine schleife gepakt werden welches die algos eins nach dem anderen aus dem array ausliest

algo="equihash"     # $xxxx aus dem array
bechchmarkfile="benchmark_GPU-742cb121-baad-f7c4-0314-cfec63c6ec70.json"    # gpu index uuid in "../$uuid/benchmark_$uuid"
cat $bechchmarkfile |grep -n -A 4 $algo | grep BenchmarkSpeed | gawk -e 'BEGIN {FS=" "} {print $1}' | sed 's/-//' > temp


# ## in der temp steht die zeilen nummer zum editieren des hashwertes
temp=$(cat "temp")
#echo "$temp"

sed -i -e ''$temp's/[0-9.]\+/1111/' $bechchmarkfile





######################
# Löschen der Log datei
rm benchmark_$tempnv.log











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