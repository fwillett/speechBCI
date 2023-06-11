#!/usr/local/bin/gawk -f
#
# compute-oov-rate --
#	Compute OOV word rate from a vocabulary and a unigram count file
#
# usage: compute-oov-rate vocab countfile ...
#
# Assumes unigram counts do not have repeated words.
#
# $Header: /home/srilm/CVS/srilm/utils/src/compute-oov-rate.gawk,v 1.10 2018/01/24 03:35:38 stolcke Exp $
#

BEGIN {
	# high bit characters also detect multibyte characters
	letter = "[[:alpha:]\x80-\xFF]";
	if ("x" !~ letter) letter = "[A-Za-z\x80-\xFF]";
}

# Read vocab
#
ARGIND == 1 {
	vocab[$1] = 1;
}

function is_fragment(word) {
	return word ~ (letter "-$") || word ~ ("^-" letter);
}

#
# Read counts
#
ARGIND > 1 {
	if ($1 == "<s>" || $1 == "</s>" || $1 == "-pau-") {
		next;
	}

	total_count += $2;
	total_types ++;

	if (!vocab[$1]) {
		oov_count += $2;
		oov_types ++; 

		if (debug) {
		    print "OOV: " $1, $2 > "/dev/stderr";
		}

		if (!is_fragment($1)) {
		    if (write_oov_words) {
			    print > write_oov_words;
		    }
		} else {
		    if (write_oov_frags) {
			    print > write_oov_frags;
		    }
		}
	}

	if (!is_fragment($1)) {
		total_nofrag_count += $2;
		total_nofrag_types ++;

		if (!vocab[$1]) {
			oov_nofrag_count += $2;
			oov_nofrag_types ++; 
		}
	}

}
END {
	printf "OOV tokens: %d / %d (%.2f%%) ", \
		oov_count, total_count, total_count == 0 ? 0 : 100 * oov_count/total_count;
	printf "excluding fragments: %d / %d (%.2f%%)\n", \
		oov_nofrag_count, total_nofrag_count, \
		total_nofrag_count == 0 ? 0 : 100 * oov_nofrag_count/total_nofrag_count;
	printf "OOV types: %d / %d (%.2f%%) ", \
		oov_types, total_types, total_types == 0 ? 0 : 100 * oov_types/total_types;
	printf "excluding fragments: %d / %d (%.2f%%)\n", \
		oov_nofrag_types, total_nofrag_types, \
		total_nofrag_types == 0 ? 0 : 100 * oov_nofrag_types/total_nofrag_types;
}
