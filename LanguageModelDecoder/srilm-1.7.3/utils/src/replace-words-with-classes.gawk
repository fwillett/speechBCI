#!/usr/local/bin/gawk -f
#
# replace-with-words-classes --
#	replace class expansions with class names
#
# usage: replace-with-words-classes classes=<classfile> text > text-with-classes
#        replace-with-words-classes classes=<classfile> have_counts=1 counts \
#							> counts-with-classes
#
# optional arguments:
#	outfile=<file>	output file for class expansion counts (default: none)
#	normalize=<0|1>	normalize counts to probabilities (default = 1)
#	addone=<count>	value to add to counts for probability smoothing (1)
#
# $Header: /home/srilm/CVS/srilm/utils/src/replace-words-with-classes.gawk,v 1.7 2004/11/02 02:00:35 stolcke Exp $
#

function read_classes(file) {
	
    num_class_defs = 0;
    delete num_class_expansions;
    delete class_expansions;
    delete class_expansion_probs;

    while ((getline line < file) > 0) {

	n = split(line, a);
	if (n == 0) continue;

	class = a[1];
	num_exp = ++ num_class_expansions[class];

	if (a[2] ~ /^[-+0-9.][-+0-9e.]*$/) {
		prob = a[2];
		i = 3;
	} else {
		prob = "";
		i = 2;
	}
	
	expansion = a[i];
	for (i++; i <= n; i++) {
	    expansion = expansion " " a[i];
	}

	class_expansions[class " " num_exp] = expansion;
	if (prob != "") {
	    class_expansion_probs[class " " num_exp] = prob;
	}
	num_class_defs ++;
    }

    print "read " num_class_defs " class expansions" >> "/dev/stderr";

    # assign default expansion probs

    for (class in num_class_expansions) {

	num_exp =  num_class_expansions[class];

	for (i = 1; i <= num_exp; i ++) {
	    if (class_expansion_probs[class " " i] == "") {
		class_expansion_probs[class " " i] = 1/num_exp;
	    }
	}
	
    }
}

##############################################################################

function add_to_prefix_tree(class, expansion, prob) {

    nwords = split(expansion, w);

    node = 0;

    for (k = 1; k <= nwords; k ++) {
	next_node = tree[node " " w[k]];

	if (!next_node) {
	    next_node = ++num_nodes;
	    tree[node " " w[k]] = next_node;
	}

	node = next_node;
    }

    if (!(node in node_class)) {
	node_class[node] = class;
	node_prob[node] = prob;
    }
    return node;
}

BEGIN {
    normalize = 1;
    addone = 1;
    partial = 0;
}

NR == 1 {
    if (classes) {
	read_classes(classes);
	close(classes);
    } else {
	print "no classes file specified" >> "/dev/stderr";
    }

    for (class in num_class_expansions) {
	for (i = 1; i <= num_class_expansions[class]; i ++) {
	    class_expansion_node[class " " i] = \
		add_to_prefix_tree(class, class_expansions[class " " i], \
				    class_expansion_probs[class " " i]);
	}
    }
}
	
{
    output = "";
    next_pos = 1;


    # partial option: multiple spaces block multiword replacement
    if (partial) {
	gsub("[ 	][ 	]*[ 	]", " | ");
    }

    #
    # handle ngram counts by simply leaving the count value alone
    # and doing substitution on the ngram itself.
    #
    if (have_counts) {
	max_pos = NF - 1;
    } else {
	max_pos = NF;
    }

    while (next_pos <= max_pos) {

	class = "";
	prob = 0;
	num_exp_words = 0;

	# search for largest class expansion starting at current position
	node = 0;
	k = 0;
	while (1) {
	    node = tree[node " " $(next_pos + k)];

	    if (node) {
		if (node in node_class) {
		    # we have found a complete expansion, record its class
		    class = node_class[node];
		    class_node = node;
		    prob = node_prob[prob];
		    num_exp_words = k + 1;
		}
	    } else {
		break;
	    }
	    k ++;
	}

	if (next_pos == 1) {
	    space = "";
	} else {
	    space = " ";
	}

	if (!class) {
	    output = output space $next_pos;
	    next_pos ++;
	} else {
	    output = output space class;
	    next_pos += num_exp_words;

	    node_count[class_node] ++;
	    class_count[class] ++;
	}
    }

    # partial option: multiple spaces block multiword replacement
    if (partial) {
	gsub(" [|] ", " ", output);
	sub("^[|]", " ", output);
	sub("[|]$", " ", output);
    }

    if (have_counts) {
	print output, $NF;
    } else {
	print output;
    }
}

function estimate(count, total, N) {
    denom = total + N *addone;

    if (denom == 0) {
	return 0;
    } else {
	return (count + addone)/denom;
    }
}

END {
    if (outfile) {
	for (class in num_class_expansions) {
	    for (i = 1; i <= num_class_expansions[class]; i ++) {
		nc = node_count[class_expansion_node[class " " i]] + 0;
		print class, \
		      normalize ? \
				 estimate(nc, class_count[class], \
					num_class_expansions[class]) :
				 nc, \
		      class_expansions[class " " i] > outfile;
	    }
	}
	close(outfile);
    }
}

