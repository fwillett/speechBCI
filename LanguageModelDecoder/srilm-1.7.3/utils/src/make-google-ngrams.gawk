#!/usr/local/bin/gawk -f
#
# make-google-ngrams --
#	split ngram count file into an indexed directory structure
# 	compatible with the Google ngrams distributed by LDC
#
# $Header: /home/srilm/CVS/srilm/utils/src/make-google-ngrams.gawk,v 1.6 2010/08/20 00:17:18 stolcke Exp $
#
# usage: zcat counts.gz | make-google-ngrams [dir=DIR] [per_file=N] [gzip=0] [yahoo=1]
#
# INPUT DATA is assumed to be a sorted ngram count file
#
# 
# OUTPUT DATA FORMAT
#
# a) top-level directory
#    doc: documentation
#    data: data
#    (the top-level structure is required by LDC)
# b) data directory
#    one sub-directory per n-gram order: 1gms, 2gms, 3gms, 4gms, 5gms
#    (separating the orders makes it easier for people to use smaller orders)
# c) contents of sub-directory 1gms
#    - file 'vocab.gz' contains the vocabulary sorted by word in unix
#      sort-order. Each word is on its own line:
#      WORD <tab> COUNT
#    - file 'vocab_cs.gz' contains the same data as 'vocab.gz' but
#      sorted by count.
#    (need to be 8+3 file names)
# d) contents of sub-directories 2gms, 3gms, 4gms, 5gms:
#    - files 'Ngm-KKKK.gz' where N is the order of the n-grams
#      and KKKK is the zero-padded number of the file. Each file contains
#      10 million n-gram entries. N-grams are unix-sorted. Each
#      n-gram occupies one line:
#      WORD1 <space> WORD2 <space> ... WORDN <tab> COUNT
#    - file 'Ngm.idx' where N is the order of the n-grams, with one line for
#      each n-gram file:
#      FILENAME <tab> FIRST_NGRAM_IN_FILE

BEGIN {
    dir = "data";

    per_file = 10000000;
    gzip = 1;
}

NR == 1 {
    if (gzip) {
	gzip_cmd = "gzip";
	gzip_suff = ".gz";
    } else {
	gzip_cmd = "cat";
	gzip_suff = "";
    }
}

# determine ngram length
{
    if (yahoo) {
	order = NF - 5;
	if (order > 0) {
	    $NF = $(NF-1) = $(NF-2) = $(NF-3) = "";
	}
    } else {
	order = NF - 1;
    }
}

#
# unigrams
#
order == 1 {
    if (!have_dir[1]) {
	system("mkdir -p " dir "/1gms");
	have_dir[1] = 1;

	output_file[1] = gzip_cmd " > " dir "/1gms/vocab" gzip_suff;
    }

    print | output_file[1];
    next;
}

order > 1 {
    if (output_ngram_count[order] == 0) {
	output_ngram_count[order] = 1;

	system("mkdir -p " dir "/" order "gms");
	if (output_file[order]) close(output_file[order]);
	    output_name = sprintf("%dgm-%04d%s", order, output_file_count[order] ++, gzip_suff);
	output_file[order] = gzip_cmd " > " dir "/" order "gms/" output_name;

	ngram = $1;
	for (i = 2; i <= order; i ++) {
	    ngram = ngram " " $i;
	}

	print output_name "\t" ngram > (dir "/" order "gms/" order "gm.idx");
    }

    print | output_file[order];

    output_ngram_count[order] += 1;
    output_ngram_count[order] %= (per_file + 1);
    next;
}

order < 1 {
    print FILENAME ": " FNR ": insufficient number of fields" > "/dev/stderr";
    print $0 > "/dev/stderr";
    exit(1);
}

#
# sort unigrams by count
#
END {
    close(output_file[1]);

    if (have_dir[1]) {
	system("gzip -dcf " dir "/1gms/vocab" gzip_suff " | sort -k 2,2rn | " gzip_cmd " > " dir "/1gms/vocab_cs" gzip_suff);
    }
}

