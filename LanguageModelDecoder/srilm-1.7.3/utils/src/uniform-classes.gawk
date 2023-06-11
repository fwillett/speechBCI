#!/usr/local/bin/gawk -f
#
# uniform-classes --
#	Assign uniform membership probabilities to word class expansions
# 	that don't already have probabilities
#
# usage: uniform-clases CLASSFILE > UNIFORM-CLASSFILE
#
# $Header: /home/srilm/CVS/srilm/utils/src/uniform-classes.gawk,v 1.3 2016/05/13 23:00:35 stolcke Exp $
#

BEGIN {
    num_class_defs = 0;
}

{
    line = $0;

    n = split(line, a);
    if (n == 0) next;

    class = a[1];
    num_exp = ++ num_class_expansions[class];

    if (a[2] ~ /^[-+]?[.]?[0-9][0-9.]*(e[+-]?[0-9]+)?$/) {
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

END {
    print "read " num_class_defs " class expansions" >> "/dev/stderr";

    # assign default expansion probs

    for (class in num_class_expansions) {

	num_exp =  num_class_expansions[class];

	for (i = 1; i <= num_exp; i ++) {
	    prob = class_expansion_probs[class " " i];

	    if (prob == "") {
		prob = 1/num_exp;
	    }

	    print class, prob, class_expansions[class " " i];
	}
    }
}

