#!/usr/local/bin/gawk -f
#
# continuous-ngram-count --
#	Generate ngram counts ignoring line breaks 
#	
# usage: continous-ngram-count order=ORDER textfile | ngram-count -read -
#
# $Header: /home/srilm/CVS/srilm/utils/src/continuous-ngram-count.gawk,v 1.1 1998/08/24 00:52:30 stolcke Exp $
#
BEGIN {
	order = 3;

	head = 0;	# next position in ring buffer
}

function process_word(w) {
	buffer[head] = w;

	ngram = "";
	for (j = 0; j < order; j ++) {
		w1 = buffer[(head + order - j) % order];
		if (w1 == "") {
			break;
		}
		ngram = w1 " " ngram;
		print ngram 1;
	}
	head = (head + 1) % order;
}

{
	for (i = 1; i <= NF; i ++) {
		process_word($i);
	}
}
