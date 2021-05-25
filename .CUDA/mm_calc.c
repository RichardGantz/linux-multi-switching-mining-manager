#include <stdio.h>
#include <stdlib.h>
#include <string.h>
//#include <unistd.h>  //Header file for sleep(). man 3 sleep for details.

#define DEBUG 0
#define VERBOSE 0
#define OVERSIZED 50 // Das war mal MAX_GOOD_GPUs, bevor es als Parameter übergeben wurde, um Array-Dimensionen richtig zu dimensioniern
                     // Auf das muss geachtet werden !!!

#define useThreads 1
// Ohne Verwendung von malloc (also Variablen im Stack) verschwindet irgendwann die Funktion (und damit ihr Stack), die den Thread gestartet hat,
//      BEVOR die CPUs Gelegenheit hatten, den Thread überhaupt zu starten.
//      d.h. die Werte, die dann auf dem Stack stehen, sind völlig andere!
// Dann tritt bestenfalls irgendwann ein Speicherzugriffsfehler auf und es erfolgt Abbruch und Erzeugung eines coredump
// Das war hier (8 Prozessoren) schon ab 140 Threads der Fall. Manchmal kam er sogar bis über 400 Threads.
// Nein, die Werte müssen in Speicher gelegt werden, der immer noch da ist, auch wenn der Thread Stunden später gestartet werden sollte.
#if useThreads
#include <pthread.h>
#define useCALLOC 1
#define TIDS 10000
pthread_mutex_t lock;
pthread_t tid[ TIDS ];
int tidsCnt = 0;
#else
#define useCALLOC 0
// Für eine fortlaufende Ausgabe, die bei der Verwendung von Threads nicht gebraucht werden
double old_MAX_PROFIT;
double old_MAX_FP_MINES;
#endif

#define ARRAYMEMBERS(x) (sizeof(x) / sizeof((x)[0]))
//printf( "PossibleCandidateGPUidx[] kann %li Member aufnehmen\n", ARRAYMEMBERS( PossibleCandidateGPUidx ) );

// Globale Variablen, deren Zugriff durch Mutexes zu isolieren sind.
long   GLOBAL_GPU_COMBINATION_LOOP_COUNTER=0;
int    max_watts = 0;
char   best_profit_algo_combi[ (3+1+3+1)*OVERSIZED + 1 ];
char   max_mines_algo_combi  [ (3+1+3+1)*OVERSIZED + 1 ];
double solar_kosten_btc;

// Zu übergebende Variablen:
int    MIN_GOOD_GPUs;                        //  1.
int    MAX_GOOD_GPUs;                        //  2.
int    BEST_ALGO_CNT;                        //  3.
int    SolarWattAvailable;                   //  4.
double kWhMin;                               //  5.
double kWhMax;                               //  6.
double MAX_PROFIT;                           //  7.
double MAX_FP_MINES;                         //  8.
int    PossibleCandidateGPUidx[OVERSIZED];   //  9.
int    exactNumAlgos[OVERSIZED];             // 10.
int    WATTS[OVERSIZED][OVERSIZED];          // 11.
double MINES[OVERSIZED][OVERSIZED];          // 12.

void * _CALCULATE_GV_of_all_TestCombinationGPUs_members( void * arg ) {
  // Der Compiler weiss dadurch, dass TestCombinationGPUs auf ein int zeigt und kann damit Arrays richtig indexieren
  int *TestCombinationGPUs = (int *) arg;
  int MAX_GPU_TIEFE = TestCombinationGPUs[ MAX_GOOD_GPUs ];
#if DEBUG
  char intArrayStr[ (3+1)*(MAX_GOOD_GPUs+1) + 1 ];
  char intValStr  [  3+1 + 1 ];
  for (int i=0; i<MAX_GPU_TIEFE; i++) {
    sprintf( intValStr, "%3i,", TestCombinationGPUs[i] );
    strcat( intArrayStr, intValStr );
  }
  printf( "Entered _CALCULATE_GV_of_all_TestCombinationGPUs_members with %i Members: %s\n",
	  MAX_GPU_TIEFE, intArrayStr );
#endif
  double LOCAL_MAX_PROFIT   = 0;
  double LOCAL_MAX_FP_MINES =.0;
  int    LOCAL_max_watts    = 0;
  char   LOCAL_best_profit_algo_combi[ (3+1+3+1)*MAX_GOOD_GPUs + 1 ]; // 3 Stellen gpu_idx + 1x":" + 3 algoIdx + 1x","
  char   LOCAL_max_mines_algo_combi  [ (3+1+3+1)*MAX_GOOD_GPUs + 1 ]; // 3 Stellen gpu_idx + 1x":" + 3 algoIdx + 1x","
  long   LOCAL_GPU_COMBINATION_LOOP_COUNTER = 0;

  double gesamt_kosten;
  double real_profit;
  int    watts_sum;
  double mines_sum;

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
  old_MAX_PROFIT = MAX_PROFIT;
  old_MAX_FP_MINES  = MAX_FP_MINES;
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
    if ( real_profit > LOCAL_MAX_PROFIT ) {
      LOCAL_MAX_PROFIT = real_profit;
      memcpy( LOCAL_best_profit_algo_combi, algosCombinationKey, (3+1+3+1)*MAX_GOOD_GPUs + 1 );
    }
    if ( mines_sum > LOCAL_MAX_FP_MINES ) {
      LOCAL_MAX_FP_MINES = mines_sum;
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

    do {
      testGPUs[ --lfdGPU ]++;
      if ( testGPUs[lfdGPU] == exactNumAlgos[ TestCombinationGPUs[lfdGPU] ] ) {
	// zurücksetzen...
	testGPUs[lfdGPU]=0;
	// und jetzt die anderen nach unten prüfen, solange es ein "unten" gibt...
	if ( lfdGPU > 0 ) continue;
	else finished=1;
      }
      break;
    } while( 1 );
  }  // while [[ $finished == 0 ]]; do

#if useThreads
  pthread_mutex_lock(&lock);
#endif
  if ( LOCAL_MAX_PROFIT > MAX_PROFIT ) {
    MAX_PROFIT = LOCAL_MAX_PROFIT;
    memcpy( best_profit_algo_combi, LOCAL_best_profit_algo_combi, (3+1+3+1)*MAX_GOOD_GPUs + 1 );
  }
  if ( LOCAL_MAX_FP_MINES > MAX_FP_MINES ) {
    MAX_FP_MINES = LOCAL_MAX_FP_MINES;
    memcpy( max_mines_algo_combi, LOCAL_max_mines_algo_combi, (3+1+3+1)*MAX_GOOD_GPUs + 1 );
    max_watts = LOCAL_max_watts;
  }
  GLOBAL_GPU_COMBINATION_LOOP_COUNTER += LOCAL_GPU_COMBINATION_LOOP_COUNTER;
#if useThreads
  pthread_mutex_unlock(&lock);
#endif

#if !useThreads
  if ( old_MAX_PROFIT   < MAX_PROFIT   ) printf( "MAX_PROFIT: %.10f %s\n",          MAX_PROFIT,   best_profit_algo_combi );
  if ( old_MAX_FP_MINES < MAX_FP_MINES ) printf( "FP_M:       %.10f %s FP_W: %i\n", MAX_FP_MINES, max_mines_algo_combi, max_watts );
#endif

}

int _CREATE_AND_CALCULATE_EVERY_AND_ALL_SUBSEQUENT_COMBINATION_CASES( int maxTiefe, int myStart, int myDepth, int *myStack ) {
#if DEBUG
  printf( "Entered RECURSIVE with %i, %i, %i, %i\n",
	  maxTiefe, myStart, myDepth, (myStack == NULL) ? 0 : myStack[MAX_GOOD_GPUs] );
#endif
  int iii;
#if useCALLOC
  int *TestCombinationGPUs;
  TestCombinationGPUs = (int *) calloc( MAX_GOOD_GPUs+1, sizeof(int) );
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

  if ( myDepth == maxTiefe ) {
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
      pthread_create( & tid[ tidsCnt++ ], NULL,
		      _CALCULATE_GV_of_all_TestCombinationGPUs_members,
#if useCALLOC
                      (void *) TestCombinationGPUs );
#else
                      (void *) &TestCombinationGPUs );
#endif
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

  /* Das Array wurde oben um EINEN Member, ein durchlaufender gpu_idx erweitert.
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
      ( maxTiefe, iii+1, myDepth+1, TestCombinationGPUs );
  }
 }
}

/* Der Aufruf aus dem multimining_calc.sh
.CUDA/mm_calc ${MIN_GOOD_GPUs} ${MAX_GOOD_GPUs} ${BEST_ALGO_CNT} ${SolarWattAvailable} \
	  ${kWhMin} ${kWhMax} ${MAX_PROFIT} ${MAX_FP_MINES} \
          "${PossibleCandidateGPUidx[*]}" "${exactNumAlgos[*]}" \
          "${WATTS_Parameter_String_for_mm_calC%% }" "${MINES_Parameter_String_for_mm_calC%% }"
*/
int main( int argc, char* argv[] ) {
  const char s[2] = " ";
  char *token;
  char *IntVal;
  char *DoubleVal;
  int p, a;
  const char msg__98[] = "Die Anzahl an übergebenen %s[]-Members=%i ist ungleich MAX_GOOD_GPUs=%i%s\n";
  const char msg_a98[] = " ODER es wurden zu viele Werte übergeben";
  const char exitmsg[] = "Es erfolgt ein Abbruch mit exit-Code %i\n";

  for (int i=1; i<argc; i++) {
    switch(i) {
    case 1:
      MIN_GOOD_GPUs = (int) strtol( argv[i], NULL, 10 );
#if DEBUG
      printf("MIN_GOOD_GPUs: %i\n", MIN_GOOD_GPUs );
#endif
      break;

    case 2:
      MAX_GOOD_GPUs = (int) strtol( argv[i], NULL, 10 );
#if DEBUG
      printf("MAX_GOOD_GPUs: %i\n", MAX_GOOD_GPUs );
#endif
      if (MAX_GOOD_GPUs > OVERSIZED) {
	printf( "MAX_GOOD_GPUs=%i > OVERSIZED=%i. Bitte im C-Sourcecode erhöhen\n", MAX_GOOD_GPUs, OVERSIZED );
	printf( exitmsg, 99 );
	return( 99 );
      }
      break;

    case 3:
      BEST_ALGO_CNT = (int) strtol( argv[i], NULL, 10 );
#if DEBUG
      printf("BEST_ALGO_CNT: %i\n", BEST_ALGO_CNT );
#endif
      break;

    case 4:
      SolarWattAvailable = (int) strtol( argv[i], NULL, 10 );
#if DEBUG
      printf("SolarWattAvailable: %i\n", SolarWattAvailable );
#endif
      break;

    case 5:
      kWhMin = strtod( argv[i], NULL );
#if DEBUG
      printf("kWhMin: %.10f\n", kWhMin );
#endif
      break;

    case 6:
      kWhMax = strtod( argv[i], NULL );
#if DEBUG
      printf("kWhMax: %.10f\n", kWhMax );
#endif
      break;

    case 7:
      MAX_PROFIT = strtod( argv[i], NULL );
#if DEBUG
      printf("MAX_PROFIT: %.10f\n", MAX_PROFIT );
#endif
      break;

    case 8:
      MAX_FP_MINES = strtod( argv[i], NULL );
#if DEBUG
      printf("MAX_FP_MINES: %.10f\n", MAX_FP_MINES );
#endif
      break;

    case 9:
      p=0;
      token = strtok( argv[i], s );
      while( token != NULL ) {
	PossibleCandidateGPUidx[p] = (int) strtol( token, NULL, 10 );
#if DEBUG
	printf( "PossibleCandidateGPUidx[%i] = %i\n", p, PossibleCandidateGPUidx[p] );
#endif
	p++;
	token = strtok( NULL, s );
      }
      PossibleCandidateGPUidx[p] = p;
      if ( p != MAX_GOOD_GPUs) {
	printf( msg__98, "PossibleCandidateGPUidx", p, MAX_GOOD_GPUs, "" );
	printf( exitmsg, 98 );
	return( 98 );
      }
      break;

    case 10:
      p=0;
      token = strtok( argv[i], s );
      while( token != NULL ) {
        exactNumAlgos[p] = (int) strtol( token, NULL, 10 );
#if DEBUG
	printf( "exactNumAlgos[%i] = %i\n", p, exactNumAlgos[p] );
#endif
	p++;
	token = strtok( NULL, s );
      }
      if ( p != MAX_GOOD_GPUs) {
	printf( msg__98, "exactNumAlgos", p, MAX_GOOD_GPUs, "" );
	printf( exitmsg, 98 );
	return( 98 );
      }
      break;

    case 11:
#if DEBUG
      printf( "WATTS: %s\n", argv[i] );
#endif
      p=0; a=0;
      IntVal = strtok( argv[i], s );
      while( IntVal != NULL && p < MAX_GOOD_GPUs ) {
        WATTS[p][a] = (int) strtol( IntVal, NULL, 10 );
#if DEBUG
	printf( "WATTS[%i][%i] = %i\n", p, a, WATTS[p][a] );
#endif
	if (++a == exactNumAlgos[p]) { p++; a=0; }
	IntVal = strtok( NULL, s );
      }
      if ( p != MAX_GOOD_GPUs || IntVal != NULL ) {
	printf( msg__98, "WATTS[GPUs]", p, MAX_GOOD_GPUs, msg_a98 );
	printf( exitmsg, 98 );
	return( 98 );
      }
      break;

    case 12:
#if DEBUG
      printf("MINES: %s\n", argv[i] );
#endif
      p=0; a=0;
      DoubleVal = strtok( argv[i], s );
      while( DoubleVal != NULL && p < MAX_GOOD_GPUs ) {
        MINES[p][a] = (double) strtod( DoubleVal, NULL );
#if DEBUG
	printf( "MINES[%i][%i] = %.10f\n", p, a, MINES[p][a] );
#endif
	if (++a == exactNumAlgos[p]) { p++; a=0; }
	DoubleVal = strtok( NULL, s );
      }
      if ( p != MAX_GOOD_GPUs || DoubleVal != NULL ) {
	printf( msg__98, "MINES[GPUs]", p, MAX_GOOD_GPUs, msg_a98 );
	printf( exitmsg, 98 );
	return( 99 );
      }
      break;

    default:
      printf( "Parameter %2i: %s\n", i, argv[i] );
    }
  }

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
  printf( "MAX_GOOD_GPUs: %i bei SolarWattAvailable: %i\n", MAX_GOOD_GPUs, SolarWattAvailable );
#endif
  for ( int numGPUs=MIN_GOOD_GPUs; numGPUs<=MAX_GOOD_GPUs; numGPUs++ ) {
    // Parameter: $1 = maxTiefe
    //            $2 = Beginn Pointer1 bei Index 0
    //            $3 = Ende letzter Pointer 5
    //            $4-  Jede Ebene hängt dann ihren aktuellen Wert in der Schleife hin,
    //                 in der sie sich selbst gerade befindet.
#if (VERBOSE > 0)
    printf( "\nBerechnung aller Kombinationen des Falles, dass nur %i GPUs von %i laufen:\n", numGPUs, MAX_GOOD_GPUs );
#endif
    //return 0;
    _CREATE_AND_CALCULATE_EVERY_AND_ALL_SUBSEQUENT_COMBINATION_CASES
      ( MAX_GOOD_GPUs, 0, (MAX_GOOD_GPUs - numGPUs + 1), NULL );
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
  printf( "MAX_PROFIT: %.10f %s\n",          MAX_PROFIT,    best_profit_algo_combi );
  printf( "FP_M:       %.10f %s FP_W: %i\n", MAX_FP_MINES,  max_mines_algo_combi, max_watts );
#endif
  printf( "GLOBAL_GPU_COMBINATION_LOOP_COUNTER: %li\n", GLOBAL_GPU_COMBINATION_LOOP_COUNTER );
}
