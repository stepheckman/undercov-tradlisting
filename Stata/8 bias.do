**********************************************************************
* calcs of bias and variance
* R level weight

clear
set more off


global df 43

	
* 3/5/2012
* now 2 methods to calc bias
* let A be set of L1 only cases
* let B be set of L1 & L2 cases
* let C be set of L2 only cases -- we don't know about these

* true relbias is (Ybc - Yabc)/Yabc
* method1: relbias = (Yb - Yab)/Yab
* method2: relbias = (Yab - Yaab)/Yaab
*	using weights to upweight A cases by 2

do "$code\8.1 calc bias and var.do"



* create one dataset of reuslts from both methods together
use biasvar_method1, replace
rename relbias relbias_m1
rename se se_relbias_m1
rename tstat_reg tstat_reg_m1
keep relbias se variable n sig tstat_reg_m1

merge 1:1 variable using biasvar_method2
assert _merge==3

rename relbias relbias_m2
rename se_relbias se_relbias_m2
rename tstat_reg tstat_reg_m2
keep relbias* se* variable n sig* tstat_reg_m*
capture drop _merge

gen pvalue_m1 = round(ttail($df, abs(tstat_reg_m1)),.001)
gen pvalue_m2 = round(ttail($df, abs(tstat_reg_m2)),.001)
format pvalu* %8.3f
sum pv*

lab var relbias_m1 "method1: assume L1 has no undercoverage" 
lab var relbias_m2 "method2: assume L1 undercov just like L2 undercov"
lab var pvalue_m1 "p value assoc with reg test of sig. bias, method 1"
lab var pvalue_m2 "p value assoc with reg test of sig. bias, method 2"

save biasresults, replace


qui do "$code\8.2 bias graphs.do"


set more off
capture log close
log using "$results\8_bias_$date.smcl", replace

use biasresults, replace
keep if n > 350

qui do "$code\8.2.1 var labels and types.do"
drop if vartype=="Opinion"
foreach v in $dropv {
	drop if variable == "`v'"
}

li variable vartype2 relbias_m1 sig*_m1 if inlist(sig_relbias_m1,1,2,3)
li variable vartype2 relbias_m2 sig*_m2 if inlist(sig_relbias_m2,1,2,3)

tab2 vartype2 sig_relbias*, firstonly

sort relbias_m1
li var2 relbias*

gsort vartype2 relbias_m1 
format relbias* %5.2f
format pvalue* %5.3f
replace relbias_m1 = relbias_m1*100
replace relbias_m2 = relbias_m2*100
li var2 n relbias_m1 pvalue_m1 relbias_m2 pvalue_m2, ///
	sepby(vartype2) compress

capture log close

exit 






*format mean_m1 %5.2f 
format relbias* se* %5.4f

sort vartype2 relbias_m1 relbias_m2
li vartype2 var2 relbias_m1 se_relbias_m1 sig_relbias_m1 ///
	relbias_m2 se_relbias_m2 sig_relbias_m2
	
listtex var2 relbias_m1 se_relbias_m1 relbias_m2 se_relbias_m2 ///
	using "$results\bias_output_$date.tex", replace rstyle(tabular)	
