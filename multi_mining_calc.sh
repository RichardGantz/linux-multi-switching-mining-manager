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

# GLOBALE VARIABLEN, nützliche Funktionen
[[ ${#_GLOBALS_INCLUDED}     -eq 0 ]] && source globals.inc
[[ ${#_MINERFUNC_INCLUDED}   -eq 0 ]] && source ${LINUX_MULTI_MINING_ROOT}/miner-func.inc

### SCREEN ADDITIONS: ###
if [ ${UseScreen} -eq 1 ]; then
    [ ${#STY} -eq 0 ] && { echo "Bitte den Multi-Miner in einer Screen-Session startet, bis er selbst tut."; exit 1 ; }
    # Es muss eine .screenrc mit diesem Namen geben, die am Ende einen detach macht.
    [ ! -s ${LINUX_MULTI_MINING_ROOT}/screen/screenrc.${BG_SESS%%.*} ] && {
	echo ${BG_SESS}
	echo "Bitte die Datei ${LINUX_MULTI_MINING_ROOT}/screen/screenrc.${BG_SESS%%.*} zur Verfügung stellen."
	exit 1
    }
fi

# Für die Ausgabe von mehr Zwischeninformationen auf 1 setzen.
# Null, Empty String, oder irgendetwas andere bedeutet AUS.
verbose=1

# Wenn debug=1 ist, werden die temporären Dateien beim Beenden nicht gelöscht.
debug=1

# Performance-Test-Werte und Bedeutung:
# 1: Sekundenzeitstempel an folgenden 8 signifikanten Stellen der Endlosschleife in Datei "perfmon.log"
#
# >1.< While Loop ENTRY"
# >2.< Startschuss: Neue Daten sind verfügbar"
# >3.< GPUs haben alle Daten geschrieben"
# >4.< Alle Algos aller GPUs sind eigelesen."
# >5.< Berechnungen beginnen mit Einzelberechnungen"
# >6.< Beginn mit der Gesamtsystemberechnung"
# >7.< Auswertung und Miner-Steuerungen"
# >8.< Eintritt in den WARTEZYKLUS..."
#
performanceTest=1

# Sicherheitshalber alle .pid Dateien löschen.
# Das machen die Skripts zwar selbst bei SIGTERM, nicht aber bei SIGKILL und anderen.
# Sonst startet er die Prozesse nicht.
# Die .pid ist in der Endlosschleife der Hinweis, dass der Prozess läuft und NICHT gestartet werden muss.
#
find . -name \*\.pid                 -delete
find . -name \*\.ppid                -delete
find . -name \*\.lock                -delete
find . -name ALGO_WATTS_MINES\.in    -delete
find . -name .sort_profit_algoIdx_\* -delete
rm -f ${algoID_KURSE__PAY__WEB} ${algoID_KURSE_PORTS_WEB} \
   .NVIDIA_SMI_PM_LAUNCHED_GPUs .CUDA/make.out

# Aktuelle PID der 'multi_mining_calc.sh' ENDLOSSCHLEIFE
This=$(basename $0 .sh)
echo $$ >${This}.pid
# Ermittlung der Process Group ID, die beim multi_mining_calc.sh seiner eigenen PID gleicht.
# Alles, was er aufruft, sollte die selbe Group-ID haben, also auch die gpu_gv-algos und algo_multi_abfrage.sh
# Interessant wird es bei den gpu_gv-algo.sh's, wenn die wiederum etwas rufen.
# Wie lautet dann die Group-ID?
#  PID  PGID   SID TTY          TIME CMD
# 9462  9462  1903 pts/0    00:00:00 multi_mining_ca
# ps -j --pid $$ | grep $$

# Der nächste Befehl stellt sicher, dass eine Datei für den Vergleich da ist, falls das System das allererste mal gestartet wird.
# Die Funktion _set_ALLE_MINER_from_path braucht diese Datei für den ersten Vergleich.
# Danach "veraltet" sie immer wieder und wird vollständig von der Funktion _set_ALLE_MINER_from_path gepflegt
# Durch den Aufruf hier wird die Funktion _set_ALLE_MINER_from_path um diese Prüfung bei jedem Zyklus entlastet
[ ! -f miners/.all_miner_algos ] && touch miners/.all_miner_algos
[ ! -s miners/live_miners ] && echo "First Call" >miners/live_miners

# Die folgenden Kommandos sind als root in der MM-Root auszuführen, damit der MM sich auf RealTime Priority setzen kann:
REGEXPAT="^-rwsr-xr-x"
_RTPRIO_=$(ls -la .#rtprio#)
if [[ ! "${_RTPRIO_}" =~ ${REGEXPAT} ]]; then
    echo "
Damit der MultiMiner überhaupt vernünftig arbeiten kann, bitte als Kenner des root-Passworts die folgenden Kommandos in der MM-Root ausführen:
$ su
# cp /usr/bin/chrt .#rtprio#
# chmod 4755 .#rtprio#
# exit

Danach den MultiMiner neu starten.
"
    exit 2 # No Real-Time Priority
fi

_NICE_=$(ls -la .#nice#)
if [[ ! "${_NICE_}" =~ ${REGEXPAT} ]]; then
    echo "
Damit der MultiMiner überhaupt vernünftig arbeiten kann, bitte als Kenner des root-Passworts die folgenden Kommandos in der MM-Root ausführen:
$ su
# cp /usr/bin/nice .#nice#
# chmod 4755 .#nice#
# exit

Danach den MultiMiner neu starten.
"
    exit 3 # No Nice-Command
fi

_SMI_=$(ls -l benchmarking/nvidia-befehle/smi)
if [[ ! "${_SMI_}" =~ ${REGEXPAT} ]]; then
    echo "
Damit die Power-Limits der NVIDIA-Karten erfolgreich abgesetzt werden können, bitte als Kenner des root-Passworts die folgenden Kommandos in der MM-Root ausführen:
$ su
# cp /usr/bin/nvidia-smi benchmarking/nvidia-befehle/smi
# chmod 4755 benchmarking/nvidia-befehle/smi
# exit

Danach den MultiMiner neu starten.
"
    exit 4 # No acceptable nvidia-smi command
fi

#2021-05-25: Die Berechnungen wurden nun in C geschrieben unter Verwendung von Multi-Threading als Vorstufe für die Verlagerung in GPU's
if [ 1 -eq 0 ]; then
    #2021-05-26: Dieses make wird als kurze Zeitverzögerung vor den Start des algo_multi_abfrage.sh gelegt, damit die GPUs ein bisschen mehr Zeit haben,
    #            sich aus dem System zu nehmen, um zu Benchmarken (damit der MM das auch mitbekommt und vor der ersten Berechnung nicht unnötig wartet).
    cd .CUDA
    make &>make.out
    RC=$?
    if [ ! ${RC} -eq 0 ]; then
	echo "
Der make des Multithreading-Berechnungsroutinen-Programms mm_calc meldet keinen Erfolg.
Die Ausgaben stehen in der Datei .CUDA/make.out und werden hier ausgegeben.
Danach erfolgt ein exit.
"
	cat make.out
	exit 5 # mm_calc did not compile properly
    fi
    cd ..
fi

export BC_LINE_LENGTH=0
export MULTI_MINERS_PID=$$
export ERRLOG=${LINUX_MULTI_MINING_ROOT}/${This}.err
mv -f ${ERRLOG} ${ERRLOG}.BAK

function _delete_temporary_files () {
    rm -f ${SYNCFILE} ${SYSTEM_STATE}.lock .bc_result_GPUs_* .bc_results_all .bc_prog_GPUs_* ._reserve_and_lock_counter.* \
       .NVIDIA_SMI_PM_LAUNCHED_GPUs .*.lock .sort_profit_algoIdx_* \
       I_n_t_e_r_n_e_t__C_o_n_n_e_c_t_i_o_n__L_o_s_t
}
_delete_temporary_files

#
# Aufräumarbeiten beim ordungsgemäßen kill -15 Signal (SIGTERM)
#
function _terminate_all_log_ptys () {
    for gpu_idx in ${!LOG_PTY_CMD[@]}; do
        if [ -n "${LOG_PTY_CMD[${gpu_idx}]}" ]; then
            echo "Beenden des Logger-Terminals GPU #${gpu_idx} ... "
            REGEXPAT="${LOG_PTY_CMD[${gpu_idx}]//\//\\/}"
            REGEXPAT="${REGEXPAT//\+/\\+}"
            pkill -f "${REGEXPAT}"
        fi
    done
}

function _On_Exit () {
    printf "MultiMiner: _On_EXIT() ENTRY, CLEANING UP RESOURCES NOW...\n"
    _terminate_all_log_ptys
    echo "Killing algo_multi_abfrage.sh..."
    pkill -f "algo_multi_abfrage.sh$"
    echo "Killing all gpu_gv-algo.sh..."
    pkill -f "gpu_gv-algo.sh$"

    # Temporäre Dateien löschen
    [[ $debug -eq 0 ]] && _delete_temporary_files

    ### SCREEN ADDITIONS: ###
    if [ ${UseScreen} -eq 1 ]; then
	# Die Background-Session entfernen durch Abmeldung von der Shell, in der das Window immer noch steht
	screen -drx ${BG_SESS} -p "BG-Procs" -X stuff "HISTSIZE=0\nexit\n"
	rm -f ${LINUX_MULTI_MINING_ROOT}/screen/.screenrc.${BG_SESS}
    fi

    rm -f ${This}.pid
    printf "MultiMiner: CLEANING UP RESOURCES FINISHED... exiting NOW.\n"
}
trap _On_Exit EXIT

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
pkill -f "gpu_gv-algo.sh$"
pkill -f "algo_multi_abfrage.sh$"
# ---> WIR MÜSSEN AUCH ÜBERLEGEN, WAS WIR MIT DEM RUNNING_STATE MACHEN !!! <---
# ---> WIE SINNVOLL IST ES, DEN AUFZUHEBEN?                                <---
rm -f ${RUNNING_STATE}

# Danach ist alles saubergeputzt, soweit wir das im Moment überblicken und es kann losgehen, die
# gpu_gv-algos's zu starten, die erst mal auf SYNCFILE warten
# und dann algo_multi_abfrage.sh

# Startet eine Session ${BG_SESS} und eine shell, aus der heraus nvidia-settings laufen,
# sofern sie aus einem mate-terminal-Child gerufen werden, das eine screen-Session für dem MM-Start erstellt hat.
# !!! GANZ WICHTIG: Die angegebene screenrc muss mit einem "detach" enden !!!
#     Sonst kommt er nicht nach hierher zurück und überlagert den ${MAINSCREEN}
if [ ${UseScreen} -eq 1 ]; then
    if [ $(screen -ls|grep -c ${BG_SESS}) -eq 0 ]; then
	cp ${LINUX_MULTI_MINING_ROOT}/screen/screenrc.${BG_SESS%%.*} ${LINUX_MULTI_MINING_ROOT}/screen/.screenrc.${BG_SESS}
	screen -c ${LINUX_MULTI_MINING_ROOT}/screen/.screenrc.${BG_SESS} -S ${BG_SESS}
    fi
fi
#screen -rx ${BG_SESS} -p + -t "ERRLOG" -X eval detach
#screen -d

#echo "where I'm now? PID: $$"
#read -p "Press ENTER to continue after Screens have built up..." xyz
#exit

MultiMining_log=${LINUX_MULTI_MINING_ROOT}/${This}.log
exec 9>&1
#mv -f ${MultiMining_log} ${MultiMining_log}.BAK
exec 1>>${MultiMining_log}
tail -f ${MultiMining_log} >&9 &

exec 2>>${ERRLOG}
# Error-Kanal in eigenes Terminal ausgeben
unset ii; declare -i ii=0
unset LOG_PTY_CMD; declare -ag LOG_PTY_CMD
LOG_PTY_CMD[999]="tail -f ${ERRLOG}"

### SCREEN ADDITIONS: ###
# Das war nur, um den Namen der .pid-datei zu verifizieren
if [ ${UseScreen} -eq 1 ]; then
    screen -X screen -t "ERRLOG"
    screen -p "ERRLOG" -X stuff "${LOG_PTY_CMD[999]}\nHISTSIZE=0\nexit\n"
    screen -X other
else
    ofsX=$((ii*60+50))
    ofsY=$((ii*30+50))
    let ii++
    ${_TERMINAL_} --hide-menubar \
		  --title="MultiMining Error Channel Output" \
		  --geometry="100x24+${ofsX}+${ofsY}" \
		  -e "${LOG_PTY_CMD[999]}"
#                 -x bash -c "${LOG_PTY_CMD[999]}"
fi

# Besteht nun hauptsächlich aus der Funktion _func_gpu_abfrage_sh
source ./gpu-abfrage.sh

declare -ig GPU_COUNT
export GPU_COUNT
echo ${BEST_ALGO_CNT} >BEST_ALGO_CNT

# Das Prioritätenkürzel für die MINER.
# Kann hier global gesetzt werden, weil nur der Miner aus diesem Skript gestartet wird.
# Bei der Änderung der eigenen RT-Priorität verwenden wir "mm" statt einer Variablen
ProC="gpu"

printf "\n=========         Beginn neues Logfile um:    $(date "+%Y-%m-%d %H:%M:%S" )     $(date +%s)         =========\n"
echo "Scheduling-Daten für die Miner:"
echo "RT_PRIORITY[\"mi\"] ="${RT_PRIORITY["mi"]}
echo "RT_POLICY[\"mi\"]   ="${RT_POLICY["mi"]}
echo "NICE[\"mi\"]        ="${NICE["mi"]}
echo "Scheduling-Daten für die MinerShells:"
echo "RT_PRIORITY[\"ms\"] ="${RT_PRIORITY["ms"]}
echo "RT_POLICY[\"ms\"]   ="${RT_POLICY["ms"]}
echo "NICE[\"ms\"]        ="${NICE["ms"]}
echo "Scheduling-Daten für die gpu_gv-algos:"
echo "RT_PRIORITY[\"gpu\"]="${RT_PRIORITY["gpu"]}
echo "RT_POLICY[\"gpu\"]  ="${RT_POLICY["gpu"]}
echo "NICE[\"gpu\"]       ="${NICE["gpu"]}
echo "Scheduling-Daten für den MM:"
echo "RT_PRIORITY[\"mm\"] ="${RT_PRIORITY["mm"]}
echo "RT_POLICY[\"mm\"]   ="${RT_POLICY["mm"]}
echo "NICE[\"mm\"]        ="${NICE["mm"]}

#echo "I'm going to exit now"
# Damit die anderen beiden Screens wirklich aufgebaut sind, künstlich warten
#read -p "Press ENTER to continue after Screens have built up..." xyz
#exit
# Das gibt Informationen der gpu-abfrage.sh aus
ATTENTION_FOR_USER_INPUT=1
while : ; do
    printf "\n=========         Beginn neuer Zyklus um:     $(date "+%Y-%m-%d %H:%M:%S" )     $(date +%s)         =========\n"

    [[ ${performanceTest} -ge 1 ]] && echo "$(date +%s): >1.< While Loop ENTRY" >>perfmon.log

    # Diese Abfrage erzeugt die beiden Dateien "gpu_system.out" und "GLOBAL_GPU_SYSTEM_STATE.in"
    # Daten von "GLOBAL_GPU_SYSTEM_STATE.in", WELCHES MANUELL BEARBEITET WERDEN KANN,
    #       werden berücksichtigt, vor allem sind das die Daten über den generellen Beachtungszustand
    #       von GPUs und Algorithmen.
    #       GPUs können als ENABLED (1) oder DISABLED (0) gesetzt werden
    # _func_gpu_abfrage_sh ruft
    #    _set_Miner_Device_to_Nvidia_GpuIdx_maps ruft
    #        _set_ALLE_MINER_from_path
    #        _read_in_minerFees_to_MINER_FEES
    #        _set_ALLE_LIVE_MINER
    _func_gpu_abfrage_sh
    echo "Anzahl Enabled GPUs: ${NumEnabledGPUs}"
    #
    # Wir schalten jetzt die GPU-Abfragen ein, wenn sie nicht schon laufen...
    # ---> Müssen auch daran denken, sie zu stoppen, wenn die GPU DISABLED wird <---
    for lfdUuid in "${!uuidEnabledSOLL[@]}"; do
        if [ ${uuidEnabledSOLL[${lfdUuid}]} -eq 1 ]; then
            if [ ! -f ${lfdUuid}/gpu_gv-algo.pid ]; then

                # Ins GPU-Verzeichnis wechseln
                cd ${lfdUuid}

                lfd_gpu_idx=$(< gpu_index.in)
                GPU_GV_LOG="gpu_gv-algo_${lfdUuid}.log"
                mv -f ${GPU_GV_LOG} ${GPU_GV_LOG}.BAK
                echo "GPU #${lfd_gpu_idx}: Starting process in the background..."
                exec 1>&9

		### SCREEN ADDITIONS: ###
                if [ ${RT_PRIORITY[${ProC}]} -gt 0 ]; then
		    cmd="${LINUX_MULTI_MINING_ROOT}/.#rtprio# ${RT_POLICY[${ProC}]} ${RT_PRIORITY[${ProC}]}"
                else
		    cmd="${LINUX_MULTI_MINING_ROOT}/.#nice# -n ${NICE[${ProC}]}"
                fi
		cmd+=" ${LINUX_MULTI_MINING_ROOT}/${lfdUuid}/gpu_gv-algo.sh &>>${GPU_GV_LOG}"
		if [ ${UseScreen} -eq 1 ]; then
		    cmd+='\nHISTSIZE=0\nexit\n'
		    GPU_gv_Title="GV#${lfd_gpu_idx}"
		    screen -drx ${BG_SESS} -X screen -t ${GPU_gv_Title}
		    screen -drx ${BG_SESS} -p ${GPU_gv_Title} -X stuff "cd ${LINUX_MULTI_MINING_ROOT}/${lfdUuid}\n ${cmd}"
		else
		    "${cmd}" &
                    BG_PIDs+=( $! )
		fi

                exec 1>>${MultiMining_log}
                # ${_TERMINAL_} -x ./abc.sh
                #    Für die Logs in eigenem Terminalfenster, in dem verblieben wird, wenn tail abgebrochen wird:
                LOG_PTY_CMD[${lfd_gpu_idx}]="tail -f ${LINUX_MULTI_MINING_ROOT}/${lfdUuid}/${GPU_GV_LOG}"
		### SCREEN ADDITIONS: ###
		if [ ${UseScreen} -eq 1 ]; then
		    cmd="${LOG_PTY_CMD[${lfd_gpu_idx}]}"'\nHISTSIZE=0\nexit\n'
		    GPU_gv_LOG_Title="GV#${lfd_gpu_idx}"
		    screen -X screen -t ${GPU_gv_LOG_Title}
		    screen -p ${GPU_gv_LOG_Title} -X stuff "cd ${LINUX_MULTI_MINING_ROOT}/${lfdUuid}\n"
		    until [ -s ${GPU_GV_LOG} ]; do sleep .01; done
		    screen -p ${GPU_gv_LOG_Title} -X stuff "${cmd}"
		    screen -X select ${MAINSCREEN}
		else
		    ofsX=$((ii*60+50))
		    ofsY=$((ii*30+50))
                    ${_TERMINAL_} --hide-menubar \
				  --title="GPU #${lfd_gpu_idx}  -  ${lfdUuid}" \
				  --geometry="100x24+${ofsX}+${ofsY}" \
				  -e "${LOG_PTY_CMD[${lfd_gpu_idx}]}"
                    let ii++
		fi

                cd ${_WORKDIR_} >/dev/null
            fi
        fi
    done

    #
    # Dann starten wir die algo_multi_abfrage.sh, wenn sie nicht schon läuft...
    #
    if [ ! -f algo_multi_abfrage.pid ]; then
	# Hier könnten wir noch 2s oder so warten, bis alle 13 GPUs gestartet sind und sich aus dem Spiel genommen haben,
	#      falls sie ein paar algos benchen müssen...
	# sleep 2

	#2021-05-26: Dieses make dient an dieser Stelle als kurze Zeitverzögerung.
	if [ ! -s .CUDA/make.out ]; then
	    cd .CUDA
	    make &>make.out
	    RC=$?
	    if [ ! ${RC} -eq 0 ]; then
		echo "
Der make des Multithreading-Berechnungsroutinen-Programms mm_calc meldet keinen Erfolg.
Die Ausgaben stehen in der Datei .CUDA/make.out und werden hier ausgegeben.
Danach erfolgt ein exit.
"
		cat make.out
		exit 5 # mm_calc did not compile properly
	    fi
	    cd ..
	fi

        # Das lohnt sich erst, wenn wir den curl dazu gebracht haben, ebenfalls umzuleiten...
        # ${_TERMINAL_} -x ./abc.sh
        #    Für die Logs in eigenem Terminalfenster, in dem verblieben wird, wenn tail abgebrochen wird:
        mv -f algo_multi_abfrage.log algo_multi_abfrage.log.BAK
        echo "Starting algo_multi_abfrage.sh in the background..."
	cmd="${LINUX_MULTI_MINING_ROOT}/algo_multi_abfrage.sh &>>algo_multi_abfrage.log"
        LOG_PTY_CMD[998]="tail -f ${LINUX_MULTI_MINING_ROOT}/algo_multi_abfrage.log"
        exec 1>&9

	### SCREEN ADDITIONS: ###
	if [ ${UseScreen} -eq 1 ]; then
	    PREISE_Title="PREISE"
	    # Das erzeugt einen neuen Prozess und der ursprüngliche ist überdeckt und unzugänglich!
	    # ... bis wir uns davon detached haben...
	    #screen -S Web-Session -t ${PREISE_Title} ${BASH} -c "${cmd}"
	    #screen -drx -X eval detach

	    #screen -p + -t ${PREISE_Title} ${BASH} -c "${cmd}"
	    cmd+='\nHISTSIZE=0\nexit\n'
	    screen -drx ${BG_SESS} -X screen -t ${PREISE_Title}
	    screen -drx ${BG_SESS} -p ${PREISE_Title} -X chdir "${LINUX_MULTI_MINING_ROOT}" # nicht sicher, ob dieses Kommando einen Effekt hat...
	    screen -drx ${BG_SESS} -p ${PREISE_Title} -X stuff "${cmd}"
            exec 1>>${MultiMining_log}

            ##LOG_PTY_CMD[998]="${LOG_PTY_CMD[998]} &; screen -X eval detach"
	    cmd="${LOG_PTY_CMD[998]}"'\nHISTSIZE=0\nexit\n'
	    PREISE_LOG_Title="PREISE-LOG"
	    #screen -rx ${BG_SESS} -p + -t ${PREISE_LOG_Title} ${BASH} -c "${LOG_PTY_CMD[998]}"
	    screen -X screen -t ${PREISE_LOG_Title} 98
	    screen -p ${PREISE_LOG_Title} -X stuff "${cmd}"
	    screen -X select ${MAINSCREEN}
	else
            "${cmd}" &
            BG_PIDs+=( $! )
            exec 1>>${MultiMining_log}

            ofsX=$((ii*60+50))
            ofsY=$((ii*30+50))
            ${_TERMINAL_} --hide-menubar \
			  --title="\"RealTime\" Algos und Kurse aus dem Web" \
			  --geometry="100x24+${ofsX}+${ofsY}" \
			  -e "${LOG_PTY_CMD[998]}"
            exec 1>>${MultiMining_log}
	fi
    fi

    ### SCREEN ADDITIONS: ###
    if [ ${UseScreen} -eq 0 ]; then
	if [ ${debug} -eq 1 ]; then
            if [ ${#BG_PIDs[@]} -gt 0 ]; then
		echo "Process-IDs from Processes in the Background:" ${BG_PIDs[@]}
            else
		echo "Keine Background-PIDs gesammelt. Komisch. ???"
            fi
	fi
    fi

    ###############################################################################################
    #
    # Wieviele Profitabelste Wats/MInes-Werte sollen pro GPU in die Gesamtberechnung einfließen?
    #
    ###############################################################################################
    [ -s BEST_ALGO_CNT ] && BEST_ALGO_CNT=$(< BEST_ALGO_CNT)
    
    if [ ${#rtprio_set} -eq 0 ]; then
        # ./.#rtprio# -f -p ${RTPRIO_MM} $$
        if [ ${RT_PRIORITY["mm"]} -gt 0 ]; then
            ./.#rtprio# ${RT_POLICY["mm"]} -p ${RT_PRIORITY["mm"]} $$
        #else # RENICE NEEDED!!!!
        #    ./.#nice# -n ${NICE["mm"]}
        fi
        rtprio_set=1
    fi

    ###############################################################################################
    #
    # Einlesen des bisherigen RUNNING Status
    #
    ###############################################################################################
    # Wer diese Datei schreiben oder lesen will, muss auf das Verschwinden von *.lock warten...
    _reserve_and_lock_file ${RUNNING_STATE}  # Zum Lesen reservieren...
    _read_in_actual_RUNNING_STATE            # ... einlesen...
    _remove_lock                                     # ... und wieder freigeben

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

    ###############################################################################################
    ###############################################################################################
    ###
    ###              WARTEN und TESTEN AUF GÜLTIGE DATEN AUS DEM NETZ
    ###
    ###############################################################################################
    ###############################################################################################
    _progressbar='\r'
    while [ ! -f ${SYNCFILE} ]; do
        [[ "${_progressbar}" == "\r" ]] && echo "###---> Waiting for ${SYNCFILE} to become available..."
        _progressbar+='.'
        if [[ ${#_progressbar} -gt 75 ]]; then
            printf '\r                                                                            '
            _progressbar='\r.'
        fi
        printf ${_progressbar}
        sleep .5
    done
    [[ "${_progressbar}" != "\r" ]] && printf "\n"
    #  Das neue "Alter" von ${SYNCFILE} in der Variablen ${new_Data_available} merken für später.
    #  Die GPUs haben schon losgelegt, das heisst, dass SYNCFILE da ist und in etwa 31s neu getouched wird
    #new_Data_available=$(stat -c %Y ${SYNCFILE})
    read new_Data_available SynFrac <<<$(_get_file_modified_time_ ${SYNCFILE})
    SynSecs=$((${new_Data_available} + ${MM_validating_delay}))

    [[ ${performanceTest} -ge 1 ]] && echo "$(date +%s): >2.< Startschuss: Neue Daten sind verfügbar" >>perfmon.log

    ###############################################################################################
    # (26.10.2017)
    # Vor dem Einlesen der Werte aus dem SMARTMETER, um u.a. SolarWattAvailable berechnen zu können,
    # warten wir erst mal, bis alle ENABLED GPUs ihre Dateien ALGO_WATTS_MINES.in geschrieben haben.
    # Darin enthalten sind die Watt-Angaben und die BTC "Mines", die sie produzieren würden,
    # wenn sie laufen würden.
    # Wir warten darauf, dass das Modification Date der Datei ALGO_WATTS_MINES.in größer oder gleich
    # dem des SYNCFILE ist, weil die "alten" Dateien der letzten 31s noch rumliegen.
    #
    # Erst, wenn alle BTC "Mines" anhand der aktuellen Kurse berechnet wurden
    #       und wir die optimale Konfiguration durchrechnen können,
    #       bestimmen wir den momentanen "Strompreis" anhand der Daten aus dem SMARTMETER
    #
    # Zunächst also warten, bis die "Mines"-Berechnungen und die Wattangaben alle verfügbar sind.

    echo $(date "+%Y-%m-%d %H:%M:%S %s.%N" ) "Going to wait for all GPUs to calculate their ALGO_WATTS_MINES.in"
    [ ${debug} -eq 1 ] && echo "Maximum waittime until: \${SynSecs}.\${SynFrac} ${SynSecs}.${SynFrac}"

    unset ALGO_WATTS_MINES_delivering_GPUs validation_time NumValidatedGPUs
    declare -i  NumValidatedGPUs=0
    declare -Ag ALGO_WATTS_MINES_delivering_GPUs validation_time

    # Nochmal "kurz" die GLOBAL_GPU_SYSTEM_STATE.in einlesen, um nicht zu lange auf disabled GPU's warten zu müssen
    # Hat leider nichts gebracht. Ganz wenige GPU's, die sich ganz am Anfang rausnehmen, um zu benchmarken, waren "zu langsam".
    # Sie wurden schon "zu spät" gestartet, was weiter oben verbessert wurde. Danach hat es geklappt.
    # Aber bei 11 GPU's sind wir schon fast an einem Limit, das bald wieder erreicht sein könnte.
    # Es geht hier eigentlich NUR um den allerersten Start, dass der MM nicht 15s Sekunden wartet, obwohl sich GPU's bereits rausgenommen haben.
    # Möglicherweise sollte diese "Beschleunigung" anders gelöst werden.
    # Es funktioniert im Moment jedenfalls
    # Da _progressbar im weiteren Verlauf IMMER gleich '\r' ist, wird diese Kontrolle nur beim allerersten Mal gemacht
    [[ "${_progressbar}" != "\r" ]] && { _get_SYSTEM_STATE_in; echo "Erster Start (eventuell bechmarken schon manche GPUs). Enabled GPUs: ${NumEnabledGPUs}"; }

    if [ ${NumEnabledGPUs} -gt 0 ]; then

        # Warten bis zu maximal 15 Sekunden (${MM_validating_delay}), bis wenigstens 1 GPU gültige Werte signalisiert hat.
	{ read nowSecs nowFrac <<<$(date "+%s %N"); nowFrac=${nowFrac##*(0)}; nowFrac=${nowFrac:-1}; }
        until (( ${nowSecs} > ${SynSecs} || ( ${nowSecs} == ${SynSecs} && ${nowFrac} > ${SynFrac} ) )); do
            for UUID in ${!uuidEnabledSOLL[@]}; do
                if [ ${uuidEnabledSOLL[${UUID}]} -eq 1 ]; then

                    if [ ${#ALGO_WATTS_MINES_delivering_GPUs[${UUID}]} -eq 0 ]; then
                        read valSecs valFrac <<<$(_get_file_modified_time_ ${UUID}/${GPU_VALID_FLAG})
                        if [[ ${valSecs} -ge ${new_Data_available} || (${valSecs} -eq ${new_Data_available} && ${valFrac} -gt ${SynFrac}) ]]; then
                            # Diese GPU UUID wird in den Berechnungen berücksichtigt
                            ALGO_WATTS_MINES_delivering_GPUs[${UUID}]=${GPU_idx[${UUID}]}
                            let NumValidatedGPUs++
                        fi
                    fi
                fi
            done
            [ ${NumEnabledGPUs} -eq ${NumValidatedGPUs} ] && break

            sleep .1
	    { read nowSecs nowFrac <<<$(date "+%s %N"); nowFrac=${nowFrac##*(0)}; nowFrac=${nowFrac:-1}; }
        done
	echo "Enabled, ValidatedGPUs: ${NumEnabledGPUs}, ${NumValidatedGPUs}";
    else
        echo "---> ACHTUNG: Im Moment sind ALLE GPU's DISABLED..."
    fi
    if [ ${#ALGO_WATTS_MINES_delivering_GPUs[@]} -gt 0 ]; then
        # Diese GPU UUID wird in den Berechnungen berücksichtigt
        echo "Die folgenden GPU's werden in der nun folgenden Berechnung berücksichtigt:"
        for UUID in ${!ALGO_WATTS_MINES_delivering_GPUs[@]}; do
            printf "    GPU #%s mit UUID %s\n" ${ALGO_WATTS_MINES_delivering_GPUs[${UUID}]} "${UUID}"
        done
    else
        echo "---> ACHTUNG: Im Moment werden KEINE GPU's bei der Berechnung berücksichtigt, weil sie zu spät Werte abgeliefert haben"
    fi

    [ ${debug} -eq 1 ] && echo "Last read nowSecs: ${nowSecs}.${nowFrac}             [ SS.SF: ${SynSecs}.${SynFrac} ]"
    echo $(date "+%Y-%m-%d %H:%M:%S" ) $(date +%s)
    [[ ${performanceTest} -ge 1 ]] && echo "$(date +%s): >3.< GPUs haben alle Daten geschrieben" >>perfmon.log

    ###############################################################################################
    #
    #    Info über Algos, die DISABLED wurden und sind ausgeben
    #
    if [ -f GLOBAL_ALGO_DISABLED ]; then
        echo "------------->         Die folgenden Algos sind GENERELL DISABLED:                            <-------------"
        cat GLOBAL_ALGO_DISABLED | grep -E -v -e '^#|^$'
    fi
    if [ -f BENCH_ALGO_DISABLED ]; then
        echo "------------->         Die folgenden Algos sind aufgrund des Benchmarings DAUERHAFT DISABLED: <-------------"
        cat BENCH_ALGO_DISABLED | grep -E -v -e '^#|^$'
    fi
    if [ -f MINER_ALGO_DISABLED ]; then
        echo "------------->         Die folgenden Algos sind für 5 Minuten DISABLED:                       <-------------"
        cat MINER_ALGO_DISABLED | sort -k 3
    fi

    ###############################################################################################
    #
    #    EINLESEN ALLER ALGORITHMEN, WATTS und MINES, AUF DIE WIR GERADE GEWARTET HABEN
    #
    # m_m_calc.sh wird zwar das selbe auch tun, aber wir brauchen die Daten, wenn wir die Ergebnisse von m_m_calc.sh bekommen,
    # denn diese Ergebnisse sind nur exakte Pointer/Zeiger in diese Datenmenge hinein, die wir brauchen, um die Anweisungen
    # über ${RUNNING_STATE} an die GPUs weitergeben zu können. Wir können uns das Einlesen also nicht ersparen.

    # Alt:
    #    _read_in_All_ALGO_WATTS_MINESin
    # Neu:
    _read_in_Validated_ALGO_WATTS_MINESin

    [[ ${performanceTest} -ge 1 ]] && echo "$(date +%s): >4.< Alle Algos aller GPUs sind eigelesen." >>perfmon.log

    ###############################################################################################
    #
    #     EINLESEN der STROMPREISE in BTC
    #
    # In algo_multi_abfrage.sh, die vor Kurzem gelaufen sein muss,
    # werden die EUR-Strompreise in BTC-Preise umgewandelt.
    # Diese Preise brauchen wir in BTC, um die Kosten von den errechneten "Mines" abziehen zu können.
    #
    _read_in_kWhMin_kWhMax_kWhAkk

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

    # Nach Anschluss einer SOLAR-Anlage wieder aktivieren
    if [ 1 -eq 0 ]; then
        # Datei smartmeter holen
        w3m "http://192.168.6.170/solar_api/v1/GetMeterRealtimeData.cgi?Scope=Device&DeviceId=0&DataCollection=MeterRealtimeData" > smartmeter

	printf "         Sum of actually running WATTS: %5dW\n" ${SUM_OF_RUNNING_WATTS}

	# ABFRAGE PowerReal_P_Sum
	ACTUAL_SMARTMETER_KW=$(grep $PHASE smartmeter | gawk '{print substr($3,0,index($3,".")-1)}')
	printf "Aktueller Verbrauch aus dem Smartmeter: %5dW\n" ${ACTUAL_SMARTMETER_KW}

	if [[ $((${ACTUAL_SMARTMETER_KW} - ${SUM_OF_RUNNING_WATTS})) -lt 0 ]]; then
            SolarWattAvailable=$(expr ${SUM_OF_RUNNING_WATTS} - ${ACTUAL_SMARTMETER_KW})    
	fi
	printf "                 Verfügbare SolarPower: %5dW\n" ${SolarWattAvailable}
    fi

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

    # Jetzt geht's los:
    # Jetzt brauchen wir ALLE möglichen Kombinationen aus GPU-Konstellationen:
    # Jede GPU und mit jedem möglichen Algo, den sie kann, wird mit allen anderen möglichen
    #      GPUs und deren Algos, und Kombinationen aus GPUs berechnet.
    # Wir errechnen die jeweilige max. BTC-Generierung pro Kombination
    #     und den entsprechenden Gesamtwattverbrauch.
    # Anhand des Gesamtwattverbrauchs der Kombination errechnen wir die Gesamtkosten dieser Kombination
    #     unter Berücksichtigung eines entsprechenden "solar" Anteils, wodurch die Kosten sinken.
    # Die Kombination mit dem besten GV-Verhältnis merken wir uns jeweils in MAX_PROFIT und MAX_PROFIT_GPU_Algo_Combination:
    
    [[ ${performanceTest} -ge 1 ]] && echo "$(date +%s): >5.< Berechnungen beginnen mit Einzelberechnungen" >>perfmon.log

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
    OLD_MAX_PROFIT=".0"
    MAX_PROFIT_GPU_Algo_Combination=''
    MAX_FP_MINES=".0"
    OLD_MAX_FP_MINES=".0"
    MAX_FP_WATTS=0
    MAX_FP_GPU_Algo_Combination=''
    declare -ig GLOBAL_GPU_COMBINATION_LOOP_COUNTER=0
    declare -ig GLOBAL_MAX_PROFIT_CALL_COUNTER=0
    unset MAX_PROFIT_MSG_STACK MAX_FP_MSG_STACK

    echo "=========  GPU Einzelberechnungen  ========="
    echo "Ermittlung aller gewinnbringenden Algorithmen durch Berechnung:"
    echo "Jede GPU für sich betrachtet, wenn sie als Einzige laufen würde UND Beginn der Ermittlung und des Hochfahrens von MAX_PROFIT !"

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
    unset SwitchNotGPUs
    declare -a SwitchNotGPUs           # GPUs, die durchzuschleifen sind, weil sie beim Abliefern von Werten aufgehalten wurden.
    unset PossibleCandidateGPUidx
    declare -a PossibleCandidateGPUidx # GPUs mit mindestens 1 gewinnbringenden Algo.
    # Welcher es werden soll, muss errechnet werden
    # gefolgt von mind. 1x declare -a "PossibleCandidate${gpu_index}AlgoIndexes" ...
    unset exactNumAlgos
    declare -a exactNumAlgos  # ... und zur Erleichterung die Anzahl Algos der entsprechenden "PossibleCandidate" GPU's

    WATTS_Parameter_String_for_mm_calC=""
    MINES_Parameter_String_for_mm_calC=""
    for (( idx=0; $idx<${#index[@]}; idx++ )); do
        gpu_idx=${index[$idx]}
        declare -n actGPUAlgos="GPU${gpu_idx}Algos"
        declare -n actAlgoWatt="GPU${gpu_idx}Watts"
        declare -n actAlgoMines="GPU${gpu_idx}Mines"
        declare -n actAlgoProfit="GPU${gpu_idx}Profit"
        declare -n dstAlgoWatts="GPU${gpu_idx}WATTS"
        declare -n dstAlgoMines="GPU${gpu_idx}MINES"
        declare -n actSortedProfits="SORTED${gpu_idx}PROFITs"

        numAlgos=${#actGPUAlgos[@]}
	if [ 1 -eq 0 -a ${verbose} -eq 1 ]; then
	    echo "Anzahl aktueller Algos von GPU#${gpu_idx}: ${numAlgos}" 
	fi
        # Wenn die GPU seit neuestem generell DISABLED ist, pushen wir sie hier auf den
        # SwitchOffGPUs Stack, indem wir die numAlgos künslich auf 0 setzen:
        if [[ "${uuidEnabledSOLL[${uuid[${gpu_idx}]}]}" == "0" ]]; then
            numAlgos=0
        fi
        case "${numAlgos}" in

            "0")
                # Karte ist auszuschalten. Kein (gewinnbringender) Algo im Moment.
                # Es kam offensichtlich nichts aus der Datei ALGO_WATTS_MINES.in.
                # Vielleicht wegen einer Vorabfilterung durch gpu_gv-algo.sh (unwahrscheinlich aber machbar)
                # ---> ARRAYPUSH 2 <---
                SwitchOffGPUs+=( ${gpu_idx} )
                ;;

            *)
                # Es werden nur diejenigen GPUs berücksichtigt, die erklärt haben, dass gültige Werte in der ALGO_WATTS_MINES.in waren
                if [ ${#ALGO_WATTS_MINES_delivering_GPUs[${uuid[${gpu_idx}]}]} -gt 0 ]; then
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
                        # Achtung: actGPUAlgos[$algoIdx] ist ein String und besteht aus 5 Teilen:
                        #          "$coin#$pool#$miningAlgo#$miner_name#$miner_version"
                        # Wenn uns davon etwas interessiert, können wir es so in Variablen einlesen.
                        # Einst war die folgende Zeile hier aktiv, aber actAlgoName ist nirgends abgefragt oder verwendet worden.
                        # Deshalb wurde es am 24.12.2017 herausgenommen. Nach der großen Trennung von $algo in $coin und $miningAlgo
                        #read actAlgoName muck <<<"${actGPUAlgos[$algoIdx]//#/ }"

                        _calculate_ACTUAL_REAL_PROFIT_and_set_MAX_PROFIT \
                            ${SolarWattAvailable} ${actAlgoWatt[$algoIdx]} "${actAlgoMines[$algoIdx]}"
			[ "${MAX_PROFIT}"   == "0" ] && MAX_PROFIT=".0"
			[ "${MAX_FP_MINES}" == "0" ] && MAX_FP_MINES=".0"

                        # Wenn das NEGATIV ist, muss der Algo dieser Karte übergangen werden. Uns interessieren nur diejenigen,
                        # die POSITIV sind und später in Kombinationen miteinander verglichen werden müssen.
                        # if [[ ! $(expr index "${ACTUAL_REAL_PROFIT}" "-") == 1 ]]; then
                        # Punkt raus und gucken, ob > 0, sonst interessiert uns das ebenfalls nicht
                        _octal_=${ACTUAL_REAL_PROFIT//\.}
                        _octal_=${_octal_//0}
			if [ 1 -eq 0 -a ${debug} -eq 1 ]; then
			    echo "\${ACTUAL_REAL_PROFIT}: ${ACTUAL_REAL_PROFIT}"
			fi
                        if [[ "${ACTUAL_REAL_PROFIT:0:1}" != "-" && ${#_octal_} -gt 0 ]]; then
                            profitableAlgoIndexes+=( ${algoIdx} )
                            actAlgoProfit[${algoIdx}]=${ACTUAL_REAL_PROFIT}
                        fi
                    done

                    profitableAlgoIndexesCnt=${#profitableAlgoIndexes[@]}
                    if [[ ${profitableAlgoIndexesCnt} -gt 0 ]]; then

                        ###
                        ### Jetzt steht fest, dass diese GPU mindestens 1 Algo hat, der mit Gewinn rechnet.
                        ###
                        PossibleCandidateGPUidx+=( ${gpu_idx} )

                        # Hilfsarray für AlgoIndexe vor dem Neuaufbau immer erst löschen
                        declare -n deleteIt="PossibleCandidate${gpu_idx}AlgoIndexes";    unset deleteIt
                        declare -ag "PossibleCandidate${gpu_idx}AlgoIndexes"
                        declare -n actCandidatesAlgoIndexes="PossibleCandidate${gpu_idx}AlgoIndexes"

                        ###
                        ### Bevor wir das Array nun endgültig freigeben, sortieren wir es und packen nur die BEST_ALGO_CNT=5 Stück drauf.
                        ###
                        ### profitableAlgoIndexes+=( ${algoIdx} )
                        ### actAlgoProfit[${algoIdx}]=${ACTUAL_REAL_PROFIT}
                        rm -f .sort_profit_algoIdx_${gpu_idx}.in
                        for ((sortIdx=0; $sortIdx<${profitableAlgoIndexesCnt}; sortIdx++)); do
                            algoIdx=${profitableAlgoIndexes[${sortIdx}]}
                            echo ${actAlgoProfit[${algoIdx}]} ${algoIdx} >>.sort_profit_algoIdx_${gpu_idx}.in
                        done
                        unset SORTED_PROFITS
                        sort -n -r .sort_profit_algoIdx_${gpu_idx}.in \
                            | tee .sort_profit_algoIdx_${gpu_idx}.out \
                            | readarray -n 0 -O 0 -t SORTED_PROFITS
                        [ ${profitableAlgoIndexesCnt} -gt ${BEST_ALGO_CNT} ] && profitableAlgoIndexesCnt=${BEST_ALGO_CNT}
                        if [ ! : ]; then
                            for ((sortIdx=0; $sortIdx<${profitableAlgoIndexesCnt}; sortIdx++)); do
                                dstIdx=$((${profitableAlgoIndexesCnt}-${sortIdx}-1))
                                actSortedProfits[${dstIdx}]=${SORTED_PROFITS[${sortIdx}]}
                                algoIdx=${SORTED_PROFITS[${sortIdx}]#* }
                                actCandidatesAlgoIndexes[${dstIdx}]=${algoIdx}
                                dstAlgoWatts[${dstIdx}]=${actAlgoWatt[${algoIdx}]}
                                dstAlgoMines[${dstIdx}]=${actAlgoMines[${algoIdx}]}
                            done
                        else
                            for ((sortIdx=0; $sortIdx<${profitableAlgoIndexesCnt}; sortIdx++)); do
                                actSortedProfits[${sortIdx}]=${SORTED_PROFITS[${sortIdx}]}
                                algoIdx=${SORTED_PROFITS[${sortIdx}]#* }
                                actCandidatesAlgoIndexes[${sortIdx}]=${algoIdx}
                                dstAlgoWatts[${sortIdx}]=${actAlgoWatt[${algoIdx}]}
                                dstAlgoMines[${sortIdx}]=${actAlgoMines[${algoIdx}]}
                            done
                        fi
                        exactNumAlgos[${gpu_idx}]=${profitableAlgoIndexesCnt}
			WATTS_Parameter_String_for_mm_calC+="${dstAlgoWatts[@]} "
			MINES_Parameter_String_for_mm_calC+="${dstAlgoMines[@]} "
                    else
                        # Wenn kein Algo übrigbleiben sollte, GPU aus.
			SwitchOffGPUs+=( ${gpu_idx} )
                    fi
                else
                    SwitchNotGPUs+=( ${gpu_idx} )
                fi
                ;;
        esac
    done

    if [ ${verbose} -eq 1 ]; then
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
        if [[ ${#SwitchNotGPUs[@]} -gt 0 ]]; then
            unset gpu_string
            for (( i=0; $i<${#SwitchNotGPUs[@]}; i++ )); do
                gpu_string+="#${SwitchNotGPUs[$i]}, "
            done
            echo "Switch NOT GPU's ${gpu_string%, }"
        fi
    fi
    if [ ${debug} -eq 1 ]; then
        echo "Summe SwitchOffGPUs + SwitchNotGPUs + PossibleCandidateGPUidx = $((${#PossibleCandidateGPUidx[@]}+${#SwitchOffGPUs[@]}+${#SwitchNotGPUs[@]}))"
        echo "Anzahl System-GPUs                                            = ${#index[@]}"
    fi

    [[ ${performanceTest} -ge 1 ]] && echo "$(date +%s): >6.< Beginn mit der Gesamtsystemberechnung" >>perfmon.log
    
    # Sind überhaupt irgendwelche Date eingelesen worden und prüfbare GPU's ermittelt worden?
    # Wenn nicht, gab es keine Einzelberechnung und dann ist auch keine Gesamtberechnung nötig.
    if [ ${#PossibleCandidateGPUidx[@]} -gt 0 ]; then

        echo "=========  Gesamtsystemberechnung  ========="

        # Für die Mechanik der systematischen GV-Werte Ermittlung
        # Hilfsarray testGPUs, das die "GPU${idx}Algos/Watts/Mines" Algos/Watts/Mines indexiert
        unset MAX_GOOD_GPUs; declare -i MAX_GOOD_GPUs  # Wieviele GPUs haben mindestens 1 möglichen Algo

        # Die folgenden 3 Variablen werden bei jedem Aufruf von _CALCULATE_GV_of_all_TestCombinationGPUs_members
        # neu gesetzt und verwendet. (Vorletzte "Schale")
        unset MAX_GPU_TIEFE; declare -i MAX_GPU_TIEFE  # Wieviele dieser GPUs sollen berechnet werden
        unset lfdGPU; declare -i lfdGPU                # Laufender Zähler analog dem meist verwendeten $i
        # Nachdem diese Aufgabe aus der bash entfernt wurde, wird dieses Stellwerk nicht mehr benutzt.
        #unset testGPUs; declare -A testGPUs            # Test-Zähler-Stellwerk

        # Diese Nummer bildet die globale, die äusserste, letzte "Schale", von der aus die anderen gestartet/verwendet werden
        unset numGPUs; declare -i numGPUs

        MAX_GOOD_GPUs=${#PossibleCandidateGPUidx[@]}
        if [ ${MAX_GOOD_GPUs} -gt 1 ]; then      # Den Fall für 1 GPU allein haben wir ja schon ermittelt.
	    MIN_GOOD_GPUs=2
	    # Um die Anzahl an Berechnungen einzuschränken, starten wir mal mit der Anzahl an GPU's -3, wenn die Zahl größer ist als 8 GPU's
	    #[ ${MAX_GOOD_GPUs} -ge 8 ] && MIN_GOOD_GPUs=8

	    echo "MAX_GOOD_GPUs: ${MAX_GOOD_GPUs} bei SolarWattAvailable: ${SolarWattAvailable}"
	    if [ 1 -eq 0 ]; then

		# Wir starten alle Kombinationene parallel
		#     Key(!)=BackgroundPID, Value=OutputFileNameGPU_TIEFE
		#     bc_THREAD_PIDS[${bc_thread_pid}]=".bc_result_GPUs_${MAX_GPU_TIEFE}${FN_combi}"
		unset bc_THREAD_PIDS
		declare -Ag bc_THREAD_PIDS

		# Bei zu wenig Solarpower könnte das ins Minus rutschen...
		#     [ DAS MÜSSEN WIR NOCH CHECKEN, OB DAS WIRKLICH SICHTBAR WIRD ]
		# Deshalb werden wir auch noch Kombinationen mit weniger als der vollen Anzahl an gewinnbringenden GPUs
		#     durchrechnen.
		# Dazu entwickeln wir eine rekursive Funktion, die ALLE möglichen Kombinationen
		#     angefangen mit jeweils ZWEI laufenden GPUs von MAX_GOOD_GPUs
		#                           (EINE laufende GPU haben wir oben schon durchgerechnet)
		#     über DREI laufende GPUs von MAX_GOOD_GPUs
		#     bis hin zu ALLEN laufenden MAX_GOOD_GPUs.
		#
		# numGPUs:        Anzahl zu berechnender GPU-Kombinationen mit numGPUs GPU's
		#

		rm -f .bc_result_GPUs_* .bc_prog_GPUs_* .bc_results_all 
		start[$c]=$(date +%s)
		for (( numGPUs=${MIN_GOOD_GPUs}; $numGPUs<=${MAX_GOOD_GPUs}; numGPUs++ )); do
                    # Parameter: $1 = maxTiefe
                    #            $2 = Beginn Pointer1 bei Index 0
                    #            $3 = Ende letzter Pointer 5
                    #            $4-  Jede Ebene hängt dann ihren aktuellen Wert in der Schleife hin,
                    #                 in der sie sich selbst gerade befindet.
                    echo "Berechnung aller Kombinationen des Falles, dass nur ${numGPUs} GPUs von ${MAX_GOOD_GPUs} laufen:"
                    _CREATE_AND_CALCULATE_EVERY_AND_ALL_SUBSEQUENT_COMBINATION_CASES \
			${MAX_GOOD_GPUs} 0 $((${MAX_GOOD_GPUs} - ${numGPUs} + 1))
		done
		echo "$(date "+%Y-%m-%d %H:%M:%S" ) $(date +%s) Berechnung Ende, es folgt das Warten auf die .bc_result_* Dateien" >>${ERRLOG}

		# Woher wissen wir nun, wann der Prozess beendet ist?
		# PID und Befehlszeile - bc >.bc_result_GPUs_${MAX_GPU_TIEFE}${FN_combi} ?

		# Die folgenden Dateien werden von den bekannten PIDs erzeugt
		#     Key(!)=BackgroundPID, Value=OutputFileNameGPU_TIEFE
		#     bc_THREAD_PIDS[${bc_thread_pid}]=".bc_result_GPUs_${MAX_GPU_TIEFE}${FN_combi}"
		

		# Die folgenden Aktionen wurden früher von der bash Version nach der Schleife durchgeführt, die jetzt auch angepasst werden müssen:
		# Das machen wir im Hauptmodul, was meist der m_m_calc.sh ist
		#let GLOBAL_GPU_COMBINATION_LOOP_COUNTER++
		#MAX_PROFIT_GPU_Algo_Combination=${algosCombinationKey}
		#msg="New Maximum Profit ${MAX_PROFIT} with GPU:AlgoIndexCombination ${MAX_PROFIT_GPU_Algo_Combination}"
		#MAX_PROFIT_MSG_STACK+=( ${msg} )
		#MAX_FP_WATTS=${CombinationWatts}
		#MAX_FP_GPU_Algo_Combination=${algosCombinationKey}
		#msg="New FULL POWER Profit ${MAX_FP_MINES} with GPU:AlgoIndexCombination ${MAX_FP_GPU_Algo_Combination} and ${MAX_FP_WATTS}W"
		#MAX_FP_MSG_STACK+=( ${msg} )

		# So sieht der Output des bc aus (Zwischenmeldungen werden im Moment nicht auf den msg-Stack gelegt):
		#TOTAL NUMBER OF LOOPS = 58*54*54 = 169128
		#MAX_PROFIT_GPU_Algo_Combination: 0:21,1:17,2:17
		#MAX_PROFIT:                      15580.31473048
		#MAX_FP_GPU_Algo_Combination:     0:21,1:17,2:17
		#FP_M:                            15580.31499102
		#FP_W:                            675

		wait ${!bc_THREAD_PIDS[@]}
		RC=$?
		ende[$c]=$(date +%s)
		echo "$(date -d "@${ende[$c]}" "+%Y-%m-%d %H:%M:%S" ) ${ende[$c]} Ergebnis des \"wait \${!bc_THREAD_PIDS[@]}\": ->$RC<-" >>${ERRLOG}

		# GEWALTIGES Timing-Problem entdeckt, das nicht anders gelöst werden konnte, als die Pieline aufzugeben...
		if [ 1 -eq 1 ]; then
		    cat $(ls .bc_result_GPUs_*) \
			| tee .bc_results_all \
			| grep -E -e '^#TOTAL ' \
			| awk -e 'BEGIN {sum=0} {sum+=$NF} END {print sum}' \
			      >.GLOBAL_GPU_COMBINATION_LOOP_COUNTER
		    cat .bc_results_all \
			| grep -e '^MAX_PROFIT:' \
			| sort -g -k2 \
			| tail -n 1 \
			       >.MAX_PROFIT.in
		    cat .bc_results_all \
			| grep -e '^FP_M:' \
			| sort -g -k2 \
			| tail -n 1 \
			       >.MAX_FP_MINES.in
		    until [[ -s .MAX_PROFIT.in || -s .MAX_FP_MINES.in || -s .GLOBAL_GPU_COMBINATION_LOOP_COUNTER ]]; do sleep .01; done
		elif [ 1 -eq 0 ]; then
		    # Die pipeline hängt irgendwo, die .lock Dateien werden nicht gelöscht.
		    touch .MAX_PROFIT.in.lock .MAX_FP_MINES.in.lock .GLOBAL_GPU_COMBINATION_LOOP_COUNTER.lock
		    cat $(ls .bc_result_GPUs_*) \
			| tee >(grep -E -e '#TOTAL ' | awk -e 'BEGIN {sum=0} {sum+=$NF} END {print sum}' >.GLOBAL_GPU_COMBINATION_LOOP_COUNTER; \
				rm -f .GLOBAL_GPU_COMBINATION_LOOP_COUNTER.lock) \
			| grep -E -v -e '^#|^$' \
			| tee >(grep -e '^MAX_PROFIT:'   | sort -g -r -k2 | grep -E -m1 '.*' >.MAX_PROFIT.in; \
				rm -f .MAX_PROFIT.in.lock) \
			      >(grep -e '^FP_M:' | sort -g -r -k2 | grep -E -m1 '.*' >.MAX_FP_MINES.in; \
				rm -f .MAX_FP_MINES.in.lock) \
			      >/dev/null
		    while [[ -f .MAX_PROFIT.in.lock || -f .MAX_FP_MINES.in.lock || -f .GLOBAL_GPU_COMBINATION_LOOP_COUNTER.lock ]]; do sleep .01; done
		else
		    # Die pipeline hängt immer noch. Die Daten sind durch, aber die greps/awk/sorts/tail warten immer noch auf input. Komisch... $$$$$$$$$$$$$$$$$$$$
		    # cat $(ls .bc_result_GPUs_*) \ #
		    cat $(ls .bc_result_GPUs_*) >.bc_results_all
		    cat .bc_results_all \
			| tee >(grep -E -e '^#TOTAL '  | awk -e 'BEGIN {sum=0} {sum+=$NF} END {print sum}' >.GLOBAL_GPU_COMBINATION_LOOP_COUNTER) \
			      >(grep -e '^MAX_PROFIT:' | sort -g -k2 | tail -n 1 >.MAX_PROFIT.in) \
			      >(grep -e '^FP_M:'       | sort -g -k2 | tail -n 1 >.MAX_FP_MINES.in) \
			      >.bc_results_all_out
		    until [[ -s .MAX_PROFIT.in || -s .MAX_FP_MINES.in || -s .GLOBAL_GPU_COMBINATION_LOOP_COUNTER ]]; do sleep .01; done
		fi

		# Warten auf die bc Threads und Auswerten der Ergebnisse.

		# Das stand bei dem ersten exit 77 in .MAX_PROFIT.in:
		# MAX_PROFIT:   .00190162 1:0,2:0,3:0,4:0,6:0,7:0
		#
		read muck MAX_PROFIT   MAX_PROFIT_GPU_Algo_Combination <<<$(< .MAX_PROFIT.in)   #${_MAX_PROFIT_in}
		# echo -e "\$muck: $muck\n \$MAX_PROFIT: $MAX_PROFIT\n \$MAX_PROFIT_GPU_Algo_Combination: $MAX_PROFIT_GPU_Algo_Combination"

		# Das steht in .MAX_FP_MINES.in:
		# FP_M: .00295375 1:0,2:0,3:0,4:0,5:0,6:1 FP_W: 1199
		read muck MAX_FP_MINES MAX_FP_GPU_Algo_Combination     muck2 MAX_FP_WATTS <<<$(< .MAX_FP_MINES.in) #${_MAX_FP_MINES_in}

		GLOBAL_GPU_COMBINATION_LOOP_COUNTER=$(< .GLOBAL_GPU_COMBINATION_LOOP_COUNTER)

	    else  # hier ist letztlich [ 1 -eq 1 ]
		unset mm_calc_RESULTS
		start[$c]=$(date +%s)
		.CUDA/mm_calc ${MIN_GOOD_GPUs} ${MAX_GOOD_GPUs} ${BEST_ALGO_CNT} ${SolarWattAvailable} \
			      ${kWhMin} ${kWhMax} ${MAX_PROFIT} ${MAX_FP_MINES} \
			      "${PossibleCandidateGPUidx[*]}" "${exactNumAlgos[*]}" \
			      "${WATTS_Parameter_String_for_mm_calC%% }" "${MINES_Parameter_String_for_mm_calC%% }" \
                    | readarray -n 0 -O 0 -t mm_calc_RESULTS
		# Die Ausgabe von mm_calc sieht so aus:
		# MAX_PROFIT: 0.0011031243 0:2,1:2,2:2,3:2,4:2,5:2,6:2,7:2,8:2,9:2,10:2,11:2,12:2,
		# FP_M:       0.0015441198 0:2,1:2,2:2,3:2,4:2,5:2,6:2,7:2,8:2,9:2,10:2,11:2,12:2, FP_W: 2038
		# GLOBAL_GPU_COMBINATION_LOOP_COUNTER: 67108824
		read muck MAX_PROFIT   MAX_PROFIT_GPU_Algo_Combination                    <<<${mm_calc_RESULTS[0]}
		read muck MAX_FP_MINES MAX_FP_GPU_Algo_Combination     muck2 MAX_FP_WATTS <<<${mm_calc_RESULTS[1]}
		read muck GLOBAL_GPU_COMBINATION_LOOP_COUNTER                             <<<${mm_calc_RESULTS[2]}
		ende[$c]=$(date +%s)
	    fi
	    echo "Benötigte Zeit zur parallelen Berechnung aller Kombinationen:" $(( ${ende[$c]} - ${start[$c]} )) Sekunden

	    if [ ${#MAX_PROFIT} -eq 0 ]; then
                echo "${ende[$c]}: Stopping MultiMiner because of no MAX_PROFIT with exit code 77" | tee -a ${ERRLOG} .MM_STOPPED_INTERALLY
                exit 77
	    fi
	    msg="New Maximum Profit ${MAX_PROFIT} with GPU:AlgoIndexCombination ${MAX_PROFIT_GPU_Algo_Combination}"
	    MAX_PROFIT_MSG_STACK+=( "${msg}" )
	    msg="New FULL POWER Profit ${MAX_FP_MINES} with GPU:AlgoIndexCombination ${MAX_FP_GPU_Algo_Combination} and ${MAX_FP_WATTS}W"
	    MAX_FP_MSG_STACK+=( "${msg}" )

	    GLOBAL_MAX_PROFIT_CALL_COUNTER+=GLOBAL_GPU_COMBINATION_LOOP_COUNTER
	    #exit 77
	    if [ 1 -eq 1 ]; then
		echo "=========    Berechnungsverlauf    ========="
		if [ 1 -eq 0 ]; then
		    # Veränderungen an MIN_GOOD_GPUs, PossibleCandidateGPUidx=( {0..10} ), etc. müssen in dieser Datei manuell vorgenommen werden!
		    # Lauf bei 8 von 11 bis 11 von 11 GPUs bis zu 2 Sekunden, die man sich sparen kann :-)
		    ./bc_berechnungs_historie.sh
		else
		    for msg in ${!MAX_PROFIT_MSG_STACK[@]}; do
			echo ${MAX_PROFIT_MSG_STACK[$msg]}
		    done
		fi
	    fi
	    if [[ "${MAX_PROFIT_GPU_Algo_Combination}" != "${MAX_FP_GPU_Algo_Combination}" \
		      && "${MAX_FP_MINES}" > "${MAX_PROFIT}" ]]; then
		echo "FULL POWER MINES ${MAX_FP_MINES} wären mehr als die EFFIZIENZ Mines ${MAX_PROFIT}"
		FP_echo="FULL POWER MODE wäre möglich bei ${SolarWattAvailable}W SolarPower"
		FP_echo+=" und maximal ${MAX_FP_WATTS}W GPU-Verbrauch:"
		if [[ ${MAX_FP_WATTS} -lt ${SolarWattAvailable} ]]; then
		    for msg in ${!MAX_FP_MSG_STACK[@]}; do
			echo ${MAX_FP_MSG_STACK[$msg]}
		    done
		    echo ${FP_echo}
		else
		    echo "KEIN(!)" ${FP_echo}
		fi
	    fi
        else
	    echo "Keine Gesamtberechnung nötig. Es ist nur 1 GPU aktiv und die wurde schon berechnet."
        fi  # if [[ ${MAX_GOOD_GPUs} -gt 1 ]]; then
    else
        echo "ACHTUNG: Keine Berechnungsdaten verfügbar oder alle negativ oder alle GPU's Disabled. Es finden im Moment keine Berechnungen statt."
        echo "ACHTUNG: GPU's, die sich selbst für ein Benchmarking aus dem System genommen haben, kommen auch von selbst wieder zurück"
        echo "ACHTUNG: und beginnen damit, wieder Daten zu liefern."
    fi  # if [[ ${#PossibleCandidateGPUidx[@]} -gt 0 ]]

    ################################################################################
    #
    #                Die Auswertung der optimalen Kombination
    #
    ################################################################################

    [[ ${performanceTest} -ge 1 ]] && echo "$(date +%s): >7.< Auswertung und Miner-Steuerungen" >>perfmon.log

    printf "=========       Endergebnis        =========\n"
    echo "\$GLOBAL_GPU_COMBINATION_LOOP_COUNTER: $GLOBAL_GPU_COMBINATION_LOOP_COUNTER"
    echo "\$GLOBAL_MAX_PROFIT_CALL_COUNTER     : $GLOBAL_MAX_PROFIT_CALL_COUNTER"

    printf "############################################\n"

    # Wer diese Datei schreiben oder lesen will, muss auf das Verschwinden von *.lock warten...
    _reserve_and_lock_file ${RUNNING_STATE}          # Zum Schreiben reservieren...

    # Sichern der alten Datei. Vielleicht brauchen wir sie bei einem Abbruch zur Analyse
    [[ -f ${RUNNING_STATE} ]] && cp -f ${RUNNING_STATE} ${RUNNING_STATE}.BAK

    #####################################################
    # Ausgabe des neuen Status
    ####################################################

    printf 'UUID : GPU-Index : Enabled (1/0) : Watt : Running with AlgoName or Stopped if \"\"\n' >${RUNNING_STATE}
    printf '================================================================================\n'  >>${RUNNING_STATE}

    # Man könnte noch gegenchecken, dass die Summe aus laufenden und abgeschalteten
    #     GPU's die Anzahl GPU's ergeben muss, die im System sind.
    # Es gibt ja ${MAX_GOOD_GPUs}, ${SwitchOnCnt}, ${SwitchOffCnt}, ${SwitchNotCnt} und ${GPUsCnt}
    # Es müsste gelten: ${MAX_GOOD_GPUs} + ${SwitchOffCnt}, ${SwitchNotCnt} == ${GPUsCnt}
    #              und: ${MAX_GOOD_GPUs} >= ${SwitchOnCnt},
    #                   da möglicherweise die beste Kombination aus weniger als ${MAX_GOOD_GPUs} besteht.
    # Dann hätten wir diejenigen ${MAX_GOOD_GPUs} - ${SwitchOnCnt} noch zu überprüfen und zu stoppen !?!?

    # Es handelt sich um durch Kommas getrennte Kombinationen aus GPU-Index und entsprechendem AlgoIndex,
    #     die durch einen Doppelpunkt getrennt sind.
    #
    #    z.B.    "0:1,4:0,6:3,8:1,"   bedeutet:
    #
    #        4 GPUs mit den IndexNummern #0, #4, #6 und #8 wurden mit den angegebenen AlgorithmenIndexen berechnet:
    #
    #        GPU#0 hat (mindestens) 2 gewinnbringende Algorithmen, die über Index 0 und 1 angesteuert werden.
    #              Bei dieser Berechnung ist GPU#0 mit dem Algo und Watt, der hinter Index 1 steckt, berechnet worden.
    #        GPU#4 hat (mindestens) 1 gewinnbringenden Algorithmus, der über Index 0 angesteuert wird.
    #        GPU#6 hat (mindestens) 4 gewinnbringende Algorithmen, die über Index 0 bis 3 angesteuert werden.
    #              Bei dieser Berechnung ist GPU#6 mit dem Algo und Watt, der hinter Index 3 steckt, berechnet worden.
    #        GPU#8 hat (mindestens) 2 gewinnbringende Algorithmen, die über Index 0 und 1 angesteuert werden.
    #              Bei dieser Berechnung ist GPU#8 mit dem Algo und Watt, der hinter Index 1 steckt, berechnet worden.
    #
    unset GPUINDEXES; declare -ag GPUINDEXES
    read -a GPUINDEXES <<<"${MAX_PROFIT_GPU_Algo_Combination//,/ }"

    declare -i SwitchOnCnt=${#GPUINDEXES[@]}
    declare -i GPUsCnt=${#index[@]}

    if [[ ${verbose} == 1 ]]; then
        echo "Die optimale Konfiguration besteht aus diesen ${SwitchOnCnt} Karten:"
    fi
    ###                                                             ###
    #   Zuerst die am Gewinn beteiligten GPUs, die laufen sollen...   #
    ###                                                             ###
    for (( i=0; i<${SwitchOnCnt}; i++ )); do
        # Split the "String" at ":" into the 2 variables "gpu_idx" and "algoidx"
        read gpu_idx bc_algoidx <<<"${GPUINDEXES[$i]//:/ }"

        # Ausfiltern des guten gpu_idx aus PossibleCandidateGPUidx, das nun immer mehr abnimmt.
        # PossibleCandidateGPUidx enthält dann zum Schluss nur noch ebenfalls abzuschaltende GPUs
	pString=${PossibleCandidateGPUidx[@]}
	PossibleCandidateGPUidx=( ${pString/@(${gpu_idx})} )
	
        declare -n actGPUalgoName="GPU${gpu_idx}Algos"
        declare -n actGPUalgoWatt="GPU${gpu_idx}Watts"
        # Korrektur vom bc-indirekt-AlgoIdx zum tatsächlichen algoIdx
        declare -n actCandidatesAlgoIndexes="PossibleCandidate${gpu_idx}AlgoIndexes"
        algoidx=${actCandidatesAlgoIndexes[${bc_algoidx}]}
        gpu_uuid=${uuid[${gpu_idx}]}

        declare -n actSortedProfits="SORTED${gpu_idx}PROFITs"
        declare -n actbackedUpProfits="LAST_SORTED${gpu_idx}PROFITs"
        if [ ${debug} -eq 1 ]; then
            echo "Gerade noch laufende, nun veraltete Profits: ${actbackedUpProfits[@]}"
            echo "Neu berechnete, möglicherweise neue Profits: ${actSortedProfits[@]}"
        fi

        if [ ! ${#RunningGPUid[${gpu_uuid}]} -eq 0 ]; then
            #############################   CHAOS BEHADLUNG Anfang  #############################
            ### Schweres Thema: IST DER GPU-INDEX NOCH DER SELBE ??? <-----------------------
            #echo "\${gpu_idx}:${gpu_idx} == \${RunningGPUid[\${gpu_uuid}:${gpu_uuid}]}:${RunningGPUid[${gpu_uuid}]}"
            if [[ "${gpu_idx}" != "${RunningGPUid[${gpu_uuid}]}" ]]; then
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
            #printf "${gpu_uuid}:${gpu_idx}:${uuidEnabledSOLL[${gpu_uuid}]}:" >>${RUNNING_STATE}
            printf "${gpu_uuid}:${gpu_idx}" >>${RUNNING_STATE}

            # Ist die GPU generell Enabled oder momentan nicht zu behandeln?
            if [ ${WasItEnabled[${gpu_uuid}]} -eq 1 ]; then
                #
                # Die Karte WAR generell ENABLED
                #
                if [ ${uuidEnabledSOLL[${gpu_uuid}]} -eq 1 ]; then

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
                            cycle_counter[${actGPUalgoName[${algoidx}]}]=1
                        else
                            # MINER- Behandlung
                            if [ ${cycle_counter[${WhatsRunning[${gpu_uuid}]}]} -eq 1 ]; then
                                cycle_counter[${WhatsRunning[${gpu_uuid}]}]=0
                                echo "---> SWITCH-NOT: Eigentlich sollte von \"${WhatsRunning[${gpu_uuid}]}\" auf \"${actGPUalgoName[${algoidx}]}\" gewechselt werden."
                                echo "                 Laufende BTC/MInes: ${actbackedUpProfits[0]}  -  Neu einzustellende BTC/MInes wären: ${actSortedProfits[0]}"
                                actGPUalgoName[${algoidx}]=${WhatsRunning[${gpu_uuid}]}
                            else
                                echo "---> SWITCH-CMD: GPU#${gpu_idx} Algo WECHSELN von \"${WhatsRunning[${gpu_uuid}]}\" auf \"${actGPUalgoName[${algoidx}]}\""
                                cycle_counter[${actGPUalgoName[${algoidx}]}]=1
                            fi
                        fi
                    else
                        # Alter und neuer Algo ist gleich, kann weiterlaufen
                        echo "---> SWITCH-NOT: GPU#${gpu_idx} BLEIBT weiterhin auf \"${actGPUalgoName[${algoidx}]}\""
                        cycle_counter[${WhatsRunning[${gpu_uuid}]}]=0
                    fi
                    printf ":${uuidEnabledSOLL[${gpu_uuid}]}:${actGPUalgoWatt[${algoidx}]}:${actGPUalgoName[${algoidx}]}\n" >>${RUNNING_STATE}
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
                    if [ ${cycle_counter[${WhatsRunning[${gpu_uuid}]}]} -eq 1 ]; then
                        cycle_counter[${WhatsRunning[${gpu_uuid}]}]=0
                        echo "---> SWITCH-NOT: Da die GPU aber erst einen Zyklus gelaufen ist, lassen wir sie noch einen weiteren laufen. Sie bleibt im RUN_STATE Enabled"
                        actGPUalgoName[${algoidx}]=${WhatsRunning[${gpu_uuid}]}
                        printf ":1:${RunningWatts[${gpu_uuid}]}:${WhatsRunning[${gpu_uuid}]}\n" >>${RUNNING_STATE}
                    else
                        printf ":${uuidEnabledSOLL[${gpu_uuid}]}:0:\n" >>${RUNNING_STATE}
                    fi
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
                    printf ":${uuidEnabledSOLL[${gpu_uuid}]}:${actGPUalgoWatt[${algoidx}]}:${actGPUalgoName[${algoidx}]}\n" >>${RUNNING_STATE}
                    cycle_counter[${actGPUalgoName[${algoidx}]}]=1
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
                cycle_counter[${actGPUalgoName[${algoidx}]}]=1
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
        [ ${debug} -eq 1 ] && echo "==============="
    done

    # Die Guten GPUs sind raus aus PossibleCandidateGPUidx.
    # PossibleCandidateGPUidx enthält jetzt nur noch ebenfalls abzuschaltende GPUs,
    # die wir jetzt auf's SwitchOffGPUs Array packen
    SwitchOffGPUs+=( ${PossibleCandidateGPUidx[@]} )

    ###                                                             ###
    #   ... dann die GPU's, die abgeschaltet werden sollen            #
    ###                                                             ###

    declare -i SwitchOffCnt=${#SwitchOffGPUs[@]}

    # Auch hier kann es natürlich vorkommen, dass sich eine Indexnummer geändert hat
    #      und dass dann die CHAOS-BEHANDLUNG durchgeführt werden muss.
    if [ ${SwitchOffCnt} -gt 0 ]; then
        if [[ ${verbose} == 1 ]]; then
            echo "Die folgenden Karten müssen ausgeschaltet werden:"
        fi

        for (( i=0; $i<${SwitchOffCnt}; i++ )); do
            gpu_idx=${SwitchOffGPUs[$i]}
            gpu_uuid=${uuid[${gpu_idx}]}

            if [ ! ${#RunningGPUid[${gpu_uuid}]} -eq 0 ]; then
                #############################   CHAOS BEHADLUNG Anfang  #############################
                ### Schweres Thema: IST DER GPU-INDEX NOCH DER SELBE ??? <-----------------------
                if [[ "${gpu_idx}" != "${RunningGPUid[${gpu_uuid}]}" ]]; then
                    _notify_about_GPU_INDEX_CHANGED_WHILE_RUNNING "${name[${gpu_idx}]}" \
                                                                  "${gpu_uuid}" \
                                                                  "${RunningGPUid[${gpu_uuid}]}" \
                                                                  "${gpu_idx}"
                    exit
                fi
                #############################   CHAOS BEHADLUNG  Ende  #############################

                if [ ${WasItEnabled[${gpu_uuid}]} -eq 1 ]; then
                    #
                    # Die Karte WAR generell ENABLED
                    #
                    if [ -n "${WhatsRunning[${gpu_uuid}]}" ]; then
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

    declare -i SwitchNotCnt=${#SwitchNotGPUs[@]}
    if [ ${SwitchNotCnt} -gt 0 ]; then
        if [[ ${verbose} == 1 ]]; then
            echo "Die folgenden Karten müssen unverändert durchgeschleift werden:"
        fi

        for (( i=0; $i<${SwitchNotCnt}; i++ )); do
            gpu_idx=${SwitchNotGPUs[$i]}
            gpu_uuid=${uuid[${gpu_idx}]}
            runningWatts=0

            if [ ! ${#RunningGPUid[${gpu_uuid}]} -eq 0 ]; then
                #############################   CHAOS BEHADLUNG Anfang  #############################
                ### Schweres Thema: IST DER GPU-INDEX NOCH DER SELBE ??? <-----------------------
                if [[ "${gpu_idx}" != "${RunningGPUid[${gpu_uuid}]}" ]]; then
                    _notify_about_GPU_INDEX_CHANGED_WHILE_RUNNING "${name[${gpu_idx}]}" \
                                                                  "${gpu_uuid}" \
                                                                  "${RunningGPUid[${gpu_uuid}]}" \
                                                                  "${gpu_idx}"
                    exit
                fi
                #############################   CHAOS BEHADLUNG  Ende  #############################

                if [ ${WasItEnabled[${gpu_uuid}]} -eq 1 ]; then
                    runningWatts=${RunningWatts[${gpu_uuid}]}
                    #
                    # Die Karte WAR generell ENABLED
                    #
                    if [ -n "${WhatsRunning[${gpu_uuid}]}" ]; then
                        # MINER- Behandlung
                        echo "---> SWITCH-NOT: GPU#${gpu_idx} läuft noch mit \"${WhatsRunning[${gpu_uuid}]}\""
                    fi
                fi
            fi
            printf "${gpu_uuid}:${gpu_idx}:${uuidEnabledSOLL[${gpu_uuid}]}:${runningWatts}:${WhatsRunning[${gpu_uuid}]}\n" >>${RUNNING_STATE}
        done
    fi

    #if [ $((${SwitchOffCnt} + ${SwitchOnCnt})) -ne ${GPUsCnt} ]; then
    if [ $((${SwitchOffCnt} + ${SwitchOnCnt} + ${SwitchNotCnt})) -ne ${GPUsCnt} ]; then
        echo "---> ??? Oh je, ich glaube fast, wir haben da ein paar GPU's vergessen abzuschalten ??? <---"
    fi

    if [[ ${verbose} == 1 ]]; then
        echo "-------------------------------------------------"
    fi

    # Zugriff auf die Globale Steuer- und Statusdatei wieder zulassen
    _remove_lock                                     # ... und wieder freigeben

    printf "############################################\n"
    echo "Zugriff auf neues globales Switching Sollzustand Kommandofile ${RUNNING_STATE} freigegeben:"
    cat ${RUNNING_STATE}

    [[ ${performanceTest} -ge 1 ]] && echo "$(date +%s): >8.< Eintritt in den WARTEZYKLUS..." >>perfmon.log

    printf "=========         Ende des Zyklus um:         $(date "+%Y-%m-%d %H:%M:%S" )     $(date +%s)         =========\n"
    # Nach der obigen Freigabe laufen die GPUs los und starten/switchen/stoppen ihre MinerShells.
    # Und die algo_multi_abfrage.sh wartet 5 Sekunden vor dem erneuten Web-Abruf und touch des SYNCFILE
    while [ "${new_Data_available}" == "$(date --reference=${SYNCFILE} +%s)" ] ; do
        sleep 1
    done

done  ## while : 

