#!/usr/local/bin/gawk -f
#
# compute-best-sentence-mix --
#	Compute the best sentence-level mixture weight for interpolating N
#	LMs.
#
# usage: compute-best-sentence-mix [lambda="l1 l2 ..."] [addone=N] [precision=p] pplout1 pplout2 ...
#
# where pplout1, pplout2, ... is the output of ngram -debug 1 -ppl for the 
# models.  li are initial guesses at the mixture weights, and p is the
# precision with which the best lambda vector is to be found.
#
# $Header: /home/srilm/CVS/srilm/utils/src/compute-best-sentence-mix.gawk,v 1.4 2016/06/01 20:20:38 stolcke Exp $
#
BEGIN {
	verbose = 0;

	lambda = "0.5";
	addone = 0;
	precision = 0.001;
	M_LN10 = 2.30258509299404568402;	# from <math.h>

	logINF = -320;
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

FNR == 1 {
	nfiles ++;
	num_words = 0;
	num_sentences = 0;
}

# 1 sentences, 6 words, 0 OOVs
/^1 sentences, [0-9]* words, [0-9]* OOVs/ {
	# exclude OOVs
	num_words += $3 - $5;
	expect_logprob = 1;
}

# 0 zeroprobs, logprob= -22.9257 ppl= 1884.06 ppl1= 6621.32
/^[0-9]* zeroprobs, logprob= / && expect_logprob {

	# exclude zero prob words
	num_words -= $1;
	num_sentences += 1;

	if ($4 ~ /-[Ii]nf|-1\.#INF/) {
	    prob = logINF;
	} else {
	    prob = $4;
	}

	sample_no = ++ nsamples[nfiles];
	samples[nfiles " " sample_no] = prob;

	expect_logprob = 0;
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
			continue;
		}

		log_like += logsum;

		for (i = 1; i <= nfiles; i ++) {
			post_totals[i] += exp10(logpost[i] - logsum);
		}
	    }
	    printf "iteration %d, lambda = %s, ppl = %g\n", \
		    iter, print_vector(priors, nfiles), \
		    exp10(-log_like/(num_words + num_sentences)) \
							>> "/dev/stderr";
	    fflush();
	
	    have_converged = 1;
	    for (i = 1; i <= nfiles; i ++) {
		last_prior = priors[i];
		priors[i] = (post_totals[i] + addone)/(num_sentences + nfiles * addone);

		if (abs(last_prior - priors[i]) > precision) {
			have_converged = 0;
		}
	    }
	}

	printf "%d sentences, %d non-oov words, best lambda %s\n", 
			num_sentences, num_words, print_vector(priors, nfiles);
}
