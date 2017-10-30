#!/bin/bash
###############################################################################
#                           Multi-Mining-Sort und -Calc
# 
# Hier werden die GPU's Algorythmen jeder Karte Sortiert und zusammengefasst.
# 
# Welche Karte "sieger" ist und als erstes z.b. anfangen darf zu minen
#
#
#
#
###############################################################################

# Für die Ausgabe von mehr Zwischeninformationen auf 1 setzen.
# Null, Empty String, oder irgendetwas andere bedeutet AUS.
verbose=0

# Sicherheitshalber alle .pid Dateien löschen.
# Das machen die Skripts zwar selbst bei SIGTERM, nicht aber bei SIGKILL und anderen.
# Sonst startet er die Prozesse nicht.
# Die .pid ist in der Endlosschleife der Hinweis, dass der Prozess läuft und NICHT gestartet werden muss.
#
find . -depth -name \*.pid -delete

# Aktuelle PID der 'multi_mining-controll.sh' ENDLOSSCHLEIFE
echo $$ >$(basename $0 .sh).pid

#
# Aufräumarbeiten beim ordungsgemäßen kill -15 Signal (SIGTERM)
#
function _terminate_all_processes_of_script () {
    kill_pids=$(ps -ef \
       | grep -e "/bin/bash.*$1" \
       | grep -v 'grep -e ' \
       | gawk -e 'BEGIN {pids=""} {pids=pids $2 " "} END {print pids}')
    if [ ! "$kill_pids" == "" ]; then
        printf "Killing all $1 processes... "
        kill $kill_pids
        printf "done.\n"
    fi
}

function _On_Exit () {
    _terminate_all_processes_of_script "gpu_gv-algo.sh"
    _terminate_all_processes_of_script "algo_multi_abfrage.sh"
    rm -f $(basename $0 .sh).pid
}
trap _On_Exit EXIT

# Wenn keine Karten da sind, dürfen verschiedene Befehle nicht ausgeführt werden
# und müssen sich auf den Inhalt fixer Dateien beziehen.
# ---> wird in gpu-abfrage.sh gesetzt, das wir bald als "source" hinzunehmen <---
#NoCards:        if [ $HOME == "/home/richard" ]; then NoCards=true; fi
#SYSTEM_FILE:    "gpu_system.out"
#SYSTEM_STATE:   "GLOBAL_GPU_SYSTEM_STATE"

# Hier drin halten wir den aktuellen GLOBALEN Status des Gesamtsystems fest
RUNNING_STATE="GLOBAL_GPU_ALGO_RUNNING_STATE"

SYNCFILE="you_can_read_now.sync"

GRID[0]="netz"
GRID[1]="solar"
GRID[2]="solar_akku"

# Funktionen Definitionen ausgelagert
source ./multi_mining_calc.inc

# Hier nun einige Vorarbeiten und dann der Einstig in die Endlosschleife
# Um die algo_multi_abfrage.sh zu stoppen, müssen wir in der Prozesstabelle nach
#        '/bin/bash.*algo_multi_abfrage.sh'
#        suchen und die Prozess-ID vielleicht mit der Datei vergleichen,
#        die algo_multi_abfrage.sh selbst geschrieben hat?
#
# Die gpu_gv-algo.sh können selbst die Miner stoppen und weitere Aufräumarbeiten durch führen
# kill $(ps -ef \
#      | grep gpu_gv-algo.sh \
#      | grep -v grep \
#      | grep -e '/bin/bash.*gpu_gv-algo.sh' \
#      | gawk -e 'BEGIN {pids=""} {pids=pids $2 " "} END {print pids}')

# Jetzt erst mal der einfachste Fall:
# Wenn multi_mining_calc.sh gestoppt wird, soll alles gestoppt werden.
# ALLE LAUFENDEN gpu_gv-algo.sh killen.
# ---> DAS MUSS NATÜRLICH AUCH DEN MINERN NOCH MITGETEILT WERDEN! <---
# ---> WIR BEFINDEN UNS HIER NOCH IN DER TROCKENÜBUNG             <---
_terminate_all_processes_of_script "gpu_gv-algo.sh"
_terminate_all_processes_of_script "algo_multi_abfrage.sh"
# ---> WIR MÜSSEN AUCH ÜBERLEGEN, WAS WIR MIT DEM RUNNING_STATE MACHEN !!! <---
# ---> WIE SINNVOLL IST ES, DEN AUFZUHEBEN?                                <---
# Danach ist alles saubergeputzt, soweit wir das im Moment überblicken und es kann losgehen, die
# gpu_gv-algos's zu starten, die erst mal auf SYNCFILE warten
# und dann algo_multi_abfrage.sh


while : ; do

# Diese Abfrage erzeugt die beiden Dateien "gpu_system.out" und "GLOBAL_GPU_SYSTEM_STATE.in"
# Daten von "GLOBAL_GPU_SYSTEM_STATE.in", WELCHES MANUELL BEARBEITET WERDEN KANN,
#       werden berücksichtigt, vor allem sind das die Daten über den generellen Beachtungszustand
#       von GPUs und Algorithmen.
#       GPUs könen als ENABLED (1) oder DISABLED (0) gesetzt werden
#       Algorithmen können ebenfalls als "Disabled" geführt werden mit einem Eintrag "AlgoDisabled:$algoName"
source ./gpu-abfrage.sh

#
# Wir schalten jetzt die GPU-Abfragen ein, wenn sie nicht schon laufen...
# ---> Müssen auch dara denken, sie zu stoppen, wenn die GPU DISABLED wird <---
for lfdUuid in "${!uuidEnabledSOLL[@]}"; do
    if [ ${uuidEnabledSOLL[${lfdUuid}]} -eq 1 ]; then
        if [ ! -f ${lfdUuid}/gpu_gv-algo.pid ]; then
            cd ${lfdUuid}
            echo "GPU #$(< gpu_index.in): Starting process in the background..."
            ./gpu_gv-algo.sh &
            cd -
        fi
    fi
done
             
#
# Dann starten wir die algo_multi_abfrage.sh, wenn sie nicht schon läuft...
#
if [ ! -f algo_multi_abfrage.pid ]; then
    echo "Starting algo_multi_abfrage.sh in the background..."
    ./algo_multi_abfrage.sh &
fi

###############################################################################################
#
# Einlesen des bisherigen RUNNING Status
#
###############################################################################################
# Wer diese Datei schreiben oder lesen will, muss auf das Verschwinden von *.lock warten...
while [ -f ${RUNNING_STATE}.lock ]; do
    echo "Waiting for READ access to ${RUNNING_STATE}"
    sleep 1
done
# Zum Lesen reservieren
echo $$ >${RUNNING_STATE}.lock

_read_in_actual_RUNNING_STATE

# Und wieder freigeben
rm -f ${RUNNING_STATE}.lock

# Folgende Arrays stehen uns jetzt zur Verfügung, die uns sagen, welche GPU seit den
# vergangenen 31s mit welchem Algorithmus und welchem Watt-Konsum laufen sollte,
# ob sie ENABLED WAR und mit welchem GPU-Index sie "damals" gestartet wurde.
# Auf all diese Informationen haben wir über die UUID Zugriff.
#      RunningGPUid[ $UUID ]=${RunningGPUidx}    GPU-Index
#      WasItEnabled[ $UUID ]=${GenerallyEnabled} (0/1)
#      RunningWatts[ $UUID ]=${Watt}             Watt
#      WhatsRunning[ $UUID ]=${RunningAlgo}      AlgoName
unset SUM_OF_RUNNING_WATTS; declare -i SUM_OF_RUNNING_WATTS=0

unset lfdUUID
if [[ ${#RunningGPUid[@]} -gt 0 ]]; then
    for lfdUUID in ${!RunningGPUid[@]}; do
        if [[ ${WasItEnabled[$lfdUUID]} == 1 ]]; then
            SUM_OF_RUNNING_WATTS+=${RunningWatts[$lfdUUID]}
        fi
    done
fi
# Ausgabe besser weiter unten, dass zusammen mit den anderen beiden Angaben sichtbar ist.
# Die Hintergrundprozesse posten ihren Output einfach frech dazwischen, so dass diese Zeilen,
# die über die momentanen Leistungsverhältnisse aufklären, nicht untereinander stehen könnten.
#printf "         Sum of actually running WATTS: %5dW\n" ${SUM_OF_RUNNING_WATTS}

###############################################################################################
# (26.10.2017)
# Vor dem Einlesen der Werte aus dem SMARTMETER, um u.a. SolarWattAvailable berechnen zu können,
# warten wir erst mal, bis alle ENABLED GPUs ihre Dateien ALGO_WATTS_MINES.in geschrieben haben.
# Darin enthalten sind die Watt-Angaben und die BTC "Mines", die sie produzieren würden,
# wenn sie laufen würden.
# Wir warten darauf, dass das Modification Date der Datei ALGO_WATTS_MINES.in größer oder gleich
# dem des SYNCFILE ist.
# Wir haben auch die Anzahl ENABLED GPUs und die UUIDs in dem Array uuidEnabledSOLL
#
# Erst, wenn alle Kurse bekannt sind und wir die optimale Konfiguration durchrechnen können,
# bestimmen wir den momentanen "Strompreis" anhand der Daten aus dem SMARTMETER

while [ ! -f ${SYNCFILE} ]; do
    echo "$(basename $0): ###---> Waiting for ${SYNCFILE} to become available..."
    sleep 1
done
declare -i new_Data_available=$(stat -c %Y ${SYNCFILE})
while [ 1 == 1 ]; do
    declare -i AWMTime=new_Data_available+3600
    for UUID in ${!uuidEnabledSOLL[@]}; do
        if [ ${uuidEnabledSOLL[${UUID}]} -eq 1 ]; then
            declare -i gpuTime=$(stat -c %Y ${UUID}/ALGO_WATTS_MINES.in)
            if [ $gpuTime -lt $AWMTime ]; then AWMTime=gpuTime; fi
        fi
    done
    if [ $AWMTime -lt $new_Data_available ]; then
        echo "Waiting for all GPUs to calculate their ALGO_WATTS_MINES.in"
        sleep 1
    else
        break
    fi
done


#  Das neue "Alter" von ${SYNCFILE} in der Variablen ${new_Data_available} merken für später.
#  Die GPUs haben schon losgelegt, das heisst, dass SYNCFILE da ist und in etwa 31s neu getouched wird
# new_Data_available=$(date --utc --reference=${SYNCFILE} +%s)

###############################################################################################
#
#    EINLESEN ALLER ALGORITHMEN, WATTS und MINES, AUF DIE WIR GERADE GEWARTET HABEN
#
# In dieser Datei hat die jeweilige GPU jetzt aber ALL ihre Algos,
#           die dabei verbrauchten Watts
#           und die "Mines" in BTC, die sie dabei errechnet, festgehalten:
# ALGO_WATTS_MINES.in
# Und kann wie üblich über readarray eingelesen werden.

#
# Und wir speichern diese in einem Array-Drilling, der immer synchron zu setzen ist:
#     GPU{realer_gpu_index}Algos[]                 also u.a.  GPU5Algos[]
#     GPU{realer_gpu_index}Watts[]                 also u.a.  GPU5Watts[]
#     GPU{realer_gpu_index}Mines[]                 also u.a.  GPU5Mines[]
#
# Wenn zur Zeit mehrere Algos für eine GPU möglich sind, sieht das z.B. so aus im Fall von 3 Algos:
#     GPU{realer_gpu_index}Algos[0]="cryptonight"  also u.a.  GPU5Algos[0]="cryptonight"
#                               [1]="equihash"                         [1]="equihash"
#                               [2]="daggerhashimoto"                  [2]="daggerhashimoto"
#     GPU{realer_gpu_index}Watts[0]="55"           also u.a.  GPU5Watts[0]="55"
#                               [1]="104"                              [1]="104"    
#                               [2]="98"                               [2]="98"
#     GPU{realer_gpu_index}Mines[0]=".00011711"    also u.a.  GPU5Mines[0]=".00011711"
#                               [1]=".00017009"                        [1]=".00017009"    
#                               [2]=".00013999"                        [2]=".00013999"
#
for (( idx=0; $idx<${#index[@]}; idx++ )); do
    declare -n actGPUAlgos="GPU${index[$idx]}Algos"
    declare -n actAlgoWatt="GPU${index[$idx]}Watts"
    declare -n actAlgoMines="GPU${index[$idx]}Mines"

    if [ -s ${uuid[${index[$idx]}]}/ALGO_WATTS_MINES.in ]; then
        unset READARR
        readarray -n 0 -O 0 -t READARR <${uuid[${index[$idx]}]}/ALGO_WATTS_MINES.in
        for ((i=0; $i<${#READARR[@]}; i+=3)) ; do
            actGPUAlgos=(${actGPUAlgos[@]}   "${READARR[$i]}")
            actAlgoWatt=(${actAlgoWatt[@]}   "${READARR[$i+1]}")
            actAlgoMines=(${actAlgoMines[@]} "${READARR[$i+2]}")
        done
    fi
done

###############################################################################################
#
#     EINLESEN der STROMPREISE in BTC
#
# In algo_multi_abfrage.sh, die vor Kurzem gelaufen sein muss,
# werden die EUR-Strompreise in BTC-Preise umgewandelt.
# Diese Preise brauchen wir in BTC, um die Kosten von den errechneten "Mines" abziehen zu können.
#
unset kwh_BTC; declare -A kwh_BTC
for ((grid=0; $grid<${#GRID[@]}; grid+=1)); do
    # ACHTUNG. DAS MUSS AUF JEDEN FALL EIN MAL PRO Preiseermittlungslauf LAUF GEMACHT WERDEN!!!
    # IST NUR DER BEQUEMLICHKEIT HALBER IN DIESE <GRID> SCHLEIFE GEPACKT,
    # WEIL SIE NUR 1x DURCHLÄUFT
    # Die in BTC umgerechneten Strompreise für die Vorausberechnungen später
    kwh_BTC[${GRID[$grid]}]=$(< kWh_${GRID[$grid]}_Kosten_BTC.in)
done
# AUSNAHME BIS GEKLÄRT IST, WAS MIT DEM SOLAR-AKKU ZU TU IST, hier nur diese beiden Berechnungen
kWhMax=${kwh_BTC["netz"]}
kWhMin=${kwh_BTC["solar"]}
kWhAkk=${kwh_BTC["solar_akku"]}

##################################################################################
##################################################################################
#
#     EINLESEN SMARTMETER und BERECHNEN VON SolarWattAvaiable
#
# Irgendwann brauchen wir irgendwoher den aktuellen Powerstand aus dem Smartmeter
# w3m "http://192.168.6.170/solar_api/blabla..." > smartmeter
#          "PowerReal_P_Sum" : 20.0,
# kW=$( grep PowerReal_P_Sum smartmeter | gawk '{print substr($3,1,index($3,".")-1)}' ) ergibt Integer Wattzahl
#
# Jetzt können wir den aktuellen Verbrauch aller Karten von kW abziehen, um zu sehen, ob wir uns
#     im "Einspeisemodus" befinden.
#     (${kW} - ${ActuallyRunningWatts}) < 0 ? SolarWatt=$(expr ${ActuallyRunningWatts} - ${kW} )
#
###                                                                            ###
### FALLS ES ALSO "solar" Power gibt, wird die Variable SolarWattAvailable > 0 ###
### Die Berechnungen stimmen so oder so. Auch für den Fall, dass es keine      ###
### "solar" Power gibt, was durch SolarWattAvailable=0 ausgedrückt wird.       ###
###                                                                            ###

PHASE=PowerReal_P_Phase_1
PHASE=PowerReal_P_Phase_2
PHASE=PowerReal_P_Phase_3
PHASE=PowerReal_P_Sum

declare -i ACTUAL_SMARTMETER_KW
declare -i SolarWattAvailable=0

if [ ! $NoCards ]; then
    # Datei smartmeter holen
    w3m "http://192.168.6.170/solar_api/v1/GetMeterRealtimeData.cgi?Scope=Device&DeviceId=0&DataCollection=MeterRealtimeData" > smartmeter
fi
    
printf "         Sum of actually running WATTS: %5dW\n" ${SUM_OF_RUNNING_WATTS}

# ABFRAGE PowerReal_P_Sum
ACTUAL_SMARTMETER_KW=$(grep $PHASE smartmeter | gawk '{print substr($3,0,index($3,".")-1)}')
printf "Aktueller Verbrauch aus dem Smartmeter: %5dW\n" ${ACTUAL_SMARTMETER_KW}

if [[ $((${ACTUAL_SMARTMETER_KW} - ${SUM_OF_RUNNING_WATTS})) -lt 0 ]]; then
    SolarWattAvailable=$(expr ${SUM_OF_RUNNING_WATTS} - ${ACTUAL_SMARTMETER_KW})    
fi
printf "                 Verfügbare SolarPower: %5dW\n" ${SolarWattAvailable}

###############################################################################################
#
# Jetzt wollen wir die Arrays zur Berechnung des optimalen Algo pro Karte mit den Daten füllen,
# die wir für diese Berechnung brauchen.
#
# Folgendes ist noch wichtig:
#
# 1. Der Fall "solar_akku" ist überhaupt noch nicht in diese Überlegungen einbezogen worden.
#    Bis her brauchen wir nur aktiv zu werden, wenn "solar" ins Spiel kommt.
#    Wie das dann zu berechnen ist, haben wir tief durchdacht.
#    Nicht aber, wie "solar_akku" da hineinspielt.
#    ---> DESHALB NEHMEN WIR DIE 3. SCHLEIFE EINFACH MAL WEG !!! <---
#
# 2. Beste Algorithmen, die nur etwas kosten (GV<0) lassen wir gleich weg.
#    Das bedeutet, dass die GPU unverzüglich anzuhalten ist,
#    wenn diese GPU nicht mehr durch einen anderen Algo im Array vertreten ist!
#    Der entsprechende Array-Drilling hat dann keinerlei Members, was wir daran erkennen,
#        dass die Anzahl Array-Members oder die "Länge" der Arrays
#        ${#GPU{realer_gpu_index}Algos/Watts/Mines} gleich 0 ist.
#             also z.B.  GPU3Algos[]
#             also z.B.  GPU3Watts[]
#             also z.B.  GPU3Mines[]
#




# Voraussetzungen, die noch geklärt werden müssen:
# 1. Wir brauchen jetzt natürlich Informationen aus dem SMARTMETER
# 2. Und wir brauchen eine Datenstruktur, anhand der wir erkennen, welche GPU's gerade mit welchem Algo laufen.

# Jetzt geht's los:
# Jetzt brauchen wir alle möglichen Kombinationen aus GPU-Konstellationen:
# Jeder mögliche Algo wird mit allen anderen möglichen Kombinationen berechnet.
# Wir errechnen die jeweilige max. BTC-Generierung pro Kombination
#     und den entsprechenden Gesamtwattverbrauch.
# Anhand des Gesamtwattverbrauchs der Kombination errechnen wir die Gesamtkosten dieser Kombination
#     unter Berücksichtigung eines entsprechenden "solar" Anteils, wodurch die Kosten sinken.
# Die Kombination mit dem besten GV-Verhältnis merken wir uns jeweils in MAX_PROFIT und MAX_PROFIT_GPU_Algo_Combination

# Im Groben brauchen wir folgendes Datenfeld für angenommene 2 Algos pro GPU, die sinnvoll sind:
# (Die Routine ist natürlich so ausgelegt, dass beliebig viele Algos pro GPU möglich sind.
#  Die Anzahl der möglichen Kombinationen steigt mit jeder GPU und jedem weiteren Algo EXPONENTIELL an)
#
# GV-Kombi-0,0,0 ... 0:
# GPU#0:Algo[0]     GPU#1:Algo[0]     GPU#2:Algo[0] ...  GPU#10:Algo[0]
#       Watt[0]  +        Watt[0]  +        Watt[0] ... +       Watt[0]  =  Gesamtwatt-Kombi-0
#       BTCs[0]  +        BTCs[0]  +        BTCs[0] ... +       BTCs[0]  =  GesamtBTCs-Kombi-0
#
# GV-Kombi-0,0,0 ... 1:
# GPU#0:Algo[0]     GPU#1:Algo[0]     GPU#2:Algo[0] ...  GPU#10:Algo[1]
#       Watt[0]  +        Watt[0]  +        Watt[0] ... +       Watt[1]  =  Gesamtwatt-Kombi-1
#       BTCs[0]  +        BTCs[0]  +        BTCs[0] ... +       BTCs[1]  =  GesamtBTCs-Kombi-1
#
# GV-Kombi-0,0 ... 1,0:
# GPU#0:Algo[0]     GPU#1:Algo[0]     GPU#2:Algo[1] ...  GPU#10:Algo[0]
#       Watt[0]  +        Watt[0]  +        Watt[1] ... +       Watt[0]  =  Gesamtwatt-Kombi-2
#       BTCs[0]  +        BTCs[0]  +        BTCs[1] ... +       BTCs[0]  =  GesamtBTCs-Kombi-2
#
# GV-Kombi-0,0 ... 1,1:
# GPU#0:Algo[0]     GPU#1:Algo[0]     GPU#2:Algo[1] ...  GPU#10:Algo[1]
#       Watt[0]  +        Watt[0]  +        Watt[1] ... +       Watt[1]  =  Gesamtwatt-Kombi-3
#       BTCs[0]  +        BTCs[0]  +        BTCs[1] ... +       BTCs[1]  =  GesamtBTCs-Kombi-3
#
# ...
#
# GV-Kombi-1,1 ... 1,0:
# GPU#0:Algo[1]     GPU#1:Algo[1]     GPU#2:Algo[1] ...  GPU#10:Algo[0]
#       Watt[1]  +        Watt[1]  +        Watt[1] ... +       Watt[0]  =  Gesamtwatt-Kombi-2 hoch 11 - 1
#       BTCs[1]  +        BTCs[1]  +        BTCs[1] ... +       BTCs[0]  =  GesamtBTCs-Kombi-2 hoch 11 - 1
#
# GV-Kombi-1,1 ... 1,1:
# GPU#0:Algo[1]     GPU#1:Algo[1]     GPU#2:Algo[1] ...  GPU#10:Algo[1]
#       Watt[1]  +        Watt[1]  +        Watt[1] ... +       Watt[1]  =  Gesamtwatt-Kombi-2 hoch 11
#       BTCs[1]  +        BTCs[1]  +        BTCs[1] ... +       BTCs[1]  =  GesamtBTCs-Kombi-2 hoch 11
#
# Bei 11 GPUs und je 2 Algorithmen sind das 2 hoch 11 Kombinationen: 2048
#

#####################################################################################################
#
#     DAS IST EIN EXTREM WICHTIGES VARIABLENPAAR:
#     MAX_PROFIT und MAX_PROFIT_GPU_Algo_Combination
#
# Die Berechnungen schieben gleich den maximalen Gewinn immer höher und merken sich die Kombination.
#     Bei jeder gültigen Berechnung lassen wir die Variable MAX_PROFIT von ".0" aus hochfahren
#     und halten jedes mal die Kombination aus GPU's und Algo's fest in MAX_PROFIT_GPU_Algo_Combination
#     in der Form '${gpu_idx}:${algoIdx},'. Bei mehreren GPUs wird der String länger.
#
# --> DAS IST FÜR SPÄTERES FEINTUNING: <--
# Wir können das auch noch weiter verfeinern, wenn wir Kombinationen mit GLEICHEM Gewinn
#     darauf hin untersuchen, welche "effektiver" ist, welche z.B. bei gleichem Gewinn den minimalsten Strom
#     verbraucht und diesen dann vorziehen.

MAX_PROFIT=".0"
MAX_PROFIT_GPU_Algo_Combination=''

echo "=========  GPU Einzelberechnungen  ========="
echo "Ermittlung aller gewinnbringenden Algorithmen durch Berechnung:"
echo "Jede GPU für sich betrachtet, wenn sie als Einzige laufen würde"
echo "UND Beginn der Ermittlung und des Hochfahrens von MAX_PROFIT !"
if [ ${verbose} == 1 ]; then
    echo "Damit sparen wir uns später den Fall '1 GPU aus MAX_GOOD möglichen GPUs' und können gleich mit 2 beginnen!"
fi

# Die meisten der folgenden Arrays, die wir erstellen werden, sind nichts weiter als eine Art "View"
# auf die GPU{realer_gpu_index}Algos/Watts/Mines Arrays, die die Rohdaten halten und
#     die diese Rohdaten NUR dort halten.
# Die meisten der folgenden Arrays sind also Hilfs-Arrays oder "Zwischenschritt"-Arrays, die immer
#     irgendwie mit den Rohdaten-Arrays synchron gehalten werden, damit man immer auch sofort
#     auf die Rohdaten zugreifen kann, wenn man sie braucht.
# Meistens enthalten diese Arrays nur den realen GPU-Index, der in dem Namen der Rohdaten-Arrays steckt,
#     z.B. "4"  für  "GPU4Algos"
#
# Ermittlung derjenigen GPU-Indexes, die
# 1. auszuschalten sind in dem Array SwitchOffGPUs[]
#    z.B. hatte das GPU3Algos/Watts/Mines Array-Gespann von oben 0 Member und wäre dann in diesem
#         Array SwitchOffGPUs[] enthalten:
#         SwitchOffGPUs[0]="3"
#
# 2. mit mindestens einem Algo im Gewinn betrieben werden könnten.
#    Der Algo, der letztlich tatsächlich laufen soll, wird durch "Ausprobieren" der Kombinationen mit
#    den Algos der anderen GPUs ermittelt in oder über das Array PossibleCandidateGPUidx[]
#    z.B. hatte das GPU5Algos/Watts/Mines Array-Gespann von oben 3 Member und wäre dann in diesem
#         Array PossibleCandidateGPUidx[] enthalten:
#         PossibleCandidateGPUidx[0]="5"
#
#    Und auf die gewinnbringenden Algos dieser GPU können wir zugreifen, indem wir uns die Index-Nummern
#        der Algorithmen merken, die Gewinn machen; in dem weiteren Hilfs/View-Array
#        PossibleCandidate${ "5" }AlgoIndexes[]
#        z.B. hatte das GPU5Algos/Watts/Mines Array-Gespann von oben die 3 Member
#             GPU5Algos[0]="cryptonight"
#                      [1]="equihash"
#                      [2]="daggerhashimoto"
#        Nehmen wir an, dass nur "cryptonight" keinen Gewinn machen würde, dann wären die gewinnbringenden
#             Algo-Indexes der GPU#5 also
#                      [1]="equihash"
#             und      [2]="daggerhashimoto"
#        Deswegen würden wir uns in dem Hilfs-Array PossibleCandidate${ "5" }AlgoIndexes[] diese beiden
#             Algo-Indexes merken, wodurch es dann so aussehen würde:
#             PossibleCandidate5AlgoIndexes[0]="1"
#             PossibleCandidate5AlgoIndexes[1]="2"
#
#    Und um uns die Arbeit in den späteren Schleifen leichter zu machen, merken wir uns noch die Anzahl
#        der gewinnbringenden Algos dieser GPU in dem
#        (weiteren zu PossibleCandidateGPUidx[0] synchronen Hilfs-) Array
#        exactNumAlgos[5]=2
#

# Die folgenden beiden Arrays halten nur GPU-Indexnummern als Werte. Nichts weiter!
# Wir bauen diese Arrays jetzt anhand der Kriterien aus den Rohdaten-Arrays in einer
#     alle im System befindlichen GPUs durchgehenden Schleife auf.
unset SwitchOffGPUs
declare -a SwitchOffGPUs           # GPUs anyway aus, keine gewinnbringenden Algos zur Zeit
unset PossibleCandidateGPUidx
declare -a PossibleCandidateGPUidx # GPUs mit mindestens 1 gewinnbringenden Algo.
                                   # Welcher es werden soll, muss errechnet werden
           # gefolgt von mind. 1x declare -a "PossibleCandidate${gpu_index}AlgoIndexes" ...
unset exactNumAlgos
declare -a exactNumAlgos  # ... und zur Erleichterung die Anzahl Algos der entsprechenden "PossibleCandidate" GPU's

for (( idx=0; $idx<${#index[@]}; idx++ )); do
    declare -n actGPUAlgos="GPU${index[$idx]}Algos"
    declare -n actAlgoWatt="GPU${index[$idx]}Watts"
    declare -n actAlgoMines="GPU${index[$idx]}Mines"

    numAlgos=${#actGPUAlgos[@]}
    # Wenn die GPU seit neuestem generell DISABLED ist, pushen wir sie hier auf den
    # SwitchOffGPUs Stack, indem wir die numAlgos künslich auf 0 setzen:
    if [[ "${uuidEnabledSOLL[${uuid[${index[$idx]}]}]}" == "0" ]]; then
        numAlgos=0
    fi
    case "${numAlgos}" in

        "0")
            # Karte ist auszuschalten. Kein (gewinnbringender) Algo im Moment
            # (Noch haben wir die Gewinne nicht ausgerechnet!)
            SwitchOffGPUs=(${SwitchOffGPUs[@]} ${index[$idx]})
            ;;

        *)
            # GPU kann mit mindestens einem Algo laufen.
            # Wir filtern jetzt noch diejenigen Algorithmen raus, die unter den momentanen Realen
            # Verhältnissen KEINEN GEWINN machen werden, wenn sie allein, also ohne "Konkrrenz" laufen würden.
            # Gleichzeitig halten wir von denen, die Gewinn machen, denjenigen Algo fest,
            # der den grössten Gewinn macht.
            # Wir lassen jetzt schon MAX_PROFIT und die entsprechende Kombiantion aus GPU und Algo hochfahren.
            # Damit sparen wir uns später diesen Lauf mit 1 GPU, weil der auch kein anderes Ergebnis
            # bringen wird!
            unset profitableAlgoIndexes; declare -a profitableAlgoIndexes

            for (( algoIdx=0; $algoIdx<${numAlgos}; algoIdx++ )); do
                _calculate_ACTUAL_REAL_PROFIT_and_set_MAX_PROFIT \
                    ${SolarWattAvailable} ${actAlgoWatt[$algoIdx]} "${actAlgoMines[$algoIdx]}"
                # Wenn das NEGATIV ist, muss die Karte übergangen werden. Uns interessieren nur diejenigen,
                # die POSITIV sind und später in Kombinationen miteinander verglichen werden müssen.
                if [[ ! $(expr index "${ACTUAL_REAL_PROFIT}" "-") == 1 ]]; then
                    profitableAlgoIndexes=(${profitableAlgoIndexes[@]} ${algoIdx})
                fi
                if [[ ! "${MAX_PROFIT}" == "${OLD_MAX_PROFIT}" ]]; then
                    MAX_PROFIT_GPU_Algo_Combination="${index[$idx]}:${algoIdx},"
                    echo "New Maximum Profit ${MAX_PROFIT} with GPU:AlgoIndexCombination ${MAX_PROFIT_GPU_Algo_Combination}"
                fi
            done

            profitableAlgoIndexesCnt=${#profitableAlgoIndexes[@]}
            if [[ ${profitableAlgoIndexesCnt} -gt 0 ]]; then
                PossibleCandidateGPUidx=(${PossibleCandidateGPUidx[@]} ${index[$idx]})
                exactNumAlgos[${index[$idx]}]=${profitableAlgoIndexesCnt}
                # Hilfsarray für AlgoIndexe vor dem Neuaufbau immer erst löschen
                declare -n deleteIt="PossibleCandidate${index[$idx]}AlgoIndexes";    unset deleteIt
                declare -ag "PossibleCandidate${index[$idx]}AlgoIndexes"
                declare -n actCandidatesAlgoIndexes="PossibleCandidate${index[$idx]}AlgoIndexes"
                # Array kopieren
                actCandidatesAlgoIndexes=(${profitableAlgoIndexes[@]})
            else
                # Wenn kein Algo übrigbleiben sollte, GPU aus.
                SwitchOffGPUs=(${SwitchOffGPUs[@]} ${index[$idx]})
            fi
            ;;

    esac
done

if [ ${verbose} == 1 ]; then
    # Auswertung zur Analyse
    if [[ ${#PossibleCandidateGPUidx[@]} -gt 0 ]]; then
        unset gpu_string
        for (( i=0; $i<${#PossibleCandidateGPUidx[@]}; i++ )); do
            gpu_string+="#${PossibleCandidateGPUidx[$i]} with ${exactNumAlgos[${PossibleCandidateGPUidx[$i]}]} Algos, "
        done
        echo "GPU Kandidaten mit Gewinn bringenden Algos: ${gpu_string%, }"
    fi
    if [[ ${#SwitchOffGPUs[@]} -gt 0 ]]; then
        unset gpu_string
        for (( i=0; $i<${#SwitchOffGPUs[@]}; i++ )); do
            gpu_string+="#${SwitchOffGPUs[$i]}, "
        done
        echo "Switch OFF GPU's ${gpu_string%, }"
    fi
    if [[ ${verbose} == 1 ]]; then
        echo "Summe SwitchOffGPUs + PossibleCandidateGPUidx = $((${#PossibleCandidateGPUidx[@]}+${#SwitchOffGPUs[@]}))"
        echo "Anzahl System-GPUs                            = ${#index[@]}"
    fi
fi

echo "=========  Gesamtsystemberechnung  ========="

# Für die Mechanik der systematischen GV-Werte Ermittlung
# Hilfsarray testGPUs, das die "GPU${idx}Algos/Watts/Mines" Algos/Watts/Mines indexiert
unset MAX_GOOD_GPUs; declare -i MAX_GOOD_GPUs  # Wieviele GPUs haben mindestens 1 möglichen Algo

# Die folgenden 3 Variablen werden bei jedem Aufruf von _CALCULATE_GV_of_all_TestCombinationGPUs_members
# neu gesetzt und verwendet. (Vorletzte "Schale")
unset MAX_GPU_TIEFE; declare -i MAX_GPU_TIEFE  # Wieviele dieser GPUs sollen berechnet werden
unset lfdGPU; declare -i lfdGPU                # Laufender Zähler analog dem meist verwendeten $i
unset testGPUs; declare -A testGPUs            # Test-Zähler-Stellwerk

# Diese Nummer bildet die globale, die äusserste, letzte "Schale", von der aus die anderen gestartet/verwendet werden
unset numGPUs; declare -i numGPUs

MAX_GOOD_GPUs=${#PossibleCandidateGPUidx[@]}

if [[ ${MAX_GOOD_GPUs} -gt 1 ]]; then      # Den Fall für 1 GPU allein haben wir ja schon ermittelt.

    # Bei zu wenig Solarpower könnte das ins Minus rutschen...
    #     [ DAS MÜSSEN WIR NOCH CHECKEN, OB DAS WIRKLICH SICHTBAR WIRD ]
    # Deshalb werden wir auch noch Kombinationen mit weniger als der vollen Anzahl an gewinnbringenden GPUs
    #     durchrechnen.
    # Dazu entwickeln wir eine rekursive Funktion, die ALLE möglichen Kombinationen
    #     angefangen mit jeweils EINER laufenden von MAX_GOOD_GPUs
    #     über ZWEI laufende von MAX_GOOD_GPUs
    #     bis hin zu ALLEN laufenden MAX_GOOD_GPUs.
    #
    # numGPUss:        Anzahl zu berechnender GPU-Kombinationen mit numGPUss GPU's
    # Diese Zeile berechnet ALLE ÜBERHAUPT DENKBAREN MÖGLICHEN KOMBINATIONEN
    # for (( numGPUs=1; $numGPUs<${MAX_GOOD_GPUs}; numGPUs++ )); do
    #
    echo "MAX_GOOD_GPUs: ${MAX_GOOD_GPUs} bei SolarWattAvailable: ${SolarWattAvailable}"
    for (( numGPUs=2; $numGPUs<=${MAX_GOOD_GPUs}; numGPUs++ )); do
        # Parameter: $1 = maxTiefe
        #            $2 = Beginn Pointer1 bei Index 0
        #            $3 = Ende letzter Pointer 5
        #            $4-  Jede Ebene hängt dann ihren aktuellen Wert in der Schleife hin,
        #                 in der sie sich selbst gerade befindet.
        endStr="GPU von ${MAX_GOOD_GPUs} läuft:"
        if [[ ${numGPUs} -gt 1 ]]; then endStr="GPUs von ${MAX_GOOD_GPUs} laufen:"; fi
        echo "Berechnung aller Kombinationen des Falles, dass nur ${numGPUs} ${endStr}"
        _CREATE_AND_CALCULATE_EVERY_AND_ALL_SUBSEQUENT_COMBINATION_CASES \
            ${MAX_GOOD_GPUs} 0 $((${MAX_GOOD_GPUs} - ${numGPUs} + 1))
    done

fi  # if [[ ${MAX_GOOD_GPUs} -gt 0 ]]; then

################################################################################
#
#                Die Auswertung der optimalen Kombination
#
################################################################################

printf "=========       Endergebnis        =========\n"

# Wer diese Datei schreiben oder lesen will, muss auf das Verschwinden von *.lock warten...
while [ -f ${RUNNING_STATE}.lock ]; do
    echo "Waiting for WRITE access to ${RUNNING_STATE}"
    sleep 1
done
# Zum Schreiben reservieren
echo $$ >${RUNNING_STATE}.lock

#####################################################
# Ausgabe des neuen Status
####################################################

printf 'UUID : GPU-Index : Enabled (1/0) : Watt : Running with AlgoName or Stopped if \"\"\n' >${RUNNING_STATE}
printf '================================================================================\n'  >>${RUNNING_STATE}

# Man könnte noch gegenchecken, dass die Summe aus laufenden und abgeschalteten
#     GPU's die Anzahl GPU's ergeben muss, die im System sind.
# Es gibt ja ${MAX_GOOD_GPUs}, ${SwitchOnCnt}, ${SwitchOffCnt} und ${GPUsCnt}
# Es müsste gelten: ${MAX_GOOD_GPUs} + ${SwitchOffCnt} == ${GPUsCnt}
#              und: ${MAX_GOOD_GPUs} >= ${SwitchOnCnt},
#                   da möglicherweise die beste Kombination aus weniger als ${MAX_GOOD_GPUs} besteht.
# Dann hätten wir diejenigen ${MAX_GOOD_GPUs} - ${SwitchOnCnt} noch zu überprüfen und zu stoppen !?!?

_decode_MAX_PROFIT_GPU_Algo_Combination_to_GPUINDEXES

declare -i SwitchOnCnt=${#GPUINDEXES[@]}
declare -i GPUsCnt=${#index[@]}
declare -i NewLoad=0

if [[ ${verbose} == 1 ]]; then
    echo "Die optimale Konfiguration besteht aus diesen ${SwitchOnCnt} Karten:"
fi
###                                                             ###
#   Zuerst die am Gewinn beteiligten GPUs, die laufen sollen...   #
###                                                             ###
for (( i=0; $i<${SwitchOnCnt}; i++ )); do
    # Split the "String" at ":" into the 2 variables "gpu_idx" and "algoidx"
    read gpu_idx algoidx <<<"${GPUINDEXES[$i]//:/ }"

    # Ausfiltern der Guten GPUs aus PossibleCandidateGPUidx.
    # PossibleCandidateGPUidx enthält dann zum Schluss nur noch ebenfalls abzuschaltende GPUs
    # ${gpu_idx} ausfiltern durch Neu-Initialisierung des Arrays, wobei ${gpu_idx} durch '' ersetzt wird
    #            und damit einfach nicht mit ausgegeben und also nicht mehr im neuen Array enthalten ist.
    PossibleCandidateGPUidx=(${PossibleCandidateGPUidx[@]/${gpu_idx}/})

    declare -n actGPUalgoName="GPU${gpu_idx}Algos"
    declare -n actGPUalgoWatt="GPU${gpu_idx}Watts"
    gpu_uuid=${uuid[${gpu_idx}]}

    if [ ! ${#RunningGPUid[@]} -eq 0 ]; then
        #############################   CHAOS BEHADLUNG Anfang  #############################
        ### Schweres Thema: IST DER GPU-INDEX NOCH DER SELBE ??? <-----------------------
        #echo "\${gpu_idx}:${gpu_idx} == \${RunningGPUid[\${gpu_uuid}:${gpu_uuid}]}:${RunningGPUid[${gpu_uuid}]}"
        if [[ "${gpu_idx}" != "${RunningGPUid[${gpu_uuid}]}" ]]; then
            echo "#############################   CHAOS BEHADLUNG   #############################"
            echo "Das gesamte System muss möglicherweise gestoppt und neu gestartet werden:"
            echo "Wir sind auf die Karte mit der UUID=${gpu_uuid} gestossen."
            echo "Sie lief bisher mit einem Miner, der sie als GPU-Index #${RunningGPUid[${gpu_uuid}]} angesprochen hat."
            echo "Jetzt soll sie aber ein Miner mit dem Index ${gpu_idx} ansprechen ???"
            echo "Was also ist mit dem Miner, der noch die vorherige GPU-Index-Nummer #${RunningGPUid[${gpu_uuid}]} bedient?"
            echo "#############################   CHAOS BEHADLUNG   #############################"
            _notify_about_GPU_INDEX_CHANGED_WHILE_RUNNING "${name[${gpu_idx}]}" \
                                                          "${gpu_uuid}" \
                                                          "${RunningGPUid[${gpu_uuid}]}" \
                                                          "${gpu_idx}"
            exit
        fi
        #############################   CHAOS BEHADLUNG  Ende  #############################

        # Der Soll-Zustand kommt aus der manuell bearbeiteten Systemdatei ganz am Anfang
        # Wir schalten auf jeden Fall den gewünschten Soll-Zustand.
        # Eventuell müssen wir mit dem letzten Run-Zustand vergleichen, um etwas zu stoppen...
        printf "${gpu_uuid}:${gpu_idx}:${uuidEnabledSOLL[${gpu_uuid}]}:" >>${RUNNING_STATE}

        # Ist die GPU generell Enabled oder momentan nicht zu behandeln?
        if ((${WasItEnabled[${gpu_uuid}]} == 1)); then
            #
            # Die Karte WAR generell ENABLED
            #
            if [[ ${uuidEnabledSOLL[${gpu_uuid}]} == 1 ]]; then

                #
                # Die Karte BLEIBT generell ENABLED
                #
                ########################################################
                ### START- STOP- SWITCHING- Skripte.
                ### Hier ist die richtige Stelle, die Miner zu switchen
                ########################################################

                ### Lief die Karte mit dem selben Algorithmus?
                if [[ "${WhatsRunning[${gpu_uuid}]}" != "${actGPUalgoName[${algoidx}]}" ]]; then
                    if [[ -z "${WhatsRunning[${gpu_uuid}]}" ]]; then
                        # MINER- Behandlung
                        echo "---> SWITCH-CMD: GPU#${gpu_idx} EINSCHALTEN mit Algo \"${actGPUalgoName[${algoidx}]}\""
                    else
                        # MINER- Behandlung
                        echo "---> SWITCH-CMD: GPU#${gpu_idx} Algo WECHSELN von \"${WhatsRunning[${gpu_uuid}]}\" auf \"${actGPUalgoName[${algoidx}]}\""
                    fi
                else
                    # Alter und neuer Algo ist gleich, kann weiterlaufen
                    echo "---> SWITCH-NOT: GPU#${gpu_idx} BLEIBT weiterhin auf \"${actGPUalgoName[${algoidx}]}\""
                fi
                printf "${actGPUalgoWatt[${algoidx}]}:${actGPUalgoName[${algoidx}]}\n" >>${RUNNING_STATE}
                NewLoad=$(($NewLoad+${actGPUalgoWatt[${algoidx}]}))
            else
                #
                # Die Karte ist NUN generell DISABLED!
                #
                # GERADE SEHEN WIR, DASS DIE TATSACHE, DASS DIESE KARTE MIT IN DIE BERECHNUNGEN
                # EINBEZOGEN WURDE, SINNLOS WAR!
                # Wir müssen im Anschluss überlegen, wo wir das abzuchecken haben, BEVOR
                # wir mit den Berechnungen beginnen.
                # Dann wird dieser Fall hier GAR NICHT MEHR VORKOMMEN <---   NOCH ZU IMPLEMENTIEREN
                # MINER- Behandlung
                echo "---> SWITCH-OFF: GPU#${gpu_idx} wurde generell DISABLED und ist abzustellen!"
                echo "---> SWITCH-OFF: Sie läuft noch mit \"${WhatsRunning[${gpu_uuid}]}\""
                printf "0:\n" >>${RUNNING_STATE}
            fi
        else
            #
            # Die Karte WAR generell DISABLED
            #
            if [[ "${uuidEnabledSOLL[${gpu_uuid}]}" == "1" ]]; then
                #
                # Die Karte IST NUN generell ENABLED
                #
                ########################################################
                ### START- STOP- SWITCHING- Skripte.
                ### Hier ist die richtige Stelle, die Miner zu switchen
                ########################################################
                # MINER- Behandlung
                echo "---> SWITCH-CMD: GPU#${gpu_idx} EINSCHALTEN mit Algo \"${actGPUalgoName[${algoidx}]}\""
                printf "${actGPUalgoWatt[${algoidx}]}:${actGPUalgoName[${algoidx}]}\n" >>${RUNNING_STATE}
                NewLoad=$(($NewLoad+${actGPUalgoWatt[${algoidx}]}))
            else
                #
                # Die Karte BLEIBT generell DISABLED
                #
                # Zeile abschliessen
                echo "---> SWITCH-NOT: GPU#${gpu_idx} BLEIBT weiterhin DISABLED"
                printf "0:\n" >>${RUNNING_STATE}
            fi
        fi
    else
        ### IM ${RUNNING_STATE} WAREN KEINERLEI EINTRÄGE.
        ### Wahrscheinlich existierte sie noch nie. Jetzt kommen AUF JEDEN FALL Einträge hinein.
        ### Wir wisseen also nichts über den laufenden Zustand und schalten deshalb einfach alles nur ein,
        ###     falls nicht eine GPU Generell DISABLED ist.
        # Den SOLL-Zustand über Generell ENABLED/DISABLED haben wir am Anfang ja eingelesen.

        if [[ "${uuidEnabledSOLL[${gpu_uuid}]}" == "1" ]]; then
            #
            # Die Karte IST generell ENABLED
            #
            ########################################################
            ### START- STOP- SWITCHING- Skripte.
            ### Hier ist die richtige Stelle, die Miner zu switchen
            ########################################################

            # MINER- Behandlung
            echo "---> SWITCH-CMD: GPU#${gpu_idx} EINSCHALTEN mit Algo \"${actGPUalgoName[${algoidx}]}\""
            printf "${gpu_uuid}:${gpu_idx}:${uuidEnabledSOLL[${gpu_uuid}]}:${actGPUalgoWatt[${algoidx}]}:${actGPUalgoName[${algoidx}]}\n" >>${RUNNING_STATE}
            NewLoad=$(($NewLoad+${actGPUalgoWatt[${algoidx}]}))
        else
            #
            # Die Karte IST generell DISABLED
            #
            # MINER- Behandlung
            echo "---> SWITCH-OFF: GPU#${gpu_idx} wurde generell DISABLED und ist abzustellen!"
            printf "${gpu_uuid}:${gpu_idx}:${uuidEnabledSOLL[${gpu_uuid}]}:0:\n" >>${RUNNING_STATE}
        fi
    fi

    if [[ ${verbose} == 1 ]]; then
        echo "GPU-Index        #${gpu_idx}"
        echo "GPU-Algo-Index   [${algoidx}]"
        echo "GPU-AlgoName     ${actGPUalgoName[${algoidx}]}"
        algoWatts=${actGPUalgoWatt[${algoidx}]}
        echo "GPU-AlgoWatt     ${algoWatts}"
        declare -n actGPUalgoMines="GPU${gpu_idx}Mines"
        algoMines=${actGPUalgoMines[${algoidx}]}
        echo "GPU-AlgoMines    ${algoMines}"
        _calculate_ACTUAL_REAL_PROFIT \
            ${SolarWattAvailable} ${algoWatts} ${algoMines}
        echo "RealGewinnSelbst ${ACTUAL_REAL_PROFIT} (wenn alleine laufen würde)"
    fi
done

# Die Guten GPUs sind raus aus PossibleCandidateGPUidx.
# PossibleCandidateGPUidx enthält jetzt nur noch ebenfalls abzuschaltende GPUs,
# die wir jetzt auf's SwitchOffGPUs Array packen
SwitchOffGPUs=(${SwitchOffGPUs[@]} ${PossibleCandidateGPUidx[@]})

###                                                             ###
#   ... dann die GPU's, die abgeschaltet werden sollen            #
###                                                             ###

declare -i SwitchOffCnt=${#SwitchOffGPUs[@]}
if [ $((${SwitchOffCnt} + ${SwitchOnCnt})) -ne ${GPUsCnt} ]; then
    echo "---> ??? Oh je, ich glaube fast, wir haben da ein paar GPU's vergessen abzuschalten ??? <---"
fi

# Auch hier kann es natürlich vorkommen, dass sich eine Indexnummer geändert hat
#      und dass dann die CHAOS-BEHANDLUNG durchgeführt werden muss.
if [ ${SwitchOffCnt} -gt 0 ]; then
    if [[ ${verbose} == 1 ]]; then
        echo "Die folgenden Karten müssen ausgeschaltet werden:"
    fi

    for (( i=0; $i<${SwitchOffCnt}; i++ )); do
        gpu_idx=${SwitchOffGPUs[$i]}
        gpu_uuid=${uuid[${gpu_idx}]}

        if [ ! ${#RunningGPUid[@]} -eq 0 ]; then
            #############################   CHAOS BEHADLUNG Anfang  #############################
            ### Schweres Thema: IST DER GPU-INDEX NOCH DER SELBE ??? <-----------------------
            if [[ "${gpu_idx}" != "${RunningGPUid[${gpu_uuid}]}" ]]; then
                echo "#############################   CHAOS BEHADLUNG   #############################"
                echo "Das gesamte System muss möglicherweise gestoppt und neu gestartet werden:"
                echo "Wir sind auf die Karte mit der UUID=${gpu_uuid} gestossen."
                echo "Sie lief bisher mit einem Miner, der sie als GPU-Index #${RunningGPUid[${gpu_uuid}]} angesprochen hat."
                echo "Jetzt soll sie aber ein Miner mit dem Index ${gpu_idx} ansprechen ???"
                echo "Was also ist mit dem Miner, der noch die vorherige GPU-Index-Nummer #${RunningGPUid[${gpu_uuid}]} bedient?"
                echo "#############################   CHAOS BEHADLUNG   #############################"
                _notify_about_GPU_INDEX_CHANGED_WHILE_RUNNING "${name[${gpu_idx}]}" \
                                                          "${gpu_uuid}" \
                                                          "${RunningGPUid[${gpu_uuid}]}" \
                                                          "${gpu_idx}"
                exit
            fi
            #############################   CHAOS BEHADLUNG  Ende  #############################

            if ((${WasItEnabled[${gpu_uuid}]} == 1)); then
                #
                # Die Karte WAR generell ENABLED
                #
                if [[ -n "${WhatsRunning[${gpu_uuid}]}" ]]; then
                    # MINER- Behandlung
                    echo "---> SWITCH-OFF: GPU#${gpu_idx} ist ABZUSTELLEN!"
                    echo "---> SWITCH-OFF: GPU#${gpu_idx} läuft noch mit \"${WhatsRunning[${gpu_uuid}]}\""
                fi
            else
                echo "---> SWITCH-NOT: GPU#${gpu_idx} BLEIBT weiterhin DISABLED"
            fi
        fi
        printf "${gpu_uuid}:${gpu_idx}:${uuidEnabledSOLL[${gpu_uuid}]}:0:\n" >>${RUNNING_STATE}
    done
fi
if [[ ${verbose} == 1 ]]; then
    echo "-------------------------------------------------"
fi

for algoName in ${!AlgoDisabled[@]}; do
    printf "AlgoDisabled:$algoName\n" >>${RUNNING_STATE}
done

# Zugriff auf die Globale Steuer- und Statusdatei wieder zulassen
rm -f ${RUNNING_STATE}.lock

echo "Neues globales Switching Sollzustand Kommandofile"
cat ${RUNNING_STATE}

if [ $NoCards ]; then
    if [[ $NewLoad -gt 0 ]]; then
        echo "         \"PowerReal_P_Sum\" : $((${ACTUAL_SMARTMETER_KW}-${SUM_OF_RUNNING_WATTS}+${NewLoad})).6099354," \
             >smartmeter
    fi
fi

while [ "${new_Data_available}" == "$(date --utc --reference=${SYNCFILE} +%s)" ] ; do
    sleep 1
done

done  ## while : 


################################################################################
#
#                      Vorläufiges ENDE des Skripts
#
################################################################################

# ./miner --cuda_dev cfg_NETZ_equihash --solver $devices --server blablub.com -u btcadrtesse -p x 

# equihash
# ./miner --server server.com --port 7777 --user name --pass secret --cuda_devices 0 1 2 3 --eexit 1

# GLOBALER miner
# -i --intensity=N[,N] GPU intensity 8.0-25.0 (default: auto) Decimals are allowed for fine tuning 
#
# -d, --devices Comma separated list of CUDA devices to use.
#
# ./ccminer -a cryptonight -o stratum+tcp://cryptonight.eu.nicehash.com:3355 -u 12X6Enpg5FBQ332Re3vjU5FAxxQWUioBMg.980ti -p 0
