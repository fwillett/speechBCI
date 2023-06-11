#!/usr/local/bin/gawk -f
#
# remove-lowprob-ngrams --
#	Remove ngrams from a backoff LM that have lower prob than their
#	backoff paths.
#
# $Header: /home/srilm/CVS/srilm/utils/src/remove-lowprob-ngrams.gawk,v 1.4 2004/11/02 02:00:35 stolcke Exp $
#

NF == 0 {
	print;
	next;
}

/^ngram *[0-9][0-9]*=/ {
	order = substr($2,1,index($2,"=")-1);
	if (order > 3) {
	    print "warning: can only handle bigrams and trigrams" >> "/dev/stderr";
	}
	if (order > maxorder && $2 !~ /=0$/) {
	    maxorder = order;
	}
	print;
	next;
}

/^\\[0-9]-grams:/ {
	currorder=substr($0,2,1);
	print;
	next;
}
/^\\/ {
	print;
	next;
}

#
# unigrams
#
currorder == 1 {
	word = $2;
	uni_prob[word] = $1;
	if (NF > 2) {
	    uni_bow[word] = $3;
	}
	print;
}

#
# bigrams
#
currorder == 2 {
	prob = $1;
	word1 = $2;
	word2 = $3;
	words = $2 " " $3;

	if (maxorder > 2) {
	    bi_prob[words] = prob;
	    if (NF > 3) {
		bi_bow[words] = $4;
	    }
	}

	total_bigrams ++;
	if (uni_bow[word1] + uni_prob[word2] <= prob) {
	    print;
	} else {
	    removed_bigrams ++;
	}
}

#
# trigrams
#
currorder == 3 {
	prob = $1;
	word1 = $2;
	word2 = $3;
	word3 = $4;

	if (word2 " " word3 in bi_prob) {
	    backoff_prob = bi_bow[word1 " " word2] + bi_prob[word2 " " word3];
	} else {
	    backoff_prob = bi_bow[word1 " " word2] + \
					uni_bow[word2] + uni_prob[word3];
	}

	total_trigrams ++;
	if (backoff_prob <= prob) {
	    print;
	} else {
	    removed_trigrams ++;
	}
}

END {
	if (total_bigrams > 0) {
	    printf "%d out of %d bigrams removed\n", \
			removed_bigrams, total_bigrams >> "/dev/stderr";
	}
	if (total_trigrams > 0) {
	    printf "%d out of %d trigrams removed\n", \
			removed_trigrams, total_trigrams >> "/dev/stderr";
	}
}
