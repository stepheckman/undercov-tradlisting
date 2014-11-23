set more off
capture log close

capture log close
log using "$results/2.2_simplestats_compcases_$date.smcl", replace



** weight to use here is hh_wgt2ph, which is uncond. prob of selection of HH
* excluding NR adjustment
* including selection into my study, 2ph sample, and psu and seg selection
* this is the right weight, because 2ph DOES affect completion




**********************************************************
* univariate  

use hu2, replace
$drpsegs
keep if complete == 1 

d, short
d hh_wgt2ph
sum hh_wgt2ph
svyset seg_id [pw=hh_wgt2ph]

* unweighted match rate
mean l2 if l1==1

* weighted match rate, clustered SE
svy: mean l2 if l1==1





**********************************************************
* cases per segment

use hu2, replace
$drpsegs2
keep if complete == 1

collapse (sum) l1 l2 complete_cases=disp_intw, by(seg_id) 

* 43 segments
sum l* *cases if complete_cases!=0, det




	
**********************************************************
* bivariate analysis 

use hulist2, replace
$drpsegs
keep if listing==2
drop if l1==0
keep if complete == 1

svyset seg_id [pw=hh_wgt2ph]

mat results = J(26,4,.)

local d = 0
local vc multi vacant trailer disp_scr_comp map_simple rural_bin ///
	lowinc_bin map_nvbb car2 langmatch safety_concerns other_job
	
capture postclose bivar_results_compcases
capture drop bivar_results_compcases
tempname d
postfile `d' str25(var) double mean0 double mean1 int n0 int n1 ///
	double F double probF using bivar_results_compcases, replace


foreach v in `vc' {

	qui {

		svy: mean listed, over(`v')
		capture mat drop n b
		mat n = e(_N)
		mat b = e(b)
		mat list n
		mat list b

		svy: logit listed `v'
		test `v'==0

		post `d' ("`v'") (b[1,1]) (b[1,2]) (n[1,1]) (n[1,2]) (e(F)) (r(p))
	}
}
postclose `d'

use bivar_results_compcases, replace

li var n0 mean0 n1 mean1 F probF 



**********************************************************
* SF, MF listing rates

use hulist2, replace
$drpsegs
keep if listing==2
drop if l1==0
keep if complete == 1

svyset seg_id [pw=hh_wgt2ph]

svy: mean sf

svy: mean listed, over(mf)
test [listed]0 = [listed]1

svy: mean listed, over(multi_status)
test [listed]_subpop_2 = [listed]_subpop_3



capture log close

exit
