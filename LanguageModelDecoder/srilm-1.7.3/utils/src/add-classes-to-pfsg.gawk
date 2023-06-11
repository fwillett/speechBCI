#!/usr/local/bin/gawk -f
#
# add-classes-to-pfsg --
#	Modify Decipher PFSG by expanding class nodes with words
#
# usage: add-classes-to-pfsg classes=<expansions> pfsg > expanded-pfsg
#
# $Header: /home/srilm/CVS/srilm/utils/src/add-classes-to-pfsg.gawk,v 1.5 2004/11/02 02:00:35 stolcke Exp $
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

######################################################################

BEGIN {
    logscale = 10000.5;
    round = 0.5;

    null = "NULL";

    classes_toupper = 1;	# map class names to upper case
}

function rint(x) {
    if (x < 0) {
	return int(x - round);
    } else {
	return int(x + round);
    }
}

function scale_prob(x) {
    return rint(log(x) * logscale);
}

function print_class_pfsg(class) {
    print "name " (classes_toupper ? toupper(class) : class);

    # compute total number of nodes needed
    num_exp =  num_class_expansions[class];
    num_words = 0;
    all_words = "";
    for (i = 1; i <= num_exp; i ++) {
	num_words += split(class_expansions[class " " i], a);
	all_words = all_words " " class_expansions[class " " i];
    }

    print "nodes " (num_words + 2) " " null " " null all_words;

    initial = 0;
    final = 1;
    print "initial " initial;
    print "final " final;

    print "transitions " (num_words + num_exp);

    node_index = final;

    for (i = 1; i <= num_exp; i ++) {
	n = split(class_expansions[class " " i], a);
	if (n == 0) {
	    print initial, final, \
		    scale_prob(class_expansion_probs[class " " i]);
	} else {
	    print initial, ++node_index, \
		    scale_prob(class_expansion_probs[class " " i]);

	    for (k = 2; k <= n; k ++) {
		print node_index, node_index + 1, 0;
		node_index ++;
	    }

	    print node_index, final, 0;
	}
    }

    print "";
}

NR == 1 {
    if (classes) {
	read_classes(classes);
    }
    close(classes);
}

# record class names used in PFSGs
$1 == "nodes" {
    for (i = 3; i <= NF; i ++) {
	if ($i != null && $i in num_class_expansions) {
	    class_used[$i] = 1;
	    if (classes_toupper) {
		upper_class = toupper($i);

		if ($i != upper_class && upper_class in num_class_expansions) {
		    print "cannot map class " $i \
			" to uppercase due to name conflict" >> "/dev/stderr";
		    exit 1;
		}

		$i = upper_class;
	    }
	}
    }
    print;
    next;
}

# pass old PFSGs through unchanged
{
    print;
}
	
# dump out class PFSGs
END {
    print "";

    for (class in class_used) {
	print_class_pfsg(class);
    }
}

