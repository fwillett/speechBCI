#!/usr/local/bin/gawk -f
#
# fsm-to-pfsg --
#	convert AT&T FSM acceptor to Decipher PFSG format
#
# usage: fsm-to-pfsg [pfsg_name=NAME] [transducer=1] [scale=S] file.fsm > file.pfsg
# pfsg_name=NAME	sets PFSG name to NAME
# transducer=1		indicates input is a transducer
# scale=S		sets transition weight scaling factor to S
#			(default -1)
#
# $Header: /home/srilm/CVS/srilm/utils/src/fsm-to-pfsg.gawk,v 1.10 2015-07-03 03:45:38 stolcke Exp $
#
BEGIN {
	pfsg_name = "from_fsm";
	transducer = 0;		# input is transducer

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
	tmpfile = tmpdir "/fsm.tmp" pid;

	# hack to remove tmpfile when killed
	trap_cmd = ("trap '/bin/rm -f " tmpfile "' 0 1 2 15 30; cat >/dev/null");
	print "" | trap_cmd;

	num_newnodes = 0;
	initial_node = -1;
	empty_output = "NULL";
	epsilon = "<eps>";	# FSM epsilon symbol
	map_epsilon = "";	# map epsilon to this symbol
	scale = -1;		# scaling of transition weights
}

# transition description
NF >= 3 {
	from_node = $1;
	to_node = $2;

	if (map_epsilon && $3 == epsilon) $3 = map_epsilon;

	if (transducer) {
		if (map_epsilon && $4 == epsilon) $4 = map_epsilon;

		# collapse input and output into a single symbol
		$3 = $3 ":" $4;	
		$4 = "";
	}

	output = $3;

	if (initial_node < 0) {
		initial_node = from_node;
	}

	
	# create new node names for pairs of output,old-node
	if (!(output " " to_node in newnode_table)) {
		output_table[num_newnodes] = output;
		newnode_table[output " " to_node] = num_newnodes ++;

		# create list of incoming outputs for each state
		insymbols[to_node] = insymbols[to_node] " " output;
	}

	# save for re-reading
	print $0 > tmpfile;
	next;
}

# final state description
NF >= 1 {
	node = $1;

	if (initial_node < 0) {
		initial_node = node;
	}

	# save for re-reading
	print $0 > tmpfile;
	next;
}

END {
	close(tmpfile);

	# create initial and final nodes
	if (!(empty_output " " initial_node in newnode_table)) {
	    output_table[num_newnodes] = empty_output;
	    newnode_table[empty_output " " initial_node] = num_newnodes ++;
	    insymbols[initial_node] = insymbols[initial_node] " " empty_output;
	}
	
	initial_newnode = newnode_table[empty_output " " initial_node];
	output_table[num_newnodes] = empty_output;
	final_newnode = num_newnodes++;

	# print PFSG header info
	print "name " pfsg_name;
	printf "nodes %d", num_newnodes;
	for (i = 0; i < num_newnodes; i ++) {
		printf " %s", output_table[i];
	}
	printf "\n";
	printf "initial %d\n", initial_newnode;
	printf "final %d\n", final_newnode;

	# re-read FSM description, counting total number of new 
	# transitions 
	num_transitions = 0;
	while (getline < tmpfile) {
		from_node = $1;

		# duplicate transition for all insymbols of from_node
		num_transitions += split(insymbols[from_node], a);
	}
	close(tmpfile);
	printf "transitions %d\n", num_transitions;

	# re-read FSM description, outputing new transitions
	while (getline < tmpfile) {
	    if (NF >= 3) {
		from_node = $1;
		to_node = $2;
		output = $3;
		cost = (NF == 3 ? 0 : $4);
		
		# duplicate transition for all insymbols of from_node
		n = split(insymbols[from_node], a);
		for (i = 1; i <= n; i ++) {
		    printf "%d %d %d\n", \
			  newnode_table[a[i] " " from_node], \
			  newnode_table[output " " to_node], \
			  scale * cost;
		}
	    } else {
		from_node = $1;
		cost = (NF == 1 ? 0 : $2);

		# add final transition for all insymbols of from_node
		n = split(insymbols[from_node], a);
		for (i = 1; i <= n; i ++) {
		    printf "%d %d %d\n", \
			  newnode_table[a[i] " " from_node], \
			  final_newnode, \
			  scale * cost;
		}
	    }
	}
}
