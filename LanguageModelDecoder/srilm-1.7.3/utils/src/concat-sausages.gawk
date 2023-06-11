#!/usr/local/bin/gawk -f
#
# concat-sausages --
#	concatenate a list of sausages into a single word confusion networks
#
# $Header: /home/srilm/CVS/srilm/utils/src/concat-sausages.gawk,v 1.1 2019/02/09 07:34:35 stolcke Exp $
#
# input format:
#
#	name Speech012_apple-iphone-6s-agc_00001330_00010030
#	numaligns 32
#	posterior 1
#	align 0 <s> 1
#	info 0 <s> 1.33 0.06 0 0 : :
#	align 1 OK 1
#	info 1 OK 1.39 0.5 0 0 : :
#	align 2 *DELETE* 1 I 3.110077054250103e-33 we 3.193624897980025e-52 i 7.615703946522299e-53
#	info 2 I 1.83 0.06 0 0 : :
#	info 2 we 1.85 0.06 0 0 : :
#	info 2 i 1.83 0.06 0 0 : :
#

BEGIN {
	name = "";
	numaligns = 0;
	posterior = 0;
	if (posterior_factor == "") {
	    posterior_factor = 1;
	}

	sent_start = "<s>";
	sent_end = "</s>";

	epsilon = 1e-05;
}

function abs(x) {
	return x < 0 ? -x : x;
}

function process_sausage(file, remove_start, remove_end) {

	if (file ~ /.*\.gz$|.*\.Z/) {
	    input = "exec gunzip -c " file;
	} else {
	    input = "exec cat " file;
	}

	while ((status = (input | getline)) > 0) {

	    if ($1 == "name") {
		if (output_name != "") {
			name = output_name;
		} else if (name == "") {
			name = $2;
		} else {
			name = name "+" $2
		}

	    } else if ($1 == "posterior") {
		if (posterior != 0 && abs($2 - posterior) > epsilon) {
		    print file ": incompatible posterior: " $2 > "/dev/stderr"
		    exit(1);
		} else {
		    posterior = $2;
#		    if (posterior_factor != 1) {
#			posterior *= posterior_factor;
#		    }
		}
	    } else if ($1 == "numaligns") {
		# offset for renumbered alignments
		start_alignment = numaligns;
	    } else if ($1 == "align") {

		$2 = $2 + start_alignment;

		if (posterior_factor != 1 && $3 != sent_start && $3 != sent_end) {
		    for (i = 4; i <= NF; i += 2) {
			$i *= posterior_factor;
		    }
		}

		#
		# remove alignment positions that are just for 
		# start/end sentence tags, if so desired
		# 
		if (NF == 4 && $3 == sent_start && remove_start) {
		    start_alignment --;
		    ;
		} else if (NF == 4 && $3 == sent_end && remove_end) {
		    start_alignment --;
		    ;
		} else {
		    alignments[$2] = $0;

		    if ($2 + 1 > numaligns) {
			numaligns = $2 + 1;
		    }
		}
	    } else if ($1 == "info") {

		$2 = $2 + start_alignment;

		if (!($2 in info)) {
		    info[$2] = $0;
		} else {
		    info[$2] = info[$2] "\n" $0;
		}
	    } else if ($1 == "time") {
		; 	# ignore
	    } else {
		print file ": unknown keyword: " $1 > "/dev/stderr";
		exit(1);
	    }
	}

	if (status < 0) {
		print "error opening " file >> "/dev/stderr";
	}

	close(input);
}

function output_sausage() {
	print "name", name;
	print "numaligns", numaligns;
	print "posterior", posterior;
	
	for (i = 0; i < numaligns; i ++) {
		if (i in alignments) {
			print alignments[i];
			if (i in info) {
			    print info[i];
			}
		}
	}
}

BEGIN {
	if (ARGC < 2) {
	    print "usage: " ARGV[0] " SAUSAGE1 SAUSAGE2 ..." \
			    >> "/dev/stderr";
	    exit(2);
	}

	for (arg = 1; arg < ARGC; arg ++) {
	    process_sausage(ARGV[arg], arg > 1, arg < ARGC-1);
	}
	
	output_sausage();
}

