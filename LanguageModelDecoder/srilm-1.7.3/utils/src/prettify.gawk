#!/usr/local/bin/gawk -f
#
# Map words in a text file to zero of more expansions
#
# $Header: /home/srilm/CVS/srilm/utils/src/prettify.gawk,v 1.1 2001/03/24 06:41:31 stolcke Exp $
#
NR == 1 {
	# read pretty map file
	if (map) {
	    while ((getline mapline < map) > 0) {
		npretty = split(mapline, pretty_list);
		word = pretty_list[1];
		pretty_map[word] = "";
		for (i = 2; i <= npretty; i ++) {
		    pretty_map[word] = pretty_map[word] " " pretty_list[i];
		}
	    }
	}
}

function pretty_up() {
	for (i = 1; i <= NF; i ++) {
	    if ($i in pretty_map) {
		$i = pretty_map[$i];
	    }
	    if (multiwords) gsub("_", " ", $i);
	}
}

{
	pretty_up();
	print;
}

