/*
 * option.c --
 *
 *	Routines to do command line option processing.
 *
 * Copyright 1986, 1991 Regents of the University of California
 * Permission to use, copy, modify, and distribute this
 * software and its documentation for any purpose and without
 * fee is hereby granted, provided that the above copyright
 * notice appear in all copies.  The University of California
 * makes no representations about the suitability of this
 * software for any purpose.  It is provided "as is" without
 * express or implied warranty.
 */

#ifndef lint
static char rcsid[] = "$Header: /home/srilm/CVS/srilm/misc/src/option.c,v 1.17 2013/04/09 06:07:02 stolcke Exp $ SPRITE (Berkeley)";
#endif

#include <option.h>
#include <cfuncproto.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#define OptNoArg(progName, opt) fprintf(stderr, \
		      "Warning: %s option \"-%s\" needs an argument\n", \
		      (progName), (opt))

/* Forward references: */

static void ParseTime _ARGS_ ((_CONST char *progName, char *str,
				 time_t *resultPtr));


/*
 *----------------------------------------------------------------------
 *
 * Opt_Parse --
 *
 *	Process a command line according to a template of accepted
 *	options.  See the manual page and header file for more details.
 *
 * Results:
 *	The number of options that weren't processed by this procedure
 *	is returned, and argv points to an array of unprocessed
 *	options.  (This is all of the options that didn't start with
 *	"-", except for those used as arguments to the options
 *	processed here; it's also anything after an OPT_REST option.)
 *
 * Side effects:
 *	The variables referenced from the option array get modified
 *	if their option was present on the command line.  Can clobber 
 *	the global buffer used by localtime(3).
 *
 *----------------------------------------------------------------------
 */

int
Opt_Parse(
    int  	  argc, 	    /* Number of arguments in argv. */
    char    	  **argv,   	    /* Array of arguments */
    Option  	  optionArray[],    /* Array of option descriptions */
    int	    	  numOptions,	    /* Size of optionArray */
    int		  flags)	    /* Or'ed combination of various flag bits:
				     * see option.h for definitions. */
{
    register Option 	*optionPtr; /* pointer to the current option in the
				     * array of option specifications */
    register char 	*curOpt;    /* Current flag argument */
    register char 	**curArg;   /* Current argument */
    register int  	argIndex;   /* Index into argv to which next unused
				     * argument should be copied */
    int 	  	stop=0;	    /* Set non-zero to stop processing
				     * arguments when an OPT_REST flag is
				     * encountered */
    int			error=0;    /* A bad option was found */
    int			length;	    /* Number of characters in current
				     * option. */

    argIndex = 1;
    argc -= 1;
    curArg = &argv[1];

    while (argc && !stop) {
	if (**curArg == '-') {
	    curOpt = &curArg[0][1];
	    curArg += 1;
	    argc -= 1;

	    /*
	     * Check for the special options "?" and "help".  If found,
	     * print documentation and exit.
	     */

	    if ((strcmp(curOpt, "?") == 0) || (strcmp(curOpt, "help") == 0)) {
		Opt_PrintUsage (argv[0], optionArray, numOptions);
		exit(0);
	    }

	    /*
	     * Loop over all the options specified in a single argument
	     * (must be 1 unless OPT_ALLOW_CLUSTERING was specified).
	     */

	    while (1) {
		/*
		 * Loop over the array of options searching for one with the
		 * matching key string.  If found, it is left pointed to by
		 * optionPtr.
		 */
		for (optionPtr = &optionArray[numOptions - 1];
			optionPtr >= optionArray;
			optionPtr -= 1) {
		     if (optionPtr->key == NULL) {
			 continue;
		     }
		     if (*optionPtr->key == *curOpt) {
			 if (flags & OPT_ALLOW_CLUSTERING) {
			     length = strlen(optionPtr->key);
			     if (strncmp(optionPtr->key, curOpt, length) == 0) {
				 break;
			     }
			 } else {
			     if (strcmp(optionPtr->key, curOpt) == 0) {
				 break;
			     }
			 }
		     }
		}

		if (optionPtr < optionArray) {
		    /*
		     * No match.  Print error message and skip option.
		     */

		    if (flags & OPT_UNKNOWN_IS_ERROR) {
			error = 1;
			stop = 1;
		    } else {
			fprintf(stderr, "Unknown option \"-%s\";", curOpt);
			fprintf(stderr, "  type \"%s -help\" for information\n",
				argv[0]);
		    }
		    break;
		}

		/*
		 * Take the appropriate action based on the option type
		 */

		if (optionPtr->type >= 0) {
		    *((int *) optionPtr->address) = optionPtr->type;
		} else {
		    switch (optionPtr->type) {
			case OPT_REST:
			    stop = 1;
			    *((int *) optionPtr->address) = argIndex;
			    break;
			case OPT_STRING:
			    if (argc == 0) {
				OptNoArg(argv[0], optionPtr->key);
			    } else {
				*((char **)optionPtr->address) = *curArg;
				curArg++;
				argc--;
			    }
			    break;
			case OPT_INT:
			case OPT_UINT:
			    if (argc == 0) {
				OptNoArg(argv[0], optionPtr->key);
			    } else {
				char *endPtr;

				int value = strtol(*curArg, &endPtr, 0);

				if (endPtr == *curArg) {
				    fprintf(stderr,
 "Warning: option \"-%s\" got a non-numeric argument \"%s\".  Using default: %d\n",
 optionPtr->key, *curArg, *((int *) optionPtr->address));
				} else if (optionPtr->type == OPT_UINT &&
								   value < 0)
				{
				    fprintf(stderr,
 "Warning: option \"-%s\" got a negative argument \"%s\".  Using default: %u.\n",
 optionPtr->key, *curArg, *((unsigned *) optionPtr->address));
				} else {
				    *((int *) optionPtr->address) = value;
				}
				curArg++;
				argc--;
			    }
			    break;
			case OPT_TIME:
			    if (argc == 0) {
				OptNoArg(argv[0], optionPtr->key);
			    } else {
				ParseTime(argv[0], *curArg, 
					  (time_t *)optionPtr->address);
				curArg++;
				argc--;
			    }
			    break;
			case OPT_FLOAT:
			    if (argc == 0) {
				OptNoArg(argv[0], optionPtr->key);
			    } else {
				char *endPtr;

				double value = strtod(*curArg, &endPtr);

				if (endPtr == *curArg) {
				    fprintf(stderr,
 "Warning: option \"-%s\" got non-floating-point argument \"%s\".  Using default: %lg.\n",
 optionPtr->key, *curArg, *((double *) optionPtr->address));
				} else {
				    *((double *) optionPtr->address) = value;
				}
				curArg++;
				argc--;
			    }
			    break;
			case OPT_GENFUNC: {
			    int	    (*handlerProc)();

			    handlerProc = (int (*)())optionPtr->address;

			    argc = (* handlerProc) (optionPtr->key, argc,
				    curArg);
			    break;
			}
			case OPT_FUNC: {
			    int (*handlerProc)();

			    handlerProc = (int (*)())optionPtr->address;
			    
			    if ((* handlerProc) (optionPtr->key, *curArg)) {
				curArg += 1;
				argc -= 1;
			    }
			    break;
			}
			case OPT_DOC:
			    Opt_PrintUsage (argv[0], optionArray, numOptions);
			    exit(0);
			    /*NOTREACHED*/
		    }
		}
		/*
		 * Advance to next option
		 */

		if (flags & OPT_ALLOW_CLUSTERING) {
		    curOpt += length;
		    if (*curOpt == 0) {
			break;
		    }
		} else {
		    break;
		}
	    }
	} else {
	    /*
	     * *curArg is an argument for which we have no use, so copy it
	     * down.
	     */
	    argv[argIndex] = *curArg;
	    argIndex += 1;
	    curArg += 1;
	    argc -= 1;

	    /*
	     * If this wasn't an option, and we're supposed to stop parsing
	     * the first time we see something other than "-", quit.
	     */
	    if (flags & OPT_OPTIONS_FIRST) {
		stop = 1;
	    }
	}
    }

    /*
     * If we broke out of the loop because of an OPT_REST argument, we want
     * to copy the rest of the arguments down, so we do.
     */
    while (argc) {
	argv[argIndex] = *curArg;
	argIndex += 1;
	curArg += 1;
	argc -= 1;
    }
    argv[argIndex] = (char *)NULL;
    if ((flags & OPT_UNKNOWN_IS_ERROR) && error) {
	return -1;
    } else {
	return argIndex;
    }
}


/*
 *----------------------------------------------------------------------
 *
 * Opt_PrintUsage --
 *
 *	Print out a usage message for a command.  This prints out the
 *	documentation strings associated with each option.
 *
 * Results:
 *	none.
 *
 * Side effects:
 *	Messages printed onto the console.
 *
 *----------------------------------------------------------------------
 */

void
Opt_PrintUsage(
    _CONST char *commandName,
    Option optionArray[],
    int numOptions)
{
    register int i;
    int width;

    /*
     * First, compute the width of the widest option key, so that we
     * can make everything line up.
     */

    width = 4;
    for (i=0; i<numOptions; i++) {
	int length;
	if (optionArray[i].key == NULL) {
	    continue;
	}
	length = strlen(optionArray[i].key);
	if (length > width) {
	    width = length;
	}
    }

    if (commandName != NULL) {
	fprintf(stderr, "Usage of command \"%s\"\n", commandName);
    }

    for (i=0; i<numOptions; i++) {
	if (optionArray[i].type != OPT_DOC) {
	    fprintf(stderr, " -%s%-*s %s\n", optionArray[i].key,
		    width+1-(int)strlen(optionArray[i].key), ":",
		    optionArray[i].docMsg);
	    switch (optionArray[i].type) {
		case OPT_INT: {
		    fprintf(stderr, "\t\tDefault value: %d\n",
			    *((int *) optionArray[i].address));
		    break;
		}
		case OPT_UINT: {
		    fprintf(stderr, "\t\tDefault value: %u\n",
			    *((unsigned *) optionArray[i].address));
		    break;
		}
		case OPT_FLOAT: {
		    fprintf(stderr, "\t\tDefault value: %lg\n",
			    *((double *) optionArray[i].address));
		    break;
		}
		case OPT_STRING: {
		    if (*(char **)optionArray[i].address != (char *) NULL) {
			    fprintf(stderr, "\t\tDefault value: \"%s\"\n",
				    *(char **) optionArray[i].address);
			    break;
		    }
		}
		default: {
		    break;
		}
	    }
	} else {
	    fprintf(stderr, " %s\n", optionArray[i].docMsg);
	}
    }
    if (commandName != NULL) {
	fprintf(stderr, " -help%-*s Print this message\n", width-3, ":");
    }
}


/*
 *----------------------------------------------------------------------
 *
 * ParseTime --
 *
 *	Convert a date and time from some string representation to 
 *	something we can compute with.
 *
 * Results:
 *	If str points to a parsable time, the corresponding UNIX time 
 *	value (seconds past the epoch) is returned through resultPtr.
 *
 * Side effects:
 *	Can clobber the global buffer used by localtime(3).
 *
 *----------------------------------------------------------------------
 */

static void
ParseTime(
    _CONST char	*progName,	/* name that the program was called as */
    char	*str,		/* the string to parse */
    time_t	*resultPtr)	/* pointer to result time value */
{
    long result;		/* the answer */
    char *endPtr;		/* pointer into str, for parsing */
    struct tm pieces;		/* year, month, etc. as integers */

    /* 
     * We currently accept the following formats:
     * 
     * (1) an integer number of seconds past the epoch.
     * (2) a string of the form "yy.mm.dd.hh.mm.ss"
     */
    
    result = strtol(str, &endPtr, 0);
    if (endPtr == str) {
	goto parseError;
    }
    if (*endPtr == '\0') {
	*resultPtr = result;
	return;
    }

    /* 
     * Not a simple integer, so try form 2. 
     */
    if (*endPtr != '.') {
	goto parseError;
    }
    pieces.tm_year = result;
    if (pieces.tm_year > 1900) {
	pieces.tm_year -= 1900;
    }
    pieces.tm_mon = strtol(endPtr+1, &endPtr, 0) - 1;
    if (endPtr == str || *endPtr != '.') {
	goto parseError;
    }
    pieces.tm_mday = strtol(endPtr+1, &endPtr, 0);
    if (endPtr == str || *endPtr != '.') {
	goto parseError;
    }
    pieces.tm_hour = strtol(endPtr+1, &endPtr, 0);
    if (endPtr == str || *endPtr != '.') {
	goto parseError;
    }
    pieces.tm_min = strtol(endPtr+1, &endPtr, 0);
    if (endPtr == str || *endPtr != '.') {
	goto parseError;
    }
    pieces.tm_sec = strtol(endPtr+1, &endPtr, 0);
    if (endPtr == str || *endPtr != '\0') {
	goto parseError;
    }

    result = mktime(&pieces);
    if (result == -1) {
	fprintf(stderr, "%s: can't represent the time \"%s\".\n",
		progName, str);
    } else {
	*resultPtr = result;
    }
    return;

 parseError:
    fprintf(stderr, "%s: can't parse \"%s\" as a time.\n", progName, str);
    return;
}
