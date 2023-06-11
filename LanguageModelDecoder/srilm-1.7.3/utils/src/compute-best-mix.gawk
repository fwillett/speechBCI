#!/usr/local/bin/gawk -f
#
# compute-best-mix --
#	Compute the best mixture weight (-lambda) for interpolating N
#	LMs.
#
# usage: compute-best-mix [lambda="l1 l2 ..."] [precision=p] pplout1 pplout2 ...
#j
# where pplout1, pplout2, ... is the output of ngram -debug 2 -ppl for the 
# models.  li are initial guesses at the mixture weights, and p is the
# precision with which the best lambda vector is to be found.
#
# $Header: /home/srilm/CVS/srilm/utils/src/compute-best-mix.gawk,v 1.13 2017/12/22 01:34:49 stolcke Exp $
#
BEGIN {
	verbose = 0;

	lambda = "0.5";
	precision = 0.001;
	M_LN10 = 2.30258509299404568402;	# from <math.h>

	logINF = -320;

	unk = "<unk>";
}
function abs(x) {
	return (x < 0) ? -x : x;
}
function log10(x) {
	return log(x) / M_LN10;
}
function exp10(x) {
	if (x < logINF) {
		return 0;
	} else {
		return exp(x * M_LN10);
	}
}
function addlogs(x,y) {
    if (x<y) {
	temp = x; x = y; y = temp;
    }
    return x + log10(1 + exp10(y - x));
}

function print_vector(x, n) {
	result = "(" x[1];
	for (k = 2; k <= n; k++) {
		result = result " " x[k];
	}
	return result ")"
}

function print_vector_pairwise(x, n) {
	total_lambda = x[1];
	result = "(" 1;
	for (k = 2; k <= n; k++) {
		total_lambda += x[k];
		result = result " " x[k]/total_lambda;
	}
	return result ")"
}

FNR == 1 {
	nfiles ++;
}
$1 == "p(" {

	word = $2;
        # Canonicalize input to have at most one representative context word; 
        sub("[|] [^)]*)", "| X )");
        $0 = $0;

	if ($0 ~ /\[ -[Ii]nf|\[ -1\.#INF/) {
	    prob = logINF;
	} else {
	    prob = $10;
	}

        # If a count is given.
	if ($11 ~ /^[*]/) {
	    count = substr($11,2);
	} else {
	    count = 1;
	}

	sample_no = ++ nsamples[nfiles];
	samples[nfiles " " sample_no] = prob;
	counts[sample_no] = count;

	if (sample_no in words) {
	    if (word != words[sample_no] && word != unk && words[sample_no] != unk) {
		print "warning: word mismatch in file " FILENAME ", token " sample_no \
			": " word " != " words[sample_no] > "/dev/stderr";
	    }
	} else {
	    words[sample_no] = word;
	}
}
END {
	for (i = 2; i <= nfiles; i ++) {
		if (nsamples[i] != nsamples[1]) {
			printf "mismatch in number of samples (%d != %d)", \
				nsamples[1], nsamples[i] >> "/dev/stderr";
			exit(1);
		}
	}

	last_prior = 0.0;

	# initialize priors from lambdas
	nlambdas = split(lambda, lambdas);
	lambda_sum = 0.0;
	for (i = 1; i <= nlambdas; i ++) {
		priors[i] = lambdas[i];
		lambda_sum += lambdas[i];
	}
	# fill in the missing lambdas
	for (i = nlambdas + 1; i <= nfiles; i ++) {
		priors[i] = (1 - lambda_sum)/(nfiles - nlambdas);
	}

	iter = 0;
	have_converged = 0;
	while (!have_converged) {
	    iter ++;

	    num_oovs = num_words = 0;
	    delete post_totals;
	    log_like = 0;

	    for (j = 1; j <= nsamples[1]; j ++) {

		all_inf = 1;
		for (i = 1; i <= nfiles; i ++) {
			sample = samples[i " " j];
			logpost[i] = log10(priors[i]) + sample;
			all_inf = all_inf && (sample == logINF);
			if (i == 1) {
				logsum = logpost[i];
			} else {
				logsum = addlogs(logsum, logpost[i]);
			}
		}

		# skip OOV words
		if (all_inf) {
   		        num_oovs += counts[j];
			continue;
		}

		num_words += counts[j];
		log_like += logsum * counts[j];

		for (i = 1; i <= nfiles; i ++) {
			post_totals[i] += exp10(logpost[i] - logsum) * counts[j];
		}
	    }

	    printf "iteration %d, lambda = %s, ppl = %g\n", \
		    iter, print_vector(priors, nfiles), \
		    exp10(-log_like/num_words) >> "/dev/stderr";
	    fflush();

	
	    have_converged = 1;
	    for (i = 1; i <= nfiles; i ++) {
		last_prior = priors[i];
		priors[i] = post_totals[i]/num_words;

		if (abs(last_prior - priors[i]) > precision) {
			have_converged = 0;
		}
	    }
	}

	printf "%d non-oov words, best lambda %s\n", 
			num_words, print_vector(priors, nfiles);
	printf "pairwise cumulative lambda %s\n", 
			print_vector_pairwise(priors, nfiles);
}
