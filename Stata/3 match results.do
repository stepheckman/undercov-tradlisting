set more off

capture log close
log using "$results\3_match_results_$date.smcl", replace


**********************************************************
* coverage rate by segments

use hu2, replace
$drpsegs
drop if l1==0

* unweighted here, because no variability WITHIN SEGMENT
* when using all cases
collapse (mean) cover_rate=l2 (count) id_hu, by(seg_id)

replace cover_rate = cover_rate * 100

sum id_hu, det

sort cover_rate
gen id_seg3 = _n
	
twoway (scatter cover_rate id_seg3, sort mcolor(black) msymbol(oh) msize(vlarge)), ///
	ytitle("Percent of Housing Units Covered", size(vlarge)) ylabel(20(20)100, labsize(huge)) ///
	xtitle("Segments (n=46)", size(huge)) xlabel(, nolabels noticks) scheme(s1mono) 
graph export "$results\covrate_byseg_allcases_$date.eps", replace

tempfile all
save `all'



**********************************************************
* coverage rate by listers

use hu2, replace
$drpsegs
drop if l1==0

* weighted here by seg weight, which is also HH weight when all cases used
collapse (mean) cover_rate=l2 [pw=seg_wgt], by(l2_id)
	
replace cover_rate = cover_rate * 100

sort cover_rate
gen id_lister3 = _n
	
twoway (scatter cover_rate id_lister3, sort mcolor(black) msymbol(oh) msize(vlarge)) , ///
	ytitle("Percent of Housing Units Covered", size(vlarge)) ylabel(20(20)100, labsize(huge)) ///
	xtitle("Listers (n=11)", size(huge)) xlabel(, nolabels noticks) scheme(s1mono) 
graph export "$results\covrate_bylister_allcases_$date.eps", replace

li 
	
	
	
capture log close

exit







**********************************************************
* coverage rate by segments -- completed cases only

use hulist2, replace

keep if complete

* weighted here by HH selection including 2 phase
* weighting does not include PSU and segment selection
* because grouping here is BY SEGMENT
collapse (mean) cover_rate=l2 [pw=cond_wgt2ph], by(seg_id)

replace cover_rate = cover_rate * 100

sort cover_rate
gen id_seg3 = _n
	
twoway (scatter cover_rate id_seg3, sort mcolor(black) msymbol(oh) msize(vlarge)), ///
	ytitle("Percent of Housing Units Covered", size(vlarge)) ylabel(20(20)100, labsize(huge)) ///
	xtitle("Segments (n=43)", size(huge)) xlabel(, nolabels noticks) scheme(s1mono) 
graph export "$results\covrate_byseg_$date.eps", replace
 



**********************************************************
* put 2 coverage by segment graphs together

rename cover_rate cov_completes
merge 1:1 seg_id using `all'
rename cover_rate cov_all

* together graph
sort cov_all
gen id_seg4 = _n

twoway (scatter cov_all id_seg4, sort mcolor(black) msymbol(th) msize(vlarge)) ///
	|| (scatter cov_completes id_seg4, sort mcolor(black) msymbol(oh) msize(vlarge)), ///
	ytitle("Percent of Housing Units Covered", size(vlarge)) ylabel(20(20)100, labsize(huge)) ///
	xtitle("Segments (n=46)", size(huge)) xlabel(, nolabels noticks) scheme(s2mono) ///
	legend(on label(1 "All Cases") label(2 "Completed Cases"))
graph export "$results\covrate_byseg_both_$date.eps", replace
	
li
