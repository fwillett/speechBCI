#!/usr/local/bin/gawk -f
#
# make-gt-discounts --
#	generate Good-Turing discounting parameters from a count-of-count
#	file
#
#	The purpose of this script is to do the GT computation off-line,
#	without ngram-count having to read all counts into memory.
#	The output is compatible with the ngram-count -gt<n> options.
#
# $Header: /home/srilm/CVS/srilm/utils/src/make-gt-discounts.gawk,v 1.3 2004/11/02 02:00:35 stolcke Exp $
#
# usage: make-gt-discounts min=<mincount> max=<maxcount> countfile
#
BEGIN {
    min=1;
    max=7;
}
/^#/ {
    # skip comments
    next;
}
{
    countOfCounts[$1] = $2;
}
END {
    # Code below is essentially identical to GoodTuring::estimate()
    # (Discount.cc).
    minCount = min;
    maxCount = max;

    if (!countOfCounts[1]) {
	printf "warning: no singleton counts\n" >> "/dev/stderr";
	maxCount = 0;
    }

    while (maxCount > 0 && countOfCounts[maxCount + 1] == 0) {
	printf "warning: count of count %d is zero -- lowering maxcount\n", \
	       maxCount + 1 >> "/dev/stderr";
	maxCount --;
    }

    if (maxCount <= 0) {
	printf "GT discounting disabled\n" >> "/dev/stderr";
    } else {
	commonTerm = (maxCount + 1) * \
				countOfCounts[maxCount + 1] / \
				    countOfCounts[1];

	for (i = 1; i <= maxCount; i++) {

	    if (countOfCounts[i] == 0) {
		printf "warning: count of count %d is zero\n", \
			i >> "/dev/stderr";
		coeff = 1.0;
	    } else {
		coeff0 = (i + 1) * countOfCounts[i+1] / \
					    (i * countOfCounts[i]);
		coeff = (coeff0 - commonTerm) / (1.0 - commonTerm);
		if (coeff <= 0 || coeff0 > 1.0) {
		    printf "warning: discount coeff %d is out of range: %g\n", \
			 i, coeff >> "/dev/stderr";
		    coeff = 1.0;
		}
	    }
	    discountCoeffs[i] = coeff;
	}
    }

    printf "mincount %d\n", minCount;
    printf "maxcount %d\n", maxCount;

    for (i = 1; i <= maxCount; i++) {
	printf "discount %d %g\n", i, discountCoeffs[i];
    }
}
