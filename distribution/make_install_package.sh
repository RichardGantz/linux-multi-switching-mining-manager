#!/bin/bash
###############################################################################
SRC_DIR=..
ARCHIVE_NAME=lmms.tar.gz

# Das wahre Linux-Multi-Mining-Switcher (lmms) Initialisierungs-Skript wird,
# um dessen Namen für den Start verwenden zu können, vorübergehend umbenannt,
# um es durch das vorübergehende "Auspackungsskript" zu ersetzen.
# So kann die Installation mit dem selben Namen beginnen wie jeder normale Initialisierungsstart

tar -cvzf ${ARCHIVE_NAME} \
    ${SRC_DIR}/algo_infos.inc \
    ${SRC_DIR}/algo_multi_abfrage.sh \
    ${SRC_DIR}/all.miningpoolhub \
    ${SRC_DIR}/all.nicehash \
    ${SRC_DIR}/all.suprnova \
    ${SRC_DIR}/.FAKE.nvidia-smi.output \
    ${SRC_DIR}/GLOBAL_ALGO_DISABLED \
    ${SRC_DIR}/GLOBAL_GPU_SYSTEM_STATE.in \
    ${SRC_DIR}/globals.inc \
    ${SRC_DIR}/gpu-abfrage.inc \
    ${SRC_DIR}/gpu-abfrage.sh \
    ${SRC_DIR}/kwh_netz_kosten.in \
    ${SRC_DIR}/kwh_solar_akku_kosten.in \
    ${SRC_DIR}/kwh_solar_kosten.in \
    ${SRC_DIR}/logfile_analysis.inc \
    ${SRC_DIR}/miner-func.inc \
    ${SRC_DIR}/m_m_calc.sh \
    ${SRC_DIR}/multi_mining_calc.inc \
    ${SRC_DIR}/multi_mining_calc.sh \
    ${SRC_DIR}/perfmon.sh \
    ${SRC_DIR}/pool.infos \
    ${SRC_DIR}/pstree_log.sh \
    ${SRC_DIR}/README_GER.md \
    ${SRC_DIR}/README.md \
    ${SRC_DIR}/smartmeter \
    ${SRC_DIR}/benchmarking/auto_benchmark_all_missing.sh \
    ${SRC_DIR}/benchmarking/bench_30s_2.sh \
    ${SRC_DIR}/benchmarking/nvidia-befehle/nvidia-query.inc \
    ${SRC_DIR}/benchmarking/nvidia-befehle/nvidia-settings \
    ${SRC_DIR}/benchmarking/nvidia-befehle/smi \
    ${SRC_DIR}/benchmarking/nvidia-befehle/smi.copy \
    ${SRC_DIR}/benchmarking/README_BENCH_GER.md \
    ${SRC_DIR}/benchmarking/tweak_commands.sh \
    ${SRC_DIR}/miners/* \
    ${SRC_DIR}/GPU-skeleton/benchmark_skeleton.json \
    ${SRC_DIR}/GPU-skeleton/gpu-bENCH.inc \
    ${SRC_DIR}/GPU-skeleton/gpu-bENCH.sh \
    ${SRC_DIR}/GPU-skeleton/gpu_gv-algo.sh \
    ${SRC_DIR}/GPU-skeleton/MinerShell.sh \
    ${SRC_DIR}/GPU-skeleton/README.md \
    ${SRC_DIR}/distribution/make_install_package.sh \
    ${SRC_DIR}/distribution/multi_mining_calc.sh.header

# Wir machen das Archiv selbstextrahierend
cat multi_mining_calc.sh.header ${ARCHIVE_NAME} >multi_mining_calc.install.sh
chmod +x multi_mining_calc.install.sh
