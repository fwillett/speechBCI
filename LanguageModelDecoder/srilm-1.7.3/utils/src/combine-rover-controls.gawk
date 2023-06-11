#!/usr/local/bin/gawk -f
#
# combine-rover-controls --
#	combined several rover control files for system combination
#	(may be used recursively)
#
# $Header: /home/srilm/CVS/srilm/utils/src/combine-rover-controls.gawk,v 1.7 2017/08/16 06:34:16 stolcke Exp $
#

function process_rover_control(file, weight, pscale) {

	dir = file;
	sub("/[^/]*$", "", dir);
	if (file == dir) {
		dir = "";
	}

	while ((status = (getline < file)) > 0) {

		if (NF == 0) continue;

		# skip comment line
		if (/^##/) continue;

		if (!keep_paths) {
		    # deal with relatve directories in rover-control file:
		    # prepend rover-control directory path
		    if ($1 !~ /^\// && dir != "") {
			$1 = dir "/" $1;
		    }
		}

		if ($3 == "+") {
		    system_id = system_id $1 " " $2 " +\n";
		} else {
		    nsystems += 1;

		    # handle missing lmw and wtw and system weights
		    if ($2 == "") $2 = 8;
		    if ($3 == "") $3 = 0;
		    if ($4 == "") $4 = 1;

		    # missing nbest depth limit
		    if ($5 == "") nbest_depth[nsystems] = 0;
		    else nbest_depth[nsystems] = $5;

		    # override posterior scale if specified
		    if (pscale) system_pscale[nsystems] = pscale;
		    else system_pscale[nsystems] = $6

		    system_id = system_id $1 " " $2 " " $3;

		    # see if this system has appeared before
		    if (system_id in system_index) {
			# merge system weights
			# ensuring weight tying spec is compatible
			if ($4 == "=") {
			    if (system_weight[system_index[system_id]] != "=") {
				print "cannot combine weight tying" > "/dev/stderr";
				exit(1);
			    }
			} else {
			    if (system_weight[system_index[system_id]] == "=") {
				print "cannot combine weight tying" > "/dev/stderr";
				exit(1);
			    }
			    system_weight[system_index[system_id]] += $4 * weight;
			}

			# skip the duplicate system
			nsystems -= 1;
		    } else {
			# divide system weight by total number of input files
			# but preserve weight tying info
			if ($4 == "=") {
			    system_weight[nsystems] = $4;
			} else {
			    system_weight[nsystems] = $4 * weight;
			}

			system_dirs_weights[nsystems] = system_id;

			system_index[system_id] = nsystems;
		    }

		    system_id = "";
		}
	}

	if (status < 0) {
		print file ": " ERRNO > "/dev/stderr";
		exit(1);
	}
	close(file);

	return;
}

BEGIN {
	arg_offset = 0;
	ninputs = ARGC - 1;
	nsystems = 0;

	while (1) {
	    if (ARGV[arg_offset+1] ~ /^lambda=/) {
		lambda = substr(ARGV[arg_offset+1], length("lambda")+2);
		ninputs -= 1;
		arg_offset += 1;
	    } else if (ARGV[arg_offset+1] ~ /^postscale=/) {
		postscale = substr(ARGV[arg_offset+1], length("postscale")+2);
		ninputs -= 1;
		arg_offset += 1;
	    } else if (ARGV[arg_offset+1] ~ /^norm=/) {
		norm_weights = substr(ARGV[arg_offset+1], length("norm")+2);
		ninputs -= 1;
		arg_offset += 1;
	    } else if (ARGV[arg_offset+1] ~ /^keeppaths=/) {
		keep_paths = substr(ARGV[arg_offset+1], length("keeppaths")+2);
		ninputs -= 1;
		arg_offset += 1;
	    } else {
		break;
	    }
	}

	if (ninputs < 1) {
	    print "usage: " ARGV[0] " [lambda=WEIGHTS] [postscale=S] ROVER-CTRL1 ROVER-CTRL2 ..." \
			    >> "/dev/stderr";
	    exit(2);
	}

        # initialize priors from lambdas
        nlambdas = split(lambda, lambdas);
        lambda_sum = 0.0;
        for (i = 1; i <= nlambdas; i ++) {
                lambda_sum += lambdas[i];
        }
        # fill in the missing lambdas with uniform values
        for (i = nlambdas + 1; i <= ninputs; i ++) {
                lambdas[i] = (1 - lambda_sum)/(ninputs - nlambdas);
        }

	for (i = 1; i <= ninputs; i ++) {
	    process_rover_control(ARGV[arg_offset + i], lambdas[i], postscale);
	}

	if (norm_weights) {
	    weight_sum = 0;
	    for (i = 1; i <= nsystems; i ++) {
		weight_sum += system_weight[i];
	    }
	    for (i = 1; i <= nsystems; i ++) {
		system_weight[i] /= weight_sum;
	    }
	}

	for (i = 1; i <= nsystems; i ++) {
	    print system_dirs_weights[i], system_weight[i], nbest_depth[i], system_pscale[i];
	}

	exit(0);
}

