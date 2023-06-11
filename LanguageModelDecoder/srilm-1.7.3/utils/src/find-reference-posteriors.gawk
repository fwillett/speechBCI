#!/usr/local/bin/gawk -f
#
# find-reference-posteriors --
#	tabular the sausage posteriors of reference words
#
# usage: find-reference-posteriors posteriors_files=NBEST_POSTERIORS SAUSAGE
#
# $Header: /home/srilm/CVS/srilm/utils/src/find-reference-posteriors.gawk,v 1.4 2010/08/20 00:17:18 stolcke Exp $
#

BEGIN {
	sentid = "UNKNOWN";

	M_LN10 = 2.30258509299404568402;        # from <math.h>
	logINF = -320;
}

function log10(x) {
	return log(x) / M_LN10;
}
function exp10(x) {
	if (x < logINF) {
		return 0;
	} else {
		return exp(x * M_LN10);
	}
}
function addlogs(x,y) {
	if (x<y) {
		temp = x; x = y; y = temp;
	}
	return x + log10(1 + exp10(y - x));
}

NR == 1 {
    if (posteriors_file) {
	hypno = 0;
	num_sources = 0;
	while ((("gzip -dcf " posteriors_file) | getline pline) > 0) {
		if (split(pline, a) == 3) {
			hyp_source[hypno] = a[1];
			if (a[1] > num_sources) {
				num_sources = a[1];
			}
			hyp_posterior[hypno] = a[3];
			hypno ++;
		}
	}
	print "read " hypno " posteriors from " num_sources " sources" \
							>> "/dev/stderr";
    }
}

# input format:
# align 1 hello 0.988212 below 0.00481234 low 0.00331215 ...
# reference 1 hello
# hyps 1 hello 0 1 2 3 4 5 6 7 8 9 10 11 16 17 18 19 

$1 == "align" {
	position = $2;

	delete word_posteriors;
	for (i = 3; i <= NF; i +=2 ) {
		word_posteriors[$i] = $(i + 1);
	}
}

$1 == "reference" && $2 == position {
	refword = $3;
}

$1 == "hyps" && $2 == position && $3 == refword {
	for (i = 1; i <= num_sources; i ++) {
		posterior_sum[i] = logINF;
	}
	for (i = 4; i <= NF; i ++) {
		posterior_sum[hyp_source[$i]] = \
		    addlogs(posterior_sum[hyp_source[$i]], hyp_posterior[$i]);
	}

	printf "%s %d %s %g", sentid, position, refword, \
					 word_posteriors[refword];

	for (i = 1; i <= num_sources; i ++) {
		printf " %g", exp10(posterior_sum[i]);
	}
	printf "\n";
}

