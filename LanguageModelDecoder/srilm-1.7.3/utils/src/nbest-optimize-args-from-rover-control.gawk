#!/usr/local/bin/gawk -f
#
# nbest-optimize-args-from-rover-control --
#	Extract initial score weights and arguments from rover-control file
#	for use with nbest-optimize
#
# $Header: /home/srilm/CVS/srilm/utils/src/nbest-optimize-args-from-rover-control.gawk,v 1.2 2017/08/16 06:34:16 stolcke Exp $
#

BEGIN {
	num_extras = 0;
}

# skip comment or empty line
/^##/ || /^[ 	]*$/ {
	next;
}

# extra score file line
$3 == "+" {
	num_extras ++;
	extra_dir[num_extras] = $1;
	extra_weight[num_extras] = $2;
	next;
}

# main system 
{
	system_dir = $1;
	lm_weight = $2;
	wt_weight = $3;
	max_nbest = $5;
	post_scale = $6;

	weights = "1 " lm_weight " " wt_weight;
	for (i = 1; i <= num_extras; i ++) {
	    weights = weights " " extra_weight[i];
	}

	if (print_weights) {
	    print weights;
	} else if (print_dirs) {
	    for (i = 1; i <= num_extras; i ++) {
		print extra_dir[i];
	    }
	} else {
	    # output all arguments

	    if (post_scale != "" && post_scale != 0) {
		print "-posterior-scale " post_scale;
	    }
	    if (max_nbest != "" && max_nbest != 0) {
		print "-max-nbest " max_nbest;
	    }

	    print "-init-lambdas '" weights "'";

	    for (i = 1; i <= num_extras; i ++) {
		print extra_dir[i];
	    }
	}

	num_extras = 0;
}
