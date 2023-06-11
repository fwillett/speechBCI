#!/usr/local/bin/gawk -f
#
# make-sub-lm --
#	extract a lower-order backoff LM from a higher order one.
#
# usage: make-sub-lm maxorder=<n> lm-file > sub-lm-file
#
# $Header: /home/srilm/CVS/srilm/utils/src/make-sub-lm.gawk,v 1.2 1998/11/09 05:54:12 stolcke Exp $
#

BEGIN {
	maxorder=2;
}
NF==0 {
	print; next;
}
/^ngram *[0-9][0-9]*=/ {
	order = substr($2,1,index($2,"=")-1);
	if (order <= maxorder) print;
	next;
}
/^\\[0-9]-grams:/ {
	currorder=substr($0,2,1);
	if (currorder <= maxorder) {
		print;
	} else {
		print "\n\\end\\";
		exit;
	}
	next;
}
/^\\/ {
	print; next;
}
currorder {
	if (currorder < maxorder) {
		print;
	} else if (currorder == maxorder) {
		#
		# delete backoff weight for maximal ngram
		#
		if (NF == currorder + 2) {
			$NF = "";
		}
		print;
	}
	next;
}
{ print }
