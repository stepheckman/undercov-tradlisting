* probabilities of selection for all phases:
	psu and segment selection prob
	line selection prob
	subsample selection prob -- some cases subsampled after half of data collection period
	selection for my diss (49 segments from 104)

	adjustment to PSU probability for non-super-8 segments
		need to divide PSU prob by 4, one qtr of nonsuper8 worked in each year
	adjustment to seg probabilty for selection of q12 from all 4 quarters for year 3
		need to divide SEG prob by 4 in non-super-8
		by 16 in super8
	thse two adjustments together lead to all unconditional segment probs divided by 16;

* assuming no adjustment for 3 segments where matching not done
* also not doing any nonresponse adjustment;

* outputs:
	sel4 -- selected cases, with all probability variables merged in;




ods rtf file="&output.\weights datasets.rtf";
* weights dataset emailed by Brady July 1 2011;
proc contents data=anal.nsfgwgt010511 varnum;
	title 'Contents of Bradys weight dataset';
run;

proc contents data=anal.q01q16_adjusted_weights varnum;
	title 'Contents of James weight dataset, no withi HH selection';
run;
ods rtf close;



********************************************************************************************
* subset weights to just cases in my segments (and in quarter 12 -- some of my segs also used in other quarters)
* adj probabilities for selection into my study;

* get respondent selection probs from this dataset;
data wgts;
	set anal.nsfgwgt010511; 

	PSU_SEG = substr(VSAMPLELINEID,1,6);

	* R prob -- does this include any subsampling?? -- it should;
	R_PROB = 1/BASEWGTQ1Q16;

	COND_R_PROB = 1/WHHWGT;

	if PSU_SEG in (&selsegs.) then output;
run;

data wgts2;
	set anal.q01q16_adjusted_weights(where=(QUARTER=12));

	PSU_SEG = substr(VSAMPLELINEID,1,6);

	* split q01q16 into seg and hh level weights (for xtmixed, which wants these split);
	SEG_PROB = q01q16_psu_prob * q01q16_seg_prob * q01q16psudomain_probability;
	HH_PROB = SEG_PROB * q01q16line_probability;
	HH_2PH_PROB = HH_PROB * SECOND_PH_COMBINED_PROBABILITY;

	if PSU_SEG in (&selsegs.) and QUARTER=12 then output;
run;

* get seg and HH selection probs from this dataset;
proc sort data=wgts; by VSAMPLELINEID; run;
proc sort data=wgts2; by VSAMPLELINEID; run;
data w1;
	merge wgts(drop=PSU_SEG) wgts2;
	by VSAMPLELINEID;

	* full HH prob of selection, for NSFG, includign second phase, is:
		q01q16_psu_prob * q01q16_seg_prob * q01q16line_probability * q01q16psudomain_probability * SECOND_PH_COMBINED_PROBABILITY
		this equals q01q16_probability in anal.q01q16_adjusted_weights dataset
		and q01q16_weight is inverse of q01q16_probability;

	* selection for dissertation;
	if PSU_SEG in (&cert.) then DISSPROB = &cprob;
	else if PSU_SEG in (&noncert.) then DISSPROB = &ncprob;
	* should be no missing;

	* adjust for year 3 and for quarter 12;
	YRQTR_PROB = &psadjp.;

	MY_SEG_PROB = SEG_PROB * DISSPROB * YRQTR_PROB;
	MY_R_PROB = R_PROB * DISSPROB * YRQTR_PROB;
	MY_HH_PROB = HH_PROB * DISSPROB * YRQTR_PROB;
	MY_HH_2PH_PROB = HH_2PH_PROB * DISSPROB * YRQTR_PROB;
	MYCOND_HH_PROB = HH_PROB/SEG_PROB;  ** HH selection only, no need for diss, yrqrt adj as these are seg only;
	MYCOND_HH_2PH_PROB = HH_2PH_PROB/SEG_PROB;  ** HH selection include 2phase, no need for diss, yrqrt adj as these are seg only;

	label R_PROB = "Respondent prob, all stages, from Brady"
		COND_R_PROB = "Respondent prob, within HH, no other stages"
		DISSPROB = "Prob of selection of HU for dissertation"
		MY_R_PROB = "Uncond probs of selection of R, incl my study, w/o NR adjustments"
		MY_SEG_PROB = "Uncond prob of sel of segment, incl my study probability adj"
		MYCOND_HH_PROB = "Cond prob of sel of HH, conditioned on seg, psu, w/o 2phase sampling"
		MYCOND_HH_2PH_PROB = "Cond prob of sel of HH, conditioned on seg, psu, w 2phase sampling"
		MY_HH_PROB = "Uncond prob of selection of HH, incl my study, w/o NR adjustments or 2phase sampling adj"
		MY_HH_2PH_PROB = "Uncond probs of selection for HH, incl my study, w/ 2phase sampling adj, w/o NR adjustments"
		YRQTR_PROB = "Adjustmet for year 3, quarter 12"
		SEG_PROB = "Uncond prob of selection of segment, w/o adj for my study"
		HH_PROB = "Uncond prob of selection of HH, w/o 2 phase or adj for my study"
		HH_2PH_PROB = "Uncond prob of selection of HH, w/ 2 phase or adj for my study"
		SECOND_PH_COMBINED_PROBABILITY = "cond prob of selection into 2nd phase, including seg and HU"
	;

	rename VSAMPLELINEID = SAMPLEID
		SECOND_PH_COMBINED_PROBABILITY = PH2_PROB;

	keep PSU_SEG R_PROB COND_R_PROB MY: DISS: YRQTR: SEG_PROB HH: VSAMPLELINEID SECOND_PH_COMBINED_PROBABILITY;

	if PSU_SEG in (&selsegs.) and QUARTER=12 then output;
run;


proc means data=w1 n nmiss min mean max;
	var R_PROB YRQTR_PROB DISSPROB MY_R_PROB MY_HH_PROB MY_SEG_PROB PH2_PROB;
	title 'Check change in probs after adjustments';
run;

data local.weights;
	set w1;
run;



proc sql; 
	create table qc as
	select PSU_SEG, min(MY_SEG_PROB) as SEG_MIN, max(MY_SEG_PROB) as SEG_MAX,
		min(MYCOND_HH_PROB) as HH_MIN, max(MYCOND_HH_PROB) as HH_MAX,
		min(MYCOND_HH_2PH_PROB) as HH_2PH_MIN, max(MYCOND_HH_2PH_PROB) as HH_2PH_MAX,
		case when min(MYCOND_HH_PROB) ne max(MYCOND_HH_PROB) then 1 else 0 end as PROB
	from local.weights
	group by PSU_SEG;

proc print data=qc noobs;
	where PROB=1;
	title 'PROBLEM: Inconsistent probabilities';
run;


/*
data adj;
	set anal.nsfgwgt010511;

	PSADJ = WGTQ1Q16/NRADJ_BW2Q1Q16;
	COVRATE = 1/PSADJ;
run;

proc means data=adj;
	var WGTQ1Q16 NRADJ_BW2Q1Q16 PSADJ COVRATE;
	TITLE 'Size of post-stratifiation adj';
run;
*/
