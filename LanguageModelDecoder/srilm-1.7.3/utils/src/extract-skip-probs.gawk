#!/usr/local/bin/gawk -f
#
# extract-skip-probs --
#	Extract the skip probabilities from a Skip-Ngram model
#
# $Header: /home/srilm/CVS/srilm/utils/src/extract-skip-probs.gawk,v 1.1 1996/05/20 21:22:09 stolcke Exp $
#
NF == 0 {
	next;
}
/\\end\\/ {
	end_seen = 1;
	next;
}
end_seen {
	printf "%s %f\n", $1, $2;
}
