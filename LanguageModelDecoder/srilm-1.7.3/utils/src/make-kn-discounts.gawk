#!/usr/local/bin/gawk -f
#
# make-kn-discounts --
#	generate modified Kneser-Ney discounting parameters from a
#	count-of-count file
#
#	The purpose of this script is to do the KN computation off-line,
#	without ngram-count having to read all counts into memory.
#	The output is compatible with the ngram-count -kn<n> options.
#
# $Header: /home/srilm/CVS/srilm/utils/src/make-kn-discounts.gawk,v 1.7 2015-05-27 08:10:52 stolcke Exp $
#
# usage: make-kn-discounts modified=<0|1> min=<mincount> countfile
#
BEGIN {
    min = 1;
    modified = 1;
}

/^#/ {
    # skip comments
    next;
}

{
    countOfCounts[$1] = $2;
    if ($1 != "total" && $1 > maxCount && $2 > 0) {
	maxCount = $1;
    }
}

#
# Estimate missing counts-of-counts f(k) based on the empirical law
#
#	log f(k) - log f(k+1) = a / k
#
# for some constant a dependent on the distribution.
#
function handle_missing_counts() {

    #
    # compute average a value based on well-defined counts-of-counts
    #
    a_sum = 0;

    for (k = maxCount - 1; k > 0; k --) {
	if (countOfCounts[k] == 0) break;

	a =  k * (log(countOfCounts[k]) - log(countOfCounts[k + 1]));

	if (debug) {
		print "k = " k ", a = " a > "/dev/stderr";
	}

	a_sum += a;
    }

    if (maxCount - 1 == k) {
	# no data to estimate a, give up
	return;
    }

    avg_a = a_sum / (maxCount - k - 1);

    if (debug) {
	print "average a = " avg_a > "/dev/stderr";
    }

    ## print "avg_a", avg_a > "/dev/stderr";

    for ( ; k > 0; k --) {
	if (countOfCounts[k] == 0) {
	    countOfCounts[k] = exp(log(countOfCounts[k + 1]) + avg_a / k);

	    print "estimating missing count-of-count " k \
					" = " countOfCounts[k] > "/dev/stderr";
	}
    }
}

END {
    # Code below is essentially identical to ModKneserNey::estimate()
    # (Discount.cc).

    handle_missing_counts();

    if (countOfCounts[1] == 0 || \
	countOfCounts[2] == 0 || \
	modified && countOfCounts[3] == 0 || \
	modified && countOfCounts[4] == 0) \
    {
	printf "error: one of required counts of counts is zero\n" \
	       						>> "/dev/stderr";
	exit(2);
    }

    Y = countOfCounts[1]/(countOfCounts[1] + 2 * countOfCounts[2]);

    if (modified) {
	discount1 = 1 - 2 * Y * countOfCounts[2] / countOfCounts[1];
	discount2 = 2 - 3 * Y * countOfCounts[3] / countOfCounts[2];
	discount3plus = 3 - 4 * Y * countOfCounts[4] / countOfCounts[3];
    } else {
	# original KN discounting
	discount1 = discount2 = discount3plus = Y;
    }

    print "mincount", min;
    print "discount1", discount1;
    print "discount2", discount2;
    print "discount3+", discount3plus;

    # check for invalid values after output, so we see where the problem is 
    if (discount1 < 0 || discount2 < 0 || discount3plus < 0) {
	printf "error: one of modified KneserNey discounts is negative\n" \
	       						>> "/dev/stderr";
	exit(2);
    }
}
