#!/usr/local/bin/gawk -f
#
# add-ppls --
#	Add text statistics (from -ppl output)
#
# Copyright (c) 1995,1997 SRI International.  All Rights Reserved
#
# $Header: /home/srilm/CVS/srilm/utils/src/add-ppls.gawk,v 1.2 1997/07/12 05:01:08 stolcke Exp $
#
/^file .*: .* sentences/ {
	totalsents += $3;
	totalwords += $5;
	totaloovs += $7;

	getline;

	zeroprobs += $1;
	totalprob += $4;
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
