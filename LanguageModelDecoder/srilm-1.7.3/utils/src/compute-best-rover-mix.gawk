#!/usr/local/bin/gawk -f
#
# compute-best-rover-mix --
#	Compute the best mixture weight for combining multiple sausages
#
# usage: compute-best-rover-mix [lambda="l1 l2 ..."] [addone=N] [precision=p] nbest-rover-ref-posteriors-output
#
# where the input is the output of nbest-rover -write-ref-posteriors .
# li are initial guesses at the mixture weights, and p is the
# precision with which the best lambda vector is to be found.
#
# $Header: /home/srilm/CVS/srilm/utils/src/compute-best-rover-mix.gawk,v 1.6 2016-12-10 07:06:41 stolcke Exp $
#
BEGIN {
	verbose = 0;

	lambda = "0.5";
	addone = 0;
	precision = 0.001;
	M_LN10 = 2.30258509299404568402;	# from <math.h>

	logINF = -320;

	zero_probs = 0;
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
	result = x[1];
	for (k = 2; k <= n; k++) {
		result = result " " x[k];
	}
	return result;
}

{
	nsystems = NF - 4;

	if ($4 == 0) {
		zero_probs ++;
	} else {
		sample_no ++;

		for (i = 1; i <= nsystems; i++) {
			samples[i " " sample_no] = $(i + 4);
		}
	}
}
	
END {
	last_prior = 0.0;

	# initialize priors from lambdas
	nlambdas = split(lambda, lambdas);
	lambda_sum = 0.0;
	for (i = 1; i <= nlambdas; i ++) {
		priors[i] = lambdas[i];
		lambda_sum += lambdas[i];
	}
	# fill in the missing lambdas
	for (i = nlambdas + 1; i <= nsystems; i ++) {
		priors[i] = (1 - lambda_sum)/(nsystems - nlambdas);
	}

	# set up weight tying - assign input systems (weights) to tying bins
	if (tying) {
		ntying = split(tying, tying_bins);
		for (i = 1; i <= ntying && i <= nsystems; i ++) {
		    this_bin = int(tying_bins[i]);
		    if (this_bin <= 0) {
			print "invalid tying bin: " tying_bins[i];
			exit(1);
		    }
		    binfor[i] = this_bin;
		    weights_in_bin[this_bin] += 1;

		    if (this_bin > nbins) nbins = this_bin;
		}
	} else {
		i = 1;
		nbins = 0;
	}
	# assign unique bins for weights not covered in tying argument string
	for ( ; i <= nsystems; i ++) {
	    binfor[i] = ++nbins;
	    weights_in_bin[nbins] = 1;
	}
		

	iter = 0;
	have_converged = 0;
	while (!have_converged) {
	    iter ++;

	    num_words = 0;
	    delete post_totals;
	    log_like = 0;

	    for (j = 1; j <= sample_no; j ++) {

		all_inf = 1;
		for (i = 1; i <= nsystems; i ++) {
			sample = log10(samples[i " " j]);
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

		num_words ++;
		log_like += logsum;

		# total up the posteriors for each weight bin
		for (i = 1; i <= nsystems; i ++) {
			post_totals[binfor[i]] += exp10(logpost[i] - logsum);
		}
	    }
	    printf "iteration %d, lambda = %s, ppl = %g\n", \
		    iter, print_vector(priors, nsystems), \
		    exp10(-log_like/num_words) >> "/dev/stderr";
	    fflush();

	
	    have_converged = 1;
	    for (i = 1; i <= nsystems; i ++) {
		last_prior = priors[i];
		priors[i] = (post_totals[binfor[i]]/weights_in_bin[binfor[i]] + addone)/(num_words + nsystems * addone);

		if (abs(last_prior - priors[i]) > precision) {
			have_converged = 0;
		}
	    }
	}

	weights = print_vector(priors, nsystems);
	printf "%d alignment positions, best lambda (%s)\n", num_words, weights;
	if (write_weights) {
		print weights > write_weights;
	}
}
