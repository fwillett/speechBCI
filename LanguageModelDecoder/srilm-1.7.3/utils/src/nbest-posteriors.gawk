#!/usr/local/bin/gawk -f
#
# nbest-posteriors --
#	rescale the scores in an nbest list to reflect weighted posterior
#	probabilities
#
# usage: nbest-posteriors [ weight=W amw=AMW lmw=LMW wtw=WTW postscale=S max_nbest=M ] NBEST-FILE
#
# The output is the same input NBEST-FILE with acoustic scores set to
# the log10 of the posterior hyp proabilities and LM scores set to zero.
# postscale=S attenuates the posterior distribution by dividing combined log 
# scores by S (the default is S=LMW).
#
# If weight=W is specified the posteriors are multiplied by W.
# (This is useful to combine multiple nbest lists in a weighted fashion).
# The input should be in SRILM nbest-format.
#
# $Header: /home/srilm/CVS/srilm/utils/src/nbest-posteriors.gawk,v 1.14 2019/02/08 14:13:35 stolcke Exp $
#

BEGIN {
	M_LN10 = 2.30258509299404568402;

	weight = 1.0;
	amw = 1.0;
	lmw = 8.0;
	wtw = 0.0;
	postscale = 0;
	max_nbest = 0;

	logINF = -320;		# log10 of smallest representable number
	log_total_numerator = logINF;
	bytelogscale = 1024.0 / 10000.5 / M_LN10;

	nbestformat = 0;
	noheader = 0;

	# tag to identify nbest list in output_posteriors
	nbest_tag = 1;
}

function log10(x) {
        return log(x)/M_LN10;
}
function exp10(x) {
	if (x <= logINF) {
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

# by default, use posterior scale = lmw
NR == 1 {
	if (!postscale) {
	    if (lmw == 0) {
		postscale = 1.0;
	    } else  {
		postscale = lmw;
	    }
	}
}

$1 ~ /^NBestList1\.0/ {
	nbestformat = 1;
	if (!noheader) {
	    # keep header in output
	    print;
	}

	if (lmw != 0 || wtw != 0) {
	    print "warning: cannot apply LMW or WTW to Decipher N-nbest lists" \
								>> "/dev/stderr";
	}

	next;
}

$1 ~ /^NBestList2\.0/ {
	nbestformat = 2;

	if (!noheader) {
	    # keep header in output
	    print;
	}

	next;
}

NF > 1 {
	if (max_nbest && num_hyps == max_nbest) exit;

	num_hyps ++;

	if (nbestformat == 1) {
	    # for Decipher nbest format 1 we use the aggregate score only
	    total_score = substr($1,2,length($1)-2);
	    total_score *= bytelogscale * amw/postscale;
	} else if (nbestformat == 2) {
	    total_score = substr($1,2,length($1)-2);

	    # compute total AC and LM scores 
	    lm_score = 0;
	    num_tokens = 0;

	    prev_end_time = -1;
	    for (i = 2; i <= NF; i += 11) {
		start_time = $(i + 3);
		end_time = $(i + 5);

		# skip tokens that are subsumed by the previous word
		# (this eliminates phone and state symbols)
		# XXX: due to a bug in Decipher some state tags have incorrect
		# timemarks.  We filter them based on their token string.
		if (start_time > prev_end_time && !($i ~ /-[0-9]$/)) {
		    num_tokens ++;

		    lm_score += $(i + 7);

		    prev_end_time = end_time;
		}
	    }

	    # Compute AC score from total and lm scores. This takes into
	    # account that the recognizer might sum scores of equivalent hyps
	    # (e.g., those differing only in pauses or pronunciations) and
	    # reflect the summing in the total score, but not in the word AC
	    # scores.
	    ac_score = total_score - lm_score;

	    # Note we don't eliminate pause tokens from the word count, since
	    # the recognizer includes them in word count weighting.
	    # (Only after LM rescoring are pauses ignored.)
	    total_score = amw * ac_score + lmw * lm_score + wtw * num_tokens;
	    total_score *= bytelogscale/postscale;
	} else {
	    total_score = (amw * $1 + lmw * $2 + wtw * $3)/postscale;
	}

	if (num_hyps == 1) {
	    score_offset = total_score;
	}

	total_score -= score_offset;

	#
	# store posteriors and hyp words
	#
	log_posteriors[num_hyps] = total_score;
	log_total_numerator = addlogs(log_total_numerator, total_score);

	num_words[num_hyps] = $3;

	if (nbestformat > 0) {
	    $1 = "";
	} else {
	    $1 = $2 = $3 = "";
	}
	hyps[num_hyps] = $0;
}

END {
	for (i = 1; i <= num_hyps; i ++) {
	    unweighted_logpost = log_posteriors[i] - log_total_numerator;
	    logpost = log10(weight) + unweighted_logpost;

	    if (nbestformat > 0) {
		printf "(%f) %s\n", logpost / bytelogscale, hyps[i];
	    } else {
		print logpost, 0, num_words[i], hyps[i];
	    }

	    if (output_posteriors) {
		print nbest_tag, i, unweighted_logpost >> output_posteriors;
	    }
	}
}

