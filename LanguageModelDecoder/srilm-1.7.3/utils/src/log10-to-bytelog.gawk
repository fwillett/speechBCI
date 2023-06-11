#!/usr/local/bin/gawk -f
#
# log10-to-bytelog --
#	convert log-base-10 scores to bytelog
#
# $Header: /home/srilm/CVS/srilm/utils/src/log10-to-bytelog.gawk,v 1.1 1997/04/22 20:20:41 stolcke Exp $
#
BEGIN {
	logscale = 2.30258509299404568402 * 10000.5 / 1024.0;
	scale = 1;
	round = 0.5;
}
function rint(x) {
	if (x < 0) {
		return int(x - round);
	} else {
		return int(x + round);
	}
}
{
	for (i = 1; i <= NF; i ++) {
	    if ($i ~ /^[-+.0-9][.0-9]*$/) {
		    if (round) {
			$i = scale * rint($i * logscale);
		    } else {
			$i = scale * $i * logscale;
		    }
	    }
	}
	print;
}
