#!/usr/local/bin/gawk -f
#
# de-vq-lm --
#	Expand parameters in a quantized ARPA backoff LM
#
# usage: de-vq-lm bins=CW lm-file > sub-lm-file
# 
# where CW defines the quantization bins.
#
# Copyright (c) 2012 Andreas Stolcke, Microsoft Corp.  All Rights Reserved.
#
# $Header: /home/srilm/CVS/srilm/utils/src/de-vq-lm.gawk,v 1.2 2019/09/09 23:13:15 stolcke Exp $
#

BEGIN {
	bins = "/dev/null";
}

# read the cw file
#
#VQSize 256
#Codeword        Mean    Count
#       0 -12.7330028909195      10454
#       1 -12.3314038288506      1494
# etc.
#
NR == 1	{
	saveline = $0;

	getline < bins;
	if ($1 != "VQSize") {
		print "file " bins " is not a VQ file" > "/dev/stderr";
		exit(1);
	}
	vqsize = $2;

	getline < bins;
	if ($1 != "Codeword") {
		print "file " bins " is not a VQ file" > "/dev/stderr";
		exit(1);
	}

	while ((getline < bins) > 0) {
		vqbin[$1] = $2;
	}
	close(bins);

	$0 = saveline;
}

NF==0 {
	print; next;
}
/^ngram *[0-9][0-9]*=/ {
	order = substr($2,1,index($2,"=")-1);
	print; next;
}
/^\\[0-9]-grams:/ {
	currorder=substr($0,2,1);
	print; next;
}
/^\\/ {
	print; next;
}

# 
# replace VQ index with value in ngram parameter lines
#
currorder {
	if (!($1 in vqbin)) {
		print "line: " NR ": VQ bin #" $1 "is undefined" > "/dev/stderr";
		exit(1);
	}
	$1 = vqbin[$1];

	# backoff weight, if any
	if (NF == currorder + 2) {
	    if (!($NF in vqbin)) {
		    print "line: " NR ": VQ bin #" $NF "is undefined" > "/dev/stderr";
		    exit(1);
	    }
	    $NF = vqbin[$NF];
	}
	
	print; next;
}

# pass through anything else
{ print }
