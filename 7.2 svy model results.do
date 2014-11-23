clear all
set more off

capture log close
log using "$results/7.2_svymodels_results_$date.smcl", replace


*************************************************************
** report full models -- all correctly listed cases

use models_goodhu_fit, clear
/*
est use a0
est sto a0
*svy: logit
svy: logit, or
estat gof, all
*/
est use g1
est sto g1
*svy: logit
svy: logit, or
lincom multi_sm-multi_lrg

capture predict lhat_1
estat gof, all
estadd scalar Fgof = r(F)
estadd scalar pgof = r(p)

/*
est use g2
est sto g2
*svy: logit
svy: logit, or
lincom 1.multi_sm-multi_lrg
capture predict lhat_2
estat gof, all
estadd scalar Fgof = r(F)
estadd scalar pgof = r(p)
*/

esttab g1, ///
	stats(N Fgof pgof) se constant star(+ 0.10 * 0.05) ///
	refcat(multi_sm "HU:" krural "seg:" krural "urban")

esttab g1 using "$results\7_svymodel_goodcases_$date.tex", ///
	stats(N Fgof pgof) replace constant booktabs star(+ 0.10 * 0.05) se ///
	refcat(multi_sm "HU:" krural "seg:" krural "urban") /// 
	eqlabels("" "Segment random effect") 

est use g1
* from page 157 long & freese
lowess listed lhat_1, ylabel(0(.2)1, grid) xlabel(0(.2)1, grid) ///
	addplot(function y=x) 
	
	
* look at cases where prediction is off (esp where prediction < actual)
gen prob = (lhat_1<.4 & listed==1)
tab prob
table seg_id prob, row 
li lhat_1 listed $huiv1 $ivs if prob, noobs
exit

* alternative measure of lroc, found on web
* there are higher than what I developed
clear all
use models_goodhu_fit, clear
qui {
est use g1
predict pp1 
somersd listed pp1 [pweight=hh_wgt], tr(c)
matrix b1 = e(b)
local auc1 = b1[1,1]

est use g2
predict pp2
somersd listed pp2 [pweight=hh_wgt], tr(c)
matrix b2 = e(b)
local auc2 = b2[1,1]
}

di   "Area under the Curve, g1 model: " %6.5f `auc1'
di   "Area under the Curve, g2 model: " %6.5f `auc2'


exit

















*************************************************************
** report full models -- complete cases only

use models_allcases_fit, clear

/*
est use c0
est sto c0
*svy: logit
svy: logit, or
estat gof, all
*/
est use a1
est sto a1
*svy: logit
svy: logit, or
lincom multi_sm-multi_lrg
capture predict lhat_1
estat gof, all
estadd scalar Fgof = r(F)
estadd scalar pgof = r(p)

est use a2
est sto a2
*svy: logit
svy: logit, or
lincom 1.multi_sm-multi_lrg
capture predict lhat_2
estat gof, all
estadd scalar Fgof = r(F)
estadd scalar pgof = r(p)

est use g1
est sto g1

esttab a1 g1, ///
	stats(N Fgof pgof) se constant star(+ 0.10 * 0.05) 

/*
esttab c1, ///
	stats(N Fgof pgof) se constant star(+ 0.10 * 0.05) ///
	refcat(multi_sm "HU:" krural "seg:" krural "urban")

esttab c1 c2 using "$results\7_svymodel_allcases_$date.tex", ///
	stats(N Fgof pgof) replace constant booktabs star(+ 0.10 * 0.05) se ///
	order($huiv krural vrural safety_concerns map_interior lt25k_pct access_gated ///
		map_nvbb multi_nvbb car2 multi_car2 ///
		langmatch multi_langmatch yrs_exper multi_exper) ///
	refcat(multi_sm "HU:" krural "seg:" krural "urban") /// 
	eqlabels("" "Segment random effect") 
*/

*save models_compcases_fit, replace


* from page 157 long & freese
/*lowess listed lhat_2, ylabel(0(.2)1, grid) xlabel(0(.2)1, grid) ///
	addplot(function y=x) 
*/	


* look at cases where prediction is off (esp where prediction < actual)
gen prob = (lhat_2<.4 & listed==1)
li $ivs $interact if prob, noobs


* alternative measure of lroc, found on web
* there are higher than what I am reporting
clear all
use models_compcases_fit, clear
qui {

est use c1
predict pp1 
somersd listed pp1 [pweight=wgt2ph], tr(c)
matrix b1 = e(b)
local auc1 = b1[1,1]

est use c2
predict pp2
somersd listed pp2 [pweight=wgt2ph], tr(c)
matrix b2 = e(b)
local auc2 = b2[1,1]
}

di   "Area under the Curve, c1 model: " %6.5f `auc1'
di   "Area under the Curve, c2 model: " %6.5f `auc2'





capture log close
exit








* lroc for interaction model
forv m = 1/2 {
est use g`m'

qui {
tempfile cuts`m'
tempname cuts`m'
postfile `cuts`m'' double(cutoff sens spec) using `cuts`m'', replace

forv i = 0(1)1000 {
	capture drop pred`i' i11 i10 i01 i00 sens spec
	* get prediction (yes/no) for this case using i as cutoff
	gen pred`i' = (lhat_`m' > `i'/1000)
	* get indicators for cells of 2x2 table
	egen i11 = total(pred`i' & listed)
	egen i01 = total(!pred`i' & listed)
	egen i00 = total(!pred`i' & !listed)
	egen i10 = total(pred`i' & !listed)
	gen sens = i11/(i11+i01)
	gen spec = i00/(i00+i10)
	post `cuts`m'' (`i'/1000) (sens) (spec)
	*tab pred50 listed
	capture drop pred`i' i11 i10 i01 i00 sens spec
}

postclose `cuts`m''
}
* output auc stat for each model
preserve
	use `cuts`m'', replace

	gen spec2 = 1-spec

	*
tw scatter sens spec2

	gen a = 0 if cutoff==0
	replace a = abs(sens*(spec2-spec2[_n-1])) if cutoff!=0
	
	egen area_`m' = total(a)
	sum area_`m'
restore
}
