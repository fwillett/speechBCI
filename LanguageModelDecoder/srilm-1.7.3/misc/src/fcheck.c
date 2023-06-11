/*
 * fcheck.c --
 *	stdio file handling with error checking
 *
 * $Header: /home/srilm/CVS/srilm/misc/src/fcheck.c,v 1.2 2003/02/21 22:01:23 stolcke Exp $
 */

#include <stdlib.h>

#define ZIO_HACK
#include "zio.h"
#include "fcheck.h"

FILE *fopen_check(const char *name, const char *mode)
{
    FILE *file = fopen(name, mode);

    if (file == 0) {
	perror(name);
	exit(1);
    } else {
	return file;
    }
}

void fclose_check(const char *name, FILE *file)
{
    if (fclose(file) != 0) {
	perror(name);
	exit(1);
    }
}

