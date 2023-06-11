#!/usr/local/bin/gawk -f
#
# uniq-ngram-counts --
#	Collapse identical successive N-grams in counts file
#
# $Header: /home/srilm/CVS/srilm/utils/src/uniq-ngram-counts.gawk,v 1.2 2007/07/13 23:50:28 stolcke Exp $
#
{
	if (NF == 1) {
	    ngram = " ";
	} else {
	    ngram = "";
	}

	for (i = 1; i < NF; i ++) {
		ngram = ngram " " $i;
	}

	# starting ngrams with space character forces string comparison
	if (ngram != last_ngram) {
	    if (last_ngram != "") {
		# avoid outputting initial space
		print substr(last_ngram, 2), total_count;
	    }
	    total_count = 0;
	    last_ngram = ngram;
	}

	total_count += $NF;
}

END {
	if (last_ngram != "") {
		print substr(last_ngram, 2), total_count;
	}
}
