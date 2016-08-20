options nofmtErr mprint cpucount=6 threads SPOOL;
title 'SUPERLEARNER: Simulation Binary Outcome, Loglikelihood Loss';

**********************;
* SAS DATA LIBRARIES *;
**********************;
%let home=C:\Users\Jordan\Desktop\CodeMark\CodeMark; * PLACE TO PUT COPIES OF DATA FOR SUPERLEARNER TRAINING *;

**********************************************;
* INCLUDE THE SAS SUPERLEARNER MACRO PROGRAM *;
**********************************************;
%include "&home\SL\SUPERLEARNER_JSS_040312.sas";


%LET myseed=415;
%LET n=1000;

%LET Qbar0 = 1/(1+exp(-1*(W3 + 5*W25 + 0.2*sin(W32*W2) + W4*W5 + W40**2)));

%LET Y =Y;
%LET X =W1  W2  W3  W4  W5  W6  W7  W8  W9  W10 
		W11 W12 W13 W14 W15 W16 W17 W18 W19 W20
		W21 W22 W23 W24 W25 W26 W27 W28 W29 W30 
		W31 W32 W33 W34 W35 W36 W37 W38 W39 W40 ;


********************;
* PRE-PROCESS DATA *;
********************;
data work;
 call streaminit(415); 
 length Y 
		W1  W2  W3  W4  W5  W6  W7  W8  W9  W10 
		W11 W12 W13 W14 W15 W16 W17 W18 W19 W20
		W21 W22 W23 W24 W25 W26 W27 W28 W29 W30 
		W31 W32 W33 W34 W35 W36 W37 W38 W39 W40 
		3;
 array Wbin {20} W1-W20;
 array Wcts {20} W21-W40;

 do _i = 1 to &n;

  * ASSIGN UNIT ID *;
  ID = _i;
  * SIMULATE BINARY Ws *;
  do _w=1 to 20;
   Wbin{_w} = rand("Bernoulli", 0.5);
  end;
  * SIMULATE CONTINUOUS Ws *;
  do _w=1 to 20;
   Wcts{_w} = rand("Normal", 0, 1);
  end;
  * FUNCTIONAL FORM OF E[Y|W] *;
  Qbar = &Qbar0 ;
  * SIMULATE Y *;
  Y = rand("Bernoulli", Qbar);;
  output;
 end; 
 drop _: ;
run;


************************************;
* CALL SUPERLEARNER MACRO FUNCTION *;
************************************;
%SUPERLEARNER(TRAIN=work, TEST=work,
              Y=Y, Y_TYPE=BIN, ID=ID, T=, WEIGHTS=,
			  X=W1  W2  W3  W4  W5  W6  W7  W8  W9  W10 
				W11 W12 W13 W14 W15 W16 W17 W18 W19 W20
				W21 W22 W23 W24 W25 W26 W27 W28 W29 W30 
				W31 W32 W33 W34 W35 W36 W37 W38 W39 W40, 
			  SL_LIBRARY=MEAN OLS LOGIT_CTS01 NN2 TREE,
              LIBRARY_DIR=&home\SL\library,
              EnterpriseMiner=T,
              LOWER_BOUND=0.00000001, UPPER_BOUND=0.99999999,
              LOSS=LOG, V=10, SEED=&SEED, FOLD=,
              WD=&home\fits, VERBOSE=T);
