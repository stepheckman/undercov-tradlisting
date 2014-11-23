* prepare list of all lines to print out
	both matched and unmatched;

* find which segments need matching and have matchable lines in both segments;
proc sql;
	create table seg_match as 
	select SEG_ID, sum(case when ID1 is NULL then 1 else 0 end) as L1_MATCHABLE,
		sum(case when ID2 is NULL then 1 else 0 end) as L2_MATCHABLE
	from listings_matched_beforeman
	group by SEG_ID
	having mean(MATCHED)<1;

data l1 l2;
	retain SEG_ID SEGLIST ID1 ID2 ORDER ADDR APT DESCR;
	merge listings_matched_beforeman(where=(LISTED=1)) seg_match(where=(L1_MATCHABLE>0 and L2_MATCHABLE>0) in=INSEG); 
	by SEG_ID;

	format SEGLIST $12. ADDR $80.;

	SEGLIST = compress(put(SEG_ID,3.) || "-" || put(LISTING,3.));
	ADDR = compbl(STR_NUMBER || STR_PREDIR || STR_NAME || STR_TYPE || STR_POSTDIR);

	if LISTING=1 and INSEG then output l1;
	else if LISTING=2 and INSEG then output l2;
run;

proc sort data=l1; by SEG_ID ORDER; run;
proc sort data=l2; by SEG_ID ORDER; run;

proc export data=l1(keep=SEGLIST ID1 ID2 ORDER ADDR APT DESCR)
	outfile="&output.\man_match\L1.xls"
	dbms=excel
	replace;
run;

proc export data=l2(keep=SEGLIST ID1 ID2 ORDER ADDR APT DESCR)
	outfile="&output.\man_match\L2.xls"
	dbms=excel
	replace;
run;
