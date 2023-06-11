#!/usr/local/bin/gawk -f
#
# make-hiddens-lm --
#	Create a hidden-sentence-boundary ngram LM from a standard one
#
# This script edits a ARPA backoff model file as follows:
#
# 1 - ngrams involving <s> and </s> are duplicated using the
#     hidden segment boundary token <#s>.
# 2 - ngrams starting with <s> are eliminated.
# 3 - the backoff weight of <s> is set to 1.
#     this together with the previous change sets all probabilities conditioned
#     on <s> to the respective marignal probabilities without <s>.
# 4 - ngrams ending in </s> get probability 1.
#     this avoids an end-of-sentence penalty in rescoring.
#
# $Header: /home/srilm/CVS/srilm/utils/src/make-hiddens-lm.gawk,v 1.7 2004/11/02 02:00:35 stolcke Exp $
#
BEGIN {
	sent_start = "<s>";
	sent_end = "</s>";
	hiddens = "<#s>";

	remove_old_ngrams = 0;
}
NF==0 {
	print; next;
}
/^ngram *[0-9][0-9]*=/ {
	print;
	next;
}
/^.[0-9]-grams:/ {
	currorder=substr($0,2,1);
}
/^\\/ {
	print; next;
}
# 
currorder && currorder < highorder {
	if (NF < currorder + 2) {
		print $0 "\t0";
	} else {
		print;
	}
	next;
}
$0 ~ sent_start || $0 ~ sent_end {
	oldline = $0;

	# modify sentence initial/final ngrams
	if ($2 == sent_end && currorder == 1) {
	    sos_uniprob = $1;

	    if (no_s_end) {
		# set </s> prob to 1
		$1 = 0;
	    }
	    if (!remove_old_ngrams) {
		print;
	    }
	    next;
	} else if ($2 == sent_start && currorder == 1) {
	    if (no_s_start) {
		# set <s> backoff weight to 1
		$3 = 0;
	    }
	    if (!remove_old_ngrams) {
		print;
	    }

	    # use unigram prob from </s>
	    if (sos_uniprob == "") {
		print "warning: could not find " sent_end " unigram" \
							    >> "/dev/stderr";
	    } else {
		oldline = sos_uniprob "\t" $2 "\t" $3;
	    }
	} else if ($2 == sent_start) {
	    # suppress other ngrams starting with <s>
	    if (!no_s_start && !remove_old_ngrams) {
		print;
	    }
	} else if ($(currorder + 1) == sent_end) {
	    if (no_s_end) {
		# set </s> prob to 1
		$1 = 0;
	    }
	    if (!remove_old_ngrams) {
	        print;
	    }
	}

	# replace <s> and </s> with <#s> and output result
	gsub(sent_start, hiddens, oldline);
	gsub(sent_end, hiddens, oldline);
	print oldline;
	next;
}
{ print }
