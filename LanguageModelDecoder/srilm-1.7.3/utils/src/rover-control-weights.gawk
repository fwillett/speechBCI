#!/usr/local/bin/gawk -f
#
# rover-control-weights --
#	retrieve or change weights in rover-control file
#
# usage:
#  retrieving
#	rover-control-weights rover-control 
#  changing:
#	rover-control-weights weights="..." rover-control > new-rover-control
#
# $Header: /home/srilm/CVS/srilm/utils/src/rover-control-weights.gawk,v 1.3 2017/08/16 06:34:16 stolcke Exp $
#

NR == 1 {
	if (weights) {
	    nweights = split(weights, w);
	}
	output_weights = "";
}

/^##/ || /^[ 	]*$/ {
	# pass through comment or empty line
	print;
	next;
}

$3 == "+" {
	if (weights) {
	    print;
	}
	next;
}
{
	# dir lmw wtw weight max_nbest scale 
	if (weights) {
	    # fill in missing parameter values
	    if (NF < 2) $2 = 8;
	    if (NF < 3) $3 = 0;

	    if (++ sysno <= nweights) {
		if ($4 == "=" && w[sysno] == w[sysno-1]) {
		    # preserve weight tying if new weights are compatible
		    ;
		} else {
		    $4 = w[sysno];
		}
	    } else {
		$4 = 1;
	    }
	    print;
	} else {
	    if (NF < 4) $4 = 1;
	    output_weights = output_weights " " $4;
	}
}

END {
	if (!weights) {
	    sub("^ ", "", output_weights);
	    print output_weights;
	}
}
	

