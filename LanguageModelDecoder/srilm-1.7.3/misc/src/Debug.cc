/*
 * Debug.cc --
 *	Generic debugging support
 *
 */

#ifndef lint
static char Copyright[] = "Copyright (c) 1995, SRI International.  All Rights Reserved.";
static char RcsId[] = "@(#)$Header: /home/srilm/CVS/srilm/misc/src/Debug.cc,v 1.2 1996/05/30 17:57:48 stolcke Exp $";
#endif

#include "Debug.h"

unsigned Debug::debugAll = 0;	    /* global debugging level */

