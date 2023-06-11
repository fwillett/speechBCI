/*
 * fcheck.h --
 *	stdio file handling with error checking
 */

#ifndef _FCHECK_H_
#define _FCHECK_H_

#include <stdio.h>

#ifdef __cplusplus
extern "C" {
#endif

FILE *fopen_check(const char *name, const char *mode);
void fclose_check(const char *name, FILE *file);

#ifdef __cplusplus
}
#endif

#endif /* _FCHECK_H_ */
