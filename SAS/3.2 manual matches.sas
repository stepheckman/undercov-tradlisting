/* 

Name: J:\diss\Tpaper\SAS\code\3.1 manual matches.sas
Started: 11/10/2009;

import and QC manual matches between L1 and L2

*/


data manual;
	infile "&output.\man_match\man_matching.csv" delimiter = ',' MISSOVER DSD lrecl=32767 firstobs=2 ;

	informat SEGLIST $3. 
		MATCH_ID1 best32. 
		MATCH_ID2 best32. 
		MATCH_ID1_ORIG best32.
		MATCH_ID2_ORIG best32.
		ORDER best32. 
		ADDR $18. 
		APT $9. 
		DESCR $200. ;

	format SEGLIST $3. 
		MATCH_ID1 best12. 
		MATCH_ID2 best12. 
		MATCH_ID1_ORIG best12. 
		MATCH_ID2_ORIG best12. 
		ORDER best12. 
		ADDR $18. 
		APT $9. 
		DESCR $1. ;

	input
		SEGLIST $
		MATCH_ID1 
		MATCH_ID2
		MATCH_ID1_ORIG 
		MATCH_ID2_ORIG
		ORDER
		ADDR $
		APT $
		DESCR $
	;

	NEW_MATCH=0; CHANGE_MATCH=0; OLD_MATCH=0;
	if MATCH_ID1_ORIG=MATCH_ID1 and MATCH_ID2 = MATCH_ID2_ORIG and MATCH_ID1 ne . and MATCH_ID2 ne . then OLD_MATCH=1;
	else if MATCH_ID1_ORIG=. and MATCH_ID1 ne . and MATCH_ID2 = MATCH_ID2_ORIG then NEW_MATCH=1;
	else if MATCH_ID2_ORIG ne MATCH_ID2 or MATCH_ID1_ORIG ne MATCH_ID1 then CHANGE_MATCH=1;

	if NEW_MATCH=1 or CHANGE_MATCH=1 then do;
		MATCH_PASS=9;
		MATCH_ID = MATCH_PASS*100000+_N_;
	end;

	format MATCH_PASS mtchtypp.;
run;


proc freq data=manual;
	tables OLD_MATCH NEW_MATCH CHANGE_MATCH ;
	title 'Review manual matches from round 1';
run;



* should be no dupes within dataset of manual matches;
%iddupe(manual(where=(MATCH_ID1 ne .)), MATCH_ID1);
%iddupe(manual(where=(MATCH_ID2 ne .)), MATCH_ID2);

* make sure all IDs in manual match dataset exist;
proc sql;
	create table prob1 as
	select m.*
	from manual(where=(MATCH_ID1 is not NULL)) as m
	left outer join anal.listings(where=(LISTED=1 and LISTING=1)) as l
		on m.MATCH_ID1=ID_LISTING
	where ID_LISTING is NULL;
	
	create table prob2 as
	select m.*
	from manual(where=(MATCH_ID2 is not NULL)) as m
	left outer join anal.listings(where=(LISTED=1 and LISTING=2)) as l
		on m.MATCH_ID2=ID_LISTING
	where ID_LISTING is NULL;

proc print data=prob1 noobs;
	title 'PROBLEM: manual match to nonexist ID_LISTING1';
run;

proc print data=prob2 noobs;
	title 'PROBLEM: manual match to nonexist ID_LISTING2';
run;



proc sql;
	create table matches_afterman(rename=(MATCH_ID=ID_MATCH)) as
	select round(coalesce(m1.MATCH_ID1, m1.MATCH_ID2, a.ID1, a.ID2)/10000000,1) as SEG_ID, 
		coalesce(m1.MATCH_ID2, a.ID2) as MATCH_ID2, 
		coalesce(m1.MATCH_ID1, a.ID1) as MATCH_ID1, 
		a.MATCH_PASS as MATCH_PASS_OLD, a.MATCH_ID as MATCH_ID_OLD,
		coalesce(m1.MATCH_ID, a.MATCH_ID) as MATCH_ID,
		coalesce(m1.MATCH_PASS, a.MATCH_PASS) as MATCH_PASS
	from manual(where=(MATCH_ID1 ne .)) as m1
	/* this needs to be full outer join to pick up matches in segs where matching already done */
	full outer join match.matches as a
	on a.ID2 = m1.MATCH_ID2
	/* keep only matched lines */
	where coalesce(m1.MATCH_ID2, a.ID2) ne . and coalesce(m1.MATCH_ID1, a.ID1) ne .
	order by m1.MATCH_ID1, a.ID1;

proc freq data=matches_afterman;
	tables MATCH_PASS*MATCH_PASS_OLD /list missing;
	title 'Compare match types before and after manual matching';
run;

%iddupe(matches_afterman, ID_MATCH);



*********************************
* lots of code cut from dissertation work, because 2 way match easier than 3 way;
*********************************;


* create dataset that contains addresses for all these matches
	review them carefully to make sure matches are correct;

* modelled after macro match (data all_inputs);
proc sort data=matches_afterman; by ID_MATCH; run;
proc transpose data=matches_afterman out=m2;
	var MATCH_ID1 MATCH_ID2;
	by ID_MATCH;
	where MATCH_PASS = 9; * manual matches only;
run;

data m3;
	set m2(where=(COL1 ne .));

	DSET=input(substr(_NAME_,9,1),3.);

	TEST = mod(floor(COL1/100000),100);

	rename COL1 = ID;
run;

proc print data=m3 noobs;
	where TEST ne DSET;
	title 'PROBLEM: digit in ID does not match expected listing number';
run;


proc sql;
	create table m4 as
	select r.ID_MATCH, r.DSET, r.ID, l.*,
		compbl(STR_NUMBER || STR_PREDIR || STR_NAME || STR_POSTDIR || STR_TYPE) as ADDR,
		case when ID_LISTING is NULL then 1 else 0 end as PROBLEM
	from m3 as r
	left outer join listings_matched_beforeman(keep=LISTING LISTED STR: APT ID_LISTING NSFG_PSU SEG DESCR:) as l
	on r.ID=l.ID_LISTING
	where l.LISTED=1
	order by NSFG_PSU, SEG, r.ID_MATCH, r.DSET;

proc print data=m4 noobs width=min;
	title 'PROBLEM: no matching ID_LISTING found for manual match';
	where PROBLEM=1;
	var ID_MATCH DSET ID;
run;


proc sort data=m4; by =NSFG_PSU SEG ID_MATCH LISTING; run;
data m5;
	set m4(keep=NSFG_PSU SEG ID_MATCH ADDR APT DESCR);
	by NSFG_PSU SEG ID_MATCH;

	retain ADDR1 APT1 DESCR1;

	if first.ID_MATCH then do;
		ADDR1=ADDR;
		APT1=APT;
		DESCR1=DESCR;
	end;

	if last.ID_MATCH then output;
run;


ods html file="&output.\review manual matches.xls";
proc print data=m5 noobs width=min;
	var ID_MATCH ADDR ADDR1 APT APT1 DESCR DESCR1;
	title 'Review all matches picked up by manual work';
	*format ID_LISTING 12.;
run;
ods html close;


* import reviewed manual matched, with type flag;
data manual_reviewed;
	infile "&output.\man_match\review manual matches.csv" delimiter = ',' MISSOVER DSD lrecl=32767 firstobs=2 ;

	informat ID_MATCH best32. 
		MANMATCH_TYPE best32. ;

	format ID_MATCH best12. 
		MANMATCH_TYPE best12. ;

	input
		ID_MATCH
		MANMATCH_TYPE
	;

	format MANMATCH_TYPE mantyp.;
run;

proc print data=manual_reviewed noobs;
	title 'PROBLEM in manual match type flag';
	where MANMATCH_TYPE not in (1 2 3 4 5 6);
run;


proc sort data=matches_afterman; by ID_MATCH; run;
proc sort data=manual_reviewed; by ID_MATCH; run;
data match.matches probs;
	merge matches_afterman(in=INM) manual_reviewed(in=INR);
	by ID_MATCH;

	if INR and not INM then output probs;
	else if INM and INR and MATCH_PASS ne 9 then output probs;
	else if INM and not INR and MATCH_PASS = 9 then output probs;

	if INM then output match.matches;
run;

proc freq data=match.matches;
	tables MATCH_PASS MATCH_PASS * MANMATCH_TYPE /list missing;
	title 'Types of matches after first manual review';
run;


* bring together all matches into anal.listings_matched;
* bring NO_NUMBER cases in here;

proc sql;
	create table listings_matched as
	select l.*, MATCH_ID1, MATCH_ID2, ID_MATCH, MATCH_PASS, MANMATCH_TYPE,
		/* HU level ID 
			for matched lines, get lowest of the matched IDs
			for unmatched lines, get ID_LISTING */
		min(MATCH_ID1, MATCH_ID2, ID_LISTING) as ID_HU
	from anal.listings(where=(LISTED=1 and LISTING in (1 2))) as l 
	left outer join match.matches as m1
	on l.ID_LISTING=m1.MATCH_ID1
		or l.ID_LISTING=m1.MATCH_ID2
	order by NSFG_PSU, SEG, ID_HU, LISTING desc;

data anal.listings_matched;
	set listings_matched;

	if LISTING=1 then do;
		ID1 = coalesce(MATCH_ID1, ID_LISTING);
		ID2 = MATCH_ID2;
	end;
	else if LISTING=2 then do;
		ID1 = MATCH_ID1;
		ID2 = coalesce(MATCH_ID2, ID_LISTING);
	end;

	if MATCH_ID1 ne . and MATCH_ID2 ne . then MATCHED=1;
	else MATCHED=0;
run;


* find which segments need matching and have matchable lines in both segments;
proc sql;
	create table seg_match as 
	select SEG_ID, sum(case when ID1 is NULL then 1 else 0 end) as L1_MATCHABLE,
		sum(case when ID2 is NULL then 1 else 0 end) as L2_MATCHABLE
	from anal.listings_matched
	group by SEG_ID
	having mean(MATCHED)<1;

data l1 l2;
	retain SEG_ID SEGLIST ID1 ID2 ORDER ADDR APT DESCR;
	merge anal.listings_matched(where=(LISTED=1)) seg_match(where=(L1_MATCHABLE>0 and L2_MATCHABLE>0) in=INSEG); 
	by SEG_ID;

	format SEGLIST $12. ADDR $80.;

	SEGLIST = compress(put(SEG_ID,3.) || "-" || put(LISTING,3.));
	ADDR = compbl(STR_NUMBER || STR_PREDIR || STR_NAME || STR_TYPE || STR_POSTDIR);

	if LISTING=1 and INSEG then output l1;
	else if LISTING=2 and INSEG then output l2;
run;

/* sort differently this time, to put all HUs on same street together;
proc sort data=l1; by SEG_ID STR_NAME STR_NUMBER; run;
proc sort data=l2; by SEG_ID STR_NAME STR_NUMBER; run;

proc export data=l1(keep=SEGLIST ID1 ID2 ADDR APT DESCR)
	outfile="&output.\man_match\L1_mm2.xls"
	dbms=excel
	replace;
run;

proc export data=l2(keep=SEGLIST ID1 ID2 ADDR APT DESCR)
	outfile="&output.\man_match\L2_mm2.xls"
	dbms=excel
	replace;
run;

*/
