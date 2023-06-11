#!/usr/local/bin/gawk -f
#
# make-kn-counts --
#	Modify N-gram counts for KN smoothing
#
# This duplicates the action of ModKneserNey::prepareCounts().
#
# $Header: /home/srilm/CVS/srilm/utils/src/make-kn-counts.gawk,v 1.5 2007/06/16 04:51:18 stolcke Exp $
#
BEGIN {
	order = 3;
	no_max_order = 0;

	sent_start = "<s>";

	ngram_count = "ngram-count";

	output = "-";
	max_per_file = 0;

	file_no = 0;
	ngram_no = 0;

}

function set_output () {
	close(output_cmd);

	ngram_cmd = ngram_count " -order " order " -read - -sort -write ";

	if (max_per_file > 0) {
		output_cmd = ngram_cmd output "-" ++file_no ".ngrams.gz";
	} else {
		output_cmd = ngram_cmd output;
	}
}


NR == 1 {
	kndiscount[1] = kndiscount1;
	kndiscount[2] = kndiscount2;
	kndiscount[3] = kndiscount3;
	kndiscount[4] = kndiscount4;
	kndiscount[5] = kndiscount5;
	kndiscount[6] = kndiscount6;
	kndiscount[7] = kndiscount7;
	kndiscount[8] = kndiscount8;
	kndiscount[9] = kndiscount9;

	if (output == "-") {
		max_per_file = 0;
	}
	set_output();
}

# discard ngrams not used in LM building
NF - 1 > order {
	next;
}
# keep ngrams not subject to KN discounting, or those starting with <s>
# if desired, highest-order ngrams are discarded to save space 
NF - 1 == order || !kndiscount[NF - 1] || $1 == sent_start {
	if (!no_max_order || NF - 1 < order) {
	    if (max_per_file > 0 && ++ngram_no % max_per_file == 0) {
		ngram_no = 0;
		set_output();
	    }
	    print | output_cmd;
	}
}
# modify lower-order ngrams subject to KN discounting
NF - 2 < order && kndiscount[NF - 2] && $2 != sent_start {
	$1 = $NF = "";

	if (max_per_file > 0 && ++ngram_no % max_per_file == 0) {
	    ngram_no = 0;
	    set_output();
	}

	# we let ngram-count add up the new counts for us
	print $0, 1 | output_cmd;
}
