#!/usr/local/bin/gawk -f
#
# rank-vocab --
#	Given K different rankings of candidate vocabularies, and 
# 	a held-out optimization unigram count file, optimize the 
#	combined ranking of words
#
# usage: rank-vocab counts words1 words2 ... worksK
#
# $Header: /home/srilm/CVS/srilm/utils/src/rank-vocab.gawk,v 1.2 2004/11/02 02:00:35 stolcke Exp $
#

BEGIN {
	num_sources = 0;
	num_output = 0;
	num_oovs = 0;

	debug = 0;
}


ARGIND == 1 {
	word_count[$1] = $2;

	num_oovs += $2;

	next;
}

ARGIND > 1 {
	k = ARGIND - 1;
	num_sources = k;

	num_words[k] ++;

	word_ranked[k, num_words[k]] = $1;
	next;
}

function dump_words(k) {
	print "source " k " words:";

	for (i = 1; i <= num_words[k]; i ++) {
	    print i, word_ranked[k,i];
	}
}

# find the next word from source k that occurs in the test set
# return 0 if no more words are available
function find_next(k) {
	for (j = last_chosen[k] + 1; j <= num_words[k]; j ++) {
	    if (word_count[word_ranked[k,j]] > 0) {
		if (debug) {
		    print "next word rank for source " k ": " j >> "/dev/stderr";
		}

		return j;
	    }
	}
	if (debug) {
	    print "no more words from source " k >> "/dev/stderr";
	}
	return 0;
}

# compute gain (number of OOVs tokens reduced per number of word types added)
# by adding the next word from source k
function compute_gain(k) {
	if (next_word[k] == 0) {
	    # no more words in source k, no gain
	    return -1;
	} else {
	    g = word_count[word_ranked[k,next_word[k]]] / (next_word[k] - last_chosen[k]);
	    if (debug) {
		print "next gain for source " k " = " g;
	    }
	    return g;
	}
}

END {
#	for (k = 1; k <= num_sources; k ++) {
#	    dump_words(k);
#	}

	for (k = 1; k <= num_sources; k ++) {
	    last_chosen[k] = 0;
	    next_word[k] = find_next(k);
	    gain[k] = compute_gain(k);
	}

	print "INITIAL OOVS = " num_oovs;

	# add words until no more gain possible (i.e., until all source
	# words have been used up)
	while (1) {
	    best_gain = -1;
	    best_source = 0;

	    # find next best source to pick word from
	    for (k = 1; k <= num_sources; k ++) {
		if (gain[k] > best_gain) {
			best_source = k;
			best_gain = gain[k];
		}
	    }

	    if (best_gain < 0) break;

	    # process all the words from source k up to the one chosen 
	    for (i = last_chosen[best_source] + 1; \
		 i <= next_word[best_source]; \
		 i ++) {
		word_chosen = word_ranked[best_source,i] 

		if (debug) {
		    print "source = " best_source \
			  " gain = " best_gain \
			  " word = " word_chosen >> "/dev/stderr";
		}

		# output the word if it hasn't been already
		if (!was_output[word_chosen]) {
		    num_output ++;

		    num_oovs -= word_count[word_chosen];

		    print "RANK " num_output " WORD " word_chosen \
				" OOVS " num_oovs;

		    was_output[word_chosen] = 1;
		}
	    }

	    # update the statistics for the source that was chosen
	    last_chosen[best_source] = next_word[best_source];
	    next_word[best_source] = find_next(best_source);
	    gain[best_source] = compute_gain(best_source);
	}
}

