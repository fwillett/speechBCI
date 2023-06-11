/*
 * testRand --
 * 	Test random number generator
 */

#include <stdio.h>
#include <stdlib.h>
#include <math.h>

#ifdef NEED_RAND48
extern "C" {
    void srand48(long);
    double drand48();
    long lrand48();
}
#endif


int
main()
{
	srand48(1);
	int i;

	for (i = 0; i < 20; i ++) {
		printf(" %ld", lrand48());
	}
	printf("\n");

	for (i = 0; i < 20; i ++) {
		printf(" %lg", drand48());
	}
	printf("\n");

	exit(0);
}
