#!/usr/local/bin/gawk -f
#
# subset-context-ngrams -- 
#	Extract counts corresponding to ngram contexts
#
#	usage: subset-context-ngrams contexts=FILE COUNTS > SUBSET
#
# $Header: /home/srilm/CVS/srilm/utils/src/subset-context-ngrams.gawk,v 1.1 2008/09/30 03:54:05 stolcke Exp $
#

# read contexts
NR == 1 {
	saveline = $0;

	if (contexts != "") {
	    howmany = 0;
	    while ((getline < contexts) > 0) {
		if (NF < 2) continue;
		$NF = "";
		subset_contexts[$0 FS] = 1;
		howmany ++;
	    }
	    print "read " howmany " contexts" > "/dev/stderr";
	}

	$0 = saveline;
}

NF == 2 {
	print;
	next;
}

NF > 2 {
	saveline = $0;

	$NF = $(NF-1) = "";
	if ($0 in subset_contexts) {
		print saveline;
	}
}

