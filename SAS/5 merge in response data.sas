/* 

Name: J:\diss\paper2\analysis\SAS\code\5 finalize and output.sas
Started: 3/19/2009;

prep external data and merge onto listings for output

updated response data delivereyd 10/28/2011 by Nicole Kirgis

input datasets: 
	resp.nsfg_c7_q12_female
	resp.nsfg_c7_q12_male
	anal.listings_matched

output datasets:
	local.rdata

ods html file="&output.\contents_response_datasets.xls";
proc contents data=resp._ALL_ varnum;
	title 'Contents of response dataset';
run;
ods html close;

*/



* look at response data;




* process weight files delivered by NSFG;
%include "&code.\5.1 weights.sas";



data resp;
	set resp.nsfg_c7_q12_female(keep=SAMPLEID &fvars. in=INF)
		resp.nsfg_c7_q12_male(keep=SAMPLEID &mvars.);

	if INF then QUEX=1; 
	else QUEX=2;
run;

proc sort data=local.weights; by SAMPLEID; run;
proc sort data=resp; by SAMPLEID; run;

data sel0;
	set anal.listings_matched(where=(SELECTED=1 and LISTING=1));

	SAMPLEID = compress(compbl(NSFG_PSU || SEG || VLINE_NUM || "11"));
run;

proc sort data=sel0 out=sel; by SAMPLEID; run;


data sel2;
	merge sel(in=INSEL) resp(in=INR) local.weights(drop=PSU_SEG);
	by SAMPLEID;

	* create new var disp_elig -- case found to be eligible for interview
	disp_intw -- case completed screener;

	if DISP in (&dspelig.) then DISP_ELIG=1;
	else if DISP in (&dspscrc.) then DISP_ELIG=0;

	if DISP_ELIG=1 then DISP_INTW = INR;
	if INSEL then output;

	drop HUSELPROB;

	label DISP_ELIG = "Case eligible for screener"
		DISP_INTW = "Case completed screener"
		QUEX = "Female (1) or Male (2) questionnaire";
run;

proc freq data=sel2;
	tables DISP_ELIG * DISP_INTW
		DISP_INTW * QUEX DISSPROB YRQTR_PROB /list missing nocum;
	title 'Review elig and interview flags';
run;




* final dataset local.rdata;
data local.rdata;
	set sel2;
run;



ods rtf file="&output.\response data.rtf";
proc contents data=local.rdata varnum;
	title 'Vars in local.rdata';
run;
proc freq data=local.rdata;
	title 'Freqs on vars in local.rdata';
	where DISP_INTW;
	tables &fvars. &mvars. /list missing;
run;
ods rtf close;
