#!/usr/local/bin/gawk -f
#
# make-abs-discount --
#	computes the absolute (constant) discount values from Good-Turing
#	counts-of-counts statistics.  (Only the n1 and n2 statistics are used.)
#
# usage: make-abs-discount COUNTFILE
#
# 	where COUNTFILE was created with get-gt-counts.
#
# $Header: /home/srilm/CVS/srilm/utils/src/make-abs-discount.gawk,v 1.2 2004/11/02 02:00:35 stolcke Exp $
#
$1 == 1 {
	gt1count = $2;
}
$1 == 2 {
	gt2count = $2;
}
END {
	if (gt1count == 0) {
		print "n1 count is zero" >> "/dev/stderr";
		exit 1;
	}
	if (gt2count == 0) {
		print "n2 count is zero" >> "/dev/stderr";
		exit 1;
	}
	print gt1count/(gt1count + 2 * gt2count);
}

