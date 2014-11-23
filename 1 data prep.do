********
* some problems with lister IDs in delivered data
* see Sharon Parker email 11/13/2010
* these problems fixed in SAS
********

set more off
capture log close


*qui do "$code\00 value labels.do"

******************************************************************
* process response dataset

* my_hh_prob -- HH level prob, constant within seg, merged on HU dataset
	* controls for PSU, seg, HH and dissertation selection
	* but not for respondent or 2phase sample
* my_hh_2ph_prob -- HH level prob, constant within seg, merged on HU dataset
	* controls for PSU, seg, HH, 2phase and dissertation selection
	* but not for respondent 
use rdata, replace
keep id_hu seg_id my_hh_prob my_hh_2ph_prob mycond* my_seg* cond_r_prob disp*

$drpsegs

* there should be 46 unique values
* i.e. all segments have only 1 probability
qui: unique seg_id my_hh_prob
assert r(sum)==46

** HH level weight, conditional on all previous selections
gen cond_hhwgt2ph = 1/mycond_hh_2ph

** seg level weights, including adj for psu, my selection, my quarter
gen seg_wgt = 1/my_seg_prob	

* gen weight = cond_hhwgt2ph * seg_wgt // this is equal to hh_wgt2ph
gen cond_rwgt = cond_hhwgt2ph * 1/cond_r_prob if disp_intw==1

gen hh_wgt = 1/my_hh_prob
gen hh_wgt2ph = 1/my_hh_2ph_prob


gen rweight = hh_wgt2ph * 1/cond_r_prob if disp_intw==1

lab var rweight "overall Resp weight, reflecting all stages, but not NR adj"
lab var hh_wgt "uncond hh weight, incl my study, w/o r sel, 2phase samp or NR adj"
lab var hh_wgt2ph "uncond hh weight, incl my study & 2ph, w/o r sel or NR adj"
lab var cond_rwgt "hh and respondent weight, cond on seg selection, for bias anal within seg"
lab var cond_hhwgt2ph "hh level weight, includes 2ph, conditional on seg"
lab var seg_wgt "seg level weight, includes adj for psu, my selection, my quarter"

sum *hh_wgt* rweight
	
* make seg level dataset, to get probs on all cases, even non-selected
preserve
	keep seg_id hh_wgt seg_wgt
	duplicates drop
	sum hh_wgt seg_wgt
	
	tempfile wgts
	save `wgts'
restore

* hh_wgt comes from seg level (`wgts' dataset) thus not needed here

* hh_wgt is weight to use when analyzing all cases togheter, selected and unselected
* hh_wgt2ph is weight to use when analyzing selected cases (accounts for 2 phase sampling)
* rweight is weight to use when using response data to make inference to population
* cond_hhwgt2ph used to do calcs on completed cases, but only WITHIN seg

keep id_hu hh_wgt hh_wgt2ph rweight cond_hhwgt2ph
sum hh_wgt hh_wgt2ph rweight cond_hhwgt2ph
tempfile wgts2
save `wgts2'


use hu, replace

qui do "$code\00 hu level var statements.do"

* get l2 lister id on dataset
rename lister l1_id
lab var l1_id "id of l1 lister"
capture drop _merge

tempfile k
save `k'

use hulist, replace
keep if listing==2
keep id_hu lister
rename lister l2_id
lab var l2_id "id of l2 lister"

* merge in L2 lister id
merge 1:1 id_hu using `k'
assert _merge==3
drop _merge

* merge in weights that are constant for all HUs in segment
merge m:1 seg_id using `wgts'
assert _merge != 2
keep if _merge==3
drop _merge

keep if l1==1 

* rescale weights by number of units in each seg
* so not count not too big
sum hh_wgt l1 l2 selected
egen N_perseg = count(id_hu), by(seg_id)
egen n_perseg = total(selected), by(seg_id)
gen f_perseg = n_perseg/N_perseg
replace hh_wgt = hh_wgt * f_perseg
drop *perseg

* merge in weights that account for 2phase sampling (sel units only)
merge 1:1 id_hu using `wgts2'
assert _merge != 2
drop _merge

svyset seg_id [pw=hh_wgt]

qui: compress
save hu2, replace




*****************************************************************
* process hulist dataset

/* 

Name: J:\diss\paper2\analysis\Stata\code\2 import HUlist.do
Started: 10/14/2009;

import HU listing level dataset and create new vars

input datasets: 
	HUlist		-- HU level dataset

*/

use rdata, replace
keep id_hu $vars disp* my* roscnt quex numchild hhkids18 
sort id_hu
lab val quex quex
tempfile d
save `d'


use hulist, replace
sort id_hu

merge m:1 id_hu using `d', keep(master match)
drop _merge 

merge m:1 seg_id using `wgts', keep(master match)
assert _merge != 2
keep if _merge==3 // drops the 3 drpsegs
drop _merge

* rescale weights by number of units in each seg
* so not count not too big
sum hh_wgt l1 l2 selected
egen N_perseg = count(id_hu), by(seg_id)
egen n_perseg = total(selected), by(seg_id)
gen f_perseg = n_perseg/N_perseg
replace hh_wgt = hh_wgt * f_perseg
drop *perseg

* id one case in each segment & listing
egen id_seg2 = tag(seg_id listing)

qui do "$code\00 hu level var statements.do"
qui do "$code\00 hulist level var statements.do"


* dep_method wrong on listing 1
replace dep_method=1 if listing==1 & l1_dep==1
replace dep_method=0 if listing==1 & l1_trad==1


* will contain some units not listed by anyone
$drpsegs
*keep if listing==2
keep if l1+l2 > 0

drop addr* apt* str_* match* manmatch* on_input

*gen listerl1 = lister if listing==1
bys id_hu (listing): gen lister_l1 = lister[1] if listing[1]==1
bys id_hu (listing): gen car2_l1 = car2[1] if listing[1]==1

lab var lister_l1 "lister ID for first listing"
lab var car2_l1 "car2 for first listing"
lab var lister "lister ID for second listing"
lab var lister_id "lister ID for second listing, as num"

* merge in weights
capture drop _merge	
merge m:1 id_hu using `wgts2', keep(match master)

sum hh_wgt* rweight 
sum hh_wgt* rweight if complete


qui do "$code\0 model labels.do"

xtset seg_id
* hh_wgt is weight to use when analyzing all cases togheter, selected and unselected
svyset seg_id [pw=hh_wgt]
* hh_wgt2ph is weight to use when analyzing selected cases (accounts for 2 phase sampling)
* rweight is weight to use when using response data to make inference to population

capture drop _merge
qui compress
save hulist2, replace



exit


* all lines listed by first lister, listing 2
keep if listing == 2 & l1==1
keep if l1+l2 > 0

capture drop _merge	
qui compress
save models_trad, replace

* only selected lines, listing 2
keep if selected==1 & disp_listelig==1

capture drop _merge
qui compress
save models_tradsel, replace



* only completed cases, listing 2
keep if disp_intw==1

capture drop iseg ilister
egen iseg = tag(seg_id)
egen ilister = tag(lister_id)

$svy

do "$code\1.1 response var recodes.do"

capture drop _merge
qui compress
save bias_data, replace




*************************************************************
* dataset for LP models 

use hulist2, replace
$drpsegs
keep if listing==2
drop if l1==0

* when using ALL listed cases
* weight for HHs = seg_wgt because no within seg selection
svyset seg_id [pw=seg_wgt]

capture drop iseg
egen iseg = tag(seg_id)

qui: compress
capture drop _merge
save models_allcases, replace

** create dataset of only selected cases flagged as good listings
* weight is HH selection weight, incl seg, psu, my study
* excluding 2ph and NR adj
keep if selected & disp_listelig
svyset seg_id [pw=hh_wgt]

capture drop iseg
egen iseg = tag(seg_id)

save models_goodhu, replace

** create dataset of only completed cases
* weight is HH selection weight, incl seg, psu, my study, 2ph
* excluding NR adju
keep if complete
svyset seg_id [pw=hh_wgt2ph]

capture drop iseg
egen iseg = tag(seg_id)

save models_compcases, replace

