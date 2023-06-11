#!/usr/local/bin/gawk -f
#
# get-unigram-probs --
#	extract unigram probabilities from backoff LM file
#
# usage: get-unigram-probs bo-file
#
# $Header: /home/srilm/CVS/srilm/utils/src/get-unigram-probs.gawk,v 1.3 2018/06/28 07:45:08 stolcke Exp $
#

BEGIN {
	linear = 0;

	currorder = 0;
	logzero = -99;
}

/^\\[0-9]-grams:/ {
	currorder = substr($0,2,1);
	next;
}

/^\\/ {
	currorder = 0;
	next;
}

currorder == 1 && NF > 0 {
	if (NF < 2) {
	    print "line " NR ": missing word" > "/dev/stderr";
	} else if (linear) {
	    print $2, $1 == logzero ? 0 : 10^$1;
	} else {
	    print $2, $1 == logzero ? "-infinity" : $1;
	}
	next;
}

