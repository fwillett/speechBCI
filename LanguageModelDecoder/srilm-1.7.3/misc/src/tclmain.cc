/*
 * tclmain.c --
 *	main() function for tcl clients
 *
 * $Header: /home/srilm/CVS/srilm/misc/src/tclmain.cc,v 1.6 2003/07/01 02:54:12 stolcke Exp $
 */

#include <tcl.h>

/*
 * Tcl versions up to 7.3 defined main() in the libtcl.a
 */
#if (TCL_MAJOR_VERSION == 7 && TCL_MINOR_VERSION > 3) || (TCL_MAJOR_VERSION > 7)

int
main(int argc, char **argv)
{
   Tcl_Main(argc, argv, Tcl_AppInit);
}

#endif

