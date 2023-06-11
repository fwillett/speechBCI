#include <stdlib.h>
/*
 * tls.cc --
 *     Abstracts pthread and Windows thread-local storage mechanisms
 *
 * Copyright (c) 2012, SRI International.  All Rights Reserved.
 */

#include "tls.h"

#if !defined(NO_TLS) && !defined(_MSC_VER) && !defined(WIN32)
// Needed for non-windows TLS
TLS_KEY srilm_tls_get_key() {
    TLS_KEY key;
    pthread_key_create(&key, 0);
    return key;
}
#endif
