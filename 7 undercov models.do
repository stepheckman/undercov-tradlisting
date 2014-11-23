set more off
clear all

global huiv1 multi_lrg trailer 
global huiv2 multi_sm multi_lrg trailer vacant

global ivs ///
	map_nvbb access_gated rural car2 ///
	safety_concerns langmatch lt25k_pct l1_trad map_wrongshape ///
	map_interior map_nolocate 
*assert map_prob==1 if map_inter==1 | map_wrong==1 | map_nolocate
	
global iv_inter map_nvbb map_interior access_gated rural car2 ///
	b0.multi_sm##(safety_concerns langmatch c.lt25k_pct)
/* b0.rural##b0.car2 doesn't work -- only 1 seg rural and walked
		(and this was the only sig cell in 2x2) 
multi_sum#yrs_exper does not estimate */

/*multi_sm#car2 multi_sm#langmatch ///
	multi_sm#safety_concerns multi_sm#c.lt25k_pct 
* multi_gated does not estimate*/

qui do "$code\7.1 fit svy models.do"

do "$code\7.2 svy model results.do"

*do "$code\7.3 interaction effects.do"


exit


