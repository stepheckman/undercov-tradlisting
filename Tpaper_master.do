/* 

Name: J:\diss\paper2\analysis\Stata\code\master.do
Started: 10/13/2009;

master code for paper 2 analysis

input datasets: 
	HUlist 		-- HU listing level dataset
	HU			-- HU level dataset

*/

global date 20121123
*global mdate 20120306

qui do "J:\diss\Tpaper\Stata\code\0 definitions.do"

qui do "$code\1 data prep.do"

do "$code\2 simple stats.do"

do "$code\3 match results.do"

do "$code\4 appendix.do"

* look for relationship between coverage and response
do "$code\5 coverage response.do"

do "$code\7 undercov models.do"

do "$code\8 bias.do"
