#!/usr/local/bin/gawk -f
#
# nbest2pfsg --
#	convert Decipher N-best list to PFSG lattice
#
# $Header: /home/srilm/CVS/srilm/utils/src/make-nbest-pfsg.gawk,v 1.5 2004/11/02 02:00:35 stolcke Exp $
#
BEGIN {
	initial = 0;
	final = 1;
	nodecount = 2;
	transcount = 0;

	null = "NULL";

	outputs[initial] = outputs[final] = null;

	format = 0;
	name = "";

	notree = 0;	# do build prefix tree

	scale = 0;	# scaling factor for log posteriors
	amw = 1;	# acoustic model weight
	lmw = 8;	# language model weight
	wtw = 0;	# word transition weight
}

function start_hyp() {
	lastnode = initial;
}

function add_word(word, weight) {
	nextnode = tree[lastnode " " word];
	if (nextnode && !notree) {
		if (weights[lastnode " " nextnode] != weight) {
			printf "inconsistent weight for transition %s -> %s\n",\
				lastnode, nextnode >> "/dev/stderr";
			exit 1;
		}

		lastnode = nextnode;
	} else {
		newnode = nodecount ++;
		outputs[newnode] = word;

		tree[lastnode " " word] = newnode;
		weights[lastnode " " newnode] = weight;
		transcount ++;

		lastnode = newnode;
	}
}

function end_hyp(weight) {
	nextnode = tree[lastnode " " null];
	if (nextnode && !notree) {
		if (weights[lastnode " " nextnode] != weight) {
			printf "inconsistent final weight for %s\n",\
						lastnode >> "/dev/stderr";
			exit 1;
		}
	} else {
		tree[lastnode " " null] = final;
		weights[lastnode " " final] = weight;
		transcount ++;
	}
}

function print_pfsg(name) {

	printf "name %s\n", name;
	printf "nodes %d", nodecount;
	for (node = 0; node < nodecount; node ++) {
		printf " %s", outputs[node];
	}
	printf "\n";

	printf "initial %d\n", initial;
	printf "final %d\n", final;

	printf "transitions %d\n", transcount;

	for (trans in weights) {
		split(trans, a);
		fromnode = a[1];
		tonode = a[2];

		printf "%d %d %g\n", fromnode, tonode, \
					weights[fromnode " " tonode];
	}
	printf "\n";
}

/^NBestList1\.0/ {
	format = 1;
	next;
}
/^NBestList2\.0/ {
	format = 2;
	next;
}
format == 0 {
	totalscore = scale * (amw * $1 + lmw * $2 + wtw * $3);
	start_hyp();
	for (i = 4; i <= NF; i ++) {
		add_word($i, 0);
	}
	end_hyp(totalscore);
	next;
}
format == 1 {
	totalscore = scale * substr($1, 2, length($1)-2);
	start_hyp();
	for (i = 2; i <= NF; i ++) {
		add_word($i, 0);
	}
	end_hyp(totalscore);
	next;
}
format == 2 {
	start_hyp();
	for (i = 2; i <= NF; i += 11) {
		add_word($i, scale * ($(i + 7) + $(i + 9)));
	}
	end_hyp(0);
	next;
}
END {
	if (!name) {
		name = FILENAME;
	}
	print_pfsg(name);
}

