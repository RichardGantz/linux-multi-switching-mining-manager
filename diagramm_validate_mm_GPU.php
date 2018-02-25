#!/usr/bin/php
<?php
include ("/usr/share/jpgraph/jpgraph.php");
include ("/usr/share/jpgraph/jpgraph_line.php");
include ("/usr/share/jpgraph/jpgraph_error.php");


// variablen übernehmen aus der bash "php diagramm_validate_mm_GPU.php Archivverz 406514 xxxx.csv Grafverzeichnis"
// die nummer ist das Verzeichniss der logs und wird mit " $argv[1] ", etc.
// dem php script übergeben 
//php diagramm_validate_mm_GPU.php /home/avalon/temp/graf/.logs 406514 mm_cycles.csv /home/avalon/temp/graf
//php diagramm_validate_mm_GPU.php /home/avalon/temp/graf/.logs 406514 GPU#1.csv /home/avalon/temp/graf
// ( Falls Sonderbehandlungen nötig sein sollten: if ( $_SERVER["LOGNAME"] == "richard" ) )

$ARCHIV_DIR    ="$argv[1]";
$LOGNR         ="$argv[2]";
$CSV           ="$argv[3]";
$GRAF_DST_DIR  ="$argv[4]";

$LOGFILES_ROOT ="$ARCHIV_DIR/$LOGNR";

$row = 0;
if (($handle = fopen("$LOGFILES_ROOT/$CSV", "r")) !== FALSE) {
    while (($data = fgetcsv($handle, 20, ";")) !== FALSE) {
        $num = count($data);
        for ($c=0; $c < $num; $c++) {
            if ($c==0) { $datay[] = $data[$c]; }
            if ($c==1) { $dataY[] = $data[$c]; }
            if ($c==2) { $dataZ[] = $data[$c]; }
            //echo $data[$c] . "\n";
        }
        $row++;  // Gleichzeitig Anzahl Member der Arrays, weil wir den letzten Wert verwerfen
    }
    fclose($handle);
    $y = count( $datay );
    $Y = count( $dataY );
    if ( $y == $Y ) {
        array_pop( $datay );
        array_pop( $dataY );
        // array_pop( $dataZ );
    }
    elseif ( $y > $Y ) { array_pop( $datay ); }
    else               { array_pop( $dataY ); }
}

//Auflöhsung in pixel
$graph = new Graph(1920,1200,"auto");
$graph->img->SetMargin(40,20,20,80);
$graph->img->SetAntiAliasing();
$graph->SetScale("textlin");

//überschrift des diagrams
$GPUNAME=substr($CSV,0,strlen($CSV)-4);
if ( substr($CSV,0,1) == "m" ) {
   $Titel    = "MM's Wartezeiten GPU-Daten und Dauer des Zyklus Log $LOGNR";
   $Legendey = "MM WAIT-Zeit";
   $LegendeY = "MM RUN Zeit";
} else {
   $Titel    = $GPUNAME."-Daten für MM gültig und Miners on/off Log $LOGNR";
   $Legendey = "Data Valid";
   $LegendeY = "Miners on/off";
}

$graph->title->Set( $Titel );
$graph->title->SetFont(FF_FONT1,FS_BOLD);


//Intervalle (10)einbauen und nicht jedes (2) nur beschriften
$graph->xaxis->SetTextTickInterval(10);
$graph->xaxis->SetTextLabelInterval(2);
//Schrift um 90 Grad drehen
$graph->xaxis->SetLabelAngle(90);

// vertikale leiste bzw höhe erweitern in %
$graph->yscale->SetGrace(1);

//Legende Positionieren % zu erst horizontal dann vertikal
$graph->legend->Pos(0.5,0.99,"center","bottom");
$graph->legend->SetLayout(LEGEND_HOR);
$graph->legend->SetFont(FF_FONT1,FS_BOLD);

//titel der horizentrale bestimmen
$graph->xaxis->title->Set("Zyklen");


//graph hinzufügen bzw linie
$p1 = new LinePlot($datay);
//$p1->mark->SetType(MARK_FILLEDCIRCLE);
$p1->SetLegend( $Legendey );
//$p1->mark->SetFillColor("red");
//$p1->mark->SetWidth(1);
$p1->SetColor("blue");
//$p1->SetCenter();
$graph->Add($p1);


//graph hinzufügen bzw linie
$p2 = new LinePlot($dataY);
//$p2->mark->SetType(MARK_FILLEDCIRCLE);
$p1->SetLegend( $LegendeY );
//$p2->mark->SetFillColor("red");
//$p2->mark->SetWidth(1);
$p2->SetColor("red");
//$p2->SetCenter();
//graph hinzufügen
$graph->Add($p2);


// Ausgabe binar
$fileName = "$GRAF_DST_DIR/$LOGNR-$GPUNAME.png";
$graph->Stroke($fileName);

?>
