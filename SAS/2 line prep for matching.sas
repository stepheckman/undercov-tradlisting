/* 

Name: J:\diss\paper2\analysis\SAS\code\2 line prep for matching.sas
Started: 10/4/2009;

prepare dataset of all listed lines in 49 segments, all three listings, for matching routines

input datasets: 
	local.tlisting_line
	local.tlisting_psu_segment

output dataset:
	anal.listings


STILL TO DO:
1.	merge in results of Sarrah's QC, if possible
	L1 lines in this dataset are right now POST-Sarrah-QC

*/


proc delete data=work._ALL_; run;



ods rtf file="&output.\2 output.rtf";


* prep block and segment level files
	compare L1 lines before and after Sarrah's QC;
*%include "&code.\2.1 listing1, segment, block prep.sas";


* dataset of all listed lines
	includes those added by Sarrah's QC of L1
		will need to flag these
	get all listed lines from same source (local.tlisting_line which comes from st.tlisting_line);

* merge seg level variables (listing method) onto line file;
proc sort data=local.tlisting_line; by VSAMPLELINEID ISEQ_NUM; run;
proc sort data=local.tlisting_psu_segment; by VSAMPLELINEID; run;

data listings1;
	* these datasets preivosly subset to my two projects;
	merge local.tlisting_line(in=INLINES drop=VTYPE) 
		local.tlisting_psu_segment(keep=VSAMPLELINEID VTYPE);
	by VSAMPLELINEID;  * this is PSUSEG in both datasets;


	************************************************ create variables;
	PSU = substr(VSAMPLELINEID,1,3);
	SEG = substr(VSAMPLELINEID,4,3);

	PSUNUM = input(PSU,3.);
	SEGNUM = input(SEG,3.);

	if substr(PSU,1,1)='8' then do;
		LISTING=2;
		LIST_TYPE2=1;  * all these lines should be traditional, check this below with comparison to LIST_TYPE;
	end;
	else if substr(PSU,1,1)='9' then do;
		LISTING=3;
		LIST_TYPE2=2; * all these lines should be dependent, check this below with comparison to LIST_TYPE;
	end;
	else LISTING=1;   * get listing method for these lines only from psu_segment dataset flag (VTYPE);

	LIST_TYPE = input(VTYPE, 3.);

	RAND = ranuni(&seed.);

	ID_LISTING = _N_;

	* this is code frame for SSTATUS in ST data dictionary table
		NB: code frame different in diff projects!;
	if SSTATUS = '01' then LINE_DELETED=0;
	else if SSTATUS = '02' then LINE_DELETED=1;


	* combine info in two flags on listing status	
		LINE_DELETED (derived above from SSTATUS)
		LISTER_CONFIRMED (derived from BLCONFIRMED)
	see 10/22/2009 email from Brad on how to reconcile these;
	if BLCONFIRMED and LINE_DELETED then LISTED=0;
	else if not BLCONFIRMED and LINE_DELETED then LISTED=0;
	else if BLCONFIRMED and not LINE_DELETED then LISTED=1;
	else if not BLCONFIRMED and not LINE_DELETED then LISTED=0;


	************************************************ subset cases;
	if INLINES;


	************************************************ clean up variables;
	rename BLCONFIRMED=LISTER_CONFIRMED  /* st.tlisting_line contains lines not really in final frame */
		NSORT=ORDER
		LVNOTES = DESCR
		VBLOCK_NUM = BLOCK
		VSAMPLELINEID = PSU_SEG
	;

	label LIST_TYPE = 'Type of listing from ST, from VTYPE variable'
		LIST_TYPE2 = 'Type of listing derived from PSU number'
		ISEQ_NUM = 'Listing order'
		ID_LISTING = 'HU listing level ID'
		VLINE_NUM = 'Line number on listing dataset, reflects order on input listing (if any) can be used as FK to input'
		NSORT = 'HU order after listing, from NSORT on listing dataset (in L1 this is pre-QC)'
		VBLOCK_NUM = 'Block number, as text'
		LVNOTES = 'HU description, lister notes'
		BLCONFIRMED = 'Line included on frame (0 for cases only on input, not frame)'
		LISTED = 'HU included on final frame, eligible for selection'
	;

	format LIST_TYPE listtype. BLCONFIRMED LINE_DELETED LISTED yesno.;
run;

proc import datafile='J:\diss\paper2\analysis\SAS\data\PSU crosswalk.xls'
	out=xwalk
	dbms=excel
	replace;
run;

proc sql;
	create table listings2 as
	select l.*, coalesce(x.NSFG_PSU, l.PSUNUM) as NSFG_PSU
	from listings1 as l
	left outer join xwalk as x
	on l.PSUNUM=x.PSU;



******* QC
* ensure three listings of each segment
* check listing 2 trad and listing 3 dependent;
proc sql;
	create table listqc as
	select NSFG_PSU, SEG, count(distinct LISTING) as LISTINGS, min(LISTING) as MINLIST, max(LISTING) as MAXLIST
	from listings2
	group by NSFG_PSU, SEG;

	create table typeqc as
	select NSFG_PSU, SEG, LISTING, LIST_TYPE, LIST_TYPE2, count(*) as CT
	from listings2
	group by NSFG_PSU, SEG, LISTING, LIST_TYPE, LIST_TYPE2;


proc print data=listqc noobs;
	title 'PROBLEM: not three listings of these segments';
	where LISTINGS ne 3 
		or MINLIST ne 1
		or MAXLIST ne 3;
run;

proc print data=typeqc noobs;
	var NSFG_PSU SEG LISTING LIST_TYPE:;
	where LIST_TYPE ne LIST_TYPE2
		and LISTING ne 1;
	title 'PROBLEM: inconsistent listing method flags';
run;

proc print data=typeqc noobs;
	var NSFG_PSU SEG LISTING LIST_TYPE:;
	where (LISTING=2 & LIST_TYPE ne 1)
		or (LISTING=3 & LIST_TYPE ne 2);
	title 'PROBLEM: unexpected listing methods';
run;



* parse HU_STREET_ADDRESS into parts;
data listings3;
	set listings2;

	if VHU_STREET_ADDRESS ne '' then do;
		%addr_parse(VHU_STREET_ADDRESS);
		PARSED=1;
	end;
	else PARSED=0;

	* flag those cases where parser did nothing;
	if VHU_STREET_NUMBER = PARSED_STREET_NAME then PARSED=0;

	%aptclean(VAPT, APT);

	rename VHU_STREET_NUMBER = STR_NUMBER
		VHU_STREET_ADDRESS = ADDRESS_UNPARSED
		VAPT = APT_PRECLEAN
		PARSED_STREET_PRE_DIR = STR_PREDIR
		PARSED_STREET_NAME = STR_NAME
		PARSED_STREET_SUFFIX = STR_TYPE
		PARSED_STREET_POST_DIR = STR_POSTDIR
	;

	format PARSED yesno.;
run;

proc freq data=listings3;
	tables ADDRESS_UNPARSED*STR_PREDIR*STR_NAME*STR_TYPE*STR_POSTDIR /list missing nocum nopercent;
	where PARSED=1
		and RAND < .01;
	title 'Review parsed addresses';
run;

/*proc print data=listings3 noobs width=min;
	var ADDRESS_UNPARSED;
	title 'Unparsed cases';
	where PARSED=0;
run;*/




* merge in input listings to L3, cases flagged with manipulations (ADD, SUPPRESS)
  	dataset made in 9 finalize manipulation 3.sas, segs.manipulated_lines;
* this version does NOT merge in input listing to L1;

%include "&code.\2.1 create L3 input dataset with manipulations.sas";



* manipulation dataset contains all lines loaded as input to L3
	plus lines from L1 that I suppressed from input to L3
	there are important flags on this dataset about the reason a line was suppressed or added
* match the manipulation dataset to the listed lines
	by PSU SEG VLINE_NUM
	VLINE_NUM is unique line ID that is preserved when the lister reorders the data on the input list
	however
		1. lines that were suppressed for the input will have no match in listings3
		2. and those lines on the input that were deleted will have:
			LISTED=0 on listings3  (LISTED is rename of BLCONFIRMED from local.tlisting_line)
		3. those on input lsit that were delted and then ADDED BACK will have:
			LISTED=0 on listings3  (LISTED is rename of BLCONFIRMED from local.tlisting_line)
			plus another occurrence of that address in listings3
	to match 1 and separete 2 from 3, 
		need to do address match between lines in L3 that do not match on VLINE_NUM
		or match but are unlisted
* VLINE_NUM matches will exist only for 3rd listing;
proc sort data=listings3; by PSU SEG VLINE_NUM; run;
proc sort data=anal.manipulated_lines; by PSU SEG VLINE_NUM; run;
data dep_list(drop=ID_INPUT INPUT_: ADD) 
	dep_manip(drop=ID_LISTING ADDRESS_UNPARSED STR_: LINE_DELETED LISTER_CONFIRMED LISTED ORDER VSELECT: APT DESCR) 
	listings4 match_step0;

	merge listings3(in=INL) anal.manipulated_lines(in=ININPUT);
	by PSU SEG VLINE_NUM;		
	

	* standardize parsed addresses parts -- will improve matching in 2.2 and 3;
	%dirfix(STR_PREDIR);
	%dirfix(STR_POSTDIR);
	%typefix(STR_TYPE);
	%dirfix(INPUT_STR_PREDIR);
	%dirfix(INPUT_STR_POSTDIR);
	%typefix(INPUT_STR_TYPE);


	* not interested in listings 1 and 2 right now
		set aside these cases to deal with later;
	if LISTING ne 3 then output listings4;

	else do;
		* set aside these cases to deal with later;
		if INL and ININPUT and LISTED then do;
			* according to email from Brad, Shonda 10/27, lister can edit address when confirming
				meaning that even among lines on these two datasets that match
				there are unmatched lines that should go into dep_list and dep_manip;
			if INPUT_ADDRESS_UNPARSED ne ADDRESS_UNPARSED
				or INPUT_STR_NUMBER ne STR_NUMBER
				or INPUT_APT ne APT then do;

				output dep_list;

				INPUT_UNMATCHED_TYPE=3;
				output dep_manip;
			end;

			* otherwise this pair matched by PSU SEG VLINE_NUM is a true match, 
				put into dataset that is set aside and not sent to 2.2 for address matching;
			else output match_step0;
		end;


		* cases only in listing were added by 3rd lister;
		if INL and not ININPUT then output dep_list;

		* cases only in manip were suppressed from L3 input list;
		else if ININPUT and not INL then do;
			INPUT_UNMATCHED_TYPE=1;    	* lines on input only (these are 561 suppressed lines);
			output dep_manip;
		end;

		* cases that match but were not confirmed were deleted by L3 lister (or added and then deleted)
			need these in dep_manip to capture cases lister deleted and then added back;
		else if INL and ININPUT and LISTED = 0 then do;
			INPUT_UNMATCHED_TYPE=2;		* lines on input and listings but not listed (deleted by lister);
			output dep_manip;
		end;

		* 2.2 code below will match these two datasets to find dupes;
	end;

	label ON_INPUT = 'Line on input dataset';

	format ON_INPUT yesno.;
run;

%include "&code.\2.2 match input and listed lines.sas";





* create final line level dataset anal.listings;


%include "&code.\2.3 prep disposition data.sas";

* assign fake segment ID
	based on NSFG_PSU and SEGMENT
	this becomes part of HU listing ID below, so don't change sort here;
proc sql;
	create table segs0 as
	select distinct NSFG_PSU, SEG
	from listings4
	order by NSFG_PSU, SEG;

data segs;
	set segs0;

	SEG_ID = _N_;
run;

* gather segment and line level chars to merge onto line level dataset;
proc sql;
	create table manip as
	select input(PSU,3.) as NSFG_PSU, SEGMENT, min(MANIP_GRP) as MANIP_GRP, max(MANIP_GRP) as MAXGRP
	from segs.lines_manip as m
	group by PSU, SEGMENT;

	create table bkey as
	select PSU as NSFG_PSU, SEGMENT as SEG, substr(BLOCK,1,4) as BLOCK, BLK_KEY
	from segs.blocks_q12;

	* need to merge this in as seg level char so not missing for lines only from input listing;
	create table fi_id as
	select PSU, SEG, min(sInterviewerEmployeeId) as LISTER, max(sInterviewerEmployeeId) as MAXLISTER
	from listings1
	where sInterviewerEmployeeId ne ''
	group by PSU, SEG;

	* get segment chars from anal.segments dataset;
	create table segs2 as
	select s.NSFG_PSU, s.SEG, SEG_ID, VSEGMENT_NAME as SEG_NAME, VSTATE_NAME as STATE, VPSU_NAME as PSU_NAME,
		VCOUNTY_NAME as COUNTY_NAME
	from anal.segments as a
	inner join segs as s
	on input(a.PSU,3.) = s.NSFG_PSU
		and a.SEGMENT = s.SEG;
		
	create table listings5 as
	select l.*, LISTER, SEG_ID, MANIP_GRP, BLK_KEY, d.DISP, d.DISP_CAT, SEG_NAME, STATE, PSU_NAME, COUNTY_NAME,
		case when d.SID is not NULL and LISTING=1 then 1 else 0 end as SELECTED, 
		case when d.SID is not NULL and LISTING=3 then 1 else 0 end as INPUT_SELECTED,
		case when d.SID is not NULL and LISTING=1 then d.SID end as SID, 
		case when d.SID is not NULL and LISTING=3 then d.SID end as INPUT_SID
	from listings4_2(drop=ID_LISTING sInterviewerEmployeeId) as l
	left outer join manip as m
	on l.NSFG_PSU = m.NSFG_PSU
		and l.SEG = m.SEGMENT
	left outer join bkey as b
	on l.NSFG_PSU = input(b.NSFG_PSU,3.)
		and l.SEG = b.SEG
		and substr(l.BLOCK,1,4) = b.BLOCK
	left outer join segs2 as st
	on l.NSFG_PSU = st.NSFG_PSU
		and l.SEG = st.SEG
	left outer join fi_id as f
	on l.PSU = f.PSU
		and l.SEG = f.SEG
	left outer join disps2 as d
	on case when LISTING = 1 then compress(l.PSU || l.SEG || l.VLINE_NUM || '11') 
		when LISTING = 3 then INPUT_VSAMPLELINEID_PREMANIP end = d.SID;


proc print data=manip noobs;
	title 'PROBLEM: more than 1 MANIP_GRP for a segment';
	where MANIP_GRP ne MAXGRP;
run;

proc print data=fi_id noobs;
	title 'PROBLEM: more than 1 lister for a segment';
	where LISTER ne MAXLISTER;
run;



* need every line to have an order for matching routines
	suppressed lines do not have order right now
	give them an order < 1;
data l6p1 l6p2;
	set listings5;

	if ORDER =. then output l6p2;
	else output l6p1;
run;

* these are the 561 suppressed lines that did not match;
data l6p2_2;
	set l6p2;

	ORDER = _N_/1000;
run;


* finalize dataset;
data anal.listings;
	set l6p1 l6p2_2;

	format ID_LISTING 8.;

	* make unique listing ID
		making this from unchanging pieces will help with matching
		for some cases (suppressec cases not matched to listed line) VLINE_NUM missing
		use VLINE_NUM before manipulation instead, incrememted by 5000
			highest VLINE_NUM is < 3000;
	if SUPPRESS=1 then ID_LISTING = SEG_ID*10000000 + LISTING*100000 + 5000 + input(INPUT_VLINE_NUM_PREMANIP,4.);
	else if INPUT_MATCH = 0 then 
		ID_LISTING = SEG_ID*10000000 + LISTING*100000 + 8000 + input(INPUT_VLINE_NUM,4.);
	else ID_LISTING = SEG_ID*10000000 + LISTING*100000 + input(VLINE_NUM,4.);

	* also make a sequential ID in case this is needed somewhere;
	ID_SEQ = _N_;

	if ID_INPUT ne . and LISTING = 3 then ON_INPUT=1;
	else if LISTING = 3 then ON_INPUT=0;

	* cases only on input listing will have missing address variables
		fill in with INPUT data (post-manipulation);
	if ON_INPUT=1 and LISTED=0 then do;
		ADDRESS_UNPARSED = coalescec(ADDRESS_UNPARSED, INPUT_ADDRESS_UNPARSED);
		STR_NUMBER = coalescec(STR_NUMBER, INPUT_STR_NUMBER);
		STR_NAME = coalescec(STR_NAME, INPUT_STR_NAME);
		STR_PREDIR = coalescec(STR_PREDIR, INPUT_STR_PREDIR);
		STR_POSTDIR = coalescec(STR_POSTDIR, INPUT_STR_POSTDIR);
		STR_TYPE = coalescec(STR_TYPE, INPUT_STR_TYPE);
		APT = coalescec(APT, INPUT_APT);
		BLOCK = coalescec(BLOCK, INPUT_BLOCK);
		DESCR = coalescec(BLOCK, INPUT_DESCR);
	end;
	else if ON_INPUT = 0 and LISTING=3 then do;
		* during conf bias testing, came out that these flags were set on cases not on the input listing;
		ADD = .;
		SUPPRESS = .;
	end;

	if upcase(substr(STR_NUMBER,1,1)) = 'N' then NO_NUMBER=1; 
	else if STR_NUMBER = '' then NO_NUMBER=1;
	else NO_NUMBER=0;

	if ON_INPUT then do;
		if LISTED = 1 then LISTER_CONFIRMED = 1;
		else LISTER_CONFIRMED = 0;
	end;


	* categorize dispositions on selected cases;

	* known households;
	if DISP in (&dsphh.) then DISP_HH=1;
	else if SELECTED=1 or INPUT_SELECTED=1 then DISP_HH = 0;

	* completed screener (may or may not be eligible);
	if DISP in (&dspscrc.) then DISP_SCR_COMP=1;
	else if SELECTED=1 or INPUT_SELECTED=1 then DISP_SCR_COMP = 0;

	* not eligible for screener (vacant, noresidential, etc.);
	if DISP in (&dspoos.) then DISP_OOS=1;
	else if SELECTED=1 or INPUT_SELECTED=1 then DISP_OOS = 0;

	* cases that were good listings, all codes but SLIP; 
	if DISP in (&dspgood.) then DISP_LISTELIG=1;
	else if SELECTED=1 or INPUT_SELECTED=1 then DISP_LISTELIG = 0;

	OVERALL = 1;

	* helpful in conf bias calcs to have no missing values here;
	if SUPPRESS=0 then SUPPRESS_REASON = 0;
	if ADD=0 then ADD_REASON = 0;



	************************************************ clean up variables;
	label
		ADD_REASON = 'Type of add to input to l3'
		ADDRESS_UNPARSED = 'Street name of final listed address, before parsing'
		dbLine_Selection_Probability = 'Probability of selection of HU (conditional?)'
		INPUT_ADDR_APT = 'Full address on input dataset'
		INPUT_ADDR_APT_PREMANIP = 'Full address on input dataset, before manipulation'
		INPUT_ADDRESS_UNPARSED = 'STR_NAME on input dataset'
		INPUT_APT = 'APT number on input dataset'
		INPUT_APT_PREMANIP = 'APT number on input dataset, before manipulation'
		INPUT_BLOCK = 'BLOCK on input dataset'
		INPUT_DESCR = 'DESCR on input dataset'
		INPUT_MULTI_PREMANIP = 'Origninal listing (L1) in multi-unit building'
		INPUT_ORDER_PREMANIP = 'Listing order after L1'
		INPUT_STR_NAME = 'STR_NAME from parsing of address on input dataset'
		INPUT_STR_NUMBER = 'STR_NUMBER on input dataset'
		INPUT_STR_NUMBER_PREMANIP = 'STR_NUMBER on input dataset, before manipulation'
		INPUT_STR_POSTDIR = 'STR_POSTDIR from parsing of address on input dataset'
		INPUT_STR_PREDIR = 'STR_PREDIR from parsing of address on input dataset'
		INPUT_STR_TYPE = 'STR_TYPE from parsing of address on input dataset'
		INPUT_VLINE_NUM_PREMANIP = 'VLINE_NUM on input dataset, before manipulation'
		LISTING = 'Indicates which listing (1,2,3) case is from'
		NSFG_PSU = 'PSU in first listing'
		PSU = 'PSU as text'
		PSU_SEG = 'PSU and SEGMENT as text'
		PSUNUM = 'PSU as number'
		SEG = 'SEGMENT as text'
		SEGNUM = 'SEGMENT as number'
		OVERALL = 'Constant'
		PARSED = 'Address parsed'
		INPUT_SID = 'SID on input list'
		SELECTED = 'Indicates cases selected from L1 for Q12'
		INPUT_SELECTED = 'Line selected for Q12, from anal.manipulated_lines dataset', 
		STR_NAME = 'STR_NAME from parsing of final listed address'
		STR_NUMBER = 'Number of final listed address'
		STR_POSTDIR = 'STR_POSTDIR from parsing of final listed address'
		STR_PREDIR = 'STR_PREDIR from parsing of final listed address'
		STR_TYPE = 'STR_TYPE from parsing of final listed address'
		SID = 'SID for selected cases, made from PSU, SEG, VLINE_NUM, 11'
		SZIPCODE = 'ZIP Code'
		SUPPRESS_REASON = 'Code for suppression from L3 input list'
		ADD_REASON = 'Code for addition to L3 input list'
		LISTER = 'Interviewer ID'
		BLNON_MAILABLE = 'Non-mailable, set by interviewer'
		VCITY = 'City'
		APT = 'Apt designator, after cleanup'
		MANIP_GRP = 'Manipulation group for prep of L3 input, at segment level'
		dLAST_MODIFIED_DATE = 'Listing date, I think'
		LINE_DELETED = 'Line deleted by lister, derived from sStatus'
		ID_LISTING = 'Unique ID on anal.listings dataset, built from SEG_ID, LISTING and VLINE_NUM'
		ID_SEQ = 'Unique ID on anal.listings dataset, may change if code 2 rerun'
		INPUT_APT_PRECLEAN = 'Apt number on input list before cleaning in program 2'
		APT_PRECLEAN = 'Apt nubmer before cleaning in program 2'
		ON_INPUT = 'Line on input dataset'
		INPUT_UNMATCHED_TYPE = 'Originally unmatched line on input listing'
		SEG_ID = 'Segment ID counter'
		DISP_HH = 'Case represents known HH, selected cases only'
		DISP_SCR_COMP = 'Case completed screener, may or may not be eligible, selected cases only'
		DISP_OOS = 'Case not eligible for screener, vacant, nonresidential, seasonal, etc, selected cases only'
		DISP_LISTELIG = 'Case was correctly listed, all selects except SLIPs'
	;

	drop iSeq_Num
		LIST_TYPE2
		RAND
		sPhone
		sState
		SSTATUS
		tLast_Modified_Time
		vProjectId
		VTYPE
	;
	
	rename ADD_REASON = ADD_TYPE
		SUPPRESS_REASON = SUPPRESS_TYPE
		blNon_Mailable = NON_MAILABLE
		dbLine_Selection_Probability = HU_SELPROB
		nLatitude = LATITUDE
		nLongitude = LONGITUDE
		sZipCode = ZIPCODE
		VCITY = CITY
		dLAST_MODIFIED_DATE = LISTING_DATE
	;

	format SELECTED LINE_DELETED ON_INPUT SUPPRESS ADD DISP_HH DISP_SCR_COMP DISP_OOS DISP_LISTELIG INPUT_MATCH yesno.
		INPUT_UNMATCHED_TYPE unmtype.
	;
run;


* check that ID is unique;
%iddupe(anal.listings, ID_LISTING);





* QC on anal.listings;
proc print data=anal.listings noobs;
	var ID_LISTING DISP DISP_HH DISP_SCR_COMP DISP_OOS DISP_LISTELIG;
	where SELECTED = 0 and INPUT_SELECTED=0
		and (DISP ne .
			or DISP_HH ne .
			or DISP_SCR_COMP ne . 
 			or DISP_OOS ne .
			or DISP_LISTELIG ne .);
	title 'PROBLEM: Disposition codes on non-selected cases';
run;
proc freq data=anal.listings;
	title 'PROBLEM: missing FI data';
	where LISTER = '';
	tables PSU * SEG /list missing nocum;
run;

proc print data=anal.listings noobs;
	title 'PROBLEM: missing block variable';
	where BLK_KEY = '' and LISTED=1;
	var NSFG_PSU SEG LISTING BLOCK ID_LISTING;
run;





proc freq data=anal.listings;
	table LISTING DISP_CAT DISP DISP_HH DISP_SCR_COMP DISP_OOS DISP_LISTELIG /missing ;
	where SELECTED = 1;
	title 'Disposition codes on selected cases';
	title2 'Should be listing 1 cases only';
run;

proc freq data=anal.listings;
	table LISTING DISP_CAT DISP DISP_HH DISP_HH*DISP_OOS DISP_SCR_COMP DISP_OOS DISP_LISTELIG /missing list;
	where INPUT_SELECTED = 1;
	title 'Disposition codes on selected cases';
	title2 'Should be listing 3 cases only';
run;


ods rtf close;





*%include "&code.\2.4 confirmation bias.sas";

*%include "&code.\2.5 confirm rates by segment.sas";
