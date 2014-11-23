/* 

Name: J:\diss\paper2\analysis\SAS\code\5 finalize and output.sas
Started: 12/10/2009;

prep external data and merge onto listings for output

input datasets: 
	anal.listings_matched
	anal.hu_level

output dataset:
	local.hulist

*/


* list of vars to drop from listings_matched before output to Stata;
%let droplm = BLOCK VLINE_NUM NON_MAILABLE ADDRESS_UNPARSED APT_PRECLEAN LISTING_DATE LISTER_CONFIRMED ORDER CITY
	ZIPCODE LATITUDE LONGITUDE HU_SELPROB PSUNUM SEGNUM LINE_DELETED PARSED INPUT_BLOCK INPUT_STR_NUMBER
	INPUT_ADDRESS_UNPARSED INPUT_APT_PRECLEAN INPUT_DESCR INPUT_ADDR_APT INPUT_STR_NUMBER_PREMANIP
	INPUT_STR_NAME_PREMANIP INPUT_APT_PREMANIP INPUT_ORDER_PREMANIP INPUT_MULTI_PREMANIP INPUT_ADDR_APT_PREMANIP
	Q12_MERGE_LINE_NUMBER INPUT_VLINE_NUM_PREMANIP ID_INPUT INPUT_STR: INPUT_VSAMPLELINEID_PREMANIP INPUT_APT 
	INPUT_UNMATCHED_TYPE INPUT_MATCH_STEP INPUT_VLINE_NUM INPUT_MATCH SEG_NAME HDD CDD TEMP_MIN DOMAIN
	MULTI_LISTERS L1_INPUT STATE PSU_NAME COUNTY_NAME SID INPUT_SID ID_SEQ OVERALL MATCH_STEP VSTATUS VTYPE VOBS_STATUS
	TRIPLE_MATCH PAIR_MATCH MATCH_ID1 MATCH_ID2 MATCH_ID3 ID_MATCH IPUBLIC_HOUSING BLDEMOLITION:
	QC: LINES_AQC LINES_BQC DEP INL SOURCE SELECT HUL3_MATCH DISP_CAT
	/* stata reported these varaibles were missing on all cases */
	bldemolition_of_hus blfound_count_discrepancy
 	Blimpediment_bars blimpediment_dog blimpediment_none blimpediment_security_door
 	blimpediment_security_signs blimpediment_trespassing_sign bllarge_apt_not_in_est
 	blnew_construction blother_discrepancy blstructure_church blstructure_commercial
 	blstructure_community_center blstructure_industrial blstructure_library
 	Blstructure_residential blstructure_school iblock_num_inconsistency_count
 	ilisting_print_count isame_zip_codes isegment_count_listed isegment_count_total
 	istreet_name_inconsistancy_count istreet_num_inconsistancy_count
 	iunihabitable_housing lvmos_discrepancy_notes
 	vaccess_seasonal_hazard_specify vstructure_type_other_specify
	dbLine_Selection_Probability iDuplicate_Addr_Count iListing_Print_Count iSame_Zip_Codes iBlock_Num_Inconsistency_Count
	iSegment_Count_Listed iSegment_Count_Total iStreet_Name_Inconsistancy_Count iStreet_Num_Inconsistancy_Count
	lvMOS_Discrepancy_Notes lvSpecial_Notes;

%let drophu = TRIPLE_MATCH PAIR_MATCH HDD CDD PRECIP_MONTH SNOW_MONTH TEMP_MIN 
	TEMP_MAX TEMP_MEAN WIND PRECIP SNOW SNOW_DEPTH
	ANY_SEX BABIES BIRTHYEAR CA_PROJECTS Complete CurrentSecs CURRENT_SCHOOL EDUC
	FLEX_IMPORT Frq11_M Frq12a Frq131 Frq132 Frq133 Frq134 Frq135 Frq14a Frq14b Frq19a1
	Frq19a2 Frq19a3 Frq19a4  Frq1b1 Frq1b2 Frq1b3 Frq1b4 Frq1b5 Frq1b6 Frq1b7 Frq20_C 
	Frq20_S Frq21 Frq21a Frq23 Frq27 Frq3_M Frq4 Frq51 Frq52 Frq53  Frq54 Frq8b FRQComplete 
	HHINCOME HISPANIC JOB_HOURS LIKE_CONVERT LIKE_COOP LIKE_INTRO LIKE_INTW LIKE_PAPER LIKE_SUPER 
	LIKE_TEAM MARRIED nsfgbefore oldkidage otherjob OTHER_COMPANY OTHER_JOBS OTHER_LANG 
	OTHER_MODE OTHER_SCR PAY PEOPLE_VARIETY Preamble RACE RELIGION RELIGION_IMPORTANT R_OBJECT
	R_PERSUADE R_RELUCTANT SAME_SEX SampleID sIwerSubscribeId source STYLUS 
	SURVEY_IMPORT TotalSecs VersionDate VersionTime YRS_EXPER ;

* list of vars to drop to anonymize data fully;
%let anonvars = addr nsfg_psu psu seg psu_name county_name input_selected ipublic_housing 
	bldemolition str_: vline_num city zipcode latitude longitude psunum segnum hu_selprob
	apt: descr state sid seg_name fips q12_merge_lin: input_:
	BLK_KEY BLOCK PSU_SEG OVERALL MATCH_STEP NOMATCH;


proc delete data=work._ALL_; run;




ods rtf file="&output.\6 output.rtf";


proc import datafile="&dt.\segment stats.xls"
	out=segselect
	replace;
run;

data segselect2;
	set segselect;

	NSFG_PSU = input(PSU,3.);

	rename SEGMENT=SEG;

	drop F3: PSU;
run;


* creates dataset work.weather2;
%include "&code.\6.1 input weather data.sas";


* creates dataset work.segobs;
%include "&code.\6.2 prep segment observations and map data.sas";


* interviewer quex response data
	see emails from Shonda 12/11, 12/17/2009;
%include "&code.\6.3 prep interviewer quex data.sas";



* combine all segment demographic data
	and weather and segment obs (segment-lister level) data 
	and interviewer quex data into one dataest;
proc sql;
	create table intw_xwalk0 as
	select NSFG_PSU, LISTING, l.*
	from (select distinct PSU, SEG, LISTER
		from anal.listings_matched) as l
	left join xwalk as x
	on x.PSU=input(l.PSU,3.)
	order by PSU, SEG, LISTER;



/* apply lister id corrections from sharon parker's email 11/13/2010

 120_428 |  22179618 11389064   6216150
 122_152 |  86678675 22179618  92320779
 122_351 |  86678675 22179618  92320779
 122_353 |  86678675 22179618  92320779
 154_253 |  74734006 83649304  74957168
 154_356 |  83649304 74734006  74957168
 154_456 |  83649304 74734006  74957168
 194_354 |  03703296  9058576  33650149
 194_361 |  03703296  9058576  33650149
*/

data intw_xwalk;
	set intw_xwalk0;

	if listing=1 & PSU="120" & SEG="428" then lister="22179618";
	else if listing=1 & PSU="122" & SEG="152" then lister="86678675";
	else if listing=1 & PSU="122" & SEG="351" then lister="86678675";
	else if listing=1 & PSU="122" & SEG="353" then lister="86678675";
	else if listing=1 & PSU="154" & SEG="253" then lister="74734006";
	else if listing=1 & PSU="154" & SEG="356" then lister="83649304";
	else if listing=1 & PSU="154" & SEG="456" then lister="83649304";
	else if listing=1 & PSU="194" & SEG="354" then lister="03703296";
	else if listing=1 & PSU="194" & SEG="361" then lister="03703296";
	else if listing=2 & PSU="120" & SEG="428" then lister="11389064";
	else if listing=2 & PSU="122" & SEG="152" then lister="22179618";
	else if listing=2 & PSU="122" & SEG="351" then lister="22179618";
	else if listing=2 & PSU="122" & SEG="353" then lister="22179618";
	else if listing=2 & PSU="154" & SEG="253" then lister="83649304";
	else if listing=2 & PSU="154" & SEG="356" then lister="74734006";
	else if listing=2 & PSU="154" & SEG="456" then lister="74734006";
	else if listing=2 & PSU="194" & SEG="354" then lister="09058576";
	else if listing=2 & PSU="194" & SEG="361" then lister="09058576";
	else if listing=3 & PSU="120" & SEG="428" then lister="06216150";
	else if listing=3 & PSU="122" & SEG="152" then lister="92320779";
	else if listing=3 & PSU="122" & SEG="351" then lister="92320779";
	else if listing=3 & PSU="122" & SEG="353" then lister="92320779";
	else if listing=3 & PSU="154" & SEG="253" then lister="74957168";
	else if listing=3 & PSU="154" & SEG="356" then lister="74957168";
	else if listing=3 & PSU="154" & SEG="456" then lister="74957168";
	else if listing=3 & PSU="194" & SEG="354" then lister="33650149";
	else if listing=3 & PSU="194" & SEG="361" then lister="33650149";
run;


proc sql;
	create table segdata2(rename=(SEGMENT=SEG) 
		drop=sIwerSubscribeId ) as
	select s.*, HDD, CDD, PRECIP_MONTH, SNOW_MONTH, TEMP_MIN, TEMP_MAX, TEMP_MEAN, WIND, PRECIP, SNOW, SNOW_DEPTH,
		FIPS, DOMAIN, MULTI_LISTERS, BLK_CT, DEP_INPUT as L1_INPUT label='Input to L1 if dependent',
		AFAM_PCT, CRIME_HIGH, CRIME_P1_HIGH, CRIME_RT_CTY, CRIME_RT_P1_CTY, CRIME_RT_VIOL_CTY,
		VIOLENT_CRIME, INCOME_HIGH, AFAM_HIGH, MULTI_HIGH, PCT_MULTI, li.GT25K_PCT, li.GT50K_PCT, li.MED_INCOME, 
		MINCOME_LOW, MINCOME_LOW2, x.LISTER, SPANISH_HHS_PCT, NONENGLISH_HHS_PCT, PCT_RURAL, i.*,
		/* &psadjp. adjusts for selection of Q12 and year 3 
		DISSPROB adjusts for selection into my dissertation sample of PSUs */
		a.ipsu_selection_probability * a.iseg_selection_probability * a.ipsudomain_selection_probability 
			* &psadjp. * DISSPROB as SEG_PROB label='Unconditional prob of selection of segment'
	from segobs2(drop=iDuplicate_Addr_Count
		dbLine_Selection_Probability
		iListing_Print_Count
		iSame_Zip_Codes iBlock_Num_Inconsistency_Count
		iSegment_Count_Listed
		iSegment_Count_Total
		iStreet_Name_Inconsistancy_Count
		iStreet_Num_Inconsistancy_Count
		lvMOS_Discrepancy_Notes
		lvSpecial_Notes) as s
	inner join weather4 as w
	on s.NSFG_PSU = w.NSFG_PSU
		and s.SEGMENT = w.SEG
		and s.LISTING = w.LISTING
	left outer join segselect2 as ss
	on s.NSFG_PSU = ss.NSFG_PSU
		and s.SEGMENT = ss.SEG
	left join intw_xwalk as x
	on s.PSU=x.PSU
		and s.SEGMENT=x.SEG
	left join (select PSU, SEGMENT, ipsu_selection_probability, iseg_selection_probability, 
		/* dont know why this prob is 0, another sources (james weight file, has 1 for this segment */
		case when ipsudomain_selection_probability = 0 then 1 else ipsudomain_selection_probability end as ipsudomain_selection_probability,
		case when put(input(PSU,3.)*1000+input(SEGMENT,3.),6.) in (&cert.) then &cprob. 
			when put(input(PSU,3.)*1000+input(SEGMENT,3.),6.) in (&noncert.) then &ncprob. end as DISSPROB
		from anal.segments) as a
	on put(s.NSFG_PSU,3.)=a.PSU
		and s.SEGMENT=a.SEGMENT
	left join intw2 as i
	on x.LISTER=i.sIwerSubscribeId
	left join local.census_data as li
	on s.NSFG_PSU = input(li.PSU,3.)
		and s.SEGMENT = li.SEGMENT
	order by s.PSU, s.SEGMENT, s.LISTING;




* get HU characteristics right;
%include "&code.\6.4 HU characteristics.sas";




* create HU level and HU list level dataset with all vars available;
proc import datafile="&dt.\PSU crosswalk.xls"
	out=xwalk
	dbms=excel
	replace;
run;


* put these seg level vars on:
	anal.listings_matched
	anal.hu_level2 (made in 5.4 code)
	anal.listings_all (this databaset contains unlisted lines for conf bias analysis);
proc sort data=segdata2; by PSU SEG LISTING; run;
proc sort data=segselect2; by NSFG_PSU SEG; run;

* for some reason, DISP_INTW not on this dataset, get from local.rdata;
proc sql;
	create table hu_level3 as
	select h.*, DISP_INTW
	from anal.hu_level2 as h
	left join local.rdata(keep=ID_HU DISP_INTW) as c
	on h.ID_HU = c.ID_HU
	order by NSFG_PSU, SEG;



* merge in different data here, only census data at seg level
	listing specific data makes no sense on this HU-level dataset;
data stata.hu prob2;
	merge hu_level3 segdata2(in=INSEGS where=(LISTING=1));
	by NSFG_PSU SEG;

	* clear up select and disp flags;
	if SELECTED=. then SELECTED=0;

	if SELECTED=0 then do;
		DISP_LISTELIG = .;
		DISP_INTW = .;
		DISP_CAT = .;
		DISP_HH = .;
		DISP_OOS = .;
	end;

	if not INSEGS then output prob2;
	else if (L1+L2) > 0 then output stata.hu;

	* drop vars not needed anywhere (droplm) and those not needed at HU level (drophu);
	drop &droplm. &drophu.;

	%include "&code.\00 var labels.sas";
run;

proc print data=prob2 noobs;
	title 'PROBLEM: error in stata.hu merge';
	var NSFG_PSU SEG;
run;



* create a dataset with three obs for each HU;
proc sort data=stata.hu; by ID_HU; run;

data hulist_level;
	set stata.hu;
	by ID_HU;

	* HU and segment level observations OK on this dataset
		need to merge in listing and interviewer level below;

	LISTING=1;
	if L1=1 then LISTED=1;
	else LISTED=0;
	output;

	LISTING=2;
	ON_INPUT = 0;
	if L2=1 then LISTED=1;
	else LISTED=0;
	output;
run;

* make crosswalk between PSU SEGMENT and LISTER;
proc sql;
	create table hulist_level2 as
	select h.*, vStatus, vType, vObs_Status, blStructure_Church, blStructure_Commercial, blStructure_Community_Center, 
		blStructure_Industrial, blStructure_Library, blStructure_Residential, blStructure_School, iUnihabitable_Housing, 
		blAccess_Gated, blAccess_Seasonal_Hazard, vAccess_Seasonal_Hazard_Specify, blAccess_Unimproved_Roads, 
		blAccess_Other, vAccess_Other_Specify, blAccess_None, iNon_English_Speakers, blNon_English_Lang_Spanish, 
		blNon_English_Lang_Other, vNon_Eng_Lang_Other_Specify, iSafety_Concerns, vSegment_Obs_Comments, 
		iStructure_Type, vStructure_Type_Other_Specify, iSegment_Type, iPublic_Housing, blImpediment_Bars, 
		blImpediment_Security_Signs, blImpediment_Trespassing_Sign, blImpediment_Security_Door, blImpediment_Dog, 
		blImpediment_None, blFound_Count_Discrepancy, blDemolition_of_HUs, blLarge_Apt_not_in_est, blNew_Construction, 
		blOther_Discrepancy, vOther_Disc_Specify, vAccess_Gated_Specify, vSafety_Concerns_Specify, sPSU_Type, 
		iZone, blFoot_Alone, blFoot_Not_Alone, blCar_Alone, blCar_Driver, HDD, CDD, PRECIP_MONTH, 
		SNOW_MONTH, TEMP_MIN, TEMP_MAX, TEMP_MEAN, WIND, PRECIP, SNOW, SNOW_DEPTH, FIPS, DOMAIN, MULTI_LISTERS, 
		BLK_CT, L1_INPUT, AFAM_PCT, CRIME_HIGH, CRIME_P1_HIGH, MED_INCOME, CRIME_RT_CTY, CRIME_RT_P1_CTY, CRIME_RT_VIOL_CTY, 
		VIOLENT_CRIME, INCOME_HIGH, AFAM_HIGH, MULTI_HIGH, LISTER, OTHER_COMPANY, OTHER_SCR, OTHER_MODE, YRS_EXPER, 
		CA_PROJECTS, STYLUS, OTHER_JOBS, JOB_HOURS, EDUC, CURRENT_SCHOOL, BIRTHYEAR, HISPANIC, RACE, OTHER_LANG, 
		RELIGION, RELIGION_IMPORTANT, MARRIED, HHINCOME, BABIES, R_OBJECT, R_PERSUADE, R_RELUCTANT, LIKE_INTRO, 
		LIKE_COOP, LIKE_INTW, LIKE_SUPER, LIKE_TEAM, LIKE_PAPER, LIKE_CONVERT, FLEX_IMPORT, SURVEY_IMPORT, PAY, 
		PEOPLE_VARIETY, SAME_SEX, ANY_SEX, nsfgbefore, oldkidage, otherjob, source
	from hulist_level(drop= BLK_CT AFAM_PCT VIOLENT_CRIME INCOME_HIGH MED_INCOME AFAM_HIGH CRIME_RT_CTY
		CRIME_RT_P1_CTY CRIME_RT_VIOL_CTY CRIME_HIGH CRIME_P1_HIGH MULTI_HIGH FIPS
		blAccess_Gated blAccess_Seasonal_Hazard blAccess_Unimproved_Roads blAccess_Other vAccess_Other_Specify
		blAccess_None iNon_English_Speakers blNon_English_Lang_Spanish blNon_English_Lang_Other vNon_Eng_Lang_Other_Specify
		iSafety_Concerns vSegment_Obs_Comments iStructure_Type iSegment_Type vOther_Disc_Specify vAccess_Gated_Specify
		vSafety_Concerns_Specify sPSU_Type iZone blFoot_Alone blFoot_Not_Alone blCar_Alone blCar_Driver LISTER) as h
	left join segdata2 as s
	on h.NSFG_PSU = s.NSFG_PSU
		and h.SEG = s.SEG
		and h.LISTING = s.LISTING;


data stata.hulist;
	set hulist_level2;

	format SAMPLEID $12.;

	SAMPLEID = put(input(PSU,3.)*(10**9) + input(SEG,3.)*(10**6) + input(VLINE_NUM_L1,5.)*100 + 11,12.);

	drop &droplm.;

	%include "&code.\00 var labels.sas";
run;


* final dataset stata.rdata;
data stata.rdata;
	set local.rdata;
run;


* weights to stata;
data stata.weights;
	set local.weights;
run;

ods rtf close;
