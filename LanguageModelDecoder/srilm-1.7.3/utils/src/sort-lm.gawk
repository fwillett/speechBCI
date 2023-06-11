#!/usr/local/bin/gawk -f
#
# sort-lm --
#	sort the ngrams in an LM in lexicographic order, as required for 
#	some other LM software (notably CMU's).
#
# usage: sort-lm lm-file > sorted-lm-file
#
# $Header: /home/srilm/CVS/srilm/utils/src/sort-lm.gawk,v 1.2 2004/11/02 02:00:35 stolcke Exp $
#

BEGIN {
	sorter = "";
	currorder = 0;
}
NF==0 {
	print;
	next;
}
/^ngram *[0-9][0-9]*=/ {
	order = substr($2,1,index($2,"=")-1);
	print;
	next;
}
/^\\[0-9]-grams:/ {
	if (sorter) {
	    close(sorter);
	}

	currorder = substr($0,2,1);
	print;
	fflush();

	# set up new sorting pipeline;
	sorter = "sort";
	for (i = 1; i <= currorder; i ++) {
		sorter = sorter " +" i " -" (i+1);
	}
	# print sorter >> "/dev/stderr";
	next;
}
/^\\/ {
	if (sorter) {
	    close(sorter);
	    sorter = "";
	}
	currorder = 0;
	print; next;
}
currorder && NF > 1 {
	print | sorter;
	next;
}
{	
	print;
}
