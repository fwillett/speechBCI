#!/usr/local/bin/gawk -f 
#
# Test for classname heuristic used in add-pauses-to-pfsg.gawk
#
# $Header: /home/srilm/CVS/srilm/utils/src/isclassname.gawk,v 1.1 2007/10/19 04:16:25 stolcke Exp $
# 

function is_classname(w) {
	return w ~ /^\*.*\*$/ || !(w ~ /[[:lower:]]/ || w ~ /[^\x00-\x7F]/);
}

{
	print $1 " is " (!is_classname($1) ? "not " : "") "a class name";
}
