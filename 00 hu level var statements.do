* labels for HU level variables


* id one case in each segment 
egen id_seg = tag(seg_id)


gen multi_sm = 1 if multi & !multi_large9
replace multi_sm = 0 if mi(multi_sm)

gen multi_lrg = 1 if multi & multi_large9
replace multi_lrg = 0 if mi(multi_lrg)



* replace HU chars coded from listings with hu_type_obs variables from interviewers
* when hu obs available

rename trailer trailer_old
rename multi_sm multi_sm_old 
rename multi_lrg multi_lrg_old 
rename multi multi_old
lab var multi_old "multi coded from address"

gen multi = inlist(hu_type_obs,2,3,4) if !mi(hu_type_obs)
replace multi = multi_old if mi(hu_type_obs)
tab multi multi_old, mis
lab var multi "multi status obs by intwer, by addr is missing"

gen trailer = (hu_type_obs==5) if !mi(hu_type_obs)
replace trailer = trailer_old if mi(hu_type_obs)
replace trailer = 0 if multi

gen multi_sm = hu_type_obs==2 if !mi(hu_type_obs)
replace multi_sm = multi_sm_old if mi(hu_type_obs)
gen multi_lrg = inlist(hu_type_obs,3,4) if !mi(hu_type_obs)
replace multi_lrg = multi_lrg_old if mi(hu_type_obs)
gen mf = multi
gen sf = !multi

egen pctmulti = mean(multi), by(seg_id)

gen multi_status = 1 if sf
replace multi_status = 2 if multi_sm
replace multi_status = 3 if multi_lrg




* create tags for segments and listers
egen iseg = tag(seg_id)
egen ilister = tag(lister)

gen complete = (disp_intw==1)

*capture rename id seg_num

capture drop nomatch
capture drop multi_listers
capture drop domain
capture drop dep
capture drop lines_bqc
capture drop lines_aqc
capture drop qc_none
capture drop qc_edit
capture drop qc_delete
capture drop qc_blkmv
capture drop mean_multi
capture drop mean_trl
capture drop mean_nonum
capture drop seg_num
* this var left over from when I thought listing done incorrectly
capture drop samelist12


* aggregate map flags
egen map_problem = rowmax(map_wrongshape map_interior map_mislabel map_nolocate)

* some code may want a var named add

destring seg, gen(seg_num)
capture drop l1_dep
capture drop l1_trad
gen l1_trad=1 if (nsfg_psu==141 & seg_num==253) | ///
	(nsfg_psu==154 & seg_num==351) | ///
	(nsfg_psu==234 & seg_num==153) | ///
	(nsfg_psu==292 & seg_num==361) | ///
	(nsfg_psu==332 & seg_num==152) | ///
	(nsfg_psu==332 & seg_num==153) | ///
	(nsfg_psu==332 & seg_num==155) | ///
	(nsfg_psu==354 & seg_num==153) | ///
	(nsfg_psu==354 & seg_num==155) | ///
	(nsfg_psu==362 & seg_num==157) | ///
	(nsfg_psu==362 & seg_num==158)
replace l1_trad=0 if mi(l1_trad)
gen l1_dep = 1 - l1_trad

/* flag lines that are first in segment
capture drop id_seg
sort seg_id
by seg_id: gen id_seg = _n==1
*/

* recode gt 50 k income as lt 50 k income
gen lt50k_pct = 1-gt50k_pct

* divide segs into income above and below median
* calc median only on one obs in each seg
sum lt50k_pct if iseg==1, d
gen lowinc_med = r(p50)
gen lowinc_bin = 1 if lt50k_pct > lowinc_med
replace lowinc_bin =0 if lt50k_pct <= lowinc_med

* few disp changes
replace disp_scr_comp = . if selected==0
gen vacant = (disp==7001 | disp==7003) if !mi(disp)
gen eligible = disp_scr_comp
replace eligible = 0 if disp==8010

* interact pct afam with multi and pct spanish with multi
gen afam_multi = afam_pct * multi
gen spanish_multi = spanish_hhs_pct * multi

* flag segments where first and second listings done by same lister
gen samelist12=1 $samelistsegs
replace samelist12=0 if mi(samelist12)
lab var samelist12 "Segment listed by same listr in L1 and L2"

gen rural_bin2 = 1 if pct_rural==0
replace rural_bin2 = 2 if pct_rural < 1 & mi(rural_bin2)
replace rural_bin2 = 3 if pct_rural == 1 & mi(rural_bin2)

gen lt25k_pct = 1-gt25k_pct


capture lab var seg_num "Full NSFG PSU segment number"
*lab var id_seg "Flags first obs in a segment, for creating seg level stats"
lab var seg_id "Segment id from NSFG_PSU and SEG"
lab var income_high "Tract median income over median"
lab var multi "HU in multi-unit building"
lab var trailer "HU is trailer"
lab var no_number "HU address has no number"
lab var pct_multi "Percent of listed units multi-unit in first listing"
lab var disp_oos "Case not eligible for screener: subsampled out, vacant, seasonal"
lab var list_type "Type of listing used in L1"
lab var l1_dep "L1 used dependent listing"
lab var l1_trad "L1 used traditional listing"
lab var lt50k_pct "Pct. HHs with income <= 50,000, BG level"
lab var vacant "HU vacant during data collection (selected only)"
lab var eligible "HU screened and eligible (selected only)"
lab var multi_sm "Multi and in building < 10 units"
lab var multi_lrg "Multi and in building >= 10 units"
lab var multi_status "SF, small, large multi unit"
lab var rural_bin2 "pct_rural in 3 bins"
lab var lt50k_pct "Pct. HHs with income <= 50,000"

lab def multi_status 1 "Single Family" 2 "Small Multi-unit" ///
	3 "Large Multi-unit"

lab val multi yesno
lab val multi_sm yesno
lab val multi_lrg yesno
lab val multi_large9 yesno
lab val multi_large19 yesno
lab val no_number yesno
lab val disp dsp
lab val disp_hh yesno
lab val disp_oos yesno
lab val disp_listelig yesno
lab val disp_scr_comp yesno
lab val list_type listtype
lab val l1_dep yesno
lab val l1_trad yesno
lab val multi_status multi_status
lab val hu_type_obs hutype







