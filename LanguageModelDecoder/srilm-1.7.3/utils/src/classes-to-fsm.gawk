#!/usr/local/bin/gawk -f
#
# usage: classes-to-fsm [symbolic=1] [isymbolfile=ISYMBOLS] [osymbolfile=OSYMBOLS] \
#			vocab=VOCAB CLASSES > class.fsm
#
# where ISYMBOLS is the input symbol table, OSYMBOLS is the output symbol table
# VOCAB is the word list 
#
# $Header: /home/srilm/CVS/srilm/utils/src/classes-to-fsm.gawk,v 1.1 1999/09/27 01:10:27 stolcke Exp $
# 
BEGIN {
    empty_input = "NULL";
    empty_output = "NULL";
    input_symbols[empty_input] = 0;
    output_symbols[empty_output] = 0;
    numinputs = 1;
    numoutputs = 1;

    isymbolfile = "";
    osymbolfile = "";
    symbolic = 0;

    startstate = 0;
    numstates = 1;

    M_LN10 = 2.30258509299404568402;	# from <math.h>
    logscale = 10000.5;
    round = 0.5;
}

NR == 1 {
    # print start/end state
    print startstate;

    if (vocab) {
	while ((getline vline < vocab) > 0) {
	    if (split(vline, a) >= 1) {
		word = a[1];
		input_symbols[word] = numinputs ++;
		output_symbols[word] = numoutputs ++;

		# print identity transition for vocab words
		print startstate, startstate, \
			    (symbolic ? word : input_symbols[word]), \
			    (symbolic ? word : output_symbols[word]);
	    }
	}
	    
    }
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
	# return log(x) / M_LN10;
}

# input format is
# 	CLASS	[PROB]	WORD1 WORD2 ... WORDN
{
    if (NF == 0) {
	    next;
    }

    class = $1;

    if (!(class in input_symbols)) {
	input_symbols[class] = numinputs++;
    }

    if ($2 ~ /^[-+]?[.]?[0-9][0-9.]*(e[+-]?[0-9]+)?$/) {
	prob = $2;
	first = 3;
    } else {
	prob = 1;
	first = 2;
    }

    # deal with empty class expansion: map class to NULL
    if (first > NF) {
	print startstate, startstate, \
		(symbolic ? class : input_symbols[class]), \
		(symbolic ? empty_output : 0), \
		-scale_prob(prob);
    }

    for (i = first; i <= NF; i ++) {
	if (!($i in output_symbols)) {
	    output_symbols[$i] = numoutputs ++;
	}

	if (i == NF) {
	    next_state = startstate;
	} else {
	    next_state = numstates ++;
	}

	if (i == first) {
	    print startstate, next_state,
		    (symbolic ? class : input_symbols[class]), \
		    (symbolic ? $i : output_symbols[$i]), \
		    -scale_prob(prob);
	} else {
	    print last_state, next_state,
		    (symbolic ? empty_input : 0), \
		    (symbolic ? $i : output_symbols[$i]), \
		    -scale_prob(1);
	}

	last_state = next_state;
    }
}

END {
    if (isymbolfile) {
	for (word in input_symbols) {
		print word, input_symbols[word] > isymbolfile;
	}
	close(isymbolfile);
    }
    if (osymbolfile) {
	for (word in output_symbols) {
		print word, output_symbols[word] > osymbolfile;
	}
	close(osymbolfile);
    }
}
