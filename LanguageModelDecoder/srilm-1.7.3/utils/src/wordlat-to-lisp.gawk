#!/usr/local/bin/gawk -f 
#
# wordlat-to-lisp --
#	Convert a word lattice description to BOOGIE-readable format
#
# #Header:$
#
BEGIN {
	print "(setq *draw-no-probs* t)";
	print "(setq *grammar* (grammar-from-list '(";
}
$1 == "initial" {
	initial = $2;
}
$1 == "final" {
	final = $2;
}
$1 == "node" {
	state = $2;
	word = $3;
	gsub("'", "+", word);
	score = $4;
	print "(" state "(";
	for (i = 5; i <= NF; i++) {
		print "  (0 . " $i ")";
	}
	print " ) ((" score " . " word ")))";
}
END {
	print ") (make-instance 'list-hmm :start-state " initial \
			" :end-state " final \
			" :state-order-fn #'number-order)))"
}
