#!/usr/local/bin/gawk -f
#
# make-diacritic-map --
#	Generate a map from ascii to accented word forms
#	for use with disambig(1)
#
# $Header: /home/srilm/CVS/srilm/utils/src/make-diacritic-map.gawk,v 1.3 1998/02/04 20:28:02 stolcke Exp $
#
/^#/ {
	next;
}
function asciify(word) {
	gsub("À", "A", word);
	gsub("Á", "A", word);
	gsub("Â", "A", word);
	gsub("Ã", "A", word);
	gsub("Ä", "A", word);
	gsub("Å", "A", word);
	gsub("Æ", "AE", word);
	gsub("Ç", "C", word);
	gsub("È", "E", word);
	gsub("É", "E", word);
	gsub("Ê", "E", word);
	gsub("Ë", "E", word);
	gsub("Ì", "I", word);
	gsub("Í", "I", word);
	gsub("Î", "I", word);
	gsub("Ï", "I", word);
	gsub("Ñ", "N", word);
	gsub("Ò", "O", word);
	gsub("Ó", "O", word);
	gsub("Ô", "O", word);
	gsub("Õ", "O", word);
	gsub("Ö", "O", word);
	gsub("Ø", "O", word);
	gsub("Ù", "U", word);
	gsub("Ú", "U", word);
	gsub("Û", "U", word);
	gsub("Ü", "U", word);
	gsub("Ý", "Y", word);
	gsub("ß", "ss", word);
	gsub("à", "a", word);
	gsub("á", "a", word);
	gsub("â", "a", word);
	gsub("ã", "a", word);
	gsub("ä", "a", word);
	gsub("å", "a", word);
	gsub("æ", "a", word);
	gsub("ç", "c", word);
	gsub("è", "e", word);
	gsub("é", "e", word);
	gsub("ê", "e", word);
	gsub("ë", "e", word);
	gsub("ì", "i", word);
	gsub("í", "i", word);
	gsub("î", "i", word);
	gsub("ï", "i", word);
	gsub("ñ", "n", word);
	gsub("ò", "o", word);
	gsub("ó", "o", word);
	gsub("ô", "o", word);
	gsub("õ", "o", word);
	gsub("ö", "o", word);
	gsub("ù", "u", word);
	gsub("ú", "u", word);
	gsub("û", "u", word);
	gsub("ü", "u", word);
	gsub("ý", "y", word);
	return word;
}
{
	word = $1;
	asciiword = asciify(word);

	if (asciiword in map) {
		map[asciiword] = map[asciiword] " " word;
	} else {
		map[asciiword] = word;
	}
}
END {
	print "<s>\t<s>"
	print "</s>\t</s>"
	fflush()

	for (w in map) {
		print w "\t" map[w] | "sort";
	}
}
