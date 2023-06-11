#!/usr/local/bin/gawk -f
#
# reverse-text --
#	Reverse the word order in a text file
#
# $Header: /home/srilm/CVS/srilm/utils/src/reverse-text.gawk,v 1.1 2003/01/01 18:35:23 stolcke Exp $
#
BEGIN {
	start_tag = "<s>";
	end_tag = "</s>";
}
{
	if ($1 == start_tag) {
		i = 2;
	} else {
		i = 1;
	}

	if ($NF == end_tag) {
	    j = NF - 1;
	} else {
	    j = NF;
	}

	while (i < j) {
		h = $i;
		$i = $j;
		$j = h; 
		i ++; j--;
	}
	print;
}
