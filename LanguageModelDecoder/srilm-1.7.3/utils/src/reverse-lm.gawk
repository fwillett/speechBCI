#!/usr/local/bin/gawk -f
#
# reverse-lm --
#	reverse N-grams in a backoff LM
#
# usage: reverse-lm lm-file > rev-lm-file
#
# $Header: /home/srilm/CVS/srilm/utils/src/reverse-lm.gawk,v 1.2 2004/11/02 02:00:35 stolcke Exp $
#

BEGIN {
	start_tag = "<s>";
	end_tag = "</s>";

	renorm_command = "ngram -debug 1 -order 2 -lm - -renorm -write-lm -";
}
NF==0 {
	print | renorm_command;
	next;
}
/^ngram *[0-9][0-9]*=/ {
	order = substr($2,1,index($2,"=")-1);

	if (order > 2) {
		print "can handle bigram LMs only" >> "/dev/stderr";
		exit(2);
	}
	print | renorm_command;
	next;
}
/^\\[0-9]-grams:/ {
	currorder=substr($0,2,1);
	print | renorm_command;
	next;
}
/^\\/ {
	print | renorm_command;
	next;
}
currorder == 1 {
	# unigrams are copied unchanged
	# store probs for later use

	prob = $1;
	word = $2;
	if (word == start_tag) {
	    ; # get <s> unigram prob from </s>
	} else if (word == end_tag) {
	    uniprob[start_tag] = uniprob[end_tag] = prob;
	} else {
	    uniprob[word] = prob;
	}

	# add dummy backoff weight
	$3 = "0";
	print | renorm_command;
	next;
}

function map_tags(w) {
	if (w == start_tag) {
	    return end_tag;
	} else if (w == end_tag) {
	    return start_tag;
	} else {
	    return w;
	}
}

currorder == 2 {
	# bigrams are reverse and new probabilities are assigned 
	prob = $1;
	w1 = map_tags($2);
	w2 = map_tags($3);

	# p_rev(w1|w2) = p(w1) p(w2|w1) / p(w2)
	new_prob = uniprob[w1] + prob - uniprob[w2];

	if (new_prob > 0) {
		print "warning: p(" w1 "|" w2 ") > 0" >> "/dev/stderr";
	}

	print new_prob "\t" w2 " " w1 | renorm_command;
	next;
}
