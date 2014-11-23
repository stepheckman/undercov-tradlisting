* see 8.bais.do for explanaton of notation used below (method1,2 a,b,c)
set more off
	
use bias_data, replace

gen undercov = (l1==1 & l2==0)
tab2 undercov l1 l2, firstonly

keep *id* rweight $biasvars l1 l2 undercov
save bias_method1, replace


* expand dataset to make method 2 work
* these new cases are those in set c, needed for method 2
expand 2 if l1==1 & l2==0, gen(newcase)

* new cases (set C) inherit weight from set A

* reset variables on these cases
replace l1=0 if newcase
replace l2=1 if newcase

* make indicators for the three sets of cases (a,b,c)
* explained in 8 bais.do file
* don't need these but I like to have them!
gen seta = (l1==1 & l2==0)
gen setb = (l1==1 & l2==1)
gen setc = (l1==0 & l2==1)

drop undercov
gen undercov = (l1==1 & l2==0)
tab2 undercov l1 l2, firstonly

save bias_method2, replace



* save results of method 1 here
tempname method1
postfile `method1' str20 variable int(n) ///
	double(mean_true mean_cov b_reg var_reg) ///
	using biasvar_method1, replace

* save results of method 2 here
tempname method2
postfile `method2' str20 variable int(n) ///
	double(mean_true mean_cov b_reg var_reg) ///
	using biasvar_method2, replace


forv m = 1/2 {
	use bias_method`m', replace
	svyset seg_id [pweight=rweight]
	d, short
	
	tab undercov

	foreach v in $biasvars {	

		capture mat drop *
				
		* true overall mean in this method: Yab
		qui: mean `v' [pweight=rweight]
		mat true = e(b)
		mat n = e(_N)

		* mean in L2 covered cases only: Yb
		qui: mean `v' if l2==1 [pweight=rweight]
		mat cov = e(b)

		* regression to see if undercov indicator is sig in diff of means of var `v'	
		di
		di
		di "****** `v' ******"
		svy: reg `v' undercov
		mat b = e(b)
		mat var = e(V)
				
		post `method`m'' ("`v'") (n[1,1]) (true[1,1]) (cov[1,1]) (b[1,1]) (var[1,1])
	}
	postclose `method`m''
		
		
	use biasvar_method`m', replace
	
	gen bias = mean_cov - mean_true	
	gen relbias = bias/mean_true
	
	gen se_reg = sqrt(var_reg)
	gen tstat_reg = b_reg/se_reg
	
	gen sig_relbias_m`m' = 3 if abs(tstat_reg) > abs(invttail($df,1-0.01/2)) & !mi(se_reg)
	replace sig_relbias_m`m' = 2 if abs(tstat_reg) > abs(invttail($df,1-0.05/2)) & !mi(se_reg) & mi(sig_relbias_m`m')
	replace sig_relbias_m`m' = 1 if abs(tstat_reg) > abs(invttail($df,1-0.1/2)) & !mi(se_reg) & mi(sig_relbias_m`m')
	replace sig_relbias_m`m'=0 if mi(sig_relbias_m`m')
	
	lab var mean_true "mean on full sample"
	lab var relbias "relative bias due to undercoverage in L2"
	lab var sig_relbias_m`m' "indicator for sig bias > 0"
	lab var se_reg "std error of regression coefficient est"
	lab var tstat_reg "t statisitic of regression coefficient est"
	lab var b_reg "regression coefficient est"	
	
	tab sig
	li variable relbias sig if sig>0

	capture drop _merge
	qui: compress
	save biasvar_method`m', replace	
}
exit

* test that svy: mean and svy: prop give the same results as the svy: reg method

use bias_method1, replace
svyset seg_id [pweight=rweight]

svy: mean abortion, over(undercov)
lincom _b[0] - _b[1]

svy: prop pill, over(undercov)
lincom [_prop_2]0 - [_prop_2]1 
