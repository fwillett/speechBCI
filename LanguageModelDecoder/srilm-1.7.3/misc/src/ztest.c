/*
 * ztest --
 *	test for zio.
 */

#ifndef lint
static char Copyright[] = "Copyright (c) 1997,2006 SRI International, 2013 Andreas Stolcke, Microsoft Corp.  All Rights Reserved.";
static char RcsId[] = "@(#)$Header: /home/srilm/CVS/srilm/misc/src/ztest.c,v 1.5 2019/09/09 23:13:15 stolcke Exp $";
#endif

#include <stdio.h>
#include <stdlib.h>

#include "zio.h"
#include "zlib.h"
#include "option.h"
#include "version.h"

char *inFile = "-";
char *outFile = "-";
int numLines = 0;
int version = 0;
int useZlib = 0;

static Option options[] = {
    { OPT_TRUE, "version", (void *)&version, "print version information" },
    { OPT_TRUE, "zlib", (void *)&useZlib, "use zlib" },
    { OPT_STRING, "read", (void *)&inFile, "input file" },
    { OPT_STRING, "write", (void *)&outFile, "output file" },
    { OPT_INT, "lines", (void *)&numLines, "number of lines to copy" },
};

int
main(int argc, char **argv)
{
    char buffer[1024];
    FILE *in, *out;
    gzFile gzin, gzout;
    int result;
    int lineno;

    Opt_Parse(argc, argv, options, Opt_Number(options), 0);

    if (version) {
	printVersion(RcsId);
	exit(0);
    }

    if (useZlib) {
	gzin = gzopen(inFile, "r");
	if (gzin == NULL) {
	    perror(inFile);
	    exit(1);
	}

	gzout = gzopen(outFile, "w");
	if (gzout == NULL) {
	    perror(outFile);
	    exit(1);
	}
    } else {
	in = zopen(inFile, "r");
	if (in == NULL) {
	    perror(inFile);
	    exit(1);
	}

	out = zopen(outFile, "w");
	if (out == NULL) {
	    perror(outFile);
	    exit(1);
	}
    }

    lineno = 0;
    while ((numLines == 0 || lineno < numLines) &&
	   (useZlib ?
		gzgets(gzin, buffer, sizeof(buffer)) :
		fgets(buffer, sizeof(buffer), in)))
    {
	if (useZlib) {
	    gzputs(gzout, buffer);
	} else {
	    fputs(buffer, out);
	}
	lineno ++;
    }

    if (lineno > 0) {
	if (useZlib) {
	    gzprintf(gzout, "THE END AFTER %d LINES\n", lineno);
	} else {
	    fprintf(out, "THE END AFTER %d LINES\n", lineno);
	}
    }

    result = useZlib ? gzclose(gzin) : zclose(in);
    fprintf(stderr, "zclose(in) = %d\n", result);

    result = useZlib ? gzclose(gzout) : zclose(out);
    fprintf(stderr, "zclose(out) = %d\n", result);

    exit(0);
}

