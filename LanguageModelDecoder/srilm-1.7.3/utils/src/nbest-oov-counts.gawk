#!/usr/local/bin/gawk -f
#
# nbest-oov-counts --
#	generate OOV counts for an nbest list
#
# usage: nbest-oov-counts vocab=VOCAB [vocab_aliases=ALIASES] NBESTLIST > COUNTS
#
# $Header: /home/srilm/CVS/srilm/utils/src/nbest-oov-counts.gawk,v 1.2 2017/08/15 19:29:34 stolcke Exp $
#

BEGIN {
	nbestformat = 0;
}

$1 ~ /^NBestList1\.0/ {
	nbestformat = 1;
	next;
}

$1 ~ /^NBestList2\.0/ {
	nbestformat = 2;
	next;
}

NR == 1 {
	nwords = 0;
	while ((getline line < vocab) > 0) {
	    if (split(line, a) > 0) {
		in_vocab[a[1]] = 1;
		nwords ++;
	    }
	}
	print "read " nwords " vocab words" > "/dev/stderr";

	naliases = 0;
	if (vocab_aliases) {
	    while ((getline line < vocab_aliases) > 0) {
		if (split(line, a) >= 2) {
		    vocab_mapping[a[1]] = a[2];
		    naliases ++;
		}
	    }
	    print "read " naliases " vocab aliases" > "/dev/stderr";
	}

	# add default vocabulary
	in_vocab["<s>"] = 1;
	in_vocab["</s>"] = 1;
	in_vocab["-pau-"] = 1;
}

function process_word(w) {
	if (w in vocab_mapping) {
	    word = vocab_mapping[w];
	} else {
	    word = w;
	}
    
	if (!(word in in_vocab)) {
	    oov_count ++;
	}
}

NF > 1 {
	oov_count = 0;

	if (nbestformat == 1) {
	    # for Decipher nbest format 1 we use the aggregate score only
	    for (i = 2; i <= NF; i ++) {
		process_word($i);
	    }
	} else if (nbestformat == 2) {
	    prev_end_time = -1;
	    for (i = 2; i <= NF; i += 11) {
		start_time = $(i + 3);
		end_time = $(i + 5);

		# skip tokens that are subsumed by the previous word
		# (this eliminates phone and state symbols)
		# XXX: due to a bug in Decipher some state tags have incorrect
		# timemarks.  We filter them based on their token string.
		if (start_time > prev_end_time && !($i ~ /-[0-9]$/)) {
		    process_word($i);

		    prev_end_time = end_time;
		}
	    }
	} else {
	    for (i = 4; i <= NF; i ++) {
		process_word($i);
	    }
	}

	print oov_count;
}

