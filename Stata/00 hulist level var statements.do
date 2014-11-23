recode other_jobs (1 = 1) (5 = 0)
recode nsfgbefore (1 = 1) (5 = 0)
recode other_company (1 = 1) (5 = 0)

recode stylus (1 = 1) (5 = 0)
recode current_school (1 = 1) (5 = 0)
recode hispanic (1 = 1) (5 = 0)
recode other_lang (1 = 1) (5 = 0)
recode blaccess_none (1 = 0) (0 = 1), gen(access_probany)

rename race intwer_race
rename hispanic intwer_hisp 
rename blaccess_gated access_gated
rename blaccess_none access_noprob
rename blaccess_other access_other
rename blaccess_seasonal_hazard access_season
rename blaccess_unimproved_roads access_roads
rename istructure_type seg_hutype
rename isegment_type seg_type
rename isafety_concerns safety_concerns
rename other_scr other_src
rename hhincome intwer_income
rename blnon_english_lang_spanish spanish_seg

* lister had someone else with her
gen partner=1 if blfoot_not_alone==1
replace partner=1 if blcar_driver==1
replace partner=0 if mi(partner)

gen intwer_afam = 1 if intwer_race==4
replace intwer_afam = 0 if intwer_race != 4

* language match between lister and segment
gen langmatch = 1 if other_lang==1
replace langmatch=1 if other_lang==0 & spanish_hhs_pct==0
replace langmatch=0 if mi(langmatch)

* race (african-american) match between lister and segment
gen racematch = 1 if afam_pct < .1 & intwer_afam == 0
replace racematch = 1 if afam_pct > .1 & intwer_afam == 1
replace racematch = 0 if mi(racematch)


* at least one year of experience
capture drop exper1
gen exper1 = 1 if yrs_exper > 0
replace exper1 = 0 if mi(exper1) & !mi(yrs_exper)

* lister in school OR has other job
gen committments = (other_jobs | current_school)


/* only 1 seg is vrural with this set up, not appropriate
gen krural = (pct_rural > 0 & pct_rural < 1)
gen vrural = pct_rural==1
lab var krural "some rural HUs in block group"
lab var vrural "entirely rural block group"
*/
gen rural = pct_rural > 0 & !mi(pct_rural)
lab var rural "block group partially or entirely rural"


gen res_seg = (seg_type==1)
gen comm_seg = (seg_type==2)
lab var res_seg "residential segment"
lab var comm_seg "commercial segment"



* log of years of experience
capture drop lexper
gen lexper = log(yrs_exper)
replace lexper = 0 if yrs_exper==0


* indicates lister listed by car (either as passengar or as driver)
capture drop car
gen car = 1 if blcar_alone==1
replace car = 1 if blcar_driver==1
replace car = 0 if mi(car)
* car2 means drove alone
gen car2 = 1 if blcar_alone==1
replace car2 = 0 if mi(car2)

* listing method
capture drop dep_method
gen dep_method = 1 if listing==1 & list_type==1
replace dep_method = 0 if listing==1 & list_type==2
replace dep_method = 0 if listing==2
replace dep_method = 1 if listing==3


* any precipitation on listing day
capture drop anyprecip
gen anyprecip = 1 if precip > 0.1
replace anyprecip = 0 if mi(anyprecip)

* interact selected with not first listing
capture drop sel_l23
gen sel_l23 = 1 if selected==1 & listing != 1
replace sel_l23 = 0 if selected==0 | listing==1

destring(lister), gen(lister_id)

gen hu_trailers = 1 if seg_hutype==1
replace hu_trailers=0 if seg_hutype!=1

gen hu_multi = 1 if seg_hutype==3 | seg_hutype==4 | seg_hutype==5
replace hu_multi = 0 if mi(hu_multi)


****** interactions



* interact safety and multi
gen safety_multi = safety_concerns * multi

* interact lister obs
gen safetygated = 1 if safety_concerns==1 & access_gated==1
replace safetygated = 0 if mi(safetygated)

gen gt50kgated = gt50k_pct if access_gated==1
replace gt50kgated = 0 if mi(safetygated)

* crime rate interacted with access problems due to gated communities
*	this is listing level because access is listing level
capture drop crimegated
gen crimegated = 1 if crime_high==1 &  access_gated==1
replace crimegated = 0 if !(crime_high==1 & access_gated==1)

gen multi_car = multi * car
*gen multi_afam_listseg = multi * afam_listseg
*gen multi_span_listseg = multi * spanish_listseg

*gen multi_listafam = multi * intwer_afam
*gen multi_listspan = multi * other_lang
gen multi_car2 = car2 * multi
gen lmatch_multi = langmatch * multi


lab var sel_l23 "Selected and in listing 2,3"
lab var nsfgbefore "Lister worked on previous NSFG studies"
lab var dep_method "Segment listed with dependent listing"
lab var car "Lister drove or was driven while listing"
lab var anyprecip "More than .1in recorded precipitation on day most listings completed, in zipcode"
lab var exper1 "Lister has at least 1 yr experience as in-person interviewer"
lab var lexper "Log of years of experience 0 = 0 "
lab var listing "Listing 1 2 3"
lab var listed "HU listed in listing"
lab var intwer_race "Race of interviewer"
lab var intwer_hisp "Interviewer Hispanic"
lab var seg_hutype "Type of HUs in segment, seg level"
lab var seg_type "Segment residential, commericial, mix"
lab var access_gated "Gated communities in segment"
lab var access_noprob "No barriers to access in segment "
lab var access_season "Seasonal access problems in segment"
lab var access_roads "Unimproved roads in segment"
lab var married "Intwer marital status"
lab var intwer_income "Intwer HH income"
lab var inon_english_speakers "Evidence of non-English speakers in block"
lab var access_probany "Lister reports any problem with access to HUs in segment"
lab var safety_concerns "Lister reports any safety concerns in segment"
lab var partner "Lister listed with partner (ex: driver)"
*lab var spanish_listseg "Lister speaks Spanish and in Spanish-speaking segment (measured by Census data)"
lab var intwer_afam "Lister African-American"
*lab var afam_listseg "Lister is African-American * AfAm pop pct in segment"
*lab var spanish_seg "Lister indicates presence of spanish speakers"
lab var safetygated "Lister reports unsafe and gated HUs"
lab var gt50kgated "Income gt 50k and gated 50s"
*lab var multi_afam_listseg "3 way interaction of multi unit with lister race and segment race"
*lab var multi_afam_listseg "3 way interaction of multi unit with lister spanish and segment language"
lab var multi_car "Interaction of multi-unit with lister drove"
lab var car2 "Lister drove herself while listing"
lab var other_jobs "Lister holds another job"
lab var other_lang "Lister speaks Spanish"
lab var afam_pct "Pct. Pop. Afr.-Amer."
lab var map_nvbb "Map, invisible boundary"
lab var car "Lister drove or was driven"
lab var safety_concerns "Lister feels unsafe"
lab var no_number "Unit has no house number"
lab var disp_oos "Vacant"
*lab var spanish_listseg "Lister and segment Spanish"
*lab var multi_span_listseg "Multi * lister and segment Spanish"
*lab var multi_listspan "Multi * Spanish segment"
*lab var spanish_multi "Multi * lister Spanish"
lab var safety_multi "Multi * lister feels unsafe"
lab var pct_rural "Pct. HUs rural"
lab var trailer "Trailer"
lab var multi "Multi-Unit"
lab var multi_car2 "Multi * lister drove"
lab var spanish_hhs_pct "Pct. Pop Spanish language"
lab var langmatch "Lister and segment language match"
lab var lmatch_multi "Multi * Language match"
lab var racematch "Lister and segment race match"
lab var committments "lister in schoool or has another job"

lab val access_gated yesno
lab val access_probany yesno
lab val access_noprob yesno
lab val access_other yesno
lab val access_season yesno
lab val access_roads yesno
lab val current_school yesno
lab val stylus yesno
lab val other_jobs yesno
lab val sel_l23 yesno
lab val dep_method yesno
lab val nsfgbefore yesno
lab val anyprecip yesno
lab val listed yesno
lab val educ educ
lab val intwer_hisp yesno
lab val blcar_alone yesno
lab val blcar_driver yesno
lab val blfoot_alone yesno
lab val blfoot_not_alone yesno
*lab val spanish_listseg yesno
lab val blnon_english_lang_other yesno
lab val inon_english_speakers yesno
lab val safety_concerns yesno
lab val seg_type segtype
lab val seg_hutype strcttyp
lab val crime_high yesno
lab val crime_p1_high yesno
lab val violent_crime yesno
lab val income_high yesno
lab val afam_high yesno
lab val multi_high yesno
lab val other_lang yesno
lab val religion relig
lab val married marital
lab val other_company yesno
lab val other_src yesno
lab val other_mode prevmode
lab val intwer_race raceeth
lab val intwer_income income
lab val r_object agree
lab val r_persuade agree
lab val r_reluctant agree
lab val same_sex agree
lab val any_sex agree
lab val otherjob jobtype
lab val car yesno
lab val on_input yesno
lab val safetygated yesno
lab val gt50kgated yesno
lab val car2
lab val hu_type_obs hutype

* these vars reported all missing by codebook command
capture drop bldemolition_of_hus
capture drop blfound_count_discrepancy
capture drop blimpediment_bars
capture drop blimpediment_dog
capture drop blimpediment_none
capture drop blimpediment_security_door
capture drop blimpediment_security_signs
capture drop blimpediment_trespassing_sign
capture drop bllarge_apt_not_in_est
capture drop blnew_construction
capture drop blother_discrepancy
capture drop blstructure_church
capture drop blstructure_commercial
capture drop blstructure_community_center
capture drop blstructure_industrial
capture drop blstructure_library
capture drop blstructure_residential
capture drop blstructure_school
capture drop iblock_num_inconsistency_count
capture drop ilisting_print_count
capture drop isame_zip_codes
capture drop isegment_count_listed
capture drop isegment_count_total
capture drop istreet_name_inconsistancy_count
capture drop istreet_num_inconsistancy_count
capture drop iunihabitable_housing
capture drop lvmos_discrepancy_notes
capture drop vaccess_seasonal_hazard_specify
capture drop vstructure_type_other_specify



