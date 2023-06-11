#!/usr/local/bin/gawk -f
#
# merge-nbest --
#	merge hyps from multiple N-best lists into a single list
#
# $Header: /home/srilm/CVS/srilm/utils/src/merge-nbest.gawk,v 1.8 2010/08/20 00:17:18 stolcke Exp $
#

BEGIN {
	M_LN10 = 2.30258509299404568402;	# from <math.h>
	logINF = -320;
	bytelogscale = M_LN10 * 10000.5 / 1024.0;

	use_orig_hyps = 1;
	add_scores = 0;
	last_nbestformat = -1;

	nbestmagic1 = "NBestList1.0";
	nbestmagic2 = "NBestList2.0";
	pause = "-pau-";

	max_nbest = 0;
	multiwords = 0;
	multichar = "_";
	nopauses = 0;
}

function log10(x) {
	return log(x) / M_LN10;
}
function exp10(x) {
	if (x < logINF) {
		return 0;
	} else {
		return exp(x * M_LN10);
	}
}
function addlogs(x,y) {
    if (x<y) {
	temp = x; x = y; y = temp;
    }
    return x + log10(1 + exp10(y - x));
}

function process_nbest(file) {
        input = "exec gzip -dcf " file;

	nbestformat = 0;
	num_hyps = 0;

	while ((status = (input | getline)) > 0) {
	    if ($1 == nbestmagic1) {
		nbestformat = 1;
	    } else if ($1 == nbestmagic2) {
		nbestformat = 2;
	    } else {
		words = "";
		num_words = 0;
		num_hyps ++;

		if (max_nbest > 0 && num_hyps > max_nbest) {
		    break;
		}

		if (nbestformat == 1) {
		    for (i = 2; i <= NF; i++) {
			words = words " " $i;
			if ($i != pause) num_words ++;
		    }
		    score = substr($1, 2, length($1)-2)/bytelogscale;
		    num_words = 1;
		} else if (nbestformat == 2) {
		    prev_end_time = -1;
		    for (i = 2; i <= NF; i += 11) {
			start_time = $(i + 3);
			end_time = $(i + 5);

			# skip tokens that are subsumed by the previous word
			# (this eliminates phone and state symbols)
			# XXX: due to a bug in Decipher some state tags have
			# incorrect timemarks.  We filter them based on their
			# token string.
			if (start_time > prev_end_time && !($i ~ /-[0-9]$/)) {
			    words = words " " $i;
			    if ($i != pause) num_words ++;
			    prev_end_time = end_time;
			}
		    }
		    score = substr($1, 2, length($1)-2)/bytelogscale;
		} else {
		    for (i = 4; i <= NF; i++) {
			words = words " " $i;
		    }
		    score = $1 + 8 * $2;
		    num_words = $3;
		}

		# resolve multiwords and eliminate pauses if so desired
		if (multiwords) {
			gsub(multichar, " ", words);
		}
		if (nopauses) {
			gsub(" " pause, " ", words);
		}

		# if word sequence is new, record it
		if (!(words in scores)) {
		    scores[words] = score;
		    hyps[words] = $0;
		    nwords[words] = num_words;
		} else if (add_scores) {
		    scores[words] = addlogs(scores[words], score);
		}

	        if (last_nbestformat < 0) {
		    last_nbestformat = nbestformat;
		} else if (nbestformat != last_nbestformat) {
		    use_orig_hyps = 0;
		    last_nbestformat = nbestformat;
		}
	    }
	}
	if (status < 0) {
		print "error opening " file >> "/dev/stderr";
	}

	close(input);
}

function output_nbest() {
	if (!use_orig_hyps || use_orig_hyps && last_nbestformat == 1) {
		print nbestmagic1;
	} else if (use_orig_hyps && last_nbestformat == 2) {
		print nbestmagic2;
	}

	for (words in scores) {
	    if (add_scores) {
		print scores[words], 0, nwords[words], words;
	    } else if (use_orig_hyps) {
		print hyps[words];
	    } else {
		print "(" (scores[words] * bytelogscale) ")" words;
	    }
	}
}

BEGIN {
	if (ARGC < 2) {
	    print "usage: " ARGV[0] " N-BEST1 N-BEST2 ..." \
			    >> "/dev/stderr";
	    exit(2);
	}

	for (arg = 1; arg < ARGC; arg ++) {
	    if (equals = index(ARGV[arg], "=")) {
		var = substr(ARGV[arg], 1, equals - 1);
		val = substr(ARGV[arg], equals + 1);

	        if (var == "multiwords") {
		    multiwords = val + 0;
	        } else if (var == "multichar") {
		    multichar = val;
		} else if (var == "max_nbest") {
		    max_nbest = val + 0;
		} else if (var == "nopauses") {
		    nopauses = val + 0;
		} else if (var == "use_orig_hyps") {
		    use_orig_hyps = val + 0;
		} else if (var == "add_scores") {
		    add_scores = val + 0;
		} 
	    } else {
	        process_nbest(ARGV[arg]);
	    }
	}

	output_nbest();
}

