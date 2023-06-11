#!/usr/local/bin/gawk -f
#
# vp2text --
#	Convert the ARPA CSR vp (verbalized punctiation) format to plain
#	text for LM training.
#
# 	This combines the functionality of Roni Rosenfeld's "vp2svp1" and
#	"sgml2text" utilities (except for case mapping).  No <s> and </s>
#	tags are retained, since our LM software doesn't need them.
#
# $Header: /home/srilm/CVS/srilm/utils/src/vp2text.gawk,v 1.2 1996/09/17 21:59:57 stolcke Exp $
#

BEGIN {
	iquote = 0;
	nquote = 5;
}
# Reset the quote counter at article boundaries
/^<art\./ {
	iquote = 0;
}
/^<DOC/ {
	iquote = 0;
}
#
# Filter out SGML tags
#
/^</ {
	next;
}
#
# Do all the easy replacements 
{
	# These are pronounced
	gsub("@AT-SIGN", "at");
	gsub("&AMPERSAND", "and");
	gsub("\\+PLUS", "plus");
	gsub("=EQUALS", "equals");
	gsub("%PERCENT", "percent");
	gsub("/SLASH", "slash");
	gsub("\\.POINT", "point");

	# These aren't
	gsub(",COMMA", "");
	gsub("\\?QUESTION-MARK", "");
	gsub(":COLON", "");
	gsub("\#SHARP-SIGN", "");
	gsub("'SINGLE-QUOTE", "");
	gsub(";SEMI-COLON", "");
	gsub("!EXCLAMATION-POINT", "");
	gsub("{LEFT-BRACE", "");
	gsub("}RIGHT-BRACE", "");
	gsub("\\(LEFT-PAREN", "");
	gsub("\\)RIGHT-PAREN", "");
	gsub("\\.PERIOD", "");
	gsub("\\.\\.\\.ELLIPSIS", "");
	gsub("--DASH", "");
	gsub("-HYPHEN", "");
}
# Handle lines containing "DOUBLE-QUOTE as a special case since this
# is more costly: replace every nquote'th occurrence with "quote", else
# delete it.
/"DOUBLE-QUOTE/ {
	output = "";
	for (i = 1; i <= NF; i++) {
		if ($i == "\"DOUBLE-QUOTE") {
			if ((iquote++) % nquote == 0) {
				output = output " quote";
			}
		} else {
			output = output " " $i;
		}
	}
	print output;
	next;
}
{
	print;
}
