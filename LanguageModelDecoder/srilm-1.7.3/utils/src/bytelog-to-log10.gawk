#!/usr/local/bin/gawk -f
#
# bytelog-to-log10 --
#	convert bytelog scores to log-base-10
#
# $Header: /home/srilm/CVS/srilm/utils/src/bytelog-to-log10.gawk,v 1.2 2002/05/15 04:47:13 stolcke Exp $
#
BEGIN {
	logscale = 2.30258509299404568402 * 10000.5 / 1024.0;
	scale = 1;
}
{
	for (i = 1; i <= NF; i ++) {
	    if ($i ~ /^[-+]+[0-9][0-9]*$/) {
		    $i = $i / scale / logscale;
	    }
	}
	print;
}
