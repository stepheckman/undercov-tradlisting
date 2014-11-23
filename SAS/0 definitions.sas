/* 

Name: J:\diss\paper2\analysis\SAS\code\definitions.sas
Started: 10/4/2009;

define libnames, macro variables, macros, formats, etc. for NSFG data prep programs

*/



options stimer=off mlogic mprint symbolgen nofmterr compress=yes 
	fmtsearch=(segs anal intw rfemale rmale) nodate orientation=landscape;

* excel versions of L1, before and after QC;
%let list_b4 = J:\NSFG\Q12 listings\Q12 Original Listings some fixes.xls;
%let list_aft = J:\NSFG\Q12 listings\Q12 listings after fixes.xls;

* Q12 dispositions at case level
	contains ALL Q12 cases, not just those in my 49 segments
	delivered by Sarrah B. 10/16/2009;
%let disps = J:\diss\Tpaper\SAS\data\Q12 result codes\Q12ScreenerSample.xls;

* meaning of those disposition codes
	delivered by Sarrah B. 10/16/2009;
%let resltcd = J:\diss\Tpaper\SAS\data\Q12 result codes\codes.xls;

* manual matches of input lines;
%let maninput = J:\diss\Tpaper\SAS\data\manual input matches\manual matches.xls;

* manual matches of input lines;
%let manmatch = J:\diss\Tpaper\SAS\data\3 way match\manual matches5.xls;

* threshold for large multis
	large ones are have MORE (>) units than this;
%let lrgmulti = 19;

* census data;
%let census = c:\census data\;


libname segs 'J:\NSFG\Q12 segment selection';
libname blkdata 'L:\Sample Design\Yr3 Segments\blocks';  * year3 libname in James code;
*libname exper '\\stat2\stephnie\experian\archive\VersionFeb2009';
*libname experdoc '\\stat2\stephnie\experian\Document\VersionFeb2009';
*libname load 'J:\diss\NSFG management\prepare files for sample loading\load files\';   
libname anal 'J:\diss\Tpaper\SAS\data';
*libname match 'J:\diss\paper2\analysis\SAS\data\match';
libname match 'C:\Documents and Settings\stephnie\My Documents\data\match';
libname st odbc dsn='NSFG_ST' uid='stephnie' pwd='cu7x7jj' schema=dba;

* trying to uncover line selection probabilities
	dug these up myself 3/27/2010 (SE)
	may not be accurate;
* datasets related to double sampling of Q12;
libname double 'L:\Sample Design\Double Sample\Yr3_Q12' access=readonly;
* datasets related to within segment selection rates for Q12;
libname linesamp 'L:\Sample Design\Line Sample\Rates' access=readonly;

* Q12 response data;
libname resp "J:\diss\Tpaper\SAS\data\response_data\" access=readonly;
libname rfemale "L:\Eckman_Listing\Q12 Data for Stephanie\Female";
libname rmale "L:\Eckman_Listing\Q12 Data for Stephanie\Male";

* from James code;
libname update "L:\Sample Design\Line Sample\Updated Listings" access=readonly;

* interviewer quex data;
libname intw "L:\Eckman_Listing\FRQ Data For Stephanie\Brady Merged FRQ Data";
* one addl interviewer completed quex;
libname intw2 "L:\Eckman_Listing\FRQ Data For Stephanie\2009 data incl. 2010 Record";

* from Frost--example delivery datasets;
libname deliver1 'L:\Sample Design\Line Sample\Line Frame\Q12';
libname deliver2 'L:\Sample Design\Segments\tListing_PSU_Segment\Q12';

* data directory for Stata;
%let local = C:\Documents and Settings\stephnie\My Documents\data;
libname stata "&local.\tpaper";
libname local "&local.";

* path for all output files;
%let output = J:\diss\Tpaper\SAS\output;

* path for SAS code;
%let code = J:\diss\Tpaper\SAS\code;

* path for SAS data directory;
%let dt = J:\diss\Tpaper\SAS\data;


* all selected PSUS, both NSFG original PSUs and mine;
%let selpsus = '120','122','131','141','154','194','230','234','262','292','332','354','362',
	'820', '822', '831', '841', '854', '894', '830', '834', '862', '892', '832', '853', '863',
	'920', '922', '931', '941', '954', '994', '930', '934', '962', '992', '932', '953', '963';

* all selected segments, using both original NSFG numbering and my numbering;
%let selsegs = '120105', '120203', '120363', '120428', '122152', '122351', '122353', '131101',
'131206', '131271', '141153', '141253', '141257', '154253', '154351', '154356', '154451', '154452', '154456',
'194153', '194351', '194354', '194358', '194361', '194368', '230155', '230253', '230254', '234153', '234252',
'234255', '262251', '262256', '262455', '292352', '292353', '292354', '292361', '292452', '292453', '332152', 
'332153', '332155', '354153', '354155', '354451', '362157', '362158', '362253', '820105', '820203', '820363',
'820428', '822152', '822351', '822353', '831101', '831206', '831271', '841153', '841253', '841257', '854253',
'854351', '854356', '854451', '854452', '854456', '894153', '894351', '894354', '894358', '894361', '894368',
'830155', '830253', '830254', '834153', '834252', '834255', '862251', '862256', '862455', '892352', '892353',
'892354', '892361', '892452', '892453', '832152', '832153', '832155', '853153', '853155', '853451', '863157',
'863158', '863253', '920105', '920203', '920363', '920428', '922152', '922351', '922353', '931101', '931206',
'931271', '941153', '941253', '941257', '954253', '954351', '954356', '954451', '954452', '954456', '994153',
'994351', '994354', '994358', '994361', '994368', '930155', '930253', '930254', '934153', '934252', '934255',
'962251', '962256', '962455', '992352', '992353', '992354', '992361', '992452', '992453', '932152', '932153',
'932155',  '953153', '953155', '953451', '963157', '963158', '963253';

* VPROJECTID associated with my segments
	found via freq on st.tlistng_psu_segment 
	where VSAMPLELINEID in (&selsegs.);
%let prjs = 'SRC.SRO.NSFG.STTEST.LIST', 'SRC.SRO.NSFG.PROD.LIST';

%let seed = 30091972;


* cases is known household;
%let dsphh = 1001, 5003, 6002, 6005, 6007, 6009, 7002, 7003, 8010, 8080;
* cases completed screener (may or may not be eligible);
%let dspscrc = 1001, 8010;
* cases not eligible for screener (vacant, noresidential, etc.);
%let dspoos = 7001, 7003, 8001, 8003;
* cases that were good listings, all codes but SLIP; 
%let dspgood = 1001, 5003, 6002, 6005, 6007, 6009, 7001, 7002, 7003, 8003, 8010, 8080;
* cases eligible for main NSFG interivew;
%let dspelig = 1001;




%let fvars =  AGESCRN MARSTAT EVRMARRY HISP RRACE1 ROSCNT NUMCHILD HHKIDS18 GOSCHOL HIGRADE HAVEDEG MOMDEGRE
DADDEGRE NUMBABES MENARCHE PREGNOWQ NUMPREGS EVERPREG CURRPREG OTHERKID NOTHRKID
SEEKADPT LVTOGHX PREVHUSB BIOCP BIONUMCP LIVEOTH EVERSEX RHADSEX AGEFSTSX GRFSTSX SXMTONCE LIFEPRT LIFEPRT_LO 
LIFEPRT_HI EVERTUBS EVERHYST PILL CONDOM WIDRAWAL MAINNOUSE BCCNS12 RWANT HLPMC DIABETES OVACYST LIMITED
EQUIPMNT ATTNDNOW STAYTOG SAMESEX LESSPLSR BINGE12 VAGSEX AGEVAGR ANYORAL ANALSEX PARTSLIF_1 SAMESEXANY STDTRT12
WAGE TOTINC FMINCDK1 FMINCDK2 FMARITAL MAREND01 AGER EDUCAT COVER: 
HISPANIC ANYMTHD ANYPRGHP EVHIVTST CURR_INS RELIGION LABORFOR COMPREG FMARNO NONMARR SEXEVER SEXP3MO CONDOMR
MTHUSE12 INFEVER POVERTY INFERT AGEPRG01 AGECON01 ABORTION LBPREGS CEBOW AGEBABY1;

%let mvars =  AGESCRN MARSTAT EVRMARRY HISP RRACE1 ROSCNT GOSCHOL HIGRADE HAVEDEG MOMDEGRE DADDEGRE
EVERSEX RHADSEX SXMTONCE LIFEPRT CURRPREG RWANT LIMITED EQUIPMNT ATTNDNOW STAYTOG SAMESEX LESSPLSR BINGE12
VAGSEX AGEVAGR ANYORAL ANALSEX PARTSLIF_1 SAMESEXANY STDTRT12 WAGE TOTINC FMINCDK1 FMINCDK2 
AGER FMARITAL EDUCAT HISPANIC FMARNO NONMARR CEBOW CURR_INS EVHIVTST RELIGION COVER:
LABORFOR POVERTY AGEBABY1 COMPREG ABORTION INFEVER MAREND01 ;




%include 'J:\diss\Tpaper\SAS\code\00 macros.sas';



proc format library=anal;
	value hutype 
		1 = 'Single family home (including townhouses)'
		2 = 'Structure with 2 to 9 units'
		3 = 'Structure with 10-49 units'
		4 = 'Structure with 50 or more units'
		5 = 'Mobile home' 
		7 = 'Other';
	value qc 
		0 = '0 No QC action'
		1 = '1 deleted by Sarrahs QC'
		2 = '2 added by Sarrahs QC'
		3 = '3 block move'
		4 = '4 address edit';                                                
	value EDITION                                                              
		1 = "1st ed, 2008";                                               
	value listtype
		1 = "1 Traditional"
		2 = "2 Dependent" ; * from data dictionary table for vType field in tListing_PSU_Segment;
	value yesno
		1 = "1 Yes"
		0 = "0 No";
	value supp
		0 = "0 Not supressed"
		1 = "1 All housing units on street segment suppressed"
		2 = "2 Two unit building turned into 1 unit"
		3 = "3 Last unit in multi-unit building suppressed"
		4 = "4 Other unit in multi-unit building suppressed"
		5 = "5 Single unit suppressed"
		6 = "6 Entire multi-unit building suppressed";
	value add
		0 = "0 Not added"
		1 = "1 Unit added to end of multi-unit"
		2 = "2 More than one unit added to end of multi-unit"
		3 = "3 Unit added in middle of multi-unit (difficult to do convincingly)"
		4 = "4 Add SF or MF in midst of other numbers (e.g. 524 between 520 and 544)"
		5 = "5 Add units to SF to make MF"
		6 = "6 Units added across the street (e.g. even instead of odd)"
		7 = "7 Units added on new street segment";
	value manipgrp
		1 = '1 high adds, high deletes'
		2 = '2  low adds, high deletes'
		3 = '3 high adds, low  deletes'
		4 = '4  low adds, low  deletes';
	value psutype
		1 = '1 SR'
		2 = '2 NSR, MSA'
		3 = '3 NSR non-MSA'
		4 = '4 AK, HI';
	value unmtype
		1 = '1 line on input only, no match to frame before code 2.2'
		2 = '2 line on input and frame, but unlisted on frame before code 2.2'
		3 = '3 VLINE_NUM on both frames but address does not match';
	value disp
		1001 = '1001 Completed Screener: Eligible Respondent'
		5003 = '5003 Screener Refusal'
		6002 = '6002 Final No Contact, Unknown HH'
		6005 = '6005 Language Barrier'
		6007 = '6007 Other NIR'
		6009 = '6009 Locked Building/Gated Community, DK if Eligible HH'
		7001 = '7001 Vacant'
		7002 = '7002 Subsampled out'
		7003 = '7003 Occupants Currently Reside Elsewhere e.g. Seasonal Residence '
		8001 = '8001 SLIP'
		8003 = '8003 Vacant Trailer Site'
		8010 = '8010 Completed Screener: No Eligible Respondent'
		8080 = '8080 No Screener completed, ineligible by Proxy or HHM';
	*value mtchtype
		0 	= '0 Match by ID'
		1   = '1 Match on all address parts'
		7   = '7 Match on #, street name and apartment' 
		9.1 = '9.1 Apartment number inconsistent'
		9.2 = '9.2 Suspected typo in house number'
		9.3 = '9.3 Suspected typo in street name'
		9.4 = '9.4 More suspicious match'
		9.5 = '9.5 Match with at least 1 NO#, based on placement and description';
	value mtchtypp
		1   = '1 Exact matches on full address across'
		2   = '2 match macros pass 1'
		3   = '2 match macros pass 2'
		4   = '2 match macros pass 3'
		5   = '2 match macros pass 4'
		6   = '2 match macros pass 5'
		7   = '2 match macros pass 6'
		8   = '2 match macros pass 7'
		9   = '3 manual match';
	value mantyp /* manual match type */
		1 = '1 Apartment number inconsistent'
		2 = '2 Suspected typo in house number'
		3 = '3 Suspected typo in street name'
		4 = '4 More suspicious match'
		5 = '5 Match with at least 1 NO#, based on placement and description'
		6 = '6 No clear reason why not matched earlier';
	*value manflag
		1   = '1 removed match due to manual review'
		2   = '2 changed match due to manual review';
run;

********************************************************************************************
* selection for my dissertation (49 out of 104, in 2 strata)
* dataset: ** none **

* at segment level
	derived from J:\diss\NSFG management\segment selection\seg select routine.xls

* these segments selected with certainty from 104
	referred to as strata 1 and 2 in spreadsheet;
%let cert = '120105' '120203' '120363' '120428' '122152' '122351' '122353' '131101' '131206' '131271' '154253' '154351' '154356'
'154451' '154452' '154456' '194153' '194351' '194354' '194358' '194361' '194368' '234153' '234252' '234255' '292352' '292353' '292354'
'292361' '292452' '292453' '332152' '332153' '332155' '354153' '354155' '354451' '362157' '362158' '362253';
%let cprob = 1;

* these segments selected with < 100% probability
	note that selection was actually of PSUs, not segments;
* prob is 3 out of 23
	3 PSUs selected out of 23 in this strataum (stra 3 in spreadsheet);
%let noncert = '141153' '141253' '141257' '230155' '230253' '230254' '262251' '262256' '262455';
%let ncprob = 3/23;

********************************************************************************************
* adjustment for selection of year 3 from all years and selection of quarter 12 from quarters in year 3
* super-8: adjust segment probs by 1/16 for quarter 12 out of all 16 quarters
* non-super-8: adjust psu probs by 1/4 (year 3 out of 4 years)
	seg probs by 1/4 as all (quarter 12 out of 4 quarters in year 3);
%let psadjp = 1/16;

