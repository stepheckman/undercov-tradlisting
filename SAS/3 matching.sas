/* 

Name: J:\diss\paper2\analysis\SAS\code\3 matching.sas
Started: 10/4/2009;

match 3 listings together

input datasets: 
	anal.listings

output dataset:
	anal.listings_matched
	anal.hu_level

BIG CHANGE FROM DISS -- match only listings 1 and 2
listing 3 dropped in first proc sort below

*/

ods rtf file="&output.\3 output.rtf";

proc delete data= work._ALL_; run;
proc delete data=match._ALL_; run;




********************************************************************;
* MATCH_STEP = 1;
* exact matches on full address;
* only non NO_NUMBER cases
	only LISTED cases;

data listings;
	set anal.listings(where=(LISTING in (1,2) and NO_NUMBER ne 1 and LISTED=1)); 
run;

data d1;
	set listings(where=(LISTING = 1)
		keep = NSFG_PSU SEG ID_LISTING ADDRESS_UNPARSED LISTING
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

data d2;
	set listings(where=(LISTING = 2)
		keep = LISTING NSFG_PSU SEG ID_LISTING ADDRESS_UNPARSED LISTING
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

	drop LISTING;
run;


* now use macros which relax match criteria to find more matches;
%address_match1(d1,d2,match,1);
%address_match2(d1_unmatched1,d2_unmatched1,match,2);
%address_match3(d1_unmatched2,d2_unmatched2,match,3);
%address_match4(d1_unmatched3,d2_unmatched3,match,4);
%address_match5(d1_unmatched4,d2_unmatched4,match,5);
%address_match6(d1_unmatched5,d2_unmatched5,match,6);
%address_match7(d1_unmatched6,d2_unmatched6,match,7);

data match.matches;
	set match.matches1_1 match.matches2_2 match.matches4_4 match.matches7_7;
run;

%iddupe(match.matches, ID1);
%iddupe(match.matches, ID2);

proc freq data=match.matches;
	tables MATCH_PASS;
	title 'Freq on matches after SAS macros, before manual';
run;

* create full dataset with amtches merged back in,
	for output to manual matching;
* bring NO_NUMBER cases in here;
proc sql;
	create table anal.listings_matched_beforeman as
	select l.*, ID1 as MATCH_ID1, ID2 as MATCH_ID2, MATCH_ID as ID_MATCH, MATCH_PASS,
		/* HU level ID 
			for matched lines, get lowest of the matched IDs
			for unmatched lines, get ID_LISTING */
		min(ID1, ID2, ID_LISTING) as ID_HU
	from anal.listings(where=(LISTED=1 and LISTING in (1 2))) as l 
	left outer join match.matches as m1
	on l.ID_LISTING=m1.ID1
		or l.ID_LISTING=m1.ID2
	order by NSFG_PSU, SEG, ID_HU, LISTING desc;




********************************************************************;
* MATCH_STEP = 3;

* output for manual matching;
*%include "&code.\3.1 export for manual matching.sas";

* bring in manual matches;
%include "&code.\3.2 manual matches.sas";


* make HU level dataset from matched dataset;
data anal.hu_level;
	retain NSFG_PSU SEG STR_NUMBER STR_PREDIR STR_NAME STR_TYPE STR_POSTDIR APT
		MATCH_ID1 MATCH_ID2 ID_MATCH MATCH_PASS SELECTED DISP:;

	* only listed lines from L1 and L3 allowed;
	set anal.listings_matched(where=(LISTED=1 and LISTING in (1 2)));
	by NSFG_PSU SEG ID_HU;

	format ADDR1 ADDR2 $200. APT1 APT2 $15.;

	retain L1 L2 MATCH_ID1 MATCH_ID2 ADDR1 ADDR2 APT1 APT2;

	if first.ID_HU then do;
		L1=0;
		L2=0;
		APT1='';
		APT2='';
		ADDR1='';
		ADDR2='';
	end;

	if LISTING=1 then do;
		if LISTED then L1=1;
		ADDR1 = compbl(STR_NUMBER || STR_PREDIR || STR_NAME || STR_TYPE || STR_POSTDIR);
		APT1 = APT;
	end;
	else if LISTING=2 then do;
		if LISTED then L2=1;
		ADDR2 = compbl(STR_NUMBER || STR_PREDIR || STR_NAME || STR_TYPE || STR_POSTDIR);
		APT2 = APT;
	end;

	
	if last.ID_HU then do;
		if MATCH_ID1 = 0 then MATCH_ID1=.;
		if MATCH_ID2 = 0 then MATCH_ID2=.;

		if nmiss(MATCH_ID1, MATCH_ID2)=1 then NOMATCH=1;
		else NOMATCH=0;

		ID_HU = min(MATCH_ID1, MATCH_ID2, ID_LISTING);
		output;
	end;

	keep NSFG_PSU SEG STR_NUMBER STR_PREDIR STR_NAME STR_TYPE STR_POSTDIR APT NOMATCH MATCH_PASS 
		MATCH_ID1 MATCH_ID2 L1 L2 SEG_ID ADDR1 ADDR2 ID_HU ID_MATCH SELECTED DISP: MANMATCH_TYPE;

	format L1 L2 NOMATCH yesno. MATCH_PASS mtchtypp.;

	label L1 = 'HU included on L1 listing'
		L2 = 'HU included on L2 listing'
		MATCH_ID1 = 'ID for this HU in L1'
		MATCH_ID2 = 'ID for this HU in L2'
		NOMATCH = 'Listing has no matches in other listings'
		ID_MATCH = 'ID for matches on match.matches dataset'
		NO_NUMBER = 'Listing does not have house number'
		ID_HU = 'HU level ID in HU level dataset'
	;
run;

ods rtf close;
