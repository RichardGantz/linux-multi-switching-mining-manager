#include <stdio.h>
#include <stdlib.h>
#include <string.h>
//#include <unistd.h>  //Header file for sleep(). man 3 sleep for details.

#define useThreads 1
// Ohne Verwendung von malloc (also Variablen im Stack) verschwindet irgendwann die Funktion (und damit ihr Stack), die den Thread gestartet hat,
//      BEVOR die CPUs Gelegenheit hatten, den Thread überhaupt zu starten.
//      d.h. die Werte, die dann auf dem Stack stehen, sind völlig andere!
// Dann tritt bestenfalls irgendwann ein Speicherzugriffsfehler auf und es erfolgt Abbruch und Erzeugung eines coredump
// Das war hier (8 Prozessoren) schon ab 140 Threads der Fall. Manchmal kam er sogar bis über 400 Threads.
// Nein, die Werte müssen in Speicher gelegt werden, der immer noch da ist, auch wenn der Thread Stunden später gestartet werden sollte.
#if useThreads
#include <pthread.h>
#define useMALLOC 1
#else
#define useMALLOC 0
#endif

#define DEBUG 0
#define VERBOSE 0
#define MAX_GOOD_GPUs 13
#define BEST_ALGO_CNT  3

/*********************************************************************************

Noch zu klären:

1. BEST_ALGO_CNT und MAX_GOOD_GPUs müssen als Parameter übergeben werden.
2. Übergeben werden muss alles mögliche:
   exactNumAlgos[ gpu_idx ] Array

/*********************************************************************************/

long GLOBAL_GPU_COMBINATION_LOOP_COUNTER=0;
int  max_watts = 0;
char best_profit_algo_combi[ (3+1+3+1)*MAX_GOOD_GPUs + 1 ]; // 3 Stellen gpu_idx + 1x":" + 3 algoIdx + 1x","
char max_mines_algo_combi  [ (3+1+3+1)*MAX_GOOD_GPUs + 1 ]; // 3 Stellen gpu_idx + 1x":" + 3 algoIdx + 1x","
double solar_kosten_btc;

// Zu übergebende Variablen:
int SolarWattAvailable = 0;
double kWhMax = .0000090161;
double kWhMin = .0000036064;
double max_profit=.0000965496; // Von den Einzelberechnungen (Frage: Was ist mit der GPU:Algo-Kombination? Ist die notfals auch noch bekannt?
double max_mines=.0001231651;

//int PossibleCandidateGPUidx[MAX_GOOD_GPUs+1] = { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, MAX_GOOD_GPUs };
//int PossibleCandidateGPUidx[MAX_GOOD_GPUs+1] = { 0, 2, 4, 6, 8, 10, 12, 1, 3, 5, 7, 9, 11, 10 };
//int exactNumAlgos[MAX_GOOD_GPUs+1] = { 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 10 };
int PossibleCandidateGPUidx[MAX_GOOD_GPUs+1] = { 0, 2, 4, 6, 8, 10, 12, 1, 3, 5, 7, 9, 11, MAX_GOOD_GPUs };
int exactNumAlgos[MAX_GOOD_GPUs+1] = { 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, MAX_GOOD_GPUs };

/* Well sorted */
int WATTS [MAX_GOOD_GPUs][BEST_ALGO_CNT] = {
    { 123, 123, 118 }
  , { 167, 167, 166 }
  , { 202, 202, 202 }
  , { 202, 202, 202 }
  , { 202, 202, 202 }
  , { 123, 123, 123 }
  , { 202, 202, 202 }
  , { 123, 123, 123 }
  , { 123, 123, 123 }
  , { 123, 123, 123 }
  , { 123, 123, 123 }
  , { 123, 123, 123 }
  , { 202, 202, 202 }
};
double MINES [MAX_GOOD_GPUs][BEST_ALGO_CNT] = {
    { .0001007585, .0001004522, .0000881206 }
  , { .0000888402, .0000888380, .0000680249 }
  , { .0001231061, .0001230783, .0001230404 }
  , { .0001231061, .0001230783, .0001230404 }
  , { .0001231061, .0001230783, .0001230404 }
  , { .0001231651, .0001219336, .0001085930 }
  , { .0001231061, .0001230783, .0001230404 }
  , { .0001231651, .0001219336, .0001085930 }
  , { .0001231651, .0001219336, .0001085930 }
  , { .0001231651, .0001219336, .0001085930 }
  , { .0001231651, .0001219336, .0001085930 }
  , { .0001231651, .0001219336, .0001085930 }
  , { .0001231061, .0001230783, .0001230404 }
};
/**/
/* Reihenfolge vertauscht
int WATTS [MAX_GOOD_GPUs][BEST_ALGO_CNT] = {
    { 118, 123, 123 }
  , { 166, 167, 167 }
  , { 202, 202, 202 }
  , { 202, 202, 202 }
  , { 202, 202, 202 }
  , { 123, 123, 123 }
  , { 202, 202, 202 }
  , { 123, 123, 123 }
  , { 123, 123, 123 }
  , { 123, 123, 123 }
  , { 123, 123, 123 }
  , { 123, 123, 123 }
  , { 202, 202, 202 }
};
double MINES [MAX_GOOD_GPUs][BEST_ALGO_CNT] = {
    { .0000881206, .0001004522, .0001007585 }
  , { .0000680249, .0000888380, .0000888402 }
  , { .0001230404, .0001230783, .0001231061 }
  , { .0001230404, .0001230783, .0001231061 }
  , { .0001230404, .0001230783, .0001231061 }
  , { .0001085930, .0001219336, .0001231651 }
  , { .0001230404, .0001230783, .0001231061 }
  , { .0001085930, .0001219336, .0001231651 }
  , { .0001085930, .0001219336, .0001231651 }
  , { .0001085930, .0001219336, .0001231651 }
  , { .0001085930, .0001219336, .0001231651 }
  , { .0001085930, .0001219336, .0001231651 }
  , { .0001230404, .0001230783, .0001231061 }
};
 */

#if useThreads
#define TIDS 10000
pthread_mutex_t lock;
pthread_t tid[ TIDS ];
int tidsCnt = 0;
#else
// Für eine fortlaufende Ausgabe, die bei der Verwendung von Threads nicht gebraucht werden
double old_max_profit;
double old_max_mines;
#endif

void * _CALCULATE_GV_of_all_TestCombinationGPUs_members( void * arg ) {
  // Der Compiler weiss dadurch, dass TestCombinationGPUs auf ein int zeigt und kann damit Arrays richtig indexieren
  int *TestCombinationGPUs = (int *) arg;
  int MAX_GPU_TIEFE = TestCombinationGPUs[ MAX_GOOD_GPUs ];
#if DEBUG
  char intArrayStr[ (3+1)*(MAX_GOOD_GPUs+1) + 1 ];
  char intValStr  [  3+1 + 1 ];
  intArrayStr[0] = '\0';
  intValStr[0]   = '\0';
  for (int i=0; i<MAX_GPU_TIEFE; i++) {
    sprintf( intValStr, "%3i,", TestCombinationGPUs[i] );
    strcat( intArrayStr, intValStr );
  }
  printf( "Entered _CALCULATE_GV_of_all_TestCombinationGPUs_members with %i Members: %s\n",
	  MAX_GPU_TIEFE, intArrayStr );
#endif
  double LOCAL_max_profit = 0;
  double LOCAL_max_mines  =.0;
  char   LOCAL_best_profit_algo_combi[ (3+1+3+1)*MAX_GOOD_GPUs + 1 ]; // 3 Stellen gpu_idx + 1x":" + 3 algoIdx + 1x","
  char   LOCAL_max_mines_algo_combi  [ (3+1+3+1)*MAX_GOOD_GPUs + 1 ]; // 3 Stellen gpu_idx + 1x":" + 3 algoIdx + 1x","
  long   LOCAL_GPU_COMBINATION_LOOP_COUNTER = 0;
  int    LOCAL_max_watts  = 0;

  double gesamt_kosten;
  double real_profit;
  double mines_sum;
  int    watts_sum;

  // Initialisierung des verschachtelten for-Loop-Simulations-Stellwerk testGPUs mit Nullen, Anzahl Members ist dieselbe wie die von TestCombinationGPUs
  // Der key in testGPUs ist dabei identisch mit dem val des TestCombinationGPUs[ key ], was ein gpu_idx ist.
  // Der val des testGPUs[ key ] durchläuft dabei die Anzahl an algos, im Moment 3 an der Zahl, also 0 bis 2
  int testGPUs[MAX_GOOD_GPUs+1];
  memcpy( testGPUs, TestCombinationGPUs, (MAX_GOOD_GPUs+1) * sizeof(int) );
  memset( testGPUs, '\0', MAX_GOOD_GPUs * sizeof(int) );

  // bash: algosCombinationKey+="${gpu_idx}:${algoIdx},"
  char algosCombinationKey[ (3+1+3+1)*MAX_GOOD_GPUs + 1 ];
  char algosCombination   [  3+1+3+1 + 1 ];
  int lfdGPU;

#if !useThreads
  old_max_profit = max_profit;
  old_max_mines  = max_mines;
#endif

  int finished=0;
  while ( finished == 0 ) {
    // Der GV_COMBINATION key des assoziativen Arrays
    algosCombinationKey[0] = '\0';
    algosCombination[0]    = '\0';
    watts_sum              = 0;
    mines_sum              = .0;

    // Aufaddieren der Watts und Mines über alle MAX_GPU_TIEFE GPU's
    for ( lfdGPU=0; lfdGPU<MAX_GPU_TIEFE; lfdGPU++ ) {
      // Index innerhalb der "GPU${idx}*" Arrays, dessen Werte zu verarbeiten sind
      int gpu_idx = TestCombinationGPUs[ lfdGPU ];
      // ???
      //declare -n actPossibleCandidateAlgoIndex="PossibleCandidate${gpu_idx}AlgoIndexes"
      //algoIdx=${actPossibleCandidateAlgoIndex[${testGPUs[$lfdGPU]}]}
      int algoIdx = testGPUs[lfdGPU];

      // bash: algosCombinationKey+="${gpu_idx}:${algoIdx},";
      sprintf( algosCombination, "%i:%i,", gpu_idx, algoIdx );
      strcat( algosCombinationKey, algosCombination );

      //declare -n sumupGPUWatts="GPU${gpu_idx}Watts";
      //declare -n sumupGPUMines="GPU${gpu_idx}Mines";
      //watts_sum+=${sumupGPUWatts[${algoIdx}]}
      //mines_sum+="${sumupGPUMines[${algoIdx}]}+";
      watts_sum += WATTS[ gpu_idx ][ algoIdx ];
      mines_sum += MINES[ gpu_idx ][ algoIdx ];
    }

    /* bash Funktionsaufruf, dessen Code anschließend hier rein gesetzt wird
    _calculate_ACTUAL_REAL_PROFIT_and_set_MAX_PROFIT
      ( SolarWattAvailable, CombinationWatts/watts_sum, CombinationMines/mines_sum );
    */
    // Um die Gesamtformel besser zu verstehen:
    // Wir haben die Summe aller Brutto BTC "Mines" nun in ${mines_sum}
    //   ${CombinationMines}
    // Wir ziehen davon die Gesamtkosten ab. Diese setzen sich zusammen aus der
    // Summe aller Wattzahlen ${watts_sum}
    // multipliziert mit den Kosten (in BTC) für anteilig SolarPower (kWhMin) und/oder NetzPower (kWhMax)
    // Wird überhaupt Netzstrom benötigt werden oder steht die Gesamte Leistung in SolarPower bereit?
    if ( SolarWattAvailable > watts_sum ) {
      gesamt_kosten = watts_sum * kWhMin;
    } else {
      gesamt_kosten = solar_kosten_btc + ( watts_sum - SolarWattAvailable ) * kWhMax;
    }
    real_profit = mines_sum - gesamt_kosten * 24 / 1000;
    if ( real_profit > LOCAL_max_profit ) {
      LOCAL_max_profit = real_profit;
      memcpy( LOCAL_best_profit_algo_combi, algosCombinationKey, (3+1+3+1)*MAX_GOOD_GPUs + 1 );
    }
    if ( mines_sum > LOCAL_max_mines ) {
      LOCAL_max_mines = mines_sum;
      memcpy( LOCAL_max_mines_algo_combi, algosCombinationKey, (3+1+3+1)*MAX_GOOD_GPUs + 1 );
      LOCAL_max_watts = watts_sum;
    }

    // Für Statistik-Zwecke. Dieser Zähler sollte über die 31s-Intervalle ziemlich gleich bleiben
    LOCAL_GPU_COMBINATION_LOOP_COUNTER++;

    // Hier ist der Testlauf beendet und der nächste kann eingeleitet werden, sofern es noch einen gibt
    //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // Waren das schon alle Kombinationen?
    // Den letzten algoIdx schalten wir jetzt eins hoch und prüfen auf Überlauf auf dieser Stelle.
    //     Aus der lfdGPU Schleife ist er schon rausgefallen mit lfdGPU=${MAX_GPU_TIEFE}
    //     Also eins übers Ziel hinaus, deshalb Erhöhung des algoIdx der Letzen GPU
    // Man könnte dieses testGPU Array auch als Zahl sehen, deren einzelne Stellen
    //     verschiedene Basen haben können, die in exactNumAlgos aber festgelegt sind.
    //     Diese merkwürdige Zahl zählt man einfach hoch, bis ein Überlauf passieren
    //     würde, indem man auf eine Stelle VOR der Zahl zugreifen müsste
    //     bzw. UNTER den Index [0] des Arrays greifen müsste.
    // while ( testGPUs[lfdGPU] == exactNumAlgos[ TestCombinationGPUs[lfdGPU] ] ) {

    testGPUs[ --lfdGPU ]++;
    while ( testGPUs[lfdGPU] == exactNumAlgos[ TestCombinationGPUs[lfdGPU] ] ) {
      // zurücksetzen...
      testGPUs[lfdGPU]=0;
      // und jetzt die anderen nach unten prüfen, solange es ein "unten" gibt...
      if ( lfdGPU > 0 ) {
	testGPUs[ --lfdGPU ]++;
	continue;
      } else {
	finished=1;
	break;
      }
    }
  }  // while [[ $finished == 0 ]]; do

#if useThreads
  pthread_mutex_lock(&lock);
#endif
  if ( LOCAL_max_profit > max_profit ) {
    max_profit = LOCAL_max_profit;
    memcpy( best_profit_algo_combi, LOCAL_best_profit_algo_combi, (3+1+3+1)*MAX_GOOD_GPUs + 1 );
  }
  if ( LOCAL_max_mines > max_mines ) {
    max_mines = LOCAL_max_mines;
    memcpy( max_mines_algo_combi, LOCAL_max_mines_algo_combi, (3+1+3+1)*MAX_GOOD_GPUs + 1 );
    max_watts = LOCAL_max_watts;

  }
  GLOBAL_GPU_COMBINATION_LOOP_COUNTER += LOCAL_GPU_COMBINATION_LOOP_COUNTER;
#if useThreads
  pthread_mutex_unlock(&lock);
#endif

#if !useThreads
  if ( old_max_profit < max_profit ) printf( "MAX_PROFIT: %.10f %s\n",          max_profit, best_profit_algo_combi );
  if ( old_max_mines  < max_mines  ) printf( "FP_M:       %.10f %s FP_W: %i\n", max_mines,  max_mines_algo_combi, max_watts );
#endif

}

int _CREATE_AND_CALCULATE_EVERY_AND_ALL_SUBSEQUENT_COMBINATION_CASES( int maxTiefe, int myStart, int myDepth, int *myStack ) {
#if DEBUG
  printf( "Entered RECURSIVE with %i, %i, %i, %i\n",
	  maxTiefe, myStart, myDepth, (myStack == NULL) ? 0 : myStack[MAX_GOOD_GPUs] );
#endif
  int iii;
#if useMALLOC
  int *TestCombinationGPUs;   //= {0,0,0,0,0,0,0,0,0,0,0,0,0,0};
  TestCombinationGPUs = (int *) malloc( (MAX_GOOD_GPUs+1) * sizeof(int) );
#if 0
  // Ist der Speicher automatisch mit {0,0,0,0,0,0,0,0,0,0,0,0,0,0} initialisiert? JA, bisher war das bei allen Testläufen so.
  for (int i=0;i<=(MAX_GOOD_GPUs); i++) {
    printf( "key=%2i, value=%4i\n", i, TestCombinationGPUs[i] );
  }
#endif
#else
  // Speicherplatz im Stack
  int TestCombinationGPUs[MAX_GOOD_GPUs+1] = {0,0,0,0,0,0,0,0,0,0,0,0,0,0};
#endif

  // Aufbereiten des/der Integer-Arrays aus GPU-Indexes
  if ( myStack != NULL ) {
    memcpy( TestCombinationGPUs, myStack, (MAX_GOOD_GPUs+1) * sizeof(int) );
  }

  /* Das Array muss um EINEN Member, ein durchlaufender gpu_idx erweitert werden, deshalb ist hier die neue Größe des Arrays zu setzen.
     Und innerhalb der Schleife wird dieser Member jeweils gesetzt. Deshalb muss innerhalb der Schleife -1 abgezogen werden
  */
  int lfdGPUidx = TestCombinationGPUs[MAX_GOOD_GPUs]++;

  if ( myDepth >= maxTiefe ) {
    // Das ist die "Abbruchbedingung", die innerste Schleife überhaupt.

    /* Das Array muss um EINEN Member, ein durchlaufender gpu_idx erweitert werden (wurde oben gemacht).
       Und innerhalb der Schleife wird dieser Member jeweils gesetzt. Deshalb muss innerhalb der Schleife -1 abgezogen werden
    */
    for ( iii=myStart; iii<myDepth; iii++ ) {
      // Jede Ebene vorher hat ihren aktuelen Indexwert an die Parameterliste gehängt.
      // Das Array TestCombinationGPUs, das die zu untersuchenden GPU-Indexe enthält,
      // wird jetzt komplett für die Berechnungsroutine aufgebaut.
      TestCombinationGPUs[ lfdGPUidx ] = PossibleCandidateGPUidx[ iii ];
#if DEBUG
      printf("\nCall to  calculate TestCombinationGPUs Address = %p\n",
	     (void *) TestCombinationGPUs );
#endif
#if useThreads
      // Das gibt einen Deadlock
      //pthread_mutex_lock(&lock);
      pthread_create( & tid[ tidsCnt++ ], NULL,
		      _CALCULATE_GV_of_all_TestCombinationGPUs_members,
#if useMALLOC
		      (void *) TestCombinationGPUs );
#else
		      (void *) &TestCombinationGPUs );
#endif
      //pthread_mutex_lock(&lock);
#if DEBUG
      printf( "tidsCnt: %i\n", tidsCnt );
#endif
#else
      _CALCULATE_GV_of_all_TestCombinationGPUs_members( TestCombinationGPUs );
#endif
  }
#if DEBUG
  printf( "FINISHED RECURSIVE with %i, %i, %i, %i\n",
	  maxTiefe, myStart, myDepth, (myStack == NULL) ? 0 : myStack[MAX_GOOD_GPUs] );
#endif
} else {
    // Hier wird eine Schleife begonnen und dann die Funktion selbst wieder gerufen
    // Dies dient dem Initiieren des zweiten bis letzten Zeigers

    /* Das Array muss um EINEN Member, ein durchlaufender gpu_idx erweitert werden (wurde oben gemacht).
       Und innerhalb der Schleife wird dieser Member jeweils gesetzt. Deshalb muss innerhalb der Schleife -1 abgezogen werden
    */
    for ( iii=myStart; iii<myDepth; iii++ ) {
      // Jede Ebene vorher hat ihren aktuelen Indexwert an die Parameterliste gehängt.
      // Das Array TestCombinationGPUs, das die zu untersuchenden GPU-Indexe enthält,
      // wird jetzt komplett für die Berechnungsroutine aufgebaut.
      TestCombinationGPUs[ lfdGPUidx ] = PossibleCandidateGPUidx[ iii ];
#if DEBUG
      printf("Call to STACK-UP  TestCombinationGPUs Address = %p\n",
	     (void *) TestCombinationGPUs );
#endif
      _CREATE_AND_CALCULATE_EVERY_AND_ALL_SUBSEQUENT_COMBINATION_CASES
	( maxTiefe, (iii+1), (myDepth+1), TestCombinationGPUs );
    }
  }
}

int main( int argc, char* argv[] ) {
  int MIN_GOOD_GPUs=2;
  //if (MAX_GOOD_GPUs > 10) MIN_GOOD_GPUs = 8;
  int max_good_gpus=PossibleCandidateGPUidx[ MAX_GOOD_GPUs ];
  //max_good_gpus=13;

  solar_kosten_btc = kWhMin * (double) SolarWattAvailable;

#if useThreads
  if ( pthread_mutex_init( &lock, NULL ) != 0 ) {
    printf("\nMutex init failed\n");
    return 1;
#if DEBUG
  } else {
    printf("\nMutex init successful\n");
#endif
  }
#endif

#if (VERBOSE > 0)
  printf( "MAX_GOOD_GPUs: %i bei SolarWattAvailable: %i\n", max_good_gpus, SolarWattAvailable );
#endif
  for ( int numGPUs=MIN_GOOD_GPUs; numGPUs<=max_good_gpus; numGPUs++ ) {
    // Parameter: $1 = maxTiefe
    //            $2 = Beginn Pointer1 bei Index 0
    //            $3 = Ende letzter Pointer 5
    //            $4-  Jede Ebene hängt dann ihren aktuellen Wert in der Schleife hin,
    //                 in der sie sich selbst gerade befindet.
#if (VERBOSE > 0)
    printf( "\nBerechnung aller Kombinationen des Falles, dass nur %i GPUs von %i laufen:\n", numGPUs, max_good_gpus );
#endif
    //return 0;
    _CREATE_AND_CALCULATE_EVERY_AND_ALL_SUBSEQUENT_COMBINATION_CASES
      ( max_good_gpus, 0, (max_good_gpus - numGPUs + 1), NULL );
  }
#if (VERBOSE > 0)
  printf( "MAIN for-Loop finished\n" );
#endif

#if useThreads
  int t=0;
  do {
#if DEBUG
    printf( "Joining #%i (index %i) of %i\n", t+1, t, tidsCnt );
#endif
    pthread_join( tid[t++], NULL);
  } while ( t < tidsCnt );

  pthread_mutex_destroy(&lock);
  
  // Wurde in den einzenlen .bc_result_* - Dateien ausgegeben
  //printf( "#TOTAL NUMBER OF LOOPS = 3*3*3*3*3*3*3*3*3*3*3*3*3 = %i\n", 3*3*3*3*3*3*3*3*3*3*3*3*3 );
  printf( "MAX_PROFIT: %.10f %s\n",          max_profit, best_profit_algo_combi );
  printf( "FP_M:       %.10f %s FP_W: %i\n", max_mines,  max_mines_algo_combi, max_watts );
#endif
  printf( "GLOBAL_GPU_COMBINATION_LOOP_COUNTER: %li\n", GLOBAL_GPU_COMBINATION_LOOP_COUNTER );
}
