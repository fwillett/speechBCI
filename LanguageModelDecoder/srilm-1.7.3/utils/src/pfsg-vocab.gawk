#!/usr/local/bin/gawk -f
#
# pfsg-vocab --
#	extract vocabulary used in PFSG
#
# usage: pfsg-vocab PFSG-FILE ... > VOCAB
#
# $Header: /home/srilm/CVS/srilm/utils/src/pfsg-vocab.gawk,v 1.1 2003/02/18 18:33:04 stolcke Exp $
#

BEGIN {
	null = "NULL";
}

$1 == "nodes" {
	for (i = 3; i <= NF; i ++) {
		if ($i != null) {
			is_word[$i] = 1;
		}
	}
	next;
}

$1 == "name" {
	# sub-pfsg names are not words, and might have been added during the
	# processing of the nodes list
	delete is_word[$2];
}

END {
	for (word in is_word) {
		print word;
	}
}

