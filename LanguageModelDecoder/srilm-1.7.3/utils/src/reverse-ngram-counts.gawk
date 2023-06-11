#!/usr/local/bin/gawk -f
#
# reverse-ngram-counts --
#	Reverse the word order in N-gram count files
#
# $Header: /home/srilm/CVS/srilm/utils/src/reverse-ngram-counts.gawk,v 1.2 2017/07/31 18:18:50 stolcke Exp $
#
BEGIN {
	start_tag = "<s>";
	end_tag = "</s>";
}
{
	i = 1;
	j = NF - 1;
	while (i < j) {
		h = $i;
		$i = $j;
		$j = h; 
		i ++; j--;
	}

	# swap <s> and </s> tags
	for (i = 1; i < NF; i ++) {
	    if ($i == end_tag) $i = start_tag;
	    else if ($i == start_tag) $i = end_tag;
	}
	print;
}
