#!/usr/local/bin/gawk -f
#
# wlat-to-dot --
#	Generate dot(1) graph description from word lattice generates by
#	nbest-lattice(1)
#
# usage: wlat-to-dot [show_probs=1] file.wlat > file.dot
#
# $Header: /home/srilm/CVS/srilm/utils/src/wlat-to-dot.gawk,v 1.6 2004/11/02 02:00:35 stolcke Exp $
#
BEGIN {
	name = "WLAT"; 
	show_probs = 0;
	show_nums = 0;

	version = 1;
}
$1 == "name" {
	name = $2;
}

#
# nbest-lattice output (without -use-mesh)
#
$1 == "initial" {
	print "digraph \"" name "\" {";
	print "rankdir = LR";

	i = $2;
}
$1 == "final" {
	i = $2;
}
$1 == "version" {
	version = $2;
}
$1 == "node" && version == 1 {
	from = $2;
	word = $3;
	post = $4;

	print "\tnode" from " [label=\"" word \
		(!show_nums ? "" : ("/" from)) \
		(!show_probs ? "" : "\\n" post ) "\"]";

	for (i = 5; i <= NF; i ++) {
	    to = $i;
	    print "\tnode" from " -> node" to ";"
	}
}
$1 == "node" && version == 2 {
	from = $2;
	word = $3;
	align = $4;
	post = $5;

	print "\tnode" from " [label=\"" word \
		(!show_nums ? "" : ("/" from)) \
		"\\n" align \
		(!show_probs ? "" : "/" post ) "\"]";

	for (i = 6; i <= NF; i += 2) {
	    to = $i;
	    print "\tnode" from " -> node" to \
		(!show_probs ? "" : " [label=\"" $(i + 1) "\"]") ";"
	}
}

#
# nbest-lattice -use-mesh output (confusion networks)
#

$1 == "numaligns" {
	print "digraph \"" name "\" {";
	print "rankdir = LR";

	print "node0 [label=\"" (show_nums ? 0 : "") "\"]";
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

		print "node" pos " -> node" (pos + 1) \
			" [label=\"" word \
			(show_probs ? ("\\n" posterior) : "") \
			"\"]";
	}
	print "node" (pos + 1) " [label=\"" (show_nums ? (pos + 1) : "") "\"]";
}

END {
	print "}"
}

