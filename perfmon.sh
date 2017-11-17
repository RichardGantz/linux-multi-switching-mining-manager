#!/bin/bash
################################################################################
#
# Bisschen Analyse der perfmon Daten

echo "######################################################################"
echo "Die Entwicklung der Berechnungsdauern in Sekunden über die Zeit hinweg"
echo "Jede Zeile ist ein 31s Zyklus"
cat perfmon.log | gawk -e '
BEGIN {  FS=":"; start=0; previous=0  }
{
    if (start==0) start=$1
    last=$1
    if (previous>start) {
        if ( last - previous > 60 ) {
            delta = previous - start
            print "6-In diesem Abschnitt " delta " Sekunden gelaufen von " start " bis " previous
            if (delta > 60)    print "6-Das sind " delta/60    " Minuten"
            if (delta > 3600)  print "6-Das sind " delta/3600  " Stunden"
            if (delta > 86400) print "6-Das sind " delta/86400 " Tage"
            start=last
            print "6-NEUSTART von multi_mining_calc.sh ab " start
        }
    }
    previous = last
}
$2 ~ /1./ {
    step = 1
    while (step < 8) {
        cycle=$1; getline
        print "Von Schritt " step " zu Schritt " ++step " in " $1-cycle " Sekunden"
    }
}                         
END {
            delta = previous - start
            print "6-In diesem Abschnitt " delta " Sekunden gelaufen von " start " bis " previous
            if (delta > 60)    print "6-Das sind " delta/60    " Minuten"
            if (delta > 3600)  print "6-Das sind " delta/3600  " Stunden"
            if (delta > 86400) print "6-Das sind " delta/86400 " Tage"
}
' | grep 6 | awk -e '/^6-/ {print; next} $3==5 {s=$8; getline; print s+$8}'


exit


################################################################################
# Testeinstellung mit dem Redeklarationsverfahren, die "elegante" Methode
# arrayRedeclareTest=1

# In diesem Abschnitt 9138 Sekunden gelaufen
# Das sind 152.3 Minuten
# Das sind 2.53833 Stunden

# bc 
# [bc] 
# [bc] <defunct> 
# /bin/bash ./algo_multi_abfrage.sh 
# /bin/bash ./gpu_gv-algo.sh 
# /bin/bash ./multi_mining_calc.sh 
# [multi_mining_ca] 
# [multi_mining_ca] <defunct> 

# Zuletzt 14 Sekunden gelaufen (Nur die Berechnungen ab Einzelberechnung bis Beginn Auswertung

################################################################################
# Testeinstellung mit dem Redeklarationsverfahren, die "elegante" Methode
# arrayRedeclareTest=0
#
# Zuletzt 9288 Sekunden gelaufen
# Das sind 154.8 Minuten
# Das sind 2.58 Stunden

# bc 
# [bc] 
# [bc] <defunct> 
# /bin/bash ./algo_multi_abfrage.sh 
# /bin/bash ./gpu_gv-algo.sh 
# /bin/bash ./multi_mining_calc.sh 
# [expr] <defunct> 
# [multi_mining_ca] 
# [multi_mining_ca] <defunct> 

# Zuletzt 17 Sekunden gelaufen

#cat perfmon.log | gawk -e '
cat perfmon.log | gawk -e '
BEGIN {
    FS=":"; start=0}
{
    if (start==0) start=$1; else last=$1
    if (previous>start) {
        if ( last - previous > 60 ) {
            delta=last - start
            print "In diesem Abschnitt " delta " Sekunden gelaufen"
            if (delta > 60)    print "Das sind " delta/60    " Minuten"
            if (delta > 3600)  print "Das sind " delta/3600  " Stunden"
            if (delta > 86400) print "Das sind " delta/86400 " Tage"
            start=last
        }
    }
    previous = last
}                         
END {
    delta=last - start
    print "Zuletzt " delta " Sekunden gelaufen"
    if (delta > 60)    print "Das sind " delta/60    " Minuten"
    if (delta > 3600)  print "Das sind " delta/3600  " Stunden"
    if (delta > 86400) print "Das sind " delta/86400 " Tage"
}
'

# Wieviel unterschiedliche Prozesse wurden "gefilmt"
cat pstree.log | grep -v -e ':$' -e ':M' | awk -e '{out=""; for (i=8;i<=NF;i++) out=out $i " "; print out}' | sort -u

cat pstree.log | grep -e ':$' | gawk -e '
BEGIN {
    FS=":"; start=0}
{
    if (start==0) start=$1; else last=$1
    if (previous>start) if ( last - previous > 3600 ) start=last
    previous = last
}                         
END {
    delta=last - start
    print "Zuletzt " delta " Sekunden gelaufen"
    if (delta > 60)    print "Das sind " delta/60    " Minuten"
    if (delta > 3600)  print "Das sind " delta/3600  " Stunden"
    if (delta > 86400) print "Das sind " delta/86400 " Tage"
}
'
