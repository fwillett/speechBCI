/*
    File:   srilm_iconv.h
    Author: Andreas Stolcke
    Date:   Sun Jan 22 12:48:55 2012
   
    Description: Portability for the iconv function

    Copyright (c) 2012 Andreas Stolcke, Microsoft Corp.  All Rights Reserved.

    RCS ID: $Id: srilm_iconv.h,v 1.6 2019/09/09 23:13:15 stolcke Exp $
*/


#if !defined(NO_ICONV) && defined(__GNUC__) && !defined(WIN32)
# include_next <iconv.h>
#else 
# if !defined(NO_ICONV) && defined(sun)
#  include "/usr/include/iconv.h"
# else

#ifndef _SRILM_ICONV_H
#define _SRILM_ICONV_H

#include <errno.h>

#undef iconv_open
#undef iconv_close
#undef iconv

# ifdef NO_ICONV

/*
 * Avoid libiconv references, disallow UTF-16 conversion.
 */
typedef void *iconv_t;	// unused

#define iconv_open(to, from)	(errno = EINVAL, (iconv_t)-1)
#define iconv_close(x)		/* nothing to do */
#define iconv(cp, in, nin, out, nout)	((size_t)-1)	// unused

# else /* ! NO_ICONV */

#  if defined(_MSC_VER) || defined(WIN32)
/*
 * Emulate simple iconv() usage using Windows API.
 * (Not pretty, but keeps the code below from being littered with #ifdefs)
 */
#include "Windows.h"

typedef void *iconv_t;	// unused

#define iconv_open(to, from)	((strcmp(to,"UTF-8")==0 && strcmp(from,"UTF-16LE")==0) ? \
					(iconv_t)1 : \
					(errno = EINVAL, (iconv_t)-1))
#define iconv_close(x)		/* nothing to do */
#define iconv(cp, in, nin, out, nout) \
		 		((*(nout) = WideCharToMultiByte(CP_UTF8, 0, \
								(LPCWSTR)*(in), -1, \
								(*out), *(nout), \
								NULL, NULL)) == 0 ? -1 : *(nout))
#  endif /* _MSC_VER */

# endif /* NO_ICONV */

#endif /* _SRILM_ICONV_H */

# endif
#endif

