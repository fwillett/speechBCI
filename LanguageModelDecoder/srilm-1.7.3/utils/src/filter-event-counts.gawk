#!/usr/local/bin/gawk -f
#
# filter-event-counts --
#	Remove from a count file all ngrams that don't correspond to an "event"
#	for the LM, such that
#
#		ngram -order N -lm LM -ppl TEXT
#	and
#		ngram-count -order N -text TEXT -write - | \
#		filter-event-counts order=N | \
#		ngram -order N -lm LM -counts -
#
# 	yield the same result.
#
# $Header: /home/srilm/CVS/srilm/utils/src/filter-event-counts.gawk,v 1.2 2009/09/25 00:06:50 stolcke Exp $
#
BEGIN {
	order = 3;
	escape = "";

	sent_start = "<s>";
}

# pass escaped lines through
escape != "" && substr($0, 1, length(escape)) == escape {
	print;
	next;
}

# Start-of-sentence ngrams are always included (except for <s> unigram)
$1 == sent_start {
	if (NF == 2) {
		next;
	} else {
		print;
		next;
	}
}

# ngrams of highest order
NF == order + 1 {
	print;
}

