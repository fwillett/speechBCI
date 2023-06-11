#!/usr/local/bin/gawk -f
#
# nbest2-to-nbest1 --
#	Convert Decipher NBestList2.0 format to NBestList1.0 format
#
# $Header: /home/srilm/CVS/srilm/utils/src/nbest2-to-nbest1.gawk,v 1.4 2004/11/02 02:00:35 stolcke Exp $
#
BEGIN {
	magic1 = "NBestList1.0";
	magic2 = "NBestList2.0";
}
NR == 1 {
	if ($0 != magic2) {
		print "Input not in " magic2 " format" >> "/dev/stderr";
		exit 1;
	}
	print magic1;
	next;
}
{
	prev_end_time = -1;
	line = $1;
	for (i = 2; i <= NF; i += 11) {
		start_time = $(i + 3);
		end_time = $(i + 5);

		# skip tokens that are subsumed by the previous word
		# (this eliminates phone and state symbols)
		# XXX: due to a bug in Decipher some state tags have incorrect
		# timemarks.  We filter them based on their token string.
		if (start_time > prev_end_time && !($i ~ /-[0-9]$/)) {
			line = line " " $i;
			prev_end_time = end_time;
		}
	}
	print line;
}
