#!/usr/local/bin/gawk -f
#
# compare-ppls --
#	Compare two LMs for significant differences in probabilities
#	The probabilities calculated for the test set words are ranked
#	pairwise, as appropriate for submitting the result a sign test.
#
# usage: compare-ppls [mindelta=d] pplout1 pplout2
#
# where pplout1, pplout2 is the output of ngram -debug 2 -ppl for the two
# models.  d is the minimum difference of logprobs for two probs to 
# be considered different.
#
# $Header: /home/srilm/CVS/srilm/utils/src/compare-ppls.gawk,v 1.6 2014-07-03 05:57:09 stolcke Exp $
#
function abs(x) {
	return (x < 0) ? -x : x;
}
BEGIN {
	sampleA_no = 0;
	sampleB_no = 0;
	mindelta = 0;
	verbose = 0;
	signif = 0;

	diff_sum = 0;
	diff_squared_sum = 0;

	logINF = -100000;
}
FNR == 1 {
	if (!readingA) {
		readingA = 1;
	} else {
		readingA = 0;
	}
}
readingA && $1 == "p(" {
	if ($0 ~ /\[ -[Ii]nf|\[ -1\.#INF/) prob = logINF;
	else prob = $10;

	sampleA[sampleA_no ++] = prob;
}
!readingA && $1 == "p(" {
	if ($0 ~ /\[ -[Ii]nf|\[ -1\.#INF/) prob = logINF;
	else prob = $10;

	if (sampleB_no > sampleA_no) {
		printf "sample B contains more data than sample A" >> "/dev/stderr";
		exit(1);
	}
	
	diff = sampleA[sampleB_no] - prob;

	if (abs(diff) <= mindelta) {
	    equal ++;
	} else {
	    diff_sum += diff;
	    diff_squared_sum += diff * diff;

	    if (diff < 0) {
		    if (verbose) {
			    print;
		    }
		greater ++;
	    }
	}

	sampleB_no ++;
}
END {
	if (sampleB_no < sampleA_no) {
		printf "sample B contains less data than sample A" >> "/dev/stderr";
	print sampleB_no, sampleA_no;
		exit(1);
	}

	mean_diff = diff_sum / sampleA_no;
	mean_sq_error = diff_squared_sum / sampleA_no - mean_diff * mean_diff;
	stdev = sqrt(mean_sq_error);

	printf "total %d, equal %d, different %d, greater %d\n", \
			sampleB_no, equal, sampleB_no - equal, greater;
	printf "meandiff %g, mse %g, stdev %g\n", \
			mean_diff, mean_sq_error, stdev;

	if (signif) {
	    printf "significance:\n";
	    less = sampleB_no - equal - greater;
	    system("cumbin " (less+greater) " " (less>greater ? less : greater));
	}
}
