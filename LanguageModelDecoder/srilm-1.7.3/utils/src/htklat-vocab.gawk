#!/usr/local/bin/gawk -f
#
# htklat-vocab --
#	extract vocabulary used in an HTK lattice
#
# usage: htklat-vocab HTK-LATTICE ... > VOCAB
#
# $Header: /home/srilm/CVS/srilm/utils/src/htklat-vocab.gawk,v 1.3 2004/02/27 21:42:28 stolcke Exp $
#

BEGIN {
	null = "!NULL";
	quotes = 0;
}

{
	for (i = 1; i <= NF; i ++) {
		# skip comments
		if ($i ~ /^#/) next;

		# Note: this doesn't handle quoted spaces
		# (as SRILM generally doesn't)
		if ($i ~ /^W=/ || $i ~ /^WORD=/) {
		    word = substr($i, index($i, "=") + 1);

		    if (quotes) {
			# HTK quoting conventions
			if (word ~ /^['"]/) {
			    word = substr(word, 2, length(word)-2);
			}
			if (word ~ /\\/) {
			    gsub(/\\\\/, "@QuOtE@", word);
			    gsub(/\\/, "", word);
			    gsub(/@QuOtE@/, "\\", word);
			}
		    }

		    if (word != null) {
			is_word[word] = 1;
		    }
		}
	}
}

END {
	for (word in is_word) {
		print word;
	}
}

