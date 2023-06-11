#!/usr/local/bin/gawk -f
#
# sentid-to-sclite --
#	convert sentid transcription format to sclite 'trn' format
#
# $Header: /home/srilm/CVS/srilm/utils/src/sentid-to-sclite.gawk,v 1.5 2016/09/23 20:05:51 stolcke Exp $
#
# i.e.:
#	sentid word1 word2 ....
#
# becomes
#
#	word1 word2 ... (sentid)
#
# The sentid is formatted to contain exactly one underscore,
# as sclite uses the first portion of the id as a speaker label to
# group results.
#
BEGIN {
    format_sentids = 1;
}

{
    sentid = $1;
    $1 = "";

    if (format_sentids) {
	# reformat sentid

	# <conv>_<channel>_<utterance> -> <conv><channel>_<utterance>
	sub("[-_]A", "A", sentid);
	sub("[-_]B", "B", sentid);
	sub("[-_]ch1", "ch1", sentid);
	sub("[-_]ch2", "ch2", sentid);

	# remove underscore after corpus tag, if any
	if (sentid ~ /^[a-z][a-z]*[-_][0-9]/) {
	    sub("[-_]", "", sentid);
	}

	# <conv>_<channel>_<utterance> -> <conv><channel>_<utterance>
	sub("[-_]A", "A", sentid);
	sub("[-_]B", "B", sentid);
	sub("[-_]ch1", "ch1", sentid);
	sub("[-_]ch2", "ch2", sentid);

	# work around problems with negative start times in sentids
	sub("_-", "_m", sentid);

	#
	# for sentid not containing _ or -, fake a speaker id out of the first
	# three characters (this works for ATIS ...)
	#
	if (! (sentid ~ /[-_]/)) {
	    sentid = substr(sentid, 1, 3) "_" sentid;
	}
    }

    print $0, "(" sentid ")";
}
