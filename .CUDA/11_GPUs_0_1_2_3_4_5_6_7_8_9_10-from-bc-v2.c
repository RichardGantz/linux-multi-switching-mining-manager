#include <stdio.h>

#define BEST_ALGO_CNT  3
#define MAX_GOOD_GPUs 11

double max_profit=.0001763811;
double max_mines=.0002039017;
double solar_kosten_btc=0*.0000037290;

int W [MAX_GOOD_GPUs][BEST_ALGO_CNT] = {
    { 118, 120, 121 }
  , { 103, 106, 103 }
  , { 202, 202, 202 }
  , { 202, 202, 202 }
  , { 202, 202, 202 }
  , { 202, 202, 202 }
  , { 123, 123, 202 }
  , { 123, 123, 202 }
  , { 123, 123, 202 }
  , { 123, 123, 202 }
  , { 202, 202, 202 }
};
double M [MAX_GOOD_GPUs][BEST_ALGO_CNT] = {
    { .0001458850, .0001457586, .0001457336 }
  , { .0000863353, .0000866363, .0000822111 }
  , { .0002038042, .0002037581, .0002036954 }
  , { .0002038042, .0002037581, .0002036954 }
  , { .0002038042, .0002037581, .0002036954 }
  , { .0002038042, .0002037581, .0002036954 }
  , { .0002039017, .0002018631, .0002038042 }
  , { .0002039017, .0002018631, .0002038042 }
  , { .0002039017, .0002018631, .0002038042 }
  , { .0002039017, .0002018631, .0002038042 }
  , { .0002038042, .0002037581, .0002036954 }
};

int main( int argc, char* argv[] ) {
  int best_profit_algo[MAX_GOOD_GPUs];
  int max_mines_algo  [MAX_GOOD_GPUs];
  double gesamt_kosten;
  double real_profit;
  double mines_sum;
  int   watts_sum;
  int   max_watts;

  printf( "#TOTAL NUMBER OF LOOPS = 3*3*3*3*3*3*3*3*3*3*3 = %i\n", 3*3*3*3*3*3*3*3*3*3*3 );
  for (int i=0;i<BEST_ALGO_CNT;i++){
    for (int j=0;j<BEST_ALGO_CNT;j++){
      for (int k=0;k<BEST_ALGO_CNT;k++){
	for (int l=0;l<BEST_ALGO_CNT;l++){
	  for (int m=0;m<BEST_ALGO_CNT;m++){
	    for (int n=0;n<BEST_ALGO_CNT;n++){
	      for (int o=0;o<BEST_ALGO_CNT;o++){
		for (int p=0;p<BEST_ALGO_CNT;p++){
		  for (int q=0;q<BEST_ALGO_CNT;q++){
		    for (int r=0;r<BEST_ALGO_CNT;r++){
		      for (int s=0;s<BEST_ALGO_CNT;s++){
			watts_sum=W[0][i]+W[1][j]+W[2][k]+W[3][l]+W[4][m]+W[5][n]+W[6][o]+W[7][p]+W[8][q]+W[9][r]+W[10][s];
			mines_sum=M[0][i]+M[1][j]+M[2][k]+M[3][l]+M[4][m]+M[5][n]+M[6][o]+M[7][p]+M[8][q]+M[9][r]+M[10][s];
			if (0>watts_sum) {
			  gesamt_kosten = watts_sum * .0000037290;
			} else {
			  gesamt_kosten = solar_kosten_btc + ( watts_sum - 0 ) * .0000093227;
			}
			real_profit = mines_sum - gesamt_kosten * 24 / 1000;
			if (real_profit>max_profit) {
			  max_profit=real_profit;
			  best_profit_algo[0]=i;
			  best_profit_algo[1]=j;
			  best_profit_algo[2]=k;
			  best_profit_algo[3]=l;
			  best_profit_algo[4]=m;
			  best_profit_algo[5]=n;
			  best_profit_algo[6]=o;
			  best_profit_algo[7]=p;
			  best_profit_algo[8]=q;
			  best_profit_algo[9]=r;
			  best_profit_algo[10]=s;
			}
			if (mines_sum > max_mines ) {
			  max_mines=mines_sum;
			  max_mines_algo[0]=i;
			  max_mines_algo[1]=j;
			  max_mines_algo[2]=k;
			  max_mines_algo[3]=l;
			  max_mines_algo[4]=m;
			  max_mines_algo[5]=n;
			  max_mines_algo[6]=o;
			  max_mines_algo[7]=p;
			  max_mines_algo[8]=q;
			  max_mines_algo[9]=r;
			  max_mines_algo[10]=s;
			  max_watts = watts_sum;
			}
		      }
		    }
		  }
		}
	      }
	    }
	  }
	}
      }
    }
  }
  printf( "MAX_PROFIT: %.10f 0:%i,1:%i,2:%i,3:%i,4:%i,5:%i,6:%i,7:%i,8:%i,9:%i,10:%i\n",
	  max_profit,
	  best_profit_algo[0],
	  best_profit_algo[1],
	  best_profit_algo[2],
	  best_profit_algo[3],
	  best_profit_algo[4],
	  best_profit_algo[5],
	  best_profit_algo[6],
	  best_profit_algo[7],
	  best_profit_algo[8],
	  best_profit_algo[9],
	  best_profit_algo[10] );
  printf( "FP_M: %.10f 0:%i,1:%i,2:%i,3:%i,4:%i,5:%i,6:%i,7:%i,8:%i,9:%i,10:%i FP_W: %i\n",
	  max_mines,
	  max_mines_algo[0],
	  max_mines_algo[1],
	  max_mines_algo[2],
	  max_mines_algo[3],
	  max_mines_algo[4],
	  max_mines_algo[5],
	  max_mines_algo[6],
	  max_mines_algo[7],
	  max_mines_algo[8],
	  max_mines_algo[9],
	  max_mines_algo[10],
	  max_watts );
}
