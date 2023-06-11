#!/usr/local/bin/gawk -f
#
# wlat-to-pfsg --
#	Create a Decipher PFSG from a nbest-lattice(1) word lattice
#
# usage: wlat-to-pfsg word-lattice> pfsg
#
# $Header: /home/srilm/CVS/srilm/utils/src/wlat-to-pfsg.gawk,v 1.6 2009/06/07 17:33:09 stolcke Exp $
#

#########################################
#
# Output format specific code
#

BEGIN {
	logscale = 10000.5;
	round = 0.5;

	null = "NULL";
	start_tag = "<s>";
	end_tag = "</s>";

	tmpfile = "tmp.pfsg.trans";
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

function start_grammar(name) {
	num_trans = 0;
	num_nodes = 0;
	return;
}

function end_grammar(name) {
	printf "%d pfsg nodes\n", num_nodes >> "/dev/stderr";
	printf "%d pfsg transitions\n", num_trans >> "/dev/stderr";

	print "name " name;
	printf "nodes %s", num_nodes;
	for (i = 0; i < num_nodes; i ++) {
	    if (node_string[i] == "") {
		print "warning: node word " i " is undefined" >> "/dev/stderr";
		node_string[i] = null;
	    } else if (i == initial_node && node_string[i] == start_tag || \
		       i == final_node && node_string[i] == end_tag) {
		node_string[i] = null;
	    }
	    printf " %s", node_string[i];
	}
	printf "\n";
	
	print "initial " initial_node;
	print "final " final_node;
	print "transitions " num_trans;
	fflush();

	close(tmpfile);
	system("/bin/cat " tmpfile "; /bin/rm -f " tmpfile);
}

function set_initial(node) {
	initial_node = node;
}

function set_final(node) {
	final_node = node;
}

function add_node(node, word) {
	if (node >= num_nodes) {
		num_nodes = node + 1;
	}
	node_string[node] = word;
}

function add_trans(from, to, prob) {
	num_trans ++;
	print from, to, scale_log(prob) > tmpfile;
}

#########################################
#
# Word lattice parsing
#

BEGIN {
	grammar_name = "PFSG";
}

NF == 0 {
	next;
}

$1 == "name" {
	grammar_name = $2;
	next;
}

#
# nbest-lattice output (without -use-mesh)
#
$1 == "version" {
	if ($2 != 2) {
		print "need word lattice version 2" >> "/dev/stderr";
		exit 1;
	}
}

$1 == "initial" {
	start_grammar(grammar_name);

	set_initial($2);
}

$1 == "final" {
	set_final($2);
}

$1 == "node" {
	add_node($2, $3);

	posterior = $5;

	if (posterior == 0) {
	    print "node " $2 ": zero posterior, omitting it" >> "/dev/stderr";
	    next;
	}

	for (i = 6; i <= NF; i += 2) {
	    if ($(i + 1) == 0) {
		print "node " $2 ": omitting zero posterior transition" \
							    >> "/dev/stderr";
	    } else {
		    add_trans($2, $i, log($(i + 1)/posterior));
	    }
	}
}

#
# nbest-lattice -use-mesh output (confusion networks)
#
$1 == "numaligns" {
	start_grammar(grammar_name);

	numaligns = $2;

	# 
	# use nodes 0 ... numaligns between the words
	# then allocate additional nodes for each word
	set_initial(0);
	set_final(numaligns);

	for (i = 0; i <= numaligns; i ++) {
		add_node(i, null);
	}
	numnodes = numaligns + 1;
}

$1 == "align" {

	pos = $2;

	for (i = 3; i <= NF; i += 2) {
		word = $i;
		posterior = $(i + 1);

		if (posterior == 0) {
		    print "align " pos ", word " word \
				": zero posterior, omitting it" >> "/dev/stderr";
		    continue;
		}

		if (word == "*DELETE*") {
		    add_trans(pos, pos + 1, log(posterior));
		} else {
		    add_node(numnodes, word);
		    add_trans(pos, numnodes, log(posterior));
		    add_trans(numnodes, pos + 1, 0);

		    numnodes ++;
		}
	}
}

END {
	end_grammar(grammar_name);
}
