#!/usr/bin/php
<?php
include ("jpgraph/jpgraph.php");
include ("jpgraph/jpgraph_line.php");
include ("jpgraph/jpgraph_error.php");
#require_once ('jpgraph/jpgraph_utils.inc.php');

// variablen übernehmen aus der bash "php diagramm_validate_mm_GPU.php Archivverz 406514 xxxx.csv Grafverzeichnis"
// die nummer ist das Verzeichniss der logs und wird mit " $argv[1] ", etc.
// dem php script übergeben 
//php diagramm_validate_mm_GPU.php /home/avalon/temp/graf/.logs 406514 mm_cycles.csv /home/avalon/temp/graf
//php diagramm_validate_mm_GPU.php /home/avalon/temp/graf/.logs 406514 GPU#1.csv /home/avalon/temp/graf
// ( Falls Sonderbehandlungen nötig sein sollten: if ( $_SERVER["LOGNAME"] == "richard" ) )

$HOME         =getenv( "HOME" );

$miner_name   ="t-rex";
$miner_version="0.19.14";
$miner_device ="9";
$coin         ="daggerhashimoto";

$MAX_VALUES_FROM_CSV=100;

if ( isset( $argv[1] ) ) $miner_device="$argv[1]";
if ( isset( $argv[2] ) ) $MAX_VALUES_FROM_CSV="$argv[2]";

$ARCHIV_DIR    ="$HOME/git/linux-multi-switching-mining-manager/.logs/home/avalon/miner/t-rex";
$LOGNR         ="1619420865";
$CSV           ="t-rex-${miner_device}-${coin}-[${LOGNR}].log.csv";
$GRAF_DST_DIR  =".";

$LOGFILES_ROOT ="$ARCHIV_DIR";

// Weil der erste Wert bisher immer bei 61s Uptime vom t-rex ausgegeben wurde, zwei Werte am Anfang,
// damit die Verhältnisse auf der x-Achse stimmen
// Die ersten drei Werte setzen wir auf 0, und die x-Achse auf 1s
$datax[] = 1;
$dataY[] = 0;
$dataZ[] = 0;
// Die nächsten drei Werte setzen wir auf 0, und die x-Achse auf 31s
$datax[] = 31;
$dataY[] = 0;
$dataZ[] = 0;

$row = 1;
if (($handle = fopen("$LOGFILES_ROOT/$CSV", "r")) !== FALSE) {
  # 0 bedeutet: Länge nicht begrenzt
  while (($data = fgetcsv($handle, 0, ";")) !== FALSE) {
    #    while (($data = fgetcsv($handle, 20, ";")) !== FALSE) {
    $num = count($data);
    for ($c=0; $c < $num; $c++) {
      if ($c==0) { $datax[] = $data[$c]; }
      if ($c==1) { $dataY[] = $data[$c]; }
      if ($c==2) { $dataZ[] = $data[$c]; }
      //echo $data[$c] . "\n";
    }
    if ($row >= $MAX_VALUES_FROM_CSV) break;
    $row++;  // Gleichzeitig Anzahl Member der Arrays, weil wir den letzten Wert verwerfen
  }
  fclose($handle);
  $x = count( $datax );
  $Y = count( $dataY );
  $Z = count( $dataZ );
}

//Auflöhsung in pixel
//$graph = new Graph(6000,4000,"auto");
$graph = new Graph(1920,1200,"auto");
$graph->img->SetMargin(40,20,20,80);
$graph->img->SetAntiAliasing();
$graph->SetScale("textlin");

/**/
//überschrift des diagrams.
$Titel    = substr( $CSV, 0, -4 )." - Mittelwerte OKs seit Start";

$LegendeY = "t-rex Shares/min Average";
$LegendeZ = "Selbst errechneter Durchschnitt (OKs / Uptime * 60)";

$graph->title->Set( $Titel );
$graph->title->SetFont(FF_FONT1,FS_BOLD);

/* * /

   //Intervalle (10) einbauen und nicht jedes (2) nur beschriften
   $graph->xaxis->SetTextTickInterval(10);
   $graph->xaxis->SetTextLabelInterval(2);
   //Schrift um 90 Grad drehen
   $graph->xaxis->SetLabelAngle(90);
   / * */

// x-Achse aus unseren Werten erstellen
$graph->xaxis->SetTickLabels( $datax );
//$graph->xaxis->SetTextTickInterval(10);
$graph->xaxis->SetTextLabelInterval( intval( ($x - 1) / 100 + 1 ) );
$graph->xaxis->SetLabelAngle(90);

// vertikale leiste bzw höhe erweitern in %
$graph->yscale->SetGrace(1);

//Legende Positionieren % zu erst horizontal dann vertikal
$graph->legend->Pos(0.5,0.99,"center","bottom");
$graph->legend->SetLayout(LEGEND_HOR);
$graph->legend->SetFont(FF_FONT1,FS_BOLD);

//titel der horizentrale bestimmen
$graph->xaxis->title->Set("Uptime in Sekunden");

//graph hinzufügen bzw linie
$p2 = new LinePlot( $dataY    );
$p2->SetLegend(     $LegendeY );
$p2->SetColor(      "blue"    );
//$p2->SetCenter();
$graph->Add($p2);

//graph hinzufügen bzw linie
$p3 = new LinePlot( $dataZ    );
$p3->SetLegend(     $LegendeZ );
$p3->SetColor(      "red"     );
//$p3->SetCenter();
$graph->Add($p3);

// Ausgabe binär
$fileName = "$GRAF_DST_DIR/$CSV-".substr( "00000".($x-1), -5 )."-Werte.png";
$graph->Stroke( $fileName );

?>
