#!/usr/local/bin/gawk -f
#
# ppl-from-log --
#	Recomputes perplexity from (a subset of) the output of 
#
#		ngram -debug 2 -ppl 
#
#	This is useful if one wants to analyse predictability of certain
#	words/contexts.
#
# usage: ppl-from-log [howmany=<numsents>] ppl-log-file
#
# Copyright (c) 1995, SRI International.  All Rights Reserved
#
# $Header: /home/srilm/CVS/srilm/utils/src/ppl-from-log.gawk,v 1.4 2014-07-03 05:57:09 stolcke Exp $
#
function result () {
	ppl = exp(-sum/(sentences + words - oovs) * M_LN10);
	printf "file %s: %d sentences, %d words, %d oovs\n", \
		FILENAME, sentences, words, oovs;
	printf "%d zeroprobs, logprob= %f, ppl= %f\n", \
			 0, sum , ppl;
}

BEGIN {
	M_LN10 = 2.30258509299404568402;	# from <math.h>
}

/^	p\( / {
	if ($0 ~ /\[ -[Ii]nf|\[ -1\.#INF/) {
		oovs ++;
	} else {
		sum += $10;
	}
	if ($2 == "</s>") {
		sentences ++;
	} else {
		words ++;
	}
	next;
}
/ ppl= / {
	sents ++;
	if (howmany > 0 && sents == howmany) {
		result();
		exit 0;
	}
	next;
}
{
	next;
}
END {
	result();
}
