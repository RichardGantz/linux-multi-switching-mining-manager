#!/bin/bash
###############################################################################
SRC_DIR=..
ARCHIVE_NAME=lmms.tar.gz

# Das wahre Linux-Multi-Mining-Switcher (lmms) Initialisierungs-Skript wird,
# um dessen Namen für den Start verwenden zu können, vorübergehend umbenannt,
# um es durch das vorübergehende "Auspackungsskript" zu ersetzen.
# So kann die Installation mit dem selben Namen beginnen wie jeder normale Initialisierungsstart

# Die folgenden Dateien und Verzeichnisse wurden vorübergehend oder endgültig herausgenommen.
# Muss noch reiflich überlegt werden.
#
# Da diese Datei in jedem System sowieso automatisch erstellt wird, macht es nur Sinn, wenn man vorher scheon
# weiss, dass man eine bestimmte GPU von Anfang DISABLED haben möchte.
#   ${SRC_DIR}/GLOBAL_GPU_SYSTEM_STATE.in \
#
# Im Miners-Folder könnte man ein einzelnes Muster mitgeben, das vom System im Normalbetrieb übergangen wird.
# Im Moment wird nur noch die all.miner.fees übergeben
#   ${SRC_DIR}/miners/* \

# ACHTUNG:
# -------
#
# ../miners - Verzeichnis ist kritisch. Soll nicht immer überschrieben werden
#             wegen der minerfolder, etc.
# globals.inc ist kritisch wegen des CUDAExport-Pfades

rm -r ../miners/*~ ../screen/.*~
tar -cvzf ${ARCHIVE_NAME} \
    ${SRC_DIR}/algo_infos.inc \
    ${SRC_DIR}/algo_multi_abfrage.sh \
    ${SRC_DIR}/all.miningpoolhub \
    ${SRC_DIR}/all.nicehash \
    ${SRC_DIR}/all.suprnova \
    ${SRC_DIR}/GLOBAL_ALGO_DISABLED \
    ${SRC_DIR}/globals.inc \
    ${SRC_DIR}/gpu-abfrage.inc \
    ${SRC_DIR}/gpu-abfrage.sh \
    ${SRC_DIR}/kwh_netz_kosten.in \
    ${SRC_DIR}/kwh_solar_akku_kosten.in \
    ${SRC_DIR}/kwh_solar_kosten.in \
    ${SRC_DIR}/logfile_analysis.inc \
    ${SRC_DIR}/miner-func.inc \
    ${SRC_DIR}/set_live_miners.sh \
    ${SRC_DIR}/multi_mining_calc.inc \
    ${SRC_DIR}/multi_mining_calc.sh \
    ${SRC_DIR}/perfmon.sh \
    ${SRC_DIR}/pool.infos \
    ${SRC_DIR}/pstree_log.sh \
    ${SRC_DIR}/README_GER.md \
    ${SRC_DIR}/README.md \
    ${SRC_DIR}/benchmarking/auto_benchmark_all_missing.sh \
    ${SRC_DIR}/benchmarking/bench_30s_2.sh \
    ${SRC_DIR}/benchmarking/nvidia-befehle/nvidia-query.inc \
    ${SRC_DIR}/benchmarking/README_BENCH_GER.md \
    ${SRC_DIR}/benchmarking/tweak_commands.sh \
    ${SRC_DIR}/GPU-skeleton/benchmark_skeleton.json \
    ${SRC_DIR}/GPU-skeleton/gpu-bENCH.inc \
    ${SRC_DIR}/GPU-skeleton/gpu-bENCH.sh \
    ${SRC_DIR}/GPU-skeleton/gpu_gv-algo.sh \
    ${SRC_DIR}/GPU-skeleton/MinerShell.sh \
    ${SRC_DIR}/GPU-skeleton/README.md \
    ${SRC_DIR}/miners/* \
    ${SRC_DIR}/distribution/make_install_package.sh \
    ${SRC_DIR}/distribution/multi_mining_calc.sh.header \
    ${SRC_DIR}/estimate_yeses.sh \
    ${SRC_DIR}/estimate_yeses.inc \
    ${SRC_DIR}/estimate_delays.sh \
    ${SRC_DIR}/estimate_delays.inc \
    ${SRC_DIR}/diagramm_validate_mm_GPU.php \
    ${SRC_DIR}/screen/screenrc.* \
    ${SRC_DIR}/screen/.screenrc.* \
    ${SRC_DIR}/GPU-[^s]*/benchmark_GPU*.json \
    ${SRC_DIR}/tar_logs.sh

#    ${SRC_DIR}/benchmarking/nvidia-befehle/nvidia-settings \
#    ${SRC_DIR}/benchmarking/nvidia-befehle/smi \
#    ${SRC_DIR}/benchmarking/nvidia-befehle/smi.copy \

# Wir machen das Archiv selbstextrahierend
cat multi_mining_calc.sh.header ${ARCHIVE_NAME} >multi_mining_calc.install.sh
chmod +x multi_mining_calc.install.sh
