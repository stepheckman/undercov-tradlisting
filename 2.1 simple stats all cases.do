set more off
capture log close

capture log close
log using "$results/2.1_simplestats_allcases_$date.smcl", replace



** weight to use here is seg_wgt, which is uncond. prob of selection of seg
* excluding hh selection, 2 ph and NR adjustment
* including selection into my study, and psu selection
* this is the right weight, because hh selection not relevant
*    when all listed HUs are used




**********************************************************
* univariate -- all listed cases

use hulist2, replace
$drpsegs
keep if listing==2

* because all cases used, need only seg level weight seg_wgt
d seg_wgt 
sum seg_wgt 
svyset seg_id [pw=seg_wgt]

* unweighted match rate
mean l2 if l1==1

* weighted match rate, clustered SE
svy: mean l2 if l1==1




**********************************************************
* cases per segment

use hu2, replace
$drpsegs

collapse (sum) l1 l2 , by(seg_id) 

* 46 segments
sum l*, det 




**********************************************************
* lister level data
use hulist2, replace

keep if listing != 3
$drpsegs

capture drop ilister
egen ilister = tag(lister listing)
keep if ilister
gen college = (educ>=4)

* chars of listers in first & second listing
mean intwer_afam other_lang college access_gated yrs_exper ///
	other_job langmatch, over(listing)
	
bys listing: sum yrs_exper

	


**********************************************************
* segments per lister
use hu2, replace
$drpsegs	

collapse (first) l2_id, by(seg_id)

collapse (count) seg_ct = seg_id, by (l2_id)

* number of segments  per lister
sum seg_ct

sort seg_ct
li


	
**********************************************************
* bivariate analysis 

use hulist2, replace
$drpsegs
keep if listing==2
drop if l1==0

svyset seg_id [pw=seg_wgt]

mat results = J(26,4,.)

local d = 0
local vc multi trailer map_simple rural_bin lowinc_bin ///
	map_nvbb car2 langmatch safety_concerns other_job
	
capture postclose bivar_results_allcases
capture drop bivar_results_allcases
tempname d
postfile `d' str25(var) double mean0 double mean1 int n0 int n1 ///
	double F double probF using bivar_results_allcases, replace


foreach v in `vc' {

	qui {

		svy: mean l2, over(`v')
		capture mat drop n b
		mat n = e(_N)
		mat b = e(b)
		mat list n
		mat list b

		svy: logit l2 `v'
		test `v'==0

		post `d' ("`v'") (b[1,1]) (b[1,2]) (n[1,1]) (n[1,2]) (e(F)) (r(p))
	}
}
postclose `d'

use bivar_results_allcases, replace

li var n0 mean0 n1 mean1 F probF 



**********************************************************
* SF, MF listing rates

use hulist2, replace
$drpsegs
keep if listing==2
drop if l1==0

svyset seg_id [pw=seg_wgt]

svy: mean sf

svy: mean l2, over(mf)
test [l2]0 = [l2]1

svy: mean l2, over(multi_status)
test [l2]_subpop_2 = [l2]_subpop_3



capture log close


exit
