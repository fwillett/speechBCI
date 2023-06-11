#!/usr/local/bin/gawk -f
# 
# pfsg-to-fsm --
#	convert a Decipher PFSG to AT&T FSM format
#
# usage: pfsg-to-fsm [symbolfile=SYMFILE] [symbolic=1] [scale=S] file.pfsg > file.fsm
#
# symbolic=1		retains output word strings in the fsm file.
# symbolfile=SYMFILE 	dump output symbol table to SYMFILE
#			(to be used with fsmcompile|fsmdraw|fsmprint -i SYMFILE)
# scale=S		set transition weight scaling factor to S
#			(default -1)
# 
#
# $Header: /home/srilm/CVS/srilm/utils/src/pfsg-to-fsm.gawk,v 1.16 2015-07-03 03:45:38 stolcke Exp $
#
BEGIN {
	empty_output = "NULL";
	output_symbols[empty_output] = 0;
	numoutputs = 1;

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
	tmpfile = tmpdir "/pfsg.tmp" pid;

	# hack to remove tmpfile when killed
	trap_cmd = ("trap '/bin/rm -f " tmpfile "' 0 1 2 15 30; cat >/dev/null");
	print "" | trap_cmd;

	symbolfile = "";
	symbolic = 0;

	scale = -1;	# scaling of transition weights
	nofinal = 0;	# do output final node definition
	final_output = "";
}
$1 == "nodes" {
	numnodes = $2;

	for (i = 0; i < numnodes; i++) {
		node_output[i] = $(i + 3);

		if (!(node_output[i] in output_symbols)) {
			output_symbols[node_output[i]] = numoutputs++;
		}
	}

	next;
}
$1 == "initial" {
	initial_node = $2;

	if (node_output[initial_node] != empty_output) {
		print "initial node must be NULL" >> "/dev/stderr";
		exit 1;
	}
	next;
}
$1 == "final" {
	final_node = $2;

	if (final_output) {
		node_output[final_node] = final_output;
		if (!(final_output in output_symbols)) {
			output_symbols[final_output] = numoutputs++;
		}
	}
	next;
}

function print_trans(from_node, to_node, cost) {
	if (to_node == final_node && node_output[final_node] == empty_output) {
		print from_node, scale * cost;
	} else {
		# PFSG bytelogs have to be negated to FSM default semiring
		print from_node, to_node, \
			(symbolic ? node_output[to_node] : \
			 output_symbols[node_output[to_node]]), \
			scale * cost;
	}
}

function print_final() {
	# if the final node is non-emitting, we don't need to output it
	# at all (see print_trans above)
	if (!nofinal && node_output[final_node] != empty_output) {
		print final_node, 0;
	}
}

$1 == "transitions" {
	num_transitions = $2;

	# process the transitions and map them to FSM transitions and
	# final states.
	# FSM requires the first transition to be out of the initial state,
	# so we scan the transitions twice.
	# The first time, to find the initial transitions, then
	# to add all the others. Yuck!
	for (k = 1; k <= num_transitions; k ++) {
		getline;

		from_node = $1;
		to_node = $2;
		cost = $3;

		if (from_node == initial_node) {
			print_trans(from_node, to_node, cost);
		} else {
			print > tmpfile;
		}
	}
	close(tmpfile);

	# output definition of the final node
	print_final();

	# now process all the non-initial transitions
	while (getline < tmpfile) {
		from_node = $1;
		to_node = $2;
		cost = $3;

		print_trans(from_node, to_node, cost);
	}

	next;
}

END {
	# dump out the symbol table
	if (symbolfile) {
		for (s in output_symbols) {
			print s, output_symbols[s] > symbolfile;
		}
	}
}
