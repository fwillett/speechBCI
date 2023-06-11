/*
 * matherr.c --
 *	Math error handling
 */

#ifndef lint
static char Copyright[] = "Copyright (c) 1996-2011 SRI International, 2012 Andreas Stolcke, Microsoft Corp.  All Rights Reserved.";
static char RcsId[] = "@(#)$Header: /home/srilm/CVS/srilm/lm/src/matherr.c,v 1.8 2019/09/09 23:13:13 stolcke Exp $";
#endif

#include <math.h>
#include <string.h>

#if defined(SING) && !defined(WIN32)
int
#if defined(_MSC_VER)
_matherr(struct _exception *x)
#else
matherr(struct exception *x)
#endif
{
    if (x->type == SING && strcmp(x->name, "log10") == 0) {
	/*
	 * suppress warnings about log10(0.0)
	 */
	return 1;
    } else {
	return 0;
    }
}
#endif /* SING && !WIN32 */

