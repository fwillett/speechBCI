/*
 * MStringTokUtil.cc --
 *      Platform-independent version of strtok_r.
 *
 * @author SRI International
 * @file MStringTokUtil.h \brief Utility for portable string tokenization.
 *
 * Copyright (C) 2011 SRI International.  Unpublished, All Rights Reserved.
 *
 * $Id: MStringTokUtil.cc,v 1.1 2011/04/01 17:47:18 victor Exp $
 */

#include <string.h>
#include <stdlib.h>

#include "MStringTokUtil.h"

char*
MStringTokUtil::strtok_r(char* s1, const char* s2, char** lasts)
{
    if (lasts == NULL) {
        return NULL;
    }

    char* retval = NULL;
    if (s1 != NULL) {
        // First call
        retval = s1;
    } else if (*lasts != NULL) {
        // Get the input from the stored pointer state
        retval = *lasts;
    } else {
        // Saved state didn't have a string
        return NULL;
    }

    // Count the number of separator characters in s2
    int numcheck = 0;
    if (s2 != NULL) {
        numcheck = strlen(s2);
    }

    // Skip any initial separator characters
    char ch;
    bool match = true;
    while (((ch = *retval) != 0) && match) {
        match = false;
        for (int i = 0; i < numcheck; i++) {
            if (ch == s2[i]) {
                retval++;
                match = true;
                break;
            }
        }
    }

    // Did we hit the end of the string?
    if (*retval == 0) {
        *lasts = NULL;
        return NULL;
    }

    // Else we are on a non-separator, non-terminal character and will
    // have something non-zero length to return.

    char* ptr = retval;
    // Loop until match separator character or find NULL-terminator
    while ((ch = *ptr) != 0) {
        for (int i = 0; i < numcheck; i++) {
            if (ch == s2[i]) {
                *ptr = 0;
                ptr++;
                if (*ptr != 0) {
                    *lasts = ptr;
                } else {
                    *lasts = NULL;
                }
                return retval;
            }
        }
        ptr++;
    }

    // If here, no separator character was found so retval is the last thing we return
    *lasts = NULL;

    return retval;
}
