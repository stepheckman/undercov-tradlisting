/* look for HOI cases in datasets with response data and weights

SRO uses last two digits of SampleID to indicate R and HOI case spawning
Since NSFG selects only 1 R per HH
anything other than "11" on the end of a sample id means an HOI was found

Datasets to check for HOI indicators

anal.nsfgwgt010511 -- from Brady

anal.q01q16_adjusted_weights  -- from James
** does nto contain SAMPLIEID so I don't think I can get HOI info from this dataset

* response data 
resp.nsfg_c7_q12_female
resp.nsfg_c7_q12_male
*/

data hoi1(rename=(VSAMPLELINEID=SAMPLEID));
	set anal.nsfgwgt010511(keep=VSAMPLELINEID);

	if substr(VSAMPLELINEID,11,2) = "11" then HOI=0;
	else HOI=1;

	format PSU SEG $3.;
	PSU = substr(VSAMPLELINEID,1,3);
	SEG = substr(VSAMPLELINEID,4,3);

	PSUSEG = substr(VSAMPLELINEID,1,6);
run;

data hoi2;
	set resp.nsfg_c7_q12_female(keep=SAMPLEID) resp.nsfg_c7_q12_male(keep=SAMPLEID);

	if substr(SAMPLEID,11,2) = "11" then HOI=0;
	else HOI=1;

	format PSU SEG $3.;
	PSU = substr(SAMPLEID,1,3);
	SEG = substr(SAMPLEID,4,3);

	PSUSEG = substr(SAMPLEID,1,6);
run;

proc sort data=hoi1; by SAMPLEID; run;
proc sort data=hoi2; by SAMPLEID; run;
data hoi;
	merge hoi1(in=IN1) hoi2;
	by SAMPLEID;

	if IN1 then SOURCE=1;
	else SOURCE=2;

	if PSUSEG in (&selsegs.) then SEL = 1;
	else SEL = 0;
run;


ods rtf file="&output.\hoi units.rtf";
proc freq data=hoi;
	tables HOI SEL*HOI /list missing;
	title 'Units found with HOI in my segments, larger set of segments';
	title1 'Not sure what the larger set of segments is here (anal.nsfgwgt010511 dataset from Brady)';
run;
ods rtf close;
