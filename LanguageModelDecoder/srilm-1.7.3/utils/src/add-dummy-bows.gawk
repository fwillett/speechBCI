#!/usr/local/bin/gawk -f
#
# add-dummy-bows --
#	add redundant backoff weights to model file to make some broken
#	programs happy.
#	(Normally a backoff weight is only required for ngrams that
#	are prefixes of longer ngrams.)
#
# $Header: /home/srilm/CVS/srilm/utils/src/add-dummy-bows.gawk,v 1.1 1995/09/20 17:36:30 stolcke Exp $
#

NF==0 {
	print; next;
}
/^ngram *[0-9][0-9]*=/ {
	order = substr($2,1,index($2,"=")-1);
	if (order > highorder) highorder = order;
	print;
	next;
}
/^.[0-9]-grams:/ {
	currorder=substr($0,2,1);
}
/^\\/ {
	print; next;
}
currorder && currorder < highorder {
	if (NF < currorder + 2) {
		print $0 "\t0";
	} else {
		print;
	}
	next;
}
{ print }
