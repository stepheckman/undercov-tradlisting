* address matching program
	will always avoid double-matching
	once a record is matched, cannot be matched again
	useful in matching addresses--one address cannot match 2 others

* creates a new output datatset lib.address_matches
	contains only matched observations
	ID1 is ID from dataset specified first
	ID2 is ID from dataset specified second;

* may generate "NOTE: DATA STEP stopped due to looping." 
	This is not a problem;

* inputs are datasets, not addresses;
* d1 must have fields ID, STREET_NUM, STREET_NAME, STREET_SUFFIX, APT;
* d2 must have fields ID, STREET_NUMBER_PREFIX, STREET_NUM, STREET_NAME, STREET_SUFFIX, APT;
* lib is libname to save output in;





* go through each of these datsets and find the obs associated with two projects:
	SRC.SRO.NSFG.STTEST.LIST
	SRC.SRO.NSFG.PROD.LIST
* backup these datasets to local library;



%macro copyST(lib, local);

* copy relevant rows of all tables from ST libnrary to local library;


proc sql noprint;

* get number of datasets in lib;
select count(*) into :count
from dictionary.tables
where libname=%upcase("&lib.");

* parse string of table names into separate macro vars;
select memname into :dsname1 - :dsname%trim(%left(&count.))
from dictionary.tables
where libname=%upcase("&lib.");
quit;

/*%do i=1 %to &count;
	%put &&dsname&i.;
%end;*/

%do i=1 %to &count;
	data &local..&&dsname&i; 
		set &lib..&&dsname&i(where=(VPROJECTID in (&prjs.) and substr(VSAMPLELINEID,1,6) in (&selsegs.))); 
	run;
%end;


* delete tables in local with no observations;

* get number of datasets in local with no observations;
proc sql noprint;

select count(*) into :count2
from dictionary.tables
where libname=%upcase("&local") and nobs=0;

* parse string of table names into separate macro vars;
select memname into :dname1 - :dname%trim(%left(&count2.))
from dictionary.tables
where libname=%upcase("&local.") and nobs=0;
quit;

%do j=1 %to &count2;
	proc delete data=&local..&&dname&j; 
	run;
%end;
%mend;


%macro man_dupe(dset);
* look for cases matched to more than 1 other case;

%do i = 1 %to 3;
	* dupes within all matched on MATCH_ID&i;
	%iddupe(&dset.(where=(MATCH_ID&i. ne .)), MATCH_ID&i.,1);

	proc sql noprint;
		select count(*) into :DCT
		from dupes;

	%if &dct. > 0 %then %do;
		create table dupes2 as
		select *
		from &dset.
		where MATCH_ID&i. in (select MATCH_ID&i. from dupes)
		order by MATCH_ID&i., MATCH_STEP;

	proc print data=dupes2 noobs;
		var MATCH_ID1 MATCH_ID2 MATCH_ID3 MATCH_STEP MATCH_SUBSTEP FLAGL2 FLAGL3 NOTES;
		title "PROBLEM: Review duplicate matches on MATCH_ID&i.";
	run;
	%end;
%end;

%mend;


%macro inptmtch;

* requires exact match on all address parts 
	and blocking variable PSU_SEG;
%address_match1(d1,d2,work);
%address_match2(d1_unmatched1,d2_unmatched1,work);
%address_match3(d1_unmatched2,d2_unmatched2,work);
%address_match4(d1_unmatched3,d2_unmatched3,work);
%address_match5(d1_unmatched4,d2_unmatched4,work);
%address_match6(d1_unmatched5,d2_unmatched5,work);
%address_match7(d1_unmatched6,d2_unmatched6,work);


* bring in manual matches;
%include "&code.\2.2.1 manual matches of input to L3.sas";


* check for duplicates between manual matches and auto matches;
data auto_matches;
	set m1_1 m1_2 m1_3 m1_4 m1_5 m1_6 m1_7;
run;
	
proc sql;
	create table mandupes1 as
	select m.*, a.ID2 as AUTO_MATCH
	from manual2 as m
	inner join auto_matches as a
	on m.ID1 = a.ID1;

	create table mandupes2 as
	select m.*, a.ID1 as AUTO_MATCH
	from manual2 as m
	inner join auto_matches as a
	on m.ID2 = a.ID2;

proc print data=mandupes1 noobs;
	title 'PROBLEM: These ID_LISTING in manual match file already matched automatically';
run;

proc print data=mandupes2 noobs;
	title 'PROBLEM: These ID_INPUT in manual match file already matched automatically';
run;


* save matched IDs to perm dataset;
data input_matches;
	set %do i = 1 %to 7;
		m1_&i.(in=IN&i.)
	%end;
		manual2(in=INMAN)
	;

	%do i = 1 %to 7;
		if IN&i. then INPUT_MATCH_STEP = &i.;
	%end;

	if INMAN then INPUT_MATCH_STEP = MANUAL_MATCH_TYPE;
	
	drop MATCH_PASS MANUAL_MATCH_TYPE;

	rename ID1 = ID_LISTING
		ID2 = ID_INPUT;

	format INPUT_MATCH_STEP mtchtype.;
run;

data anal.input_matches;
	set input_matches;

	if MATCH_ID = . then MATCH_ID = _N_;

	* manual moves of matched addresses based on review below
		move matches from unlisted to listed pair within address dupes;
	if ID_INPUT=1905 then ID_LISTING=25552;
	else if ID_INPUT=5157 then ID_LISTING=26454;
	else if ID_INPUT=5156 then ID_LISTING=26455;
	else if ID_INPUT=5620 then ID_LISTING=28868;
	else if ID_INPUT=2547 then ID_LISTING=30716;
run;

* when two idnetical addresses on dep_list are available to match,
	(identical on all address parts, segment, apt and descr)
	match should be to the listed one, not the unlisted one
	make a list of matches to dupees and review it carefully!;
proc sql;
	create table dldupes as
	select l.*, d.ID_LISTING, LISTED, 
		compbl(d.STR_NUMBER || d.STR_PREDIR || d.STR_NAME || d.STR_TYPE || d.STR_POSTDIR) as ADDR
	from dep_list as d
	inner join (select PSU_SEG, STR_NUMBER, STR_PREDIR, STR_NAME, STR_TYPE, STR_POSTDIR, APT, DESCR, count(*) as CT, sum(LISTED) as LIST
		from dep_list
		group by PSU_SEG, STR_NUMBER, STR_PREDIR, STR_NAME, STR_TYPE, STR_POSTDIR, APT, DESCR
		having count(*) > 1) as l
	on d.PSU_SEG = l.PSU_SEG
		and d.STR_NUMBER = l.STR_NUMBER
		and d.STR_PREDIR = l.STR_PREDIR
		and d.STR_NAME = l.STR_NAME
		and d.STR_TYPE = l.STR_TYPE
		and d.STR_POSTDIR = l.STR_POSTDIR
		and d.APT = l.APT
		and d.DESCR = l.DESCR;

	create table dldupes_matches as
	select l.*, ID_INPUT, INPUT_MATCH_STEP
	from anal.input_matches as i
	right outer join dldupes as l
	on i.ID_LISTING = l.ID_LISTING
	order by l.ADDR,l.LISTED;

proc print data=dldupes_matches noobs width=min;
	var ADDR APT DESCR LISTED ID_LISTING ID_INPUT INPUT_MATCH_STEP;
	title 'Review matches to cases on dep_list with multiple occurences of identical ADDR, APT, DESCR';
	title2 'Move matches from unlisted to listed cases';
run;


%iddupe(anal.input_matches2, MATCH_ID);


* make one dataset of all matches after step 1;
proc sql noprint;

select count(*) into :count2
from dictionary.tables
where libname = upcase("work") 
	and substr(MEMNAME,1,13)="MATCH_COMPARE"
	and nobs ne 0;

* parse string of table names into separate macro vars;
select memname into :dname1 - :dname%trim(%left(&count2.))
from dictionary.tables
where libname = upcase("work") 
	and substr(MEMNAME,1,13)="MATCH_COMPARE"
	and nobs ne 0
	and MEMNAME ne "MATCH_COMPARE_1";


data mtchreview0;
	set %do j = 1 %to %eval(&count2.-1);
		&&dname&j.
	%end;
		man_review(in=INMAN)
	;

	if not INMAN then ADDR = coalescec(compbl(HOUSE_NUM || DIR || STR_NAME || STR_TYPE || DIR_PFX));

	drop APT_UNIT;
run;

proc sql;
	create table mtchreview as
	select m.ID, m.MATCH_PASS, m.MATCH_ID, m.DSET, m.ADDR, m.APT, 
		coalescec(m.DESCR, d.DESCR, ma.INPUT_DESCR) as DESCR
	from mtchreview0 as m
	left outer join dep_list as d
	on m.ID = d.ID_LISTING
		and m.DSET=1
	left outer join dep_manip as ma
	on m.ID = ma.ID_INPUT
		and m.DSET=1;

	
proc sql;
	create table singles as
	select MATCH_ID, ID
	from mtchreview
	where MATCH_ID in (select MATCH_ID from mtchreview group by MATCH_ID having count(*) ne 2);

proc print data=singles;
	title 'PROBLEM: matches with other than 2 units';
run;
%mend;




%macro mtchprep(d1,d2,lib);
* gets datasets in expected shape for match routines;
* input &d1, &d2;
* output set1, set2;
data set1;
	set &d1;

	rename ID=ID1;

	keep HOUSE_NUM HOUSE_SFX DIR_PFX STR_TYPFX STR_NAME STR_TYPE
		DIR EXT APT_UNIT BLK_KEY_OUT MAF_ID VALID ID ORDER;
run;

data set2;
	set &d2;

	rename HOUSE_NUM = HOUSE_NUM_2
		HOUSE_SFX = HOUSE_SFX_2
		DIR_PFX = DIR_PFX_2
		STR_TYPFX = STR_TYPFX_2
		STR_NAME = STR_NAME_2 
		STR_TYPE = STR_TYPE_2
		DIR=DIR_2
		EXT=EXT_2
		APT_UNIT=APT_UNIT_2
		BLK_KEY_OUT=BLK_KEY_OUT_2
		ID=ID2;
	
	keep HOUSE_NUM HOUSE_SFX DIR_PFX STR_TYPFX STR_NAME STR_TYPE
		DIR EXT APT_UNIT BLK_KEY_OUT MAF_ID VALID ID ORDER;
run;

proc sort data=set1;
	by BLK_KEY_OUT HOUSE_NUM HOUSE_SFX DIR_PFX
		STR_TYPFX STR_NAME STR_TYPE DIR EXT APT_UNIT ORDER;
run;

proc sort data=set2;
	by BLK_KEY_OUT_2 HOUSE_NUM_2 HOUSE_SFX_2 DIR_PFX_2
		STR_TYPFX_2 STR_NAME_2 STR_TYPE_2 DIR_2 EXT_2 APT_UNIT_2 ORDER;
run;
%mend;

%macro address_match1(d1,d2,lib,step);

%let pass=1;

%mtchprep(&d1.,&d2.);

data m1_&pass.;
	retain set1ptr set2ptr;
	if _N_ = 1 then do;
		set set1 nobs=set1obs;
		set set2 nobs=set2obs;

		set1ptr=1;
		set2ptr=1;
	end;

	* makes sure not to advance past end of either dataset;
	if set1ptr <= set1obs and set2ptr <= set2obs then do;

		* get the requested observations from each dataset;
		set set1 point=set1ptr;
		set set2 point=set2ptr;

		if (BLK_KEY_OUT = BLK_KEY_OUT_2 
			and HOUSE_NUM = HOUSE_NUM_2 
			and HOUSE_SFX = HOUSE_SFX_2
			and DIR_PFX = DIR_PFX_2 
			and STR_TYPFX = STR_TYPFX_2 
			and STR_NAME = STR_NAME_2
			and STR_TYPE = STR_TYPE_2
			and DIR = DIR_2
			and EXT = EXT_2 
			and APT_UNIT = APT_UNIT_2)
			then do;
	
				* match found;
				output;

				* advance obs in each dataset;
				set1ptr + 1;
				set2ptr + 1;
		end;
		else do;

			if (BLK_KEY_OUT < BLK_KEY_OUT_2)
				or (BLK_KEY_OUT = BLK_KEY_OUT_2 
					and HOUSE_NUM < HOUSE_NUM_2)
				or (BLK_KEY_OUT = BLK_KEY_OUT_2 
					and HOUSE_NUM = HOUSE_NUM_2
					and HOUSE_SFX < HOUSE_SFX_2)
				or (BLK_KEY_OUT = BLK_KEY_OUT_2 
					and HOUSE_NUM = HOUSE_NUM_2
					and HOUSE_SFX = HOUSE_SFX_2
					and DIR_PFX < DIR_PFX_2)
				or (BLK_KEY_OUT = BLK_KEY_OUT_2 
					and HOUSE_NUM = HOUSE_NUM_2
					and HOUSE_SFX = HOUSE_SFX_2
					and DIR_PFX = DIR_PFX_2
					and STR_TYPFX < STR_TYPFX_2)
				or (BLK_KEY_OUT = BLK_KEY_OUT_2 
					and HOUSE_NUM = HOUSE_NUM_2
					and HOUSE_SFX = HOUSE_SFX_2
					and DIR_PFX = DIR_PFX_2
					and STR_TYPFX = STR_TYPFX_2
					and STR_NAME < STR_NAME_2)
				or (BLK_KEY_OUT = BLK_KEY_OUT_2 
					and HOUSE_NUM = HOUSE_NUM_2
					and HOUSE_SFX = HOUSE_SFX_2
					and DIR_PFX = DIR_PFX_2
					and STR_TYPFX = STR_TYPFX_2
					and STR_NAME = STR_NAME_2
					and STR_TYPE < STR_TYPE_2)
				or (BLK_KEY_OUT = BLK_KEY_OUT_2 
					and HOUSE_NUM = HOUSE_NUM_2
					and HOUSE_SFX = HOUSE_SFX_2
					and DIR_PFX = DIR_PFX_2
					and STR_TYPFX = STR_TYPFX_2
					and STR_NAME = STR_NAME_2
					and STR_TYPE = STR_TYPE_2
					and DIR < DIR_2)
				or (BLK_KEY_OUT = BLK_KEY_OUT_2 
					and HOUSE_NUM = HOUSE_NUM_2
					and HOUSE_SFX = HOUSE_SFX_2
					and DIR_PFX = DIR_PFX_2
					and STR_TYPFX = STR_TYPFX_2
					and STR_NAME = STR_NAME_2
					and STR_TYPE = STR_TYPE_2
					and DIR = DIR_2
					and EXT < EXT_2)
				or (BLK_KEY_OUT = BLK_KEY_OUT_2 
					and HOUSE_NUM = HOUSE_NUM_2
					and HOUSE_SFX = HOUSE_SFX_2
					and DIR_PFX = DIR_PFX_2
					and STR_TYPFX = STR_TYPFX_2
					and STR_NAME = STR_NAME_2
					and STR_TYPE = STR_TYPE_2
					and DIR = DIR_2
					and EXT = EXT_2
					and APT_UNIT < APT_UNIT_2)
			then set1ptr + 1;    * advance in set1;
			else set2ptr + 1;    * advance in set2;

		end;
	end;

	MATCH_PASS = &pass.;
	keep ID: MATCH_PASS;
run;


proc sql noprint;
	select count(*) into :matchct
	from m1_&pass.;

%if &matchct ne 0 %then %match(&d1.,&d2.,&lib.,&step.,&pass.);
%else %nomatch(&d1.,&d2.,&lib.,&pass.);  * no matches found in above looping dataset;

%mend;



%macro address_match2(d1,d2,lib,step);

%let pass=2;

%mtchprep(&d1.,&d2.);

data m1_&pass.;
	retain set1ptr set2ptr;
	if _N_ = 1 then do;
		set set1 nobs=set1obs;
		set set2 nobs=set2obs;

		set1ptr=1;
		set2ptr=1;
	end;

	* makes sure not to advance past end of either dataset;
	if set1ptr <= set1obs and set2ptr <= set2obs then do;

		* get the requested observations from each dataset;
		set set1 point=set1ptr;
		set set2 point=set2ptr;

		if (BLK_KEY_OUT = BLK_KEY_OUT_2 
			and HOUSE_NUM = HOUSE_NUM_2 
			and HOUSE_SFX = HOUSE_SFX_2
			and STR_TYPFX = STR_TYPFX_2 
			and STR_NAME = STR_NAME_2
			and STR_TYPE = STR_TYPE_2
			and DIR = DIR_2
			and EXT = EXT_2 
			and APT_UNIT = APT_UNIT_2)
			then do;
	
				* match found;
				output;

				* advance obs in each dataset;
				set1ptr + 1;
				set2ptr + 1;
		end;
		else do;

			if (BLK_KEY_OUT < BLK_KEY_OUT_2)
				or (BLK_KEY_OUT = BLK_KEY_OUT_2 
					and HOUSE_NUM < HOUSE_NUM_2)
				or (BLK_KEY_OUT = BLK_KEY_OUT_2 
					and HOUSE_NUM = HOUSE_NUM_2
					and HOUSE_SFX < HOUSE_SFX_2)
				or (BLK_KEY_OUT = BLK_KEY_OUT_2 
					and HOUSE_NUM = HOUSE_NUM_2
					and HOUSE_SFX = HOUSE_SFX_2
					and DIR_PFX < DIR_PFX_2)
				or (BLK_KEY_OUT = BLK_KEY_OUT_2 
					and HOUSE_NUM = HOUSE_NUM_2
					and HOUSE_SFX = HOUSE_SFX_2
					and DIR_PFX = DIR_PFX_2
					and STR_TYPFX < STR_TYPFX_2)
				or (BLK_KEY_OUT = BLK_KEY_OUT_2 
					and HOUSE_NUM = HOUSE_NUM_2
					and HOUSE_SFX = HOUSE_SFX_2
					and DIR_PFX = DIR_PFX_2
					and STR_TYPFX = STR_TYPFX_2
					and STR_NAME < STR_NAME_2)
				or (BLK_KEY_OUT = BLK_KEY_OUT_2 
					and HOUSE_NUM = HOUSE_NUM_2
					and HOUSE_SFX = HOUSE_SFX_2
					and DIR_PFX = DIR_PFX_2
					and STR_TYPFX = STR_TYPFX_2
					and STR_NAME = STR_NAME_2
					and STR_TYPE < STR_TYPE_2)
				or (BLK_KEY_OUT = BLK_KEY_OUT_2 
					and HOUSE_NUM = HOUSE_NUM_2
					and HOUSE_SFX = HOUSE_SFX_2
					and DIR_PFX = DIR_PFX_2
					and STR_TYPFX = STR_TYPFX_2
					and STR_NAME = STR_NAME_2
					and STR_TYPE = STR_TYPE_2
					and DIR < DIR_2)
				or (BLK_KEY_OUT = BLK_KEY_OUT_2 
					and HOUSE_NUM = HOUSE_NUM_2
					and HOUSE_SFX = HOUSE_SFX_2
					and DIR_PFX = DIR_PFX_2
					and STR_TYPFX = STR_TYPFX_2
					and STR_NAME = STR_NAME_2
					and STR_TYPE = STR_TYPE_2
					and DIR = DIR_2
					and EXT < EXT_2)
				or (BLK_KEY_OUT = BLK_KEY_OUT_2 
					and HOUSE_NUM = HOUSE_NUM_2
					and HOUSE_SFX = HOUSE_SFX_2
					and DIR_PFX = DIR_PFX_2
					and STR_TYPFX = STR_TYPFX_2
					and STR_NAME = STR_NAME_2
					and STR_TYPE = STR_TYPE_2
					and DIR = DIR_2
					and EXT = EXT_2
					and APT_UNIT < APT_UNIT_2)
			then set1ptr + 1;    * advance in set1;
			else set2ptr + 1;    * advance in set2;

		end;
	end;

	MATCH_PASS = &pass.;
	keep ID: MATCH_PASS;
run;

proc sql noprint;
	select count(*) into :matchct
	from m1_&pass.;

%if &matchct ne 0 %then %match(&d1.,&d2.,&lib.,&step.,&pass.);
%else %nomatch(&d1.,&d2.,&lib.,&pass.);  * no matches found in above looping dataset;

%mend address_match2;




%macro address_match3(d1,d2,lib,step);

%let pass=3;

%mtchprep(&d1.,&d2.);

data m1_&pass.;
	retain set1ptr set2ptr;
	if _N_ = 1 then do;
		set set1 nobs=set1obs;
		set set2 nobs=set2obs;

		set1ptr=1;
		set2ptr=1;
	end;

	* makes sure not to advance past end of either dataset;
	if set1ptr <= set1obs and set2ptr <= set2obs then do;

		* get the requested observations from each dataset;
		set set1 point=set1ptr;
		set set2 point=set2ptr;

		if (BLK_KEY_OUT = BLK_KEY_OUT_2 
			and HOUSE_NUM = HOUSE_NUM_2 
			and HOUSE_SFX = HOUSE_SFX_2
			and STR_TYPFX = STR_TYPFX_2 
			and STR_NAME = STR_NAME_2
			and STR_TYPE = STR_TYPE_2
			and DIR = DIR_2
			and APT_UNIT = APT_UNIT_2)
			then do;
	
				* match found;
				output;

				* advance obs in each dataset;
				set1ptr + 1;
				set2ptr + 1;
		end;
		else do;

			if (BLK_KEY_OUT < BLK_KEY_OUT_2)
				or (BLK_KEY_OUT = BLK_KEY_OUT_2 
					and HOUSE_NUM < HOUSE_NUM_2)
				or (BLK_KEY_OUT = BLK_KEY_OUT_2 
					and HOUSE_NUM = HOUSE_NUM_2
					and HOUSE_SFX < HOUSE_SFX_2)
				or (BLK_KEY_OUT = BLK_KEY_OUT_2 
					and HOUSE_NUM = HOUSE_NUM_2
					and HOUSE_SFX = HOUSE_SFX_2
					and DIR_PFX < DIR_PFX_2)
				or (BLK_KEY_OUT = BLK_KEY_OUT_2 
					and HOUSE_NUM = HOUSE_NUM_2
					and HOUSE_SFX = HOUSE_SFX_2
					and DIR_PFX = DIR_PFX_2
					and STR_TYPFX < STR_TYPFX_2)
				or (BLK_KEY_OUT = BLK_KEY_OUT_2 
					and HOUSE_NUM = HOUSE_NUM_2
					and HOUSE_SFX = HOUSE_SFX_2
					and DIR_PFX = DIR_PFX_2
					and STR_TYPFX = STR_TYPFX_2
					and STR_NAME < STR_NAME_2)
				or (BLK_KEY_OUT = BLK_KEY_OUT_2 
					and HOUSE_NUM = HOUSE_NUM_2
					and HOUSE_SFX = HOUSE_SFX_2
					and DIR_PFX = DIR_PFX_2
					and STR_TYPFX = STR_TYPFX_2
					and STR_NAME = STR_NAME_2
					and STR_TYPE < STR_TYPE_2)
				or (BLK_KEY_OUT = BLK_KEY_OUT_2 
					and HOUSE_NUM = HOUSE_NUM_2
					and HOUSE_SFX = HOUSE_SFX_2
					and DIR_PFX = DIR_PFX_2
					and STR_TYPFX = STR_TYPFX_2
					and STR_NAME = STR_NAME_2
					and STR_TYPE = STR_TYPE_2
					and DIR < DIR_2)
				or (BLK_KEY_OUT = BLK_KEY_OUT_2 
					and HOUSE_NUM = HOUSE_NUM_2
					and HOUSE_SFX = HOUSE_SFX_2
					and DIR_PFX = DIR_PFX_2
					and STR_TYPFX = STR_TYPFX_2
					and STR_NAME = STR_NAME_2
					and STR_TYPE = STR_TYPE_2
					and DIR = DIR_2
					and EXT < EXT_2)
				or (BLK_KEY_OUT = BLK_KEY_OUT_2 
					and HOUSE_NUM = HOUSE_NUM_2
					and HOUSE_SFX = HOUSE_SFX_2
					and DIR_PFX = DIR_PFX_2
					and STR_TYPFX = STR_TYPFX_2
					and STR_NAME = STR_NAME_2
					and STR_TYPE = STR_TYPE_2
					and DIR = DIR_2
					and EXT = EXT_2
					and APT_UNIT < APT_UNIT_2)
			then set1ptr + 1;    * advance in set1;
			else set2ptr + 1;    * advance in set2;

		end;
	end;

	MATCH_PASS = &pass.;
	keep ID: MATCH_PASS;
run;

proc sql noprint;
	select count(*) into :matchct
	from m1_&pass.;

%if &matchct ne 0 %then %match(&d1.,&d2.,&lib.,&step.,&pass.);
%else %nomatch(&d1.,&d2.,&lib.,&pass.);  * no matches found in above looping dataset;

%mend address_match3;




%macro address_match4(d1,d2,lib,step);

%let pass=4;

%mtchprep(&d1.,&d2.);

data m1_&pass.;
	retain set1ptr set2ptr;
	if _N_ = 1 then do;
		set set1 nobs=set1obs;
		set set2 nobs=set2obs;

		set1ptr=1;
		set2ptr=1;
	end;

	* makes sure not to advance past end of either dataset;
	if set1ptr <= set1obs and set2ptr <= set2obs then do;

		* get the requested observations from each dataset;
		set set1 point=set1ptr;
		set set2 point=set2ptr;

		if (BLK_KEY_OUT = BLK_KEY_OUT_2 
			and HOUSE_NUM = HOUSE_NUM_2 
			and HOUSE_SFX = HOUSE_SFX_2
			and STR_TYPFX = STR_TYPFX_2 
			and STR_NAME = STR_NAME_2
			and STR_TYPE = STR_TYPE_2
			and APT_UNIT = APT_UNIT_2)
			then do;
	
				* match found;
				output;

				* advance obs in each dataset;
				set1ptr + 1;
				set2ptr + 1;
		end;
		else do;

			if (BLK_KEY_OUT < BLK_KEY_OUT_2)
				or (BLK_KEY_OUT = BLK_KEY_OUT_2 
					and HOUSE_NUM < HOUSE_NUM_2)
				or (BLK_KEY_OUT = BLK_KEY_OUT_2 
					and HOUSE_NUM = HOUSE_NUM_2
					and HOUSE_SFX < HOUSE_SFX_2)
				or (BLK_KEY_OUT = BLK_KEY_OUT_2 
					and HOUSE_NUM = HOUSE_NUM_2
					and HOUSE_SFX = HOUSE_SFX_2
					and DIR_PFX < DIR_PFX_2)
				or (BLK_KEY_OUT = BLK_KEY_OUT_2 
					and HOUSE_NUM = HOUSE_NUM_2
					and HOUSE_SFX = HOUSE_SFX_2
					and DIR_PFX = DIR_PFX_2
					and STR_TYPFX < STR_TYPFX_2)
				or (BLK_KEY_OUT = BLK_KEY_OUT_2 
					and HOUSE_NUM = HOUSE_NUM_2
					and HOUSE_SFX = HOUSE_SFX_2
					and DIR_PFX = DIR_PFX_2
					and STR_TYPFX = STR_TYPFX_2
					and STR_NAME < STR_NAME_2)
				or (BLK_KEY_OUT = BLK_KEY_OUT_2 
					and HOUSE_NUM = HOUSE_NUM_2
					and HOUSE_SFX = HOUSE_SFX_2
					and DIR_PFX = DIR_PFX_2
					and STR_TYPFX = STR_TYPFX_2
					and STR_NAME = STR_NAME_2
					and STR_TYPE < STR_TYPE_2)
				or (BLK_KEY_OUT = BLK_KEY_OUT_2 
					and HOUSE_NUM = HOUSE_NUM_2
					and HOUSE_SFX = HOUSE_SFX_2
					and DIR_PFX = DIR_PFX_2
					and STR_TYPFX = STR_TYPFX_2
					and STR_NAME = STR_NAME_2
					and STR_TYPE = STR_TYPE_2
					and DIR < DIR_2)
				or (BLK_KEY_OUT = BLK_KEY_OUT_2 
					and HOUSE_NUM = HOUSE_NUM_2
					and HOUSE_SFX = HOUSE_SFX_2
					and DIR_PFX = DIR_PFX_2
					and STR_TYPFX = STR_TYPFX_2
					and STR_NAME = STR_NAME_2
					and STR_TYPE = STR_TYPE_2
					and DIR = DIR_2
					and EXT < EXT_2)
				or (BLK_KEY_OUT = BLK_KEY_OUT_2 
					and HOUSE_NUM = HOUSE_NUM_2
					and HOUSE_SFX = HOUSE_SFX_2
					and DIR_PFX = DIR_PFX_2
					and STR_TYPFX = STR_TYPFX_2
					and STR_NAME = STR_NAME_2
					and STR_TYPE = STR_TYPE_2
					and DIR = DIR_2
					and EXT = EXT_2
					and APT_UNIT < APT_UNIT_2)
			then set1ptr + 1;    * advance in set1;
			else set2ptr + 1;    * advance in set2;

		end;
	end;

	MATCH_PASS = &pass.;
	keep ID: MATCH_PASS;
run;

proc sql noprint;
	select count(*) into :matchct
	from m1_&pass.;

%if &matchct ne 0 %then %match(&d1.,&d2.,&lib.,&step.,&pass.);
%else %nomatch(&d1.,&d2.,&lib.,&pass.);  * no matches found in above looping dataset;

%mend address_match4;





%macro address_match5(d1,d2,lib,step);

%let pass=5;

%mtchprep(&d1.,&d2.);

data m1_&pass.;
	retain set1ptr set2ptr;
	if _N_ = 1 then do;
		set set1 nobs=set1obs;
		set set2 nobs=set2obs;

		set1ptr=1;
		set2ptr=1;
	end;

	* makes sure not to advance past end of either dataset;
	if set1ptr <= set1obs and set2ptr <= set2obs then do;

		* get the requested observations from each dataset;
		set set1 point=set1ptr;
		set set2 point=set2ptr;

		if (BLK_KEY_OUT = BLK_KEY_OUT_2 
			and HOUSE_NUM = HOUSE_NUM_2 
			and STR_TYPFX = STR_TYPFX_2 
			and STR_NAME = STR_NAME_2
			and STR_TYPE = STR_TYPE_2
			and APT_UNIT = APT_UNIT_2)
			then do;
	
				* match found;
				output;

				* advance obs in each dataset;
				set1ptr + 1;
				set2ptr + 1;
		end;
		else do;

			if (BLK_KEY_OUT < BLK_KEY_OUT_2)
				or (BLK_KEY_OUT = BLK_KEY_OUT_2 
					and HOUSE_NUM < HOUSE_NUM_2)
				or (BLK_KEY_OUT = BLK_KEY_OUT_2 
					and HOUSE_NUM = HOUSE_NUM_2
					and HOUSE_SFX < HOUSE_SFX_2)
				or (BLK_KEY_OUT = BLK_KEY_OUT_2 
					and HOUSE_NUM = HOUSE_NUM_2
					and HOUSE_SFX = HOUSE_SFX_2
					and DIR_PFX < DIR_PFX_2)
				or (BLK_KEY_OUT = BLK_KEY_OUT_2 
					and HOUSE_NUM = HOUSE_NUM_2
					and HOUSE_SFX = HOUSE_SFX_2
					and DIR_PFX = DIR_PFX_2
					and STR_TYPFX < STR_TYPFX_2)
				or (BLK_KEY_OUT = BLK_KEY_OUT_2 
					and HOUSE_NUM = HOUSE_NUM_2
					and HOUSE_SFX = HOUSE_SFX_2
					and DIR_PFX = DIR_PFX_2
					and STR_TYPFX = STR_TYPFX_2
					and STR_NAME < STR_NAME_2)
				or (BLK_KEY_OUT = BLK_KEY_OUT_2 
					and HOUSE_NUM = HOUSE_NUM_2
					and HOUSE_SFX = HOUSE_SFX_2
					and DIR_PFX = DIR_PFX_2
					and STR_TYPFX = STR_TYPFX_2
					and STR_NAME = STR_NAME_2
					and STR_TYPE < STR_TYPE_2)
				or (BLK_KEY_OUT = BLK_KEY_OUT_2 
					and HOUSE_NUM = HOUSE_NUM_2
					and HOUSE_SFX = HOUSE_SFX_2
					and DIR_PFX = DIR_PFX_2
					and STR_TYPFX = STR_TYPFX_2
					and STR_NAME = STR_NAME_2
					and STR_TYPE = STR_TYPE_2
					and DIR < DIR_2)
				or (BLK_KEY_OUT = BLK_KEY_OUT_2 
					and HOUSE_NUM = HOUSE_NUM_2
					and HOUSE_SFX = HOUSE_SFX_2
					and DIR_PFX = DIR_PFX_2
					and STR_TYPFX = STR_TYPFX_2
					and STR_NAME = STR_NAME_2
					and STR_TYPE = STR_TYPE_2
					and DIR = DIR_2
					and EXT < EXT_2)
				or (BLK_KEY_OUT = BLK_KEY_OUT_2 
					and HOUSE_NUM = HOUSE_NUM_2
					and HOUSE_SFX = HOUSE_SFX_2
					and DIR_PFX = DIR_PFX_2
					and STR_TYPFX = STR_TYPFX_2
					and STR_NAME = STR_NAME_2
					and STR_TYPE = STR_TYPE_2
					and DIR = DIR_2
					and EXT = EXT_2
					and APT_UNIT < APT_UNIT_2)
			then set1ptr + 1;    * advance in set1;
			else set2ptr + 1;    * advance in set2;

		end;
	end;

	MATCH_PASS = &pass.;
	keep ID: MATCH_PASS;
run;

proc sql noprint;
	select count(*) into :matchct
	from m1_&pass.;

%if &matchct ne 0 %then %match(&d1.,&d2.,&lib.,&step.,&pass.);
%else %nomatch(&d1.,&d2.,&lib.,&pass.);  * no matches found in above looping dataset;

%mend address_match5;






%macro address_match6(d1,d2,lib,step);

%let pass=6;

%mtchprep(&d1.,&d2.);

data m1_&pass.;
	retain set1ptr set2ptr;
	if _N_ = 1 then do;
		set set1 nobs=set1obs;
		set set2 nobs=set2obs;

		set1ptr=1;
		set2ptr=1;
	end;

	* makes sure not to advance past end of either dataset;
	if set1ptr <= set1obs and set2ptr <= set2obs then do;

		* get the requested observations from each dataset;
		set set1 point=set1ptr;
		set set2 point=set2ptr;

		if (BLK_KEY_OUT = BLK_KEY_OUT_2 
			and HOUSE_NUM = HOUSE_NUM_2  
			and STR_NAME = STR_NAME_2
			and STR_TYPE = STR_TYPE_2
			and APT_UNIT = APT_UNIT_2)
			then do;
	
				* match found;
				output;

				* advance obs in each dataset;
				set1ptr + 1;
				set2ptr + 1;
		end;
		else do;

			if (BLK_KEY_OUT < BLK_KEY_OUT_2)
				or (BLK_KEY_OUT = BLK_KEY_OUT_2 
					and HOUSE_NUM < HOUSE_NUM_2)
				or (BLK_KEY_OUT = BLK_KEY_OUT_2 
					and HOUSE_NUM = HOUSE_NUM_2
					and HOUSE_SFX < HOUSE_SFX_2)
				or (BLK_KEY_OUT = BLK_KEY_OUT_2 
					and HOUSE_NUM = HOUSE_NUM_2
					and HOUSE_SFX = HOUSE_SFX_2
					and DIR_PFX < DIR_PFX_2)
				or (BLK_KEY_OUT = BLK_KEY_OUT_2 
					and HOUSE_NUM = HOUSE_NUM_2
					and HOUSE_SFX = HOUSE_SFX_2
					and DIR_PFX = DIR_PFX_2
					and STR_TYPFX < STR_TYPFX_2)
				or (BLK_KEY_OUT = BLK_KEY_OUT_2 
					and HOUSE_NUM = HOUSE_NUM_2
					and HOUSE_SFX = HOUSE_SFX_2
					and DIR_PFX = DIR_PFX_2
					and STR_TYPFX = STR_TYPFX_2
					and STR_NAME < STR_NAME_2)
				or (BLK_KEY_OUT = BLK_KEY_OUT_2 
					and HOUSE_NUM = HOUSE_NUM_2
					and HOUSE_SFX = HOUSE_SFX_2
					and DIR_PFX = DIR_PFX_2
					and STR_TYPFX = STR_TYPFX_2
					and STR_NAME = STR_NAME_2
					and STR_TYPE < STR_TYPE_2)
				or (BLK_KEY_OUT = BLK_KEY_OUT_2 
					and HOUSE_NUM = HOUSE_NUM_2
					and HOUSE_SFX = HOUSE_SFX_2
					and DIR_PFX = DIR_PFX_2
					and STR_TYPFX = STR_TYPFX_2
					and STR_NAME = STR_NAME_2
					and STR_TYPE = STR_TYPE_2
					and DIR < DIR_2)
				or (BLK_KEY_OUT = BLK_KEY_OUT_2 
					and HOUSE_NUM = HOUSE_NUM_2
					and HOUSE_SFX = HOUSE_SFX_2
					and DIR_PFX = DIR_PFX_2
					and STR_TYPFX = STR_TYPFX_2
					and STR_NAME = STR_NAME_2
					and STR_TYPE = STR_TYPE_2
					and DIR = DIR_2
					and EXT < EXT_2)
				or (BLK_KEY_OUT = BLK_KEY_OUT_2 
					and HOUSE_NUM = HOUSE_NUM_2
					and HOUSE_SFX = HOUSE_SFX_2
					and DIR_PFX = DIR_PFX_2
					and STR_TYPFX = STR_TYPFX_2
					and STR_NAME = STR_NAME_2
					and STR_TYPE = STR_TYPE_2
					and DIR = DIR_2
					and EXT = EXT_2
					and APT_UNIT < APT_UNIT_2)
			then set1ptr + 1;    * advance in set1;
			else set2ptr + 1;    * advance in set2;
		end;
	end;

	MATCH_PASS = &pass.;
	keep ID: MATCH_PASS;
run;

proc sql noprint;
	select count(*) into :matchct
	from m1_&pass.;

%if &matchct ne 0 %then %match(&d1.,&d2.,&lib.,&step.,&pass.);
%else %nomatch(&d1.,&d2.,&lib.,&pass.);  * no matches found in above looping dataset;

%mend address_match6;







%macro address_match7(d1,d2,lib,step);

%let pass=7;

%mtchprep(&d1.,&d2.);

data m1_&pass.;
	retain set1ptr set2ptr;
	if _N_ = 1 then do;
		set set1 nobs=set1obs;
		set set2 nobs=set2obs;

		set1ptr=1;
		set2ptr=1;
	end;

	* makes sure not to advance past end of either dataset;
	if set1ptr <= set1obs and set2ptr <= set2obs then do;

		* get the requested observations from each dataset;
		set set1 point=set1ptr;
		set set2 point=set2ptr;

		if (BLK_KEY_OUT = BLK_KEY_OUT_2 
			and HOUSE_NUM = HOUSE_NUM_2  
			and STR_NAME = STR_NAME_2
			and APT_UNIT = APT_UNIT_2)
			then do;
	
				* match found;
				output;

				* advance obs in each dataset;
				set1ptr + 1;
				set2ptr + 1;
		end;
		else do;

			if (BLK_KEY_OUT < BLK_KEY_OUT_2)
				or (BLK_KEY_OUT = BLK_KEY_OUT_2 
					and HOUSE_NUM < HOUSE_NUM_2)
				or (BLK_KEY_OUT = BLK_KEY_OUT_2 
					and HOUSE_NUM = HOUSE_NUM_2
					and HOUSE_SFX < HOUSE_SFX_2)
				or (BLK_KEY_OUT = BLK_KEY_OUT_2 
					and HOUSE_NUM = HOUSE_NUM_2
					and HOUSE_SFX = HOUSE_SFX_2
					and DIR_PFX < DIR_PFX_2)
				or (BLK_KEY_OUT = BLK_KEY_OUT_2 
					and HOUSE_NUM = HOUSE_NUM_2
					and HOUSE_SFX = HOUSE_SFX_2
					and DIR_PFX = DIR_PFX_2
					and STR_TYPFX < STR_TYPFX_2)
				or (BLK_KEY_OUT = BLK_KEY_OUT_2 
					and HOUSE_NUM = HOUSE_NUM_2
					and HOUSE_SFX = HOUSE_SFX_2
					and DIR_PFX = DIR_PFX_2
					and STR_TYPFX = STR_TYPFX_2
					and STR_NAME < STR_NAME_2)
				or (BLK_KEY_OUT = BLK_KEY_OUT_2 
					and HOUSE_NUM = HOUSE_NUM_2
					and HOUSE_SFX = HOUSE_SFX_2
					and DIR_PFX = DIR_PFX_2
					and STR_TYPFX = STR_TYPFX_2
					and STR_NAME = STR_NAME_2
					and STR_TYPE < STR_TYPE_2)
				or (BLK_KEY_OUT = BLK_KEY_OUT_2 
					and HOUSE_NUM = HOUSE_NUM_2
					and HOUSE_SFX = HOUSE_SFX_2
					and DIR_PFX = DIR_PFX_2
					and STR_TYPFX = STR_TYPFX_2
					and STR_NAME = STR_NAME_2
					and STR_TYPE = STR_TYPE_2
					and DIR < DIR_2)
				or (BLK_KEY_OUT = BLK_KEY_OUT_2 
					and HOUSE_NUM = HOUSE_NUM_2
					and HOUSE_SFX = HOUSE_SFX_2
					and DIR_PFX = DIR_PFX_2
					and STR_TYPFX = STR_TYPFX_2
					and STR_NAME = STR_NAME_2
					and STR_TYPE = STR_TYPE_2
					and DIR = DIR_2
					and EXT < EXT_2)
				or (BLK_KEY_OUT = BLK_KEY_OUT_2 
					and HOUSE_NUM = HOUSE_NUM_2
					and HOUSE_SFX = HOUSE_SFX_2
					and DIR_PFX = DIR_PFX_2
					and STR_TYPFX = STR_TYPFX_2
					and STR_NAME = STR_NAME_2
					and STR_TYPE = STR_TYPE_2
					and DIR = DIR_2
					and EXT = EXT_2
					and APT_UNIT < APT_UNIT_2)
			then set1ptr + 1;    * advance in set1;
			else set2ptr + 1;    * advance in set2;
		end;
	end;

	MATCH_PASS = &pass.;
	keep ID: MATCH_PASS;
run;

proc sql noprint;
	select count(*) into :matchct
	from m1_&pass.;

%if &matchct ne 0 %then %match(&d1.,&d2.,&lib.,&step.,&pass.);
%else %nomatch(&d1.,&d2.,&lib.,&pass.);  * no matches found in above looping dataset;

%mend address_match7;


%macro man_match(d1,d2,lib,pass);

proc import datafile='M:\DATA\MAGE\matching\manual matches found.xls'
	out=man_matches0
	dbms=excel
	replace;
run;

data man_matches;
	set man_matches0;
	
	MATCH_ID = &pass.*100000+_N_;

	MATCH_PASS=&pass.;
run;

* make sure these lines are still unmatched;

proc sort data=man_matches; by ID1; run;
proc sort data=&d1.; by ID; run;
data mm1;
	merge man_matches(in=INM) &d1.(keep=ID rename=(ID=ID1) in=IND);
	by ID1;

	if INM and IND;
run;

proc sort data=man_matches; by ID2; run;
proc sort data=&d2.; by ID; run;
data mm2;
	merge man_matches(in=INM) &d2.(keep=ID rename=(ID=ID2) in=IND);
	by ID2;

	if INM and IND;
run;

* reduce to only those matches that involve two unmatched lines;
proc sql;
	create table  m1_&pass. as
	select mm1.ID1, mm1.ID2
	from mm1
	inner join mm2
	on mm1.MATCH_ID = mm2.MATCH_ID;

%match(&d1.,&d2.,&lib.,&step.,&pass.);

%mend;



%macro find_matched(d1,d2,lib,step,pass);
* identify matched lines from given pass;
* d1 and d2 are the datasets that were INPUTS into the round of mtachign given by pass;

proc sql;
	create table &lib..match_compare&step._&pass. as
	select m.MATCH_ID, m._LABEL_, m.MATCH_PASS, d1.*
	from m4_&pass. as m
	inner join all_inputs as d1
	on m.ID=d1.ID
		and m.DSET=d1.DSET
	order by MATCH_ID, DSET;
	
	create table &lib..matches&step._&pass. as
	select m.*, d1.BLK_KEY_OUT,
		d1.ORDER, compbl(d1.HOUSE_NUM || d1.DIR_PFX || d1.STR_NAME || d1.STR_TYPE || d1.DIR || d1.APT_UNIT) as ADDRESS, 
		d2.ORDER as ORDER_2, 
		compbl(d2.HOUSE_NUM_2 || d2.DIR_PFX_2 || d2.STR_NAME_2 || d2.STR_TYPE_2 || d2.DIR_2 || d2.APT_UNIT_2) as ADDRESS_2
	from &lib..address_match&step._&pass. as m
	left outer join &d1. as d1
	on m.ID1=d1.ID1
	left outer join &d2. as d2
	on m.ID2=d2.ID2
	order by BLK_KEY_OUT, ADDRESS, ADDRESS_2;
%mend;


%macro find_unmatched(d1,d2,lib,pass);
* identify unmatched lines for another pass;
* d1 and d2 are the datasets that were INPUTS into the round of mtachign given by pass;

proc sql;
	create table d1_unmatched&pass. as
	select *
	from &d1. 
	where ID not in (select ID from m4_&pass. where DSET=1)
	order by BLK_KEY_OUT;

	create table d2_unmatched&pass. as
	select *
	from &d2. 
	where ID not in (select ID from m4_&pass. where DSET=2)
	order by BLK_KEY_OUT;

%mend find_unmatched;


%macro match(d1,d2,lib,step,pass);
* get matches in better format;
data &lib..address_match&step._&pass.;
	set m1_&pass.;

	format MATCH_ID 8.;

	MATCH_PASS = &pass.;

	MATCH_ID = &pass.*100000 + _N_;
run;

proc transpose data=&lib..address_match&step._&pass.(drop=MATCH_PASS) out=m3_&pass.;
	var ID1 ID2;
	by MATCH_ID;
run;

data m4_&pass.(drop=_NAME_);
	set m3_&pass.;

	if _NAME_='ID1' then DSET=1;
	else DSET=2;

	rename COL1=ID;

	MATCH_PASS=&pass.;
run;


data all_inputs;
	set &d1.(in=IN1) &d2.;

	if IN1 then DSET=1; else DSET=2;
run;

%find_matched(set1, set2,&lib.,&step.,&pass.);
%find_unmatched(&d1.,&d2.,&lib.,&pass.);
%mend;

%macro nomatch(d1,d2,lib,pass);
data d1_unmatched&pass.;
	set &d1.;
run;

data d2_unmatched&pass.;
	set &d2.;
run;
%mend;




* address parser.sas;
* parse address collected by ISR listing software (which does not include street number)
	into pre direction, street name, suffix and post-direction
	to match to Experian data;

%let st_types = "RD" "DR" "CT" "BLVD" "AVE" "AV" "AVENUE" "ST" "LN" "CIR" "PARK" "BROOK" "CUTOFF"
	"PL" "WAY" "TER" "PKWY" "BND" "HWY" "LOOP" "TR" "CR" "ALY" "WALK" "VLG" "TRL" "CIRCLE"
	"COURT" "BLVE" "LANE" "RIDGE" "VIEW" "SPRING" "ROAD" "DRIVE" "STREET" "PLACE" "GRN" 
	"TERR" "APTS" "TERRACE" "BEND TERR" "PKY" "TPK" "PIKE" "FERRY PIKE" "ST PIKE" "CRK";
%let st_dirs = "SE" "NE" "NW" "SW" "SOUTH" "NORTH" "WEST" "EAST" "E" "W" "N" "S" "NO"
	"SOU" "NOR" "SO";


* assumes street number already taken off the front of the address ths is how ISR lists);

%macro addr_parse(address);

	* divide address by spaces;
	format PARSED_STREET_NAME $30.;

	* set up arrary to hold address pieces;
	array address_parts{10} $20;


	******** clean up address field;

	* remove HTML spaces;
	%badspc(&address.);

	* removes multiple blanks b/w words
		and any periods;
	ADDRESS2 = compress(trim(upcase(compbl(&address.))),'.');   


	* split address on spaces and put into array;
	* find highest numbered part;
	max_parts = 0;
	do i = 1 to 10;
		address_parts{i} = scan(ADDRESS2, i, ' ');
		if address_parts(i) = "" and max_parts = 0 then max_parts = i-1;
	end;


	* keep track of how many parts of address used;
	parts_used=0;



	***************************************;
	* start at beginning of address, and look for predirection, if any;

	if address_parts(parts_used + 1) in (&st_dirs.) then do;
		parts_used + 1;
		PARSED_STREET_PRE_DIR = address_parts(parts_used);
	end;



	***************************************;
	* then go to back and look for street type or street type + postdirection;

	* suffix is probably last part of street name;
	parts_used_end = 0;
	last_part = address_parts(max_parts);
	if last_part in (&st_types.) then do;
		PARSED_STREET_SUFFIX = last_part;
		parts_used_end = 1;
	end;

	* check if there is a postdiretion at the end instead;
	else if last_part in (&st_dirs.) then do;
		PARSED_STREET_POST_DIR = last_part;
		parts_used_end = 1;

		* here check for postdirection preceded by street type;
		if max_parts-parts_used_end > 1 then do;
			last_part = address_parts(max_parts-parts_used_end);
			if last_part in (&st_types.) then do;
				PARSED_STREET_SUFFIX = last_part;
				parts_used_end = 2;
			end;
		end;
	end;
		


	***************************************;
	* everything else is then the street name;
	* all parts b/w DIRECTION and STREET_TYPE;
	if (parts_used + 1) <= (max_parts - parts_used_end) then do;
		do i = (parts_used + 1) to (max_parts - parts_used_end);
			PARSED_STREET_NAME = compbl(PARSED_STREET_NAME || address_parts(i));
		end;
	end;



	***************************************;
	* some manual clean up

	* "E St" ends up as PARSED_STREET_PRE_DIR and STREET_TYPE but no street;
	if PARSED_STREET_NAME = "" and PARSED_STREET_PRE_DIR ne "" then do;
		PARSED_STREET_NAME = PARSED_STREET_PRE_DIR;
		PARSED_STREET_PRE_DIR = "";
	end;
	
	* "200 West" ends up as PARSED_STREET_POST_DIR but no street;
	if PARSED_STREET_NAME = "" and PARSED_STREET_POST_DIR ne "" then do;
		PARSED_STREET_NAME = PARSED_STREET_POST_DIR;
		PARSED_STREET_PRE_DIR = "";
	end;

	* remove leading blank from PARSED_STREET_NAME;
	if substr(PARSED_STREET_NAME,1,1)=' ' then 
		PARSED_STREET_NAME = substr(PARSED_STREET_NAME,2,length(PARSED_STREET_NAME)-1);


	drop ADDRESS2 i max_parts parts_used parts_used_end
		address_parts1 address_parts2 address_parts3 address_parts4 address_parts5
		address_parts6 address_parts7 address_parts8 address_parts9 address_parts10
		last_part
	;
%mend;

%macro badspc(word);
	* field contains some HMTL spaces (ASCII code 160), need to replace so parser works;
	do l = 1 to length(&word.);
		if rank(substr(&word.,l,1))=160 then substr(&word.,l,1) = ' ';
	end;

	&word. = trim(&word.);

	drop l;
%mend;


%macro iddupe(dset, id, noprint);
proc sql;
	create table dupes as
	select &id., count(*) as CT
	from &dset.
	group by &id.
	having count(*)>1;

%if &noprint ne 1 %then %do;
proc print data=dupes noobs;
	title "PROBLEM: duplicates found in ID var &id. in &dset.";
	format &id. 12.;  * suppress scientific notation;
run;
%end;
%mend;




%macro pairmtch(dset,m,n);
* match pairs of lines
	exact matches on NSFG_PSU, SEG, STR_NUMBER, ADDRESS_UNPARSED, APT;

* dset is dataset of all previously unmatched lines;
* m is number of first listing in the pair;
* n is number of second listing in the pair;

* macro creates un&m.&n., dataset of all lines unmatched after this step
	ready for another round of matching;

proc sort data=&dset.; by NSFG_PSU SEG STR_NUMBER STR_PREDIR STR_NAME STR_TYPE STR_POSTDIR APT; run;

data pairm_&m.&n.(keep=ID_&m. ID_&n.);
	set &dset(where=(LISTING in (&m.,&n.)));
	by NSFG_PSU SEG STR_NUMBER STR_PREDIR STR_NAME STR_TYPE STR_POSTDIR APT; 
	
	retain GRP_CT ID_&m. LISTSUM;

	if first.APT then do;
		GRP_CT=1;
		ID_&m. = ID_LISTING;
		LISTSUM = LISTING;
	end;
	else do;
		GRP_CT = GRP_CT+1;
		LISTSUM = LISTSUM + LISTING;
		* this cluster of PSU SEG ADDR APT has three and only three members
			must be a match triple;
		ID_&n. = ID_LISTING;

		* make sure that ths triple has 1 and only 1 member from each listing;
		if LISTSUM = %eval(&m.+&n.) and GRP_CT = 2 then output;
	end;
run;

proc sql noprint;
	create table un&m.&n. as
	select d.*
	from &dset. as d
	where ID_LISTING not in (select ID_&m. from pairm_&m.&n.)
		and ID_LISTING not in (select ID_&n. from pairm_&m.&n.);
%mend;



* un23 is then dataset with all unmatched lines so far;
* match pairs with singles from other datasets:
	12 with 3, 13 with 2 and 23 with 1
* using match macros and parsed addresses;



%macro m2to3(m,n,unm, step);
* match exact-match pairs to unmatched lines in 3rd listing
	make matched triples from matched pairs;

* m is first member of matched pair
* n is second member of matched pair
* unm is current datasetof unmatched lines
* step is MATCH_STEP to assign to these matches;

* find number of third listing;
%let p = %eval(6 - &m. - &n.);


* get address from each pair;
proc sql;
	create table match&m.&n. as
	select l.*
	from anal.listings as l
	inner join match.pair_matches m
	/* only need to grab address for one member of pair
		because these pairs are perfect matches on ADDRESS_UNPARSED */
	on l.ID_LISTING = m.ID_&m.;


data d1;
	set match&m.&n.(keep = NSFG_PSU SEG ID_LISTING ADDRESS_UNPARSED
			STR_NUMBER STR_PREDIR STR_POSTDIR APT STR_NAME STR_TYPE ORDER);

	* this is the blocking variable--matches can only be found within the same segment;
	BLK_KEY_OUT = trim(compress(NSFG_PSU || SEG));

	* rather than modifying macros, create empty varibles (will always match between two datasets);
	HOUSE_SFX = '';
	STR_TYPFX = '';
	EXT = '';
	MAF_ID = '';
	VALID = 1;

	rename ID_LISTING = ID
		STR_NUMBER = HOUSE_NUM 
		STR_PREDIR = DIR_PFX 
		STR_POSTDIR = DIR 
		APT = APT_UNIT 
	;
run;

* lines in L3 input only;
data d2;
	set &unm.(where=(LISTING = &p.)
		keep = LISTING NSFG_PSU SEG ID_LISTING ADDRESS_UNPARSED
			STR_NUMBER STR_PREDIR STR_POSTDIR APT STR_NAME STR_TYPE ORDER);

	* this is the blocking variable--matches can only be found within the same segment;
	BLK_KEY_OUT = trim(compress(NSFG_PSU || SEG));

	* rather than modifying macros, create empty varibles (will always match between two datasets);
	HOUSE_SFX = '';
	STR_TYPFX = '';
	EXT = '';
	MAF_ID = '';
	VALID = 1;

	rename ID_LISTING = ID
		STR_NUMBER = HOUSE_NUM 
		STR_PREDIR = DIR_PFX 
		STR_POSTDIR = DIR 
		APT = APT_UNIT 
		STR_NAME = STR_NAME 
		STR_TYPE = STR_TYPE
	;

	drop LISTING;
run;



%address_match1(d1,d2,match, &step.);
%address_match2(d1_unmatched1,d2_unmatched1,match, &step.);
%address_match3(d1_unmatched2,d2_unmatched2,match, &step.);
%address_match4(d1_unmatched3,d2_unmatched3,match, &step.);
%address_match5(d1_unmatched4,d2_unmatched4,match, &step.);
%address_match6(d1_unmatched5,d2_unmatched5,match, &step.);
%address_match7(d1_unmatched6,d2_unmatched6,match, &step.);

data v;
	set %do i = 1 %to 7;
		m1_&i.(in=IN&i.)
		%end;
	;

	MATCH_STEP = &step.;
	
	%do i = 1 %to 7;
		if IN&i. then MATCH_SUBSTEP = &i.;
	%end;

	drop MATCH_PASS;

	rename ID1 = ID_&m.
		ID2 = ID_&p.;
run;

proc sort data=match.pair_matches; by ID_&m.; run;
proc sort data=v; by ID_&m.; run;
data triple&m.&n.;
	merge match.pair_matches v;
	by ID_&m.;

	if ID_1 ne . and ID_2 ne . and ID_3 ne .;
run;

proc sql;
	create table un_step&step. as
	select *
	from &unm.
	where ID_LISTING not in (select ID_&p. from triple&m.&n.);

%mend;


%macro typefix(s);
* standardize street types
	run after parsing;
* will improve matching routines;
&s. = upcase(trim(left(tranwrd(&s., "DRIVE", "DR"))));
&s. = upcase(trim(left(tranwrd(&s., "PLACE", "PL"))));
&s. = upcase(trim(left(tranwrd(&s., "ROAD", "RD"))));
&s. = upcase(trim(left(tranwrd(&s., "STREET", "ST"))));
&s. = upcase(trim(left(tranwrd(&s., "AVENUE", "AVE"))));
&s. = upcase(trim(left(tranwrd(&s., "TERRACE", "TER"))));
&s. = upcase(trim(left(tranwrd(&s., "TERR", "TER"))));
&s. = upcase(trim(left(tranwrd(&s., "CREEK", "CRK"))));
&s. = upcase(trim(left(tranwrd(&s., "CIRCLE", "CR"))));
&s. = upcase(trim(left(tranwrd(&s., "CIR", "CR"))));
&s. = upcase(trim(left(tranwrd(&s., "LANE", "LN"))));
&s. = upcase(trim(left(tranwrd(&s., "TRAIL", "TRL"))));
&s. = upcase(trim(left(tranwrd(&s., "GREEN", "GRN"))));
&s. = upcase(trim(left(tranwrd(&s., "LOOP", "LP"))));
&s. = upcase(trim(left(tranwrd(&s., "COURT", "CT"))));
%mend;


%macro dirfix(s);
* standardize directions (both pre and post directions)
	run after parsing;
* will improve matching routines;
&s. = upcase(trim(left(tranwrd(&s., "SOUTH", "S"))));
&s. = upcase(trim(left(tranwrd(&s., "WEST", "W"))));
&s. = upcase(trim(left(tranwrd(&s., "EAST", "E"))));
&s. = upcase(trim(left(tranwrd(&s., "NORTH", "N"))));
&s. = upcase(trim(left(tranwrd(&s., "NO", "N"))));
&s. = upcase(trim(left(tranwrd(&s., "SO", "S"))));
%mend;


%macro aptclean(oldvar, newvar);
* apt numbers hneed cleaning in a few different datasets, standardize;

* oldvar is name of dirty apt variable
* newvar is name of clean apt variable;

%badspc(&oldvar.);

TEMPAPT = trim(left(&oldvar.));

LEN_APT = length(TEMPAPT);

* take 'LOT', 'APT' and 'UNIT' off the front of the apartment number field;
if LEN_APT > 4 and upcase(substr(TEMPAPT,1,4)) = 'APT.' then &newvar. = upcase(trim(substr(TEMPAPT,5,LEN_APT-4)));

else if LEN_APT > 3 then do; 
	if upcase(substr(TEMPAPT,1,3)) = 'APT' then &newvar. = upcase(compress(trim(substr(TEMPAPT,4,LEN_APT-3)),'.'));
	else if upcase(substr(TEMPAPT,1,3)) = 'LOT' then &newvar. = upcase(compress(trim(substr(TEMPAPT,4,LEN_APT-3)),'.'));
	else if LEN_APT > 4 and upcase(substr(TEMPAPT,1,4)) = 'UNIT' then &newvar. = upcase(compress(trim(substr(TEMPAPT,5,LEN_APT-4)),'.'));
	else &newvar. = upcase(compress(TEMPAPT,'.'));
end;

else &newvar. = upcase(compress(trim(left(TEMPAPT)),'.'));

* add word back if entire &oldvar. value is '&newvar.';
if upcase(compress(trim(&oldvar.),'.')) = 'APT' then &newvar. = 'APT';

&newvar. = trim(left(&newvar.));

drop LEN_APT TEMPAPT;
%mend;





%macro confbias(v,ftd);
* calculates FTA ratio and ADD_LIST_RATE by given variable;

* v is 1 varible to calculated confirmation bias by;
* ftd controls whether FTD results shoudl be calculated 
	(for results by DISP, I dont want these, b/c no added cases have disps);


* first FTA;
proc summary data=l_supp mean;
	by SUPPRESS;
	class &v. /missing;
	where LISTING=3
		and ADD ne 1
		and SUPPRESS ne .;
	var LISTED; 
	output out=ftarates mean()=LIST_RATE;
run;

proc sort data=ftarates; by &v. SUPPRESS; run;

data ftarates2;
	set ftarates(where=(_TYPE_=1));
	by &v. SUPPRESS;

	retain NONSUPP_LIST_RATE;

	if first.&v. then do;
		NONSUPP_LIST_RATE = LIST_RATE;
	end;

	if last.&v. then do;
		SUPP_LIST_RATE = LIST_RATE;
		if NONSUPP_LIST_RATE ne 0 then FTA_RATIO = SUPP_LIST_RATE/NONSUPP_LIST_RATE;
		else SUPP_LIST_RATE = 999;
		SUPPRESS_CT = _FREQ_;
		output;
	end;

	drop LIST_RATE _: SUPPRESS;
run;

* now FTD;
%if &ftd = 1 %then %do;
	proc summary data=l_add mean;
		by ADD;
		class &v.;
		where LISTING=3
			and SUPPRESS ne 1
			and ADD ne .;
		var LISTED; 
		output out=ftdrates mean()=LIST_RATE;
	run;

	proc sort data=ftdrates; by &v. ADD; run;

	data ftdrates2;
		set ftdrates(where=(_TYPE_=1));
		by &v. ADD;

		retain NONADD_LIST_RATE;

		if first.&v. then do;
			NONADD_LIST_RATE = LIST_RATE;
		end;

		if last.&v. then do;
			ADD_LIST_RATE = LIST_RATE;
			if ADD_LIST_RATE ne 0 then FTD_RATIO = NONADD_LIST_RATE/ADD_LIST_RATE;
			ADD_CT = _FREQ_;
			output;
		end;

		drop LIST_RATE _: ADD;
	run;

	proc sql;
		create table anal.confbias_&v. as
		select a.*, ADD_LIST_RATE format=percent8.1, ADD_CT 
		from ftarates2 as a
		left outer join ftdrates2 as d
		on a.&v. = d.&v.
		order by a.&v.;

	proc print data=anal.confbias_&v. noobs;
		var &v. SUPPRESS_CT FTA_RATIO ADD_CT ADD_LIST_RATE;
		format FTA_RATIO ADD_LIST_RATE percent7.4 ;
		sum SUPPRESS_CT ADD_CT;
		title "Conf bias results by &v.";
	run;
%end;

%else %do;
proc sql;
	create table anal.confbias_&v. as
	select a.*
	from ftarates2 as a
	order by a.&v.;

proc print data=anal.confbias_&v. noobs;
	var &v. SUPPRESS_CT FTA_RATIO;
	format FTA_RATIO percent7.4;
	sum SUPPRESS_CT;
	title "Conf bias results by &v.";
run;
%end;

%mend;

