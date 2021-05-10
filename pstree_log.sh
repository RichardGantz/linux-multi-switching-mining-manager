#!/bin/bash
###############################################################################
#
# Bisschen Analyse der perfmon Daten

[[ 1 -eq 0 ]] && \
    (rootPID=$(ps -fu $(whoami) | grep -e "$(< multi_mining_calc.pid)" | grep -v 'grep -e ' \
                      | awk -v pid=$(< multi_mining_calc.pid) -e '$3 != pid {print $3; exit }')
     echo "$1:$rootPID" >>pstree.log)

echo "$1:MessungsStart" >>pstree.log
while :; do
    #pstree -c $rootPID >>pstree.log
    echo "$(date +%s):" >>pstree.log
    ps -fu $(whoami) | grep -e "$(< multi_mining_calc.pid)" \
        | grep -v 'grep -e ' \
        | grep -v 'pstree_log.sh' \
               >>pstree.log
done
