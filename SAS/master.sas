/* 

Name: J:\diss\paper2\analysis\SAS\code\master.sas
Started: 10/4/2009;

master code file for prepping NSFG listings
	3 listings of 49 segments

match listings and output to Stata for analysis

*/


%include 'J:\diss\Tpaper\SAS\code\0 definitions.sas';



proc delete data=work._ALL_;
run;


* output info about all datasets in ST lib and make local copies of relevant lines;
*%include 'J:\diss\paper2\analysis\SAS\code\0.1 SurveyTrak datasets.sas';


* prep lines, segment and blocks for matching;
%include "&code.\2 line prep for matching.sas";


%include "&code.\3 matching.sas";


*%include "&code.\4.1 output locations for weather lookup.sas";

**** do not rerun 4.2, input files no longer exist;
*%include "&code.\4.2 census data.sas";

%include "&code.\5 merge in response data.sas";

* save final datasets in stata libname;
%include "&code.\6 finalize and output.sas";

