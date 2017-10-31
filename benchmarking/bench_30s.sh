
############################################################################### 
# 
# Erstellung der Benchmarkwerte mit hielfe des ccminers 
# 
# Erstüberblick der möglichen Algos zum Berechnen + hash werte (nicht ganz aussagekräftig) 
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
# 0, GeForce GTX 980 Ti, GPU-742cb121-baad-f7c4-0314-cfec63c6ec70 
# 1, GeForce GTX 1060 3GB, GPU-84f7ca95-d215-185d-7b27-a7f017e776fb 
 
# auswahl des devices "eingabe wartend" 
read -p "Für welches GPU device soll ein Benchmark druchgeführt werden: " var 
 
echo $var > bensh_gpu_30s_.index 
 
 
# mit ausgewählten device fortfahren (mit der Index zahl die ausgewählt wurde) 
nvidia-smi --id=$var --query-gpu=index,gpu_name,gpu_uuid --format=csv,noheader | gawk -e 'BEGIN {FS=", | %"} {print $3}' > uuid 
 
uuid=$(cat "uuid") 
 
 
# Auswahl des Algos  
 
a0="scrypt"
a1="lyra2rev2"
a2="x11gost"
#a3="scryptnf"
a4="x11"
a5="x13"
a6="keccak"
a7="x15"
a8="nist5"
a9="neoscrypt"
#------
a10="lyra2re"
a11="whirlpoolx"
a12="qubit"
a13="quark"
#a14="axiom"
a15="scryptjanenf16"
a16="blake256r8"
#a17="blake256r14"
a18="blake256r8vnl"
#a19="hodl"
#a20="daggerhashimoto"
a21="decred"
a22="cryptonight"
a23="lbry"
#a24="equihash"
#a25="pascal"
a26="sia"
a27="blake2s"
a28="skunk"

declare -n algonr 
 
echo "a0=scrypt ; a1=lyra2rev2 ; a2=x11gost ; a3=scryptnf ; a4=x11 ; a5=x13 ; a6=keccak ; a7=x15 ; a8=nist5 ; a9=neoscrypt"
echo "a10=lyra2re ; a11=whirlpoolx ; a12=qubit ; a13=quark ; a14=axiom ; a15=scryptjanenf16 ; a16=blake256r8 ; a17=blake256r14"
echo "a18=blake256r8vnl ; a19=hodl ; a20=daggerhashimoto ; a21=decred ; a22=cryptonight ; a23=lbry ; a24=equihash ; a25=pascal"
echo "a26=sia ; a27=blake2s ; a28=skunk"
 
read -p "Für welchen Algo willst du testen: " algonr 
 
echo $algonr > algo.out 
algo=$(cat "algo.out") 
 
#algo=($algonr) 
 
echo "das ist der Algo den du ausgewählt hast : ${algo}" 
 
########## 
# 
# Algo auswahl zu miner algos anpassung, da teilweise der miner andere algonamen hat 
# 
# Datei "algo_zu_ccminer-algo" 
# normale algoname ccminer-algoname 
 
if [ "$algo" = "lyra2rev2" ] ; then 
    algo="lyra2v2" 
    echo "algo muss geändert werden" 
   else 
    if [ "$algo" = "x11gost" ] ; then 
        algo="sib" 
        echo "algo muss geändert werden" 
       else 
        if [ "$algo" = "whirlpoolx" ] ; then 
            algo="whirlpool" 
            echo "algo muss geändert werden" 
        else 
            if [ "$algo" = "scryptjanenf16" ] ; then 
                algo="scrypt-jane" 
                echo "algo muss geändert werden" 
            else 
                if [ "$algo" = "blake256r8" ] ; then 
                    algo="blakecoin" 
                    echo "algo muss geändert werden" 
                else 
                    if [ "$algo" = "blake256r8vnl" ] ; then 
                        algo="vanilla" 
                        echo "algo muss geändert werden" 
                    else 
                        echo "gibt keine algoveränderung" 
                    fi     
                fi    
 
            fi    
        fi   
    fi  
fi 
 

# miner wird ausgeführt mit device und schreiben der log datei (mehrere minuten) 
# CUDA export .. wo das Cuda verzeichnis ist und ggf version 
export LD_LIBRARY_PATH=/usr/local/cuda-8.0/lib64/:$LD_LIBRARY_PATH 
 
#wo der Miner ist und welcher benutzt wird 
minerfolder="/media/avalon/dea6f367-2865-4032-8c39-d2ca4c26f5ce/ccminer-windows" 
 
echo " ./ccminer --no-color --benchmark --devices $var >> benchmark_${algo}_$uuid.log" 
$minerfolder/ccminer --no-color -a ${algo} --benchmark --devices $var > benchmark_${algo}_${uuid}.log & 
echo $! > ccminer.pid 
 
 
sleep 3 
 
 
 
 
### Starten der WATT Messung über xx Sekunden um ein ersten wert zu bekommen 
# Hier drin läuft der counter xx Sekunden, danach werden Miner bench beendet 
#  (wattmessung sekunde vorher als variable abfragen irgendwann) 
 
echo "starten des Wattmessens" 
#echo "watt_bensh_30s.sh &" 
rm COUNTER 
rm watt_bensh_30s.out 
rm -f watt_bensh_30s_max.out

#####
#
# Teilweise brauchen die Algos längere zeit um hash werte zu erzeugen, deswegen wird der timer
# je nach algo hochgesetzt, wenn dieses gebraucht wird .... bzw ... anhand der ausgabe datei
# kann es ggf festgesellt werden .... minium 20 hash werte sollten aufgerechnet werden können.
time=30    #wieviel mal soll die schleife laufen ein durchlauf 1 sekunde
    
    if [ "$algo" = "scrypt" ] ; then 
        time=1 
        echo "Dieser Algo ist nicht mehr mit Graffikkarten lohnenswert" 
       else 
        echo "gibt keine zeit Anpassung läuft mit $time Sekunden" 
    fi  


COUNTER=0
id=$(cat "bensh_gpu_30s_.index")       #später indexnummer aus gpu folder einfügen !!!


#### für so und so viele Sekunden den Watt wert in eine Datei schreiben
while [  $COUNTER -lt $time ]; do
    nvidia-smi --id=$id --query-gpu=power.draw --format=csv,noheader |gawk -e 'BEGIN {FS=" "} {print $1}'  >> watt_bensh_30s.out
    let COUNTER=COUNTER+1
    echo $COUNTER > COUNTER
    sleep 1
done



echo "Wattmessen ist beendet!!" 


echo "beenden des miners" 
## Beenden des miners 
ccminer=$(cat  "ccminer.pid") 
kill -15 $ccminer 
sleep 2 
 
############################################################################### 
# 
#Berechnung der Durchschnittlichen Verbrauches 
# 
COUNTER=$(cat "COUNTER") 
 
sort watt_bensh_30s.out |tail -1 > watt_bensh_30s_max.out 
 
WATT=$(cat "watt_bensh_30s.out") 
MAXWATT=$(cat "watt_bensh_30s_max.out") 
sum=0 
 
for i in $WATT ; do  
 
  sum=$(echo "$sum + $i" | bc) 
done 
 
avgWATT=$(echo "$sum / $COUNTER" | bc) 
 
echo " Summe: $sum " 
echo " Durchschnitt: $avgWATT " 
echo " Max WATT wert: $MAXWATT " 
 
############################################################################### 
 
 
# 
# cat 980ti_bench_log |grep MB, |gawk -M -e 'BEGIN {FS=" "} {print $3}{print $5*1000}' ### noch fehle rdrin bei 0.4 dann ausgabe 0 
# 
#  cat benchmark_$uuid.log |grep MB, |gawk -M -e 'BEGIN {FS=" "} {print $3}{print $5*1000}' 
# 
#  
################################### 
# ## ACHTUNG im ccminer können algo namen anders heißen als wir sie benennen "Vannilla = Blake2s-vnl" z.b. 
#   ggf. für jeden miner eine liste erstellen welche algos wie angesprochen werden müssen um den 
#   richtigen algo zusuweisen zu können 
# ################################### 
 
 
################### 
# 
# Da sich die algos unterscheiden und auch noch die vom anfang gebraucht und der bezug bestehen bleiben soll 
# muss der wert in 2 variablen weiter geführt werden und ggf in einer geändert bzw angepasst werden 
# 
 
algo_original="$algo" 
 
################### 
# 
# wieder richtigstellen der algos ccminer-algo zu algo 
# 
 
if [ "$algo" = "lyra2v2" ] ; then 
    algo_original="lyra2rev2" 
    echo "algo muss geändert werden" 
    else 
    if [ "$algo" = "sib" ] ; then 
        algo_original="x11gost" 
        echo "algo muss geändert werden" 
    else 
        if [ "$algo" = "whirlpool" ] ; then 
            algo_original="whirlpoolx" 
            echo "algo muss geändert werden" 
        else 
            if [ "$algo" = "scrypt-jane" ] ; then 
                algo_original="scryptjanenf16" 
                echo "algo muss geändert werden" 
            else 
                if [ "$algo" = "blakecoin" ] ; then 
                    algo_original="blake256r8" 
                    echo "algo muss geändert werden" 
                else 
                    if [ "$algo" = "vanilla" ] ; then 
                        algo_original="blake256r8vnl" 
                        echo "algo muss geändert werden" 
                    else 
                        echo "Algo muss nicht geändert werden" 
                    fi     
                fi    
            fi   
        fi  
    fi 
fi 
 
 
echo " $algo_original " 
######################## 
# 
# Benschmarkspeeed HASH und WATT werte
# (original benchmakŕk.json) für herrausfinden wo an welcher stelle ersetzt werden muss  
# 
#bechchmarkfile="benchmark_${uuid}.json"    # gpu index uuid in "../$uuid/benchmark_$uuid" 

cat benchmark_${uuid}.json |grep -n -A 4 \"${algo_original}\" | grep BenchmarkSpeed | gawk -e 'BEGIN {FS=" "} {print $1}' | sed 's/-//' > tempazb
cat benchmark_${uuid}.json |grep -n -A 4 \"${algo_original}\" | grep WATT | gawk -e 'BEGIN {FS=" "} {print $1}' | sed 's/-//' > tempazw

#" <-- wegen richtigem Highlightning in meinem proggi ... bitte nicht entfernen
## Benchmark Datei bearbeiten "wenn diese schon besteht"(wird erstmal von ausgegangen) und die zeilennummer ausgeben. 
# cat benchmark_GPU-742cb121-baad-f7c4-0314-cfec63c6ec70.json |grep -n -A 4 equihash | grep BenchmarkSpeed 
# Zeilennummer ; Name ; HASH, 
# 80-      "BenchmarkSpeed": 469.765087, 
 
 

# 
# ccminer log vom algo benchmark_$algo_$uuid.log 
# 
#[2017-10-28 16:46:56] 1 miner thread started, using 'lyra2v2' algorithm.
#[2017-10-28 16:46:56] GPU #0: Intensity set to 20, 1048576 cuda threads
#[2017-10-28 16:46:58] GPU #0: Zotac GTX 980 Ti, 33.95 MH/s
#[2017-10-28 16:46:59] Total: 34.36 MH/s
#[2017-10-28 16:47:00] Total: 34.21 MH/s
#[2017-10-28 16:47:01] Total: 34.22 MH/s
#[2017-10-28 16:47:02] GPU #0: Zotac GTX 980 Ti, 34.40 MH/s

#[2017-10-28 16:39:44] 1 miner thread started, using 'sib' algorithm.
#[2017-10-28 16:39:44] GPU #0: Intensity set to 19, 524288 cuda threads
#[2017-10-28 16:39:47] GPU #0: Zotac GTX 980 Ti, 8878.28 kH/s
#[2017-10-28 16:39:54] GPU #0: Zotac GTX 980 Ti, 9029.67 kH/s
#[2017-10-28 16:39:54] Total: 9029.67 kH/s
#[2017-10-28 16:40:04] GPU #0: Zotac GTX 980 Ti, 8964.48 kH/s
#[2017-10-28 16:40:04] Total: 8997.08 kH/s


# Wegen des MH, KH umrechnung wird später bevor die daten in die bench hineingeschrieben wird der wert angepasst.
# die Werte werden in zwei schritten herausgefiltert und in eine hash temp datei zusammengepakt, so dass jeder hash
# wert erfasst werden kann

cat benchmark_${algo}_${uuid}.log |grep Total | gawk -e 'BEGIN {FS=" "} {print $4}' > temp_hash
cat benchmark_${algo}_${uuid}.log |grep /s |grep GPU | gawk -e 'BEGIN {FS=" "} {print $9}' >> temp_hash

#falls buchstaben hinzugekommen sind in einer zeile = falsch muss sie komplett entfernt werden
sed -i '/[a-z]/d' temp_hash

# herrausfiltern ob KH,MH ....
cat benchmark_${algo}_${uuid}.log |grep -m1 Total | gawk -e 'BEGIN {FS=" "} {print $5}' > temp_einheit

############################################################################### 
# 
#Berechnung der Durchschnittlichen Hash wertes 
# 

HASHCOUNTER=0 

HASH_temp=$(cat "temp_hash") 
sum=0 
 
for i in $HASH_temp ; do  
 
  sum=$(echo "$sum + $i" | bc)
  let HASHCOUNTER=HASHCOUNTER+1 
  echo $HASHCOUNTER > HASHCOUNTER  
done 
 
avgHASH=$(echo "$sum / $HASHCOUNTER" | bc) 
 
echo " Summe: $sum " 
echo " Durchschnitt: $avgHASH "
temp_einheit=$(cat "temp_einheit")
echo "${temp_einheit}"

#######################################################
#
# Wegen des MH, KH umrechnung wird später bevor die daten in die bench hineingeschrieben wird der wert angepasst.
#
#######################################

# if abfragen ob MH KH bla blub dann berechnung und richtigstellung $temp_einheit
if [ "$temp_einheit" = "kH/s" ] ; then  
    avgHASH=$(echo "${avgHASH} * 1000" | bc)
    echo "HASHWERT wurde in Einheit ${temp_einheit} umgerechnet $avgHASH"
    else
    
    if [ "$temp_einheit" = "MH/s" ] ; then  
        avgHASH=$(echo "${avgHASH} * 1000000" | bc)
        echo "HASHWERT wurde in Einheit ${temp_einheit} umgerechnet $avgHASH"
        else 
        
        if [ "$temp_einheit" = "GH/s" ] ; then  
            avgHASH=$(echo "${avgHASH} * 1000000000" | bc)
            echo "HASHWERT wurde in Einheit ${temp_einheit} umgerechnet $avgHASH"
            else 
            
            if [ "$temp_einheit" = "TH/s" ] ; then  
                avgHASH=$(echo "${avgHASH} * 1000000000000" | bc)
                echo "HASHWERT wurde in Einheit ${temp_einheit} umgerechnet $avgHASH"
                else 
                echo "HASHWERT $avgHASH brauchte nicht umgerechnet werden" 

            fi    

        fi   

    fi  
fi


#########
#
# Einfügen des Hash wertes in die Original bench*.json datei
 
# ## in der temp_algo_zeile steht die zeilen nummer zum editieren des hashwertes
tempazw=$(cat "tempazw")
tempazb=$(cat "tempazb") 

if [ "$tempazw" -gt 1 ] ; then  
        # Hash wert änderung
        echo "der Hash wert $avgHASH wird nun in der Zeile $tempazb eingefügt" 
        sed -i -e ''$tempazb's/[0-9.]\+/'$avgHASH'/' benchmark_${uuid}.json
        # WATT wert änderung
        echo "der WATT wert $avgWATT wird nun in der Zeile $tempazw eingefügt" 
        sed -i -e ''$tempazw's/[0-9.]\+/'$avgWATT'/' benchmark_${uuid}.json
    else 
        echo "Der Algo wird zur Benchmark Datei hinzugefügt"
        echo "{" >> benchmark_${uuid}.json
        echo ""Name": "$algo_original"," >> benchmark_${uuid}.json
        echo ""NiceHashID": 0," >> benchmark_${uuid}.json
        echo ""MinerBaseType": 0," >> benchmark_${uuid}.json
        echo ""MinerName": "$algo_original"," >> benchmark_${uuid}.json
        echo ""BenchmarkSpeed": $avgHASH," >> benchmark_${uuid}.json
        echo ""ExtraLaunchParameters": ""," >> benchmark_${uuid}.json
        echo ""WATT": $avgWATT," >> benchmark_${uuid}.json
        echo ""LessThreads": 0" >> benchmark_${uuid}.json
        echo "}," >> benchmark_${uuid}.json

fi   


 

###################### 
# Löschen der Log datei 
#rm benchmark_$tempnv.log 
 
 
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
#nur die mit "yes!" zur berechnung des hashes nehmen bei "threading"
