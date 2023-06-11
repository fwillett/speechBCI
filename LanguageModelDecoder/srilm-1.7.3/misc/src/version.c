/*
 * version.c --
 *	Print version information
 * 
 */

#ifndef lint
static char Copyright[] = "Copyright (c) 2004 SRI International, 2015 Andreas Stolcke, Microsoft Corp.  All Rights Reserved.";
static char RcsId[] = "@(#)$Header: /home/srilm/CVS/srilm/misc/src/version.c,v 1.10 2019/09/09 23:13:15 stolcke Exp $";
#endif

#include <stdio.h>

#include "zio.h"
#include "version.h"
#include "SRILMversion.h"
#include <SRILMoptions.h>

#if defined(_OPENMP) && defined(_MSC_VER)
#include <omp.h>
#endif

void
printVersion(const char *rcsid)
{
	printf("SRILM release %s", SRILM_RELEASE);
#ifndef EXCLUDE_CONTRIB
	printf(" (with third-party contributions)");
#endif /* EXCLUDE_CONTRIB_END */
	printf("\n");
#if defined(__GNUC__) && !defined(__clang__)
	printf("Built with GCC %d.%d.%d\n", __GNUC__, __GNUC_MINOR__, __GNUC_PATCHLEVEL__);
#endif
#ifdef __clang__
	printf("Built with Clang %d.%d.%d\n", __clang_major__, __clang_minor__, __clang_patchlevel__);
#endif
#ifdef __INTEL_COMPILER
	printf("Built with IntelC %d\n", __INTEL_COMPILER);
#endif
#ifdef _MSC_VER
	printf("Built with MSVC %d\n", _MSC_VER);
#endif
#ifdef BUILD_OPTIONS
	printf("and options %s\n", BUILD_OPTIONS);
#endif

	printf("\nProgram version %s\n", rcsid);
#ifndef NO_ZIO
	printf("\nSupport for compressed files is included.\n");
#else
	printf("\nSupport for gzipped files is included.\n");
#endif
#ifdef HAVE_LIBLBFGS
	printf("Using libLBFGS.\n");
#endif
#ifdef _OPENMP
	printf("Using OpenMP version %d.\n", _OPENMP);
#endif
 	puts(SRILM_COPYRIGHT);
}

