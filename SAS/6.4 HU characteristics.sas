/* 

Name: J:\diss\paper2\analysis\SAS\code\6.4 HU characteristics.sas
Started: 1/10/2010;

make HU characteristics consistent across three listings:
	MULTI
	TRAILER
also ensure no unit is both MULTI and TRAILER (TRAILER wins)

input datasets: 
	local.listings_matched
	anal.hu_level
	anal.q12_huobs

output datasets:
	anal.hu_level2

*/


* HU observations for selected cases;
* email from Nicole devliering these data Nov 7, 2011;
data obs;
	set anal.q12_huobs;

	HU_TYPE_OBS = input(sHU_Obs_Structure_Type,3.);
	HU_TYPE_OTHER = vHU_Obs_Structure_Type_Other;
	PHYS_IMPED = vHU_Obs_Physical_Impediments;
	OVER45_OBS = input(vHU_Obs_Proj1,3.);
	CHILDREN_OBS = input(vHU_Obs_Proj2,3.);
	CHILDREN_WHY = vHU_Obs_Proj3;

	PHYS_IMPED1_OBS = input(substr(PHYS_IMPED,1,1),3.);
	PHYS_IMPED2_OBS = input(substr(PHYS_IMPED,3,1),3.);
	PHYS_IMPED3_OBS = input(substr(PHYS_IMPED,5,1),3.);
	PHYS_IMPED4_OBS = input(substr(PHYS_IMPED,7,1),3.);
	PHYS_IMPED5_OBS = input(substr(PHYS_IMPED,9,1),3.);

	label
		PHYS_IMPED1_OBS = "Locked common entrance, no public access to unit"
		PHYS_IMPED2_OBS = "Locked gates"
		PHYS_IMPED3_OBS = "Doorperson or other gatekeeper"
		PHYS_IMPED4_OBS = "Access to units controlled though intercom system"
		PHYS_IMPED5_OBS = "None of these above"
		HU_TYPE_OBS = "Intw obs of HU type during fielding"
		HU_TYPE_OTHER = "Intw description of HU when HU_TYPE_OBS = other"
		OVER45_OBS = "Intw obs of age of household members (all of 45 = 1)"
		CHILDREN_OBS = "Intw obs of presence of children"
	;

	* recode nos to 0; 
	if OVER45_OBS = 5 then OVER45_OBS = 0;
	if CHILDREN_OBS = 5 then CHILDREN_OBS = 0;
	if CHILDREN_OBS = 5 then CHILDREN_OBS = 0;

	format HU_TYPE_OBS hutype.;

	drop PHYS_IMPED CHILDREN_WHY vHU: sHU: QTR VPROJECTID;
run;

proc freq data=obs;
	tables HU_TYPE_OBS HU_TYPE_OTHER PHYS_IMPED: OVER45_OBS CHILDREN_OBS /list missing;
	title 'Review HU Obs data';
run;



* make HU list level MULTI and TRAILER flags;
data l1;
	set anal.listings_matched;

	* flag trailers at HU-listing level;
	if index(DESCR,'TRL')>0 then TRAILER=1;
	else if index(DESCR,'TRAILER')>0 then TRAILER=1;
	else if index(APT,'TRL')>0 then TRAILER=1;
	else if index(APT, 'TRAILER')>0 then TRAILER=1;
	else TRAILER=0;

	* flag multis at HU-listing level;

	* first flag type of multi unit designator
		and make STR_NUMBER field that removes apt designator, if any;
	if APT ne "" then do;
		MULTITYPE=1;
		STR_NUMBER_PRE = STR_NUMBER;
	end;
	else if index(STR_NUMBER,"-") > 0 then do;
		MULTITYPE=2;
		STR_NUMBER_PRE = substr(STR_NUMBER, 1, index(STR_NUMBER, "-")-1);
	end;
	else if NO_NUMBER = 0 and indexc(STR_NUMBER,'A','B','C','D','E','F','G','H','I','J','K','L','M','N','O',
		'P','Q','R','S','T','U','V','W','X','Y','Z') > 0 then do;
		MULTITYPE=3;
		STR_NUMBER_PRE = substr(STR_NUMBER, 1, indexc(STR_NUMBER,'A','B','C','D','E','F','G','H','I','J','K','L','M','N','O',
		'P','Q','R','S','T','U','V','W','X','Y','Z')-1);
	end;
	else if index(STR_NUMBER,"/") > 0 then do;
		MULTITYPE=4;
		STR_NUMBER_PRE = substr(STR_NUMBER, 1, index(STR_NUMBER, "/")-3);
	end;
	else do;
		MULTITYPE=0;
		STR_NUMBER_PRE = STR_NUMBER;
	end;

	* now flag the multis themselves;
	if MULTITYPE ne 0 then MULTI=1;
	else MULTI=0;

	if LISTING=1 then L1_SELECT = SELECTED;

	* cannot be both multi and trailer;
	if MULTI and TRAILER then do;
		MULTI=0;
		TRAILER=1;
	end;

	* build sample id (even for unselected cases) to link in HU obs by interviewers below;
	SAMPLEID = put(NSFG_PSU*(10**9) + input(SEG,3.)*(10**6) + input(VLINE_NUM,5.)*100 + 11,12.);

	* address field;
	ADDR = compbl(STR_NUMBER || STR_PREDIR || STR_NAME || STR_TYPE || STR_POSTDIR);
	* address field without apt designators in STR_NUMBER;
	ADDR_BUILD = compbl(STR_NUMBER_PRE || STR_PREDIR || STR_NAME || STR_TYPE || STR_POSTDIR);

	keep ID_HU TRAILER MULTITYPE MULTI NO_NUMBER LIST_TYPE L1_SELECT ADDR: APT STR: 
		PSU SEG LISTING LISTED SAMPLEID;
		* LIST_TYPE is indicator of method used in L1 listing;
run;


* group multis into buildings, based on type of multi;
proc freq data=l1;
	tables MULTITYPE /list missing;
	title 'Review types of multi unit listings';
run;

proc sort data=l1; by MULTITYPE; run;
proc print data=l1 noobs;
	where MULTITYPE>1;
	by MULTITYPE; id MULTITYPE;
	var STR_NUMBER_PRE ADDR APT;
	title 'Review types of multi unit listings';
run;


proc sql;
	* get intw HU obs on this dataset;
	create table obs2 as
	select ID_HU, SAMPLEID, HU_TYPE_OBS, HU_TYPE_OTHER, OVER45_OBS, CHILDREN_OBS, 
		PHYS_IMPED1_OBS, PHYS_IMPED2_OBS, PHYS_IMPED3_OBS, PHYS_IMPED4_OBS, PHYS_IMPED5_OBS
	from l1
	left outer join obs as o
	on l1.SAMPLEID = o.VSAMPLELINEID
	where LISTING=1
	order by ID_HU;

	* group multi unit cases into buildings;
	create table b1 as
	select LISTING, PSU, SEG, ADDR_BUILD, 
		case when sum(LISTED) > 0 then sum(LISTED)
			else count(*) end as BUILDING_UNIT_CT
	from l1
	where LISTED
	group by LISTING, PSU, SEG, ADDR_BUILD;

	* merge building count onto full hulist level dataset;
	create table l2 as
	select l.*, BUILDING_UNIT_CT label='Listing level count of units in this building'
	from l1 as l
	left outer join b1 as b
	on l.PSU = b.PSU
		and l.SEG = b.SEG
		and l.ADDR_BUILD = b.ADDR_BUILD;

	* straighten out inconsistent HU level flags;
	create table huchars as
	select l.ID_HU, MEAN_MULTI, MEAN_TRL, MEAN_NONUM, LIST_TYPE, L1_SELECT, MIN_BCT, MAX_BCT
	from (select ID_HU, min(L1_SELECT) as L1_SELECT,
			mean(MULTI) as MEAN_MULTI, mean(TRAILER) as MEAN_TRL,
			mean(NO_NUMBER) as MEAN_NONUM, min(LIST_TYPE) as LIST_TYPE,
			min(BUILDING_UNIT_CT) as MIN_BCT, max(BUILDING_UNIT_CT) as MAX_BCT
		from l2
		group by ID_HU) as l
	inner join anal.hu_level(keep=ID_HU L1 L2 ) as h
	on l.ID_HU = h.ID_HU;



data huchars2;
	merge huchars(in=INDISS) obs2(drop=SAMPLEID);
	by ID_HU;

	* only problem is with cases with 2 listings where one thinks multi, other thinks not;
	if MEAN_MULTI >= .5 then MULTI=1;
	else if MEAN_MULTI < .5 then MULTI=0;
	
	* if any lister thinks its a trailer then its a trailer;
	if MEAN_TRL > 0 then TRAILER=1;
	else TRAILER=0;

	* cannot be both multi unit and trailer;
	if MULTI and TRAILER then do;
		MULTI=0;
		TRAILER=1;
	end;

	if MULTI=1 then do;
		if MIN_BCT > 19 then MULTI_LARGE19 = 1;
		else MULTI_LARGE19 = 0;

		if MIN_BCT > 9 then MULTI_LARGE9 = 1;
		else MULTI_LARGE9 = 0;
	end;
	else do;
		MULTI_LARGE19 = 0;
		MULTI_LARGE9 = 0;
	end;

	* if any lister thinks no number then no number;
	if MEAN_NONUM > 0 then NO_NUMBER=1;
	else NO_NUMBER=0;

	if L1_SELECT=1 then SELECTED=1;

	if INDISS;
run;


proc freq data=huchars2;
	tables MULTI*MEAN_MULTI TRAILER NO_NUMBER*MEAN_NONUM SELECTED
		MULTI*(MULTI_LARGE: HU_TYPE_OBS) HU_TYPE_OBS PHYS: OVER45_OBS CHILDREN_OBS /list missing;
	title 'Review HU level characteristics';
run;

* merge in HU obs for selected cases;




* add these HU level chars to anal.hu_level;
proc sort data=anal.hu_level tagsort; by ID_HU; run;
proc sort data=huchars2; by ID_HU; run;

data anal.hu_level2 hu_probs;
	merge anal.hu_level(in=INHU drop=SELECTED) huchars2(in=INCHARS);
	by ID_HU;

	if not INHU then output hu_probs;
	else if INHU then output anal.hu_level2;

	drop L1_SELECT MIN_BCT MAX_BCT;

	label MULTI_LARGE19 = "Unit in multi unit building > 19 units"
		MULTI_LARGE9 = "Unit in multi unit building > 9 units";
run;

proc print data=hu_probs noobs;
	title 'PROBLEM: Bad merge in 5.4';
run;
