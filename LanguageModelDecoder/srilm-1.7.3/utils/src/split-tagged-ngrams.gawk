#!/usr/local/bin/gawk -f
#
# split-tagged-ngrams --
#	multiply tagged-word ngrams out into ngrams that contain
#	combinations of words and tags
#
# sample input:
#	a/A b/B 10
# sample output:
#	a b 10
#	a B 10
#	A b 10
#	A B 10
#
# $Header: /home/srilm/CVS/srilm/utils/src/split-tagged-ngrams.gawk,v 1.2 2006/02/11 01:31:32 stolcke Exp $
#

BEGIN {
	separator = "/";
}

# recursive expansion of the tagged-word ngram
function expand_ngram(ng, n, suffix, c,
				word, tag, word_tag) {
	if (n == 0) {
		print suffix, c;
	} else {
		last_item = ng[n];

		if (split(last_item, word_tag, separator) == 2) {
			word = word_tag[1];
			tag = word_tag[2];
			expand_ngram(ng, n-1, word " " suffix, c);
			expand_ngram(ng, n-1, tag " " suffix, c);
		} else {
			expand_ngram(ng, n-1, last_item " " suffix, c);
		}
	}
}

NF > 1 {
	count = $NF;

	delete ngram;
	for (i = 1; i < NF; i ++) {
		ngram[i] = $i;
	}

	expand_ngram(ngram, NF - 1, "", count);

	next;
}

{
	print;
}

