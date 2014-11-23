* svy logit models
set more off


**********************************************************
* models on correctly listed cases only

set more off
use models_goodhu, replace
svyset

* null model
svy: logit listed, or
est stor g0
est save g0, replace

svy: logit listed $huiv2 $ivs
est stor g1
est save g1, replace

* add in interactions with multi
svy: logit listed $huiv2 $iv_inter
est stor g2
est save g2, replace

qui:compress
save models_goodhu_fit, replace


**********************************************************
* models on all cases

use models_allcases, replace
svyset

* null model
svy: logit listed, or
est stor a0
est save a0, replace

svy: logit listed $huiv1 $ivs
est stor a1
est save a1, replace

* add in interactions with multi
svy: logit listed $huiv1 $iv_inter
est stor a2
est save a2, replace

qui:compress
save models_allcases_fit, replace

exit 








**********************************************************
* models on completed cases only

use models_compcases, replace
svyset

* null model
svy: logit listed, or
est stor c0
est save c0, replace

svy: logit listed $ivs, or
est stor c1
est save c1, replace

* add in interactions with multi
svy: logit listed $ivs $interacts, or
est stor c2
est save c2, replace

qui:compress
save models_compcases_fit, replace





