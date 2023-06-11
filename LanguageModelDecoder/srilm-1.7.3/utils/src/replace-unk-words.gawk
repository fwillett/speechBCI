#!/usr/local/bin/gawk -f
#
# replace-unk-words --
#	replace OOV words with <unk> tag
#
# usage: replace-unk-words vocab=<vocabfile> text > text-with-unk
#
# $Header: /home/srilm/CVS/srilm/utils/src/replace-unk-words.gawk,v 1.1 2013/12/11 08:32:48 stolcke Exp $
#

BEGIN {
	unk = "<unk>";
}

NR == 1 {
	if (vocab != "") {
	    nwords = 0;
	    while ((getline line < vocab) > 0) {
		if (split(line, w, " ") > 0) {
		    is_word[w[1]] = 1;
		    nwords += 1;
		}
	    }
	    close(vocab);
	    print "read " nwords " words" > "/dev/stderr";
	}

	is_word[unk] = 1;
	is_word["<s>"] = 1;
	is_word["</s>"] = 1;
}

{
	for (i = 1; i <= NF; i ++) {
	    if (!($i in is_word)) {
		$i = unk;
	    }
	}
	print;
}

