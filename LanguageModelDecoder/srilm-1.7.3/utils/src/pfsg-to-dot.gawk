#!/usr/local/bin/gawk -f
#
# pfsg-to-dot --
#	Generate dot(1) graph description from PFSG
#
# usage: pfsg-to-dot [show_probs=1] [show_nums=1] file.pfsg > file.dot
#
# $Header: /home/srilm/CVS/srilm/utils/src/pfsg-to-dot.gawk,v 1.5 2003/07/10 21:09:15 stolcke Exp $
#
BEGIN {
	show_probs = 0;
	show_logs = 0;
	show_nums = 0;
	in_a_pfsg = 0;

	logscale = 10000.5;
}

function bytelog2prob(p) {
	x = p / logscale;
	if (x < -7e2) {
	    return 0;
	} else {
	    return exp(x);
	}
}

function bytelog2log10(p) {
	return p / logscale / 2.30258509299404568402;
}

$1 == "name" {
	name = $2;

	# handle repeated PFSGs in the same file
	if (in_a_pfsg)
	       print "} digraph \"" name "\" {";
	else
	       print "digraph \"" name "\" {";
	  
	print "rankdir = LR";
	dotrans = 0;
	in_a_pfsg = 1;
}

function node_label(w, i) {
	if (show_nums) {
		return w "\\n" i;
	} else {
		return w;
	}
}
 
$1 == "nodes" {
	numnodes = $2;
	for (i = 0; i < numnodes; i ++) {
		print "\tnode" i " [label=\"" $(i + 3) \
				(show_nums ? "\\n" i : "") "\"];"
	}
}
$1 == "initial" {
	i = $2;

#	print "\tnode" i " [label=\"START\"];"
}
$1 == "final" {
	i = $2;

#	print "\tnode" i " [label=\"END\"];"
}
$1 == "transitions" {
	dotrans = 1;
	next;
}
dotrans && NF == 3 {
	from = $1;
	to = $2;
	prob = $3;

	print "\tnode" from " -> node" to \
		(!(show_probs || show_logs) ? "" :
			" [label=\"" (show_logs ? bytelog2log10(prob) :
						bytelog2prob(prob)) "\"]") ";"
}
END {
	print "}"
}
