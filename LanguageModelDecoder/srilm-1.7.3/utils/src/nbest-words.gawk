#!/usr/local/bin/gawk -f
#
# nbest-words --
#	extract words only nbest lists
#
# usage: nbest-words NBEST-FILE ... 
#
# $Header: /home/srilm/CVS/srilm/utils/src/nbest-words.gawk,v 1.1 2016/04/29 04:00:08 stolcke Exp $
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

NF > 1 {
	words = "";

	if (nbestformat == 1) {
	    for (i = 2; i <= NF; i ++) {
		words = words " " $i;
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
		    words = words " " $i
		    prev_end_time = end_time;
		}
	    }
	} else {
	    for (i = 4; i <= NF; i ++) {
		words = words " " $i;
	    }
	}
	print words;
}


