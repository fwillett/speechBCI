#include <stdlib.h>
/*
 * tserror.cc --
 *     Provide thread-safe strerror calls
 *
 * Copyright (c) 2012, SRI International.  All Rights Reserved.
 */

#define ERR_BUFF_SZ 256

#include <string.h>

#ifndef NO_TLS
#include "tserror.h"
#include "TLSWrapper.h"
static TLSW_ARRAY(char, errBuffTLS, ERR_BUFF_SZ);
char *srilm_ts_strerror(int errnum) {

#if defined(WIN32)
    char *buff = strerror(errnum);	// mingw doesn't have strerror_s()
#else
    char *buff = TLSW_GET_ARRAY(errBuffTLS);

#if defined(_MSC_VER)
    strerror_s(buff, ERR_BUFF_SZ, errnum);
#else
    strerror_r(errnum, buff, ERR_BUFF_SZ);
#endif /* _MSC_VER */
#endif /* WIN32 */

    return buff;
}

void srilm_tserror_freeThread() {
    TLSW_FREE(errBuffTLS);
}

#endif /* NO_TLS */
