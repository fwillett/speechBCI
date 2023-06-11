#!/usr/local/bin/gawk -f
#
# subtract-ppls --
#	Subtracts text statistics (from -ppl output)
#
#	The first input file contains a total, from which subsequent stats are
#	discounted.  The result is printed in a format compatible with -ppl.
#
# Copyright (c) 1995, SRI International.  All Rights Reserved
#
# $Header: /home/srilm/CVS/srilm/utils/src/subtract-ppls.gawk,v 1.2 1997/07/12 05:01:08 stolcke Exp $
#
/^file .*: .* sentences/ {
	if (ARGIND == 1) {
		totalsents = $3;
		totalwords = $5;
		totaloovs = $7;
	} else {
		totalsents -= $3;
		totalwords -= $5;
		totaloovs -= $7;
	}

	getline;

	if (ARGIND == 1) {
		zeroprobs = $1;
		totalprob = $4;
	} else {
		zeroprobs -= $1;
		totalprob -= $4;
	}
}
END {
	M_LN10 = 2.30258509299404568402;        # from <math.h>

	ppl = exp (- M_LN10 * totalprob / \
			(totalwords - totaloovs - zeroprobs + totalsents));

	printf "file TOTAL: %d sentences, %d words, %d OOVs\n", \
			totalsents, totalwords, totaloovs;
	printf "%d zeroprobs, logprob= %g ppl= %g\n", \
			zeroprobs, totalprob, ppl;
}
