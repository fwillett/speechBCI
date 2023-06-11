#!/usr/local/bin/gawk -f
#
# make-meta-counts --
#	Apply N-gram count cut-offs and insert meta-counts (counts-of-counts)
#
# $Header: /home/srilm/CVS/srilm/utils/src/make-meta-counts.gawk,v 1.2 2002/07/22 21:24:45 stolcke Exp $
#
BEGIN {
	order = 3;
	# trust_total=1 means we don't have to generate meta-counts, just
	# apply the cut-offs (in combination with ngram-count -trust-totals)
	trust_totals = 0;
	metatag = "__META__";
}

NR == 1 {
	mincount[1] = mincount1 + 0;
	mincount[2] = mincount2 + 0;
	mincount[3] = mincount3 + 0;
	mincount[4] = mincount4 + 0;
	mincount[5] = mincount5 + 0;
	mincount[6] = mincount6 + 0;
	mincount[7] = mincount7 + 0;
	mincount[8] = mincount8 + 0;
	mincount[9] = mincount9 + 0;
}

NF > order + 1 {
	next;
}

NF > 1 {
    this_order = NF - 1;

    if (!trust_totals) {
	# output buffered ngrams of higher order IF there was at least 
	# one non-meta count of the respective order
	for (i = order; i > this_order; i --) {
	    if (have_counts[i]) {
		printf "%s", buffer[i];
		have_counts[i] = 0;
	    }
	    delete buffer[i];
	}
    }

    if ($NF < mincount[this_order]) {
	if (trust_totals) {
	    next;
	} else {
	    # convert below-cutoff ngram to meta-ngram
	    $this_order = metatag int($NF);
	    $NF = 1;

	    # add it to buffer
	    buffer[this_order] = buffer[this_order] $0 "\n";
	}
    } else {
	have_counts[this_order] = 1;
	print;
    }

}

END {
    # output any remaining buffered ngrams
    for (i = order; i >= 1; i --) {
	if (have_counts[i]) {
	    printf "%s", buffer[i];
	}
    }
}

