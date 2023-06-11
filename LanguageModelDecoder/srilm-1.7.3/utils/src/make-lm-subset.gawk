#!/usr/local/bin/gawk -f
#
# filter a backoff model with a count file, so that only ngrams
# in the countfile are represented in the output
#
# usage: make-lm-subset count-file bo-file
#
# $Header: /home/srilm/CVS/srilm/utils/src/make-lm-subset.gawk,v 1.3 1999/10/17 06:10:10 stolcke Exp $
#
ARGIND==1 {
	ngram = $0;
	sub("[ 	]*[0-9]*$", "", ngram);
	count[ngram] = 1;
	next;
}
ARGIND==2 && /^$/ {
	print; next;
}
ARGIND==2 && /^\\/ {
	print; next;
}
ARGIND==2 && /^ngram / {
	print; next;
}
ARGIND==2 {
	ngram = $0;
	# strip numeric stuff
	sub("^[-.e0-9]*[ 	]*", "", ngram);
	sub("[ 	]*[-.e0-9]*$", "", ngram);
	if (count[ngram]) print;
	next;
}
