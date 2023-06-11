#!/usr/local/bin/gawk -f
#
# hits-from-log --
#	Computes n-gram hit ratios frrom the output of
#
#		ngram -debug 2 -ppl 
#
#	This is useful if one wants to analyse predictability of certain
#	words/contexts.
#
# Copyright (c) 1995, SRI International.  All Rights Reserved
#
# $Header: /home/srilm/CVS/srilm/utils/src/hits-from-log.gawk,v 1.3 1995/10/28 03:59:31 stolcke Exp $
#
BEGIN {
	M_LN10 = 2.30258509299404568402;	# from <math.h>
}
/6gram/ {
	words ++;
	hits[6] ++;
	next;
}
/5gram/ {
	words ++;
	hits[5] ++;
	next;
}
/4gram/ {
	words ++;
	hits[4] ++;
	next;
}
/3gram/ {
	words ++;
	hits[3] ++;
	next;
}
/3\+Tgram/ {
	words ++;
	thits[3] ++;
	next;
}
/2gram/ {
	words ++;
	hits[2] ++;
	next;
}
/2\+Tgram/ {
	words ++;
	thits[2] ++;
	next;
}
/1gram/ {
	words ++;
	hits[1] ++;
	next;
}
/1\+Tgram/ {
	words ++;
	thits[1] ++;
	next;
}
{
	next;
}
END {
	printf "%d words, hit rates:\n", words;
	for (i = 1; i <= 6; i++) {
	    if (hits[i]) {
		printf "%dgrams: %d (%.1f%%) ", i, hits[i], \
					(hits[i]/words * 100);
	    }
	    if (thits[i]) {
		printf "%d+Tgrams: %d (%.1f%%) ", i, thits[i], \
					(thits[i]/words * 100);
	    }
	}
	printf "\n";
}
