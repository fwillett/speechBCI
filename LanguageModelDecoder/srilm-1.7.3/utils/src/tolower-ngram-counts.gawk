#!/usr/local/bin/gawk -f
#
# tolower-ngram-counts --
#	Map N-gram counts to lowercase
#
# $Header: /home/srilm/CVS/srilm/utils/src/tolower-ngram-counts.gawk,v 1.1 2007/07/13 23:38:22 stolcke Exp $
#
{
	for (i = 1; i < NF; i ++) {
		$i = tolower($i);
	}
	print;
}
