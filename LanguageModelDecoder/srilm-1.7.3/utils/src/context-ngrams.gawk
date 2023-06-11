#!/usr/local/bin/gawk -f
#
# context-ngrams -- 
#	Extract counts corresponding to ngram contexts
#
# $Header: /home/srilm/CVS/srilm/utils/src/context-ngrams.gawk,v 1.1 2008/09/30 03:54:05 stolcke Exp $
#

NF > 2 {
	$(NF-1) = "";
	print $0;
}

