#!/bin/bash
###############################################################################
[ ! -f .multi_mining_calc.bak ] && cp multi_mining_calc.sh .multi_mining_calc.bak

if [ 1 -eq 0 ]; then
    cp multi_mining_calc.sh .multi_mining_calc.sh

    echo '#!/bin/bash
###############################################################################
# Self-Destroying Installation File
#
tar xvzf .multiminer.tar.gz
' >multi_mining_calc.sh
fi

tar -cvzf .multiminer.tar.gz \
     algo_infos.inc \
     algo_multi_abfrage.sh \
     all.miningpoolhub \
     all.nicehash \
     all.suprnova \
     .FAKE.nvidia-smi.output \
     GLOBAL_ALGO_DISABLED \
     GLOBAL_GPU_SYSTEM_STATE.in \
     globals.inc \
     gpu-abfrage.inc \
     gpu-abfrage.sh \
     kwh_netz_kosten.in \
     kwh_solar_akku_kosten.in \
     kwh_solar_kosten.in \
     logfile_analysis.inc \
     miner-func.inc \
     m_m_calc.sh \
     multi_mining_calc.inc \
     .multi_mining_calc.sh \
     multi_mining_calc.sh \
     perfmon.sh \
     pool.infos \
     pstree_log.sh \
     README_GER.md \
     README.md \
     smartmeter \
     benchmarking/auto_benchmark_all_missing.sh \
     benchmarking/bench_30s_2.sh \
     benchmarking/nvidia-befehle/nvidia-query.inc \
     benchmarking/nvidia-befehle/nvidia-settings \
     benchmarking/nvidia-befehle/smi \
     benchmarking/nvidia-befehle/smi.copy \
     benchmarking/README_BENCH_GER.md \
     benchmarking/tweak_commands.sh \
     miners/* \
     GPU-skeleton/benchmark_skeleton.json \
     GPU-skeleton/gpu-bENCH.inc \
     GPU-skeleton/gpu-bENCH.sh \
     GPU-skeleton/gpu_gv-algo.sh \
     GPU-skeleton/MinerShell.sh \
     GPU-skeleton/README.md
