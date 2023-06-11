#!/usr/local/bin/gawk -f
#
# make-ngram-pfsg --
#	Create a Decipher PFSG from an N-gram language model
#
# usage: make-ngram-pfsg [debug=1] [check_bows=1] [maxorder=N] [no_empty_bo=1] backoff-lm > pfsg
#
# $Header: /home/srilm/CVS/srilm/utils/src/make-ngram-pfsg.gawk,v 1.32 2015-07-03 03:45:38 stolcke Exp $
#

#########################################
#
# Output format specific code
#

BEGIN {
	logscale = 2.30258509299404568402 * 10000.5;
	round = 0.5;
	start_tag = "<s>";
	end_tag = "</s>";
	null = "NULL";
	version = 0;
	top_level_name = "";
	no_empty_bo = 0;

	if ("TMPDIR" in ENVIRON) {
	    tmpdir = ENVIRON["TMPDIR"];
	} else {
	    tmpdir = "/tmp"
	}

	if ("pid" in PROCINFO) {
	    pid = PROCINFO["pid"];
	} else {
	    getline pid < "/dev/pid";
	}
	tmpfile = tmpdir "/pfsg." pid;

	# hack to remove tmpfile when killed
	trap_cmd = ("trap '/bin/rm -f " tmpfile "' 0 1 2 15 30; cat >/dev/null");
	print "" | trap_cmd;

	debug = 0;

	write_contexts = "";
	read_contexts = "";
}

function rint(x) {
	if (x < 0) {
	    return int(x - round);
	} else {
	    return int(x + round);
	}
}

function scale_log(x) {
	return rint(x * logscale);
}

function output_for_node(name) {
	num_words = split(name, words);

	if (num_words == 0) {
	    print "output_for_node: got empty name" >> "/dev/stderr";
	    exit(1);
	} else if (words[1] == bo_name) {
	    return null;
	} else if (words[num_words] == end_tag || \
		   words[num_words] == start_tag) 
	{
	    return null;
	} else {
	    return words[num_words];
	}
}

function node_exists(name) {
	return (name in node_num);
}

function node_index(name) {
	i = node_num[name];
	if (i == "") {
	    i = num_nodes ++;
	    node_num[name] = i;
	    node_string[i] = output_for_node(name);

	    if (debug) {
		print "node " i " = " name ", output = " node_string[i] \
				>> "/dev/stderr";
	    }
	}
	return  i;
}

function start_grammar(name) {
	num_trans = 0;
	num_nodes = 0;
	return;
}

function end_grammar(name) {
	if (!node_exists(start_tag)) {
		print start_tag " tag undefined in LM" >> "/dev/stderr";
		exit(1);
	} else if (!node_exists(end_tag)) {
		print end_tag " tag undefined in LM" >> "/dev/stderr";
		exit(1);
	}

	printf "%d pfsg nodes\n", num_nodes >> "/dev/stderr";
	printf "%d pfsg transitions\n", num_trans >> "/dev/stderr";

	# output version id if supplied
	if (version) {
		print "version " version "\n";
	}

	# use optional top-level grammar name if given
	print "name " (top_level_name ? top_level_name : name);
	printf "nodes %s", num_nodes;
	for (i = 0; i < num_nodes; i ++) {
		printf " %s", node_string[i];
	}
	printf "\n";
	
	print "initial " node_index(start_tag);
	print "final " node_index(end_tag);
	print "transitions " num_trans;
	fflush();

	if (close(tmpfile) < 0) {
		print "error closing tmp file" >> "/dev/stderr";
		exit(1);
	}
	system("/bin/cat " tmpfile);
}

function add_trans(from, to, prob) {
	if (debug) {
	    print "add_trans " from " -> " to " " prob >> "/dev/stderr";
	}
	num_trans ++;
	print node_index(from), node_index(to), scale_log(prob) > tmpfile;
}

#########################################
#
# Generic code for parsing backoff file
#

BEGIN {
	maxorder = 0;
	grammar_name = "PFSG";
	bo_name = "__BACKOFF__";
	start_bo_name = bo_name " __FROM_START__";
	check_bows = 0;
	epsilon = 1e-5;		# tolerance for lowprob detection
}

NR == 1 {
	start_grammar(grammar_name);
	
	if (read_contexts) {
	    while ((getline context < read_contexts) > 0) {
		is_context[context] = 1;
	    }
	    close(read_contexts);
	}
}

NF == 0 {
	next;
}

/^ngram *[0-9][0-9]*=/ {
	num_grams = substr($2,index($2,"=")+1);
	if (num_grams > 0) {
	    order = substr($2,1,index($2,"=")-1);
	
	    # limit maximal N-gram order if desired
	    if (maxorder > 0 && order > maxorder) {
		order = maxorder;
	    }

	    if (order == 1) {
		grammar_name = "UNIGRAM_PFSG";
	    } else if (order == 2) {
		grammar_name = "BIGRAM_PFSG";
	    } else if (order == 3) {
		grammar_name = "TRIGRAM_PFSG";
	    } else {
		grammar_name = "NGRAM_PFSG";
	    }
	}
	next;
}

/^\\[0-9]-grams:/ {
	currorder = substr($0,2,1);
	next;
}
/^\\/ {
	next;
}

#
# unigram parsing
#
currorder == 1 {
	first_word = last_word = ngram = $2;
	ngram_prefix = ngram_suffix = "";

	# we need all unigram backoffs (except for </s>),
	# so fill in missing bow where needed
	if (NF == 2 && last_word != end_tag) {
		$3 = 0;
	}
}

#
# bigram parsing
#
currorder == 2 {
	ngram_prefix = first_word = $2;
	ngram_suffix = last_word = $3;
	ngram = $2 " " $3;
}

#
# trigram parsing
#
currorder == 3 {
	first_word = $2;
	last_word = $4;
	ngram_prefix = $2 " " $3;
	ngram_suffix = $3 " " $4;
	ngram = ngram_prefix " " last_word;
}

#
# higher-order N-gram parsing
#
currorder >= 4 && currorder <= order {
	first_word = $2;
	last_word = $(currorder + 1);
	ngram_infix = $3;
	for (i = 4; i <= currorder; i ++ ) {
		ngram_infix = ngram_infix " " $i;
	}
	ngram_prefix = first_word " " ngram_infix;
	ngram_suffix = ngram_infix " " last_word;
	ngram = ngram_prefix " " last_word;
}

# 
# shared code for N-grams of all orders
#
currorder <= order {
	prob = $1;
	bow = $(currorder + 2);

	# skip backoffs that exceed maximal order,
	# but always include unigram backoffs
	if (bow != "" && (currorder == 1 || currorder < order)) {
	    # remember all LM contexts for creation of N-gram transitions
	    bows[ngram] = bow;

	    # To avoid empty paths through backoff, we reroute transitions
	    # out of the start node to a special backoff node that does not
	    # connect directly to the end node.
	    if (no_empty_bo && ngram == start_tag) {
		this_bo_name = start_bo_name;
	    } else {
		this_bo_name = bo_name;
	    }

	    # insert backoff transitions
	    if (read_contexts ? (ngram in is_context) : \
		                (currorder < order - 1)) \
	    {
		add_trans(this_bo_name " " ngram, this_bo_name " " ngram_suffix, bow);
		add_trans(ngram, this_bo_name " " ngram, 0);
	    } else {
		add_trans(ngram, this_bo_name " " ngram_suffix, bow);
	    }

	    if (write_contexts) {
		print ngram_suffix > write_contexts;
	    }
	}

	if (last_word == start_tag) {
	    if (currorder > 1) {
		printf "warning: ignoring ngram into start tag %s -> %s\n", \
			    ngram_prefix, last_word >> "/dev/stderr";
	    }
	} else {
	    # insert N-gram transition to maximal suffix of target context
	    if (last_word == end_tag) {
		target = end_tag;
	    } else if (ngram in bows || currorder == 1) {
		# the minimal context is unigram
		target = ngram;
	    } else if (ngram_suffix in bows) {
		target = ngram_suffix;
	    } else {
		target = ngram_suffix;
		for (i = 3; i <= currorder; i ++) {
		    target = substr(target, length($i) + 2);
		    if (target in bows) break;
		}
	    }

	    if (currorder == 1 || \
		(read_contexts ? (ngram_prefix in is_context) : \
				 (currorder < order))) \
	    {
		add_trans(bo_name " " ngram_prefix, target, prob);

		# Duplicate transitions out of unigram backoff for the 
		# start-backoff-node
		if (no_empty_bo && \
		    node_exists(start_bo_name " " ngram_prefix) && \
		    target != end_tag)
		{
		    add_trans(start_bo_name " " ngram_prefix, target, prob);
		}
	    } else {
		add_trans(ngram_prefix, target, prob);
	    }

	    if (check_bows) {
		if (currorder < order) {
		    probs[ngram] = prob;
		}
		
		if (ngram_suffix in probs && \
		    probs[ngram_suffix] + bows[ngram_prefix] - prob > epsilon)
		{
		    printf "warning: ngram loses to backoff %s -> %s\n", \
			    ngram_prefix, last_word >> "/dev/stderr";
		}
	    }
	}
}

END {
	end_grammar(grammar_name);
}
