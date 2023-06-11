#!/usr/local/bin/gawk -f
#
# rover-control-tying --
#	extract tying information from rover-control file for use with
#	compute-best-rover-mix tying=...
#

BEGIN {
	bin = 0;
}

/^##/ || /^[ 	]*$/ {
	# skip comment or empty line
	next;
}

$3 == "+" {
	next;
}

{
	if ($4 == "") $4 = 1;

	if ($4 == "=") {
		output = output " " bin;
	} else {
		output = output " " ++bin;
	}
}

END {
	sub("^ ", "", output);
	print output;
}

