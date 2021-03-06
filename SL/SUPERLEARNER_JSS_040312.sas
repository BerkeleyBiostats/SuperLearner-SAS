*******************************************************************************;                                         
* %SUPERLEARRNER															  *;
*																			  *;
* SAS MACRO FOR DATA-ADAPTIVE AMCHINE LEARNING 								  *;
* FITS A SUPER LEARNER FOR CONDITIONAL EXPECTATION OF BINARY OR CONTINUOUS 	  *;
* OUTCOMES IN SINGLE-TIME POINT OR LONGITUDIINAL DATA STRUCTURES		  	  *;
*																			  *;
* JORDAN BROOKS																  *;
*																			  *;
* 032612																	  *;
*******************************************************************************;
* TESTED ON SAS 9.2 WINDOWS 64-BIT											  *;
*******************************************************************************;
* INPUTS TO THE %SUPERLEARNER MACRO:										  *;
*																			  *;
* TRAIN 				= Input SAS dataset containing training data		  *;
*																			  *;
* TEST (optional) 		= Input SAS dataset containing validation data		  *;
*																			  *;
* Y 					= Name of outcome/target variable. 					  *;
*						  The variable must be NUMERIC. 					  *;
*						  For binary outcomes the values must be coded 0/1.   *;
*						  Missing values are not allowed.					  *;
*																			  *;
* Y_TYPE 				= Type of outcome/target variable:					  *;
*		   				  CTS for continuous outcome 						  *;
*				  	      BIN for binary outcome 							  *;
*																			  *;
* X 					= Names of explanatory variables used to predict Y.   *;
*						  These variables must be NUMERIC. 					  *;
*						  Missing values are not allowed.					  *;
*																			  *;
* ID 					= Name of the variable that uniquely identifies 	  *;
*						  independent observations.					  		  *;
*	  																		  *;
* T (optional) 			= Name of the time-stamp variable for longitudinal    *;
*				 		  data structures.						    		  *;
*																			  *;
* WEIGHTS (optional) 	= Name of the variable containing observation WEIGHTS.*;
*																			  *;
* SL_LIBRARY 			= Names of SAS macros for candidate estimators in the *;
*			   			  Super Learner library. The macros must be saved 	  *;
*					      under the exact name of candidate estimator as a 	  *;
*						  .sas program in the filepath given in LIBRARY_DIR.  *;
*																			  *;
* LIBRARY_DIR 			= Filepath for directory containing the candidate 	  *;
*						  estimator macros, which are saved as .sas programs. *;
*																			  *;
* LOWER_BOUND (optional)= Lower bound for predictions. This is applied to all *;
*						  candidate estimators. If the user does not specify  *;
*						  a lower bound, the defaults are:					  *;
*						  0.00000001 for Y_TYPE=BIN, or						  *;
*						  -9999999999999999 for Y_TYPE=CTS					  *;
*																			  *;
* UPPER_BOUND (optional)= Upper bound for predictions. This is applied to all *;
*						  candidate estimators. If the user does not specify  *;
*						  an upper bound, the defaults are:					  *;
*						  0.99999999 for Y_TYPE=BIN, or						  *;
*						  9999999999999999 for Y_TYPE=CTS					  *;
*																			  *;
* EnterpriseMiner 		= Enter T/F to indicate use of SAS/EnterpriseMiner.   *;
*						  If set to T, a SAS datamining database catalog is   *;
*						  constructed based on the training data sample. 	  *;
*																			  *;
* LOSS 					= The LOSS function, whose expectation, i.e., RISK,   *;
*						  is minimized:    									  *;
*		 				  L2 for squared error LOSS/RISK  					  *;
*		 				  LOG for negative Bernoulli loglikelihood LOSS/RISK  *;
*					  	  Note: In longtiudinal data structures, the LOSS 	  *;
*						  function is taken to be the sum of the time-point   *;
*						  specific LOSSes, and the expectation is taken over  *;
*						  all independent observations.						  *;
*																			  *;
* V 					= The number of folds for V-fold crossvalidation	  *;
*	  					  NOTE: For Y_TYPE=BIN the random sampling for fold	  *;
*						  assignment is stratified on the outcome.			  *;
*																			  *;
* SEED 					= The SEED for the random number generator. 		  *;
*																			  *;
* FOLD (optional)		= Variable containing the fold number for cross		  *;
*						  validation. 				  						  *;
*																			  *;
* WD 					= The working directory. All candidate algorithm fits *;
*						  will be saved to this directory as .sas programs.   *;
*						  The inputs to the %SUPERLEARNER SAS macro and the   *;
*						  fitted alpha WEIGHTS will be saved here as SAS 	  *;
*	  					  datasets. 										  *;
*						  This directory will be assigned a SAS data libname  *;
*						  name "SL" during the fitting process.				  *;
*																			  *;
* VERBOSE (optional) 	= A T/F that indicates whether all output normally 	  *;
*					      produced by SAS data and procedure steps should be  *;
*					      sent to the listing device. The default is F.		  *;
*******************************************************************************;
%MACRO SUPERLEARNER(TRAIN=, 
					TEST=, 
					Y=, Y_TYPE=, 
					X=, 
					ID=, T=, WEIGHTS=, 
					SL_LIBRARY=, LIBRARY_DIR=,
  					LOWER_BOUND=, 
					UPPER_BOUND=, 
					EnterpriseMiner=T,
					LOSS=L2, 
					V=10, 
					SEED=715, 
					FOLD=,
					WD=, 
					VERBOSE=F);  

%LOCAL K;
%LOCAL i;

proc contents data = &TRAIN out = _TRAIN_NAMES(keep = varnum name) noprint; run;
proc sql noprint; select distinct name into :KEEP_TRAIN separated by ' ' from _TRAIN_NAMES; quit;
%LET nKEEP_TRAIN = %sysfunc(countw(&KEEP_TRAIN, ' '));
%DO _i=1 %TO &nKEEP_TRAIN;
 %LET KEEP_TRAIN_&_i = %SCAN(&KEEP_TRAIN, &_i, " ");
%END;

options nosyntaxcheck; 
ods listing;
%IF &VERBOSE=F %THEN %DO; ods listing close; %END;
%LET X = %sysfunc(COMPBL(&X));
%LET nX = %sysfunc(countw(&X));
%DO _i=1 %TO &nX;
 %LET X_&_i = %SCAN(&X, &_i, " ");
%END;
%IF "&LOWER_BOUND" = %THEN %DO;
 %IF &LOSS=LOG %THEN %DO; %LET LOWER_BOUND=0.00000001; %END;
 %IF &LOSS=L2  %THEN %DO; %LET LOWER_BOUND=-9999999999999999; %END;
%END;
%IF "&UPPER_BOUND" = %THEN %DO;
 %IF &LOSS=LOG %THEN %DO; %LET UPPER_BOUND=0.99999999; %END;
 %IF &LOSS=L2  %THEN %DO; %LET UPPER_BOUND=9999999999999999; %END;
%END;
%LET  SL_LIBRARY = %sysfunc(COMPBL(&SL_LIBRARY));
%LET K = %sysfunc(countw(&SL_LIBRARY));
%DO _i=1 %TO &K;
 %LET cand_&_i = %SCAN(&SL_LIBRARY, &_i, " ");
 %include "&LIBRARY_DIR\&&cand_&_i...sas"; 
%END;

proc sort data=&TRAIN;
 by &ID &T;
run;

%IF &FOLD = %THEN %DO; 
%LET FOLD = fold;
%IF &Y_TYPE=CTS %THEN %DO;
 data _fold;
  set &TRAIN;
  by &ID &T;
  if last.&ID;
  rand=&V*ranuni(&SEED);
  fold=ceil(rand);
  keep &ID fold;
 run;
 proc sort; by &ID; run;
 data &TRAIN;
  merge &TRAIN _fold;
  by &ID;
 run;
 proc datasets lib=work; delete _: ; run; quit;
%END;
%ELSE %IF &Y_TYPE=BIN %THEN %DO;
 data _last;
  set &TRAIN;
  by &ID &T;
  if last.&ID;
 run;
 data _Y0;
  set _last (where=(&Y=0) keep = &ID &Y);
  rand=&V*ranuni(&SEED);
  fold=ceil(rand);
  keep &ID fold;
 run;
 data _Y1;
  set _last (where=(&Y=1) keep = &ID &Y);
  rand=&V*ranuni(&SEED);
  fold=ceil(rand);
  keep &ID fold;
 run;
 data _fold;
  set _Y0 _Y1;
 run;
 proc sort; by &ID; run;
 data &TRAIN;
  merge &TRAIN _fold;
  by &ID;
 run;
 proc datasets lib=work; delete _: ; run; quit;
%END;
%END;

libname sl "&WD"; 
data sl.sl_inputs;
 TRAIN			="&TRAIN";
 TEST			="&TEST";
 Y				="&Y";
 Y_TYPE			="&Y_TYPE";
 X				="&X";
 ID				="&ID";
 T				="&T";
 WEIGHTS		="&WEIGHTS";
 LOSS			="&LOSS";
 SL_LIBRARY		="&SL_LIBRARY";
 LIBRARY_DIR	="&LIBRARY_DIR";
 LOWER_BOUND	="&LOWER_BOUND";
 UPPER_BOUND	="&UPPER_BOUND"; 
 EnterpriseMiner="&EnterpriseMiner";
 V				="&V";
 SEED			="&SEED";
 FOLD			="&FOLD";
 WD				="&WD";
 VERBOSE		="&VERBOSE";
run; 

%IF &EnterpriseMiner = T %THEN %DO;
 %IF &Y_TYPE=CTS %THEN %DO; proc dmdb batch data=&TRAIN dmdbcat=sl.dmdbcat; VAR &X &Y; target &Y; run; %END;
 %ELSE %IF &Y_TYPE=BIN %THEN %DO; proc dmdb batch data=&TRAIN dmdbcat=sl.dmdbcat; VAR &X; class &Y; target &Y; run; %END;
%END;

title2 'CONSTRUCT AND SAVE CROSS VALIDATED CANDIDATE ESTIMATOR FITS';
%DO jjj=1 %TO &V;
 %DO kkk=1 %TO &K;
  %&&cand_&kkk(TRAIN=&TRAIN(where=(&FOLD ne &jjj)), Y=&Y, Y_TYPE=&Y_TYPE, X=&X, ID=&ID, T=&T, WEIGHTS=&WEIGHTS, SEED=&SEED, WD=&WD);
  data _null_;
   fname="fname";
   rc=filename(fname,"&WD\F_&&cand_&kkk.._&jjj..sas");
   if fexist(fname) then rc=fdelete(fname);
   rc=rename("&WD\F_&&cand_&kkk...sas","&WD\F_&&cand_&kkk.._&jjj..sas","file");
  run;
  proc datasets lib=work; delete _: ; run; quit;
 %END;
 proc datasets lib=sl; delete _: ; run; quit; 
%END;

data &TRAIN;
 set &TRAIN;
 %DO _fold=1 %TO &V;
  if &FOLD=&_fold then do;
   %DO kkk = 1 %TO &K; %include "&WD\F_&&cand_&kkk.._&_fold..sas"; %END; 
  end;
 %END;
 array p {&K} %DO kkk = 1 %TO &K; p_&&cand_&kkk %END; ;
 do _i=1 to &K;
  p{_i} = max(p{_i},&LOWER_BOUND);
  p{_i} = min(p{_i},&UPPER_BOUND);
 end;
 keep %DO _i=1 %TO &nKEEP_TRAIN; &&KEEP_TRAIN_&_i %END;
 %DO kkk=1 %TO &K; p_&&cand_&kkk %END; ;
run;

title2 'ESTIMATE ALPHA, CONVEX WEIGHTS: INITIAL ESTIMATE ASSIGNS WEIGHT OF 1 TO CROSS VALIDATION SELECTOR';
%IF &K = 1 %THEN %DO; %LET minCVRISK=1; %END;
%ELSE %DO; 
 %RISK(DSN=&TRAIN, Y=&Y, YHAT=%DO kkk = 1 %TO &K; p_&&cand_&kkk %END;, WEIGHTS=&WEIGHTS, LOSS=&LOSS, ID=&ID);
 data _null_;
  set RISK_sum;
  where _STAT_="MEAN";
  array RISK{&K} %DO kkk = 1 %TO &K; loss_&kkk %END; ; 
  minCVRISK = min(of RISK{*});
  do _i=1 to &K;
   if RISK{_i}=minCVRISK then do; call symputx("minCVRISK", _i, 'G'); end;
  end;
  drop _i;
 run;
%END;
%LET alpha=;
%LET init=;
%DO _i=1 %TO &K; 
 %LET alpha = &alpha a&_i; 
 %IF &_i = &minCVRISK %THEN %DO; %LET init = &init 1; %END;
 %ELSE %DO; %LET init = &init 0; %END;
%END;
%IF &LOSS=L2 %THEN %DO;
 title2 'CONVEX ALPHA: UPDATE ESTIMATE TO MINIMIZE CROSS VALIDATED SQUARED ERROR RISK';
 proc nlp data=&TRAIN; 
  lsq L2; 
  parms %DO _i=1 %TO &K; a&_i =%SCAN(&init, &_i, " "), %END; ;
  bounds 0 <= %DO _i=1 %TO &K; a&_i %END; <=1; 
  lincon  0 %DO _i=1 %TO &K; + a&_i %END; = 1;
  %IF &WEIGHTS ne %THEN %DO; L2 = &WEIGHTS**0.5*(&Y - (%DO _i=1 %TO &K; + a&_i * p_&&cand_&_i %END;)); %END; 
  %ELSE %DO; L2 = (&Y - (%DO _i=1 %TO &K; + a&_i * p_&&cand_&_i %END;)); %END; ;
  ods output ParameterEstimates=sl.alpha;
 quit;
%END;
%ELSE %IF &LOSS=LOG %THEN %DO;
 title2 'CONVEX ALPHA: UPDATE ESTIMATE TO MINIMIZE CROSS VALIDATED BERNOULLI LOGLIKELIHOOD RISK';
 proc nlp data=&TRAIN; 
  min logL; 
  parms %DO _i=1 %TO &K; a&_i =%SCAN(&init, &_i, " "), %END; ;
  bounds 0 <= %DO _i=1 %TO &K; a&_i %END; <=1;
  lincon  0 %DO _i=1 %TO &K; + a&_i %END; = 1;
  %LET P=; %DO _i=1 %TO &K; %LET P = &P p_&&cand_&_i ; %END;
  array P{&K} %DO kkk = 1 %TO &K; %SCAN(&P, &kkk, ' ') %END; ;
  array logit{&K} %DO kkk = 1 %TO &K; logit_%SCAN(&P, &kkk, ' ') %END; ;
  do _i = 1 to &K;
   P{_i} = max(P{_i},&LOWER_BOUND);
   P{_i} = min(P{_i},&UPPER_BOUND);
   logit{_i} = log(P{_i}/(1-P{_i})) ;
  end;
  drop _:;
  %LET linpart = ; %DO _i=1 %TO &K; %LET linpart = &linpart + a&_i * logit_p_&&cand_&_i; %END;
  %IF &WEIGHTS ne %THEN %DO; logL = 2*&WEIGHTS*(log(1+exp(-1*(&linpart)))-(&Y-1)*(&linpart)); %END;
  %ELSE %DO; logL = 2*(log(1+exp(-1*(&linpart)))-(&Y-1)*(&linpart)); %END; 
  ods output ParameterEstimates=sl.alpha;
 quit;
%END;
data sl.alpha; set sl.alpha nobs=nobs; if _n_ ge (nobs-&K+1); run;
data sl.alpha;
 set sl.alpha (keep = Parameter Estimate);
 Candidate = resolve(catt('&cand_'||trim(left(_n_))));
 call symputx(catt("a",_n_), Estimate, 'G');
run;
proc datasets lib=work; delete _: ; run; quit; 

title2 'FIT CANDIDATE ESTIMATORS ON ENTIRE TRAINING DATASET';
%DO kkk=1 %TO &K;
 %&&cand_&kkk(TRAIN=&TRAIN, Y=&Y, Y_TYPE=&Y_TYPE, X=&X, ID=&ID, T=&T, WEIGHTS=&WEIGHTS, SEED=&SEED, WD=&WD);
 proc datasets lib=work; delete _: ; run; quit;
%END;
proc datasets lib=sl; delete _: ; run; quit; 

data _null_;
 file "&WD\F_SuperLearner.sas";
 put "***************************************;";
 put "* 			SUPER LEARNER			*;";
 put "***************************************;";
 %DO kkk = 1 %TO &K;
  put "* &&cand_&kkk *;"; 
 %END;
run;
%DO kkk = 1 %TO &K;
 data _null_;
  infile "&WD\F_&&cand_&kkk...sas";
  input;
  file "&WD\F_SuperLearner.sas" MOD;
  put _infile_;
 run;
%END; 
data _null_;
 file "&WD\F_SuperLearner.sas" MOD;
 put "*********************;" ;
 put "* BOUND PREDICTIONS *;" ;
 put "*********************;" ;
 put "array P{&K} ";
 %DO kkk = 1 %TO &K;
  put "p_&&cand_&kkk" ;
 %END;
 put ";";
 put "do _i=1 to &K;" ;
 put " p{_i} = max(p{_i},&LOWER_BOUND);" ;
 put " p{_i} = min(p{_i},&UPPER_BOUND);" ;
 put "end;" ;
 put "*************************;" ;
 put "* SUPER LEARNER MAPPING *;" ;
 put "*************************;" ;
 %IF &LOSS=L2 %THEN %DO;
  put " p_SL = 0 " ;
  %DO kkk = 1 %TO &K;
   put " + &&a&kkk * p_&&cand_&kkk" ;
  %END;
  put ';' ;
 %END;
 %ELSE %IF &LOSS=LOG %THEN %DO;
  put "array logit{&K}" %DO kkk = 1 %TO &K; " logit_p_&&cand_&kkk" %END; ";";
  put "do _i = 1 to &K;";
  put " logit{_i} = log(P{_i}/(1-P{_i}));";
  put "end;";
  put " p_SL = 1/(1+exp(-1*(0+ " ;
  %DO kkk = 1 %TO &K;
   put " + &&a&kkk * logit_p_&&cand_&kkk" ;
  %END;
  put ')));' ;
 %END;
 put "keep ";
 %DO _i=1 %TO &nKEEP_TRAIN;
  put "&&KEEP_TRAIN_&_i ";
 %END;
 %DO kkk=1 %TO &K;
  put "p_&&cand_&kkk";
 %END;
 put "p_SL ;" ; 
run;

%IF &TEST ne %THEN %DO;
 title2 'COMPUTE PREDICTIONS FOR VALIDATION/TEST DATA SET';
 data &TEST; set &TEST; %include "&WD\F_SuperLearner.sas"; run;
%END;

ods listing;
title2 "ALPHA";
proc print data=sl.alpha; run;

title2 "CROSS VALIDATED RISK ON TRAINING DATA";
%RISK(DSN=&TRAIN, Y=&Y, YHAT=%DO kkk = 1 %TO &K; p_&&cand_&kkk %END;, WEIGHTS=&WEIGHTS, LOSS=&LOSS, ID=&ID);
proc datasets lib=work; delete LOSS; run; quit;

%IF &TEST ne %THEN %DO;
 title2 "RISK ON VALIDATION/TEST DATA";
 %RISK(DSN=&TEST, Y=&Y, YHAT=%DO kkk = 1 %TO &K; p_&&cand_&kkk %END; p_SL, WEIGHTS=&WEIGHTS, LOSS=&LOSS, ID=&ID);
 proc datasets lib=work; delete LOSS; run; quit;
%END;
title1 ' '; title2 ' '; title3 ' '; title4 ' '; title5 ' '; title6 ' ';
%MEND SUPERLEARNER;




**************************************************************************************;
* UTILITY MACROS FOR %SUPERLEARNER:													 *;
*																					 *;
* %SRS 			- SIMPLE RANDOM SAMPLING WITHOUT REPLACEMENT						 *;
* %STRAT_SRS 	- OUTCOME-STRATIFIED SIMPLE RANDOM SAMPLING WITHOUT REPLACEMENT		 *;
* %RISK			- COMPUTE SQUARED ERROR (L2) OR BERNOULLI LOGLIKELIHOOD (LOG) RISK   *;
**************************************************************************************;

*****************************************************************************;
* SRS- SIMPLE RANDOM SAMPLING WITHOUT REPLACEMENT 		 					*;
*****************************************************************************;
%MACRO SRS(DSN, OUTDATA, SEED=715, SAMP_PROB=);
 data &OUTDATA;
  set &DSN nobs=nobs;
  rand=ranuni(&SEED);
  if rand le &SAMP_PROB;
  drop rand;
 run;
%MEND SRS;

******************************************************************************************;
* STRAT_SRS - SIMPLE RANDOM SAMPLING WITHOUT REPLACEMENT STRATIFIED ON BINARY OUTCOME	 *;
******************************************************************************************;
%MACRO STRAT_SRS(DSN, OUTDATA, SEED=715, Y_SAMP_PROB=);
 %LET prob_0 = %scan(&Y_SAMP_PROB, 1, " ");
 %LET prob_1 = %scan(&Y_SAMP_PROB, 2, " ");
 data _Y_0; set &DSN; if &Y=0; run;
 data _Y_1; set &DSN; if &Y=1; run;
 %SRS(DSN=_Y_0, OUTDATA=_sampY_0, SEED=&SEED, SAMP_PROB=&prob_0);
 %SRS(DSN=_Y_1, OUTDATA=_sampY_1, SEED=&SEED, SAMP_PROB=&prob_1);
 data &OUTDATA; set _sampY_0 _sampY_1; run;
 proc datasets lib=work; delete _: ; run; quit;
%MEND STRAT_SRS;

*****************************************************************************;
* RISK - COMPUTE SQUARED ERROR (L2) or BERNOULLI LOGLIKELIHOOD (LOG) RISK	*;
*****************************************************************************;
%MACRO RISK(DSN=, Y=, YHAT=, WEIGHTS=, LOSS=, ID=, T=);
%LET P = %sysfunc(countw(&YHAT));
proc sort data=&DSN; by &ID &T; run; 
%IF &LOSS=L2 %THEN %DO;
 data loss;
  set &DSN;
  by &ID &T;
  retain %DO kkk = 1 %TO &P; loss_&kkk %END; ;
  array loss{&P} %DO kkk = 1 %TO &P; loss_&kkk %END; ;
  array yhat{&P} %DO kkk = 1 %TO &P; %SCAN(&YHAT, &kkk, ' ') %END; ;
  if first.&ID then do; do i=1 to &P; loss{i} = 0; end; end; 
  do i=1 to &P; 
   loss{i} = loss{i} + 
   %IF &WEIGHTS ne %THEN &WEIGHTS*((&Y-yhat{i})**2); 
   %ELSE (&Y-yhat{i})**2; ;
  end;
  if last.&ID;
  %DO _i=1 %TO &P; label loss_&_i = %BQUOTE(%SCAN(&YHAT, &_i, " ")); %END;
 run;
 title3 "L2-loss: &DSN";
 proc means; 
  VAR %DO kkk = 1 %TO &P; loss_&kkk %END; ;
  output out=RISK_sum; 
 run;
%END;
%ELSE %IF &LOSS=LOG %THEN %DO;
 data loss;
  set &DSN;
  by &ID &T;
  retain %DO kkk = 1 %TO &P; loss_&kkk %END; ;
  array loss{&P} %DO kkk = 1 %TO &P; loss_&kkk %END; ;
  array yhat{&P} %DO kkk = 1 %TO &P; %SCAN(&YHAT, &kkk, ' ') %END; ;
  if first.&ID then do; do i=1 to &P; loss{i} = 0; end; end; 
  do i=1 to &P; 
   loss{i} = loss{i} + 
   %IF &WEIGHTS ne %THEN -2*&WEIGHTS*(&Y*log(yhat{i}) + (1-&Y)*log(1-yhat{i})); 
   %ELSE -2*(&Y*log(yhat{i}) + (1-&Y)*log(1-yhat{i})); ;
  end;
  if last.&ID;
  %DO _i=1 %TO &P; label loss_&_i = %BQUOTE(%SCAN(&YHAT, &_i, " ")); %END;
 run;
 title3 "Log-loss: &DSN";
 proc means; 
  VAR %DO kkk = 1 %TO &P; loss_&kkk %END; ;
  output out=RISK_sum; 
 run;
%END;
%MEND RISK;

