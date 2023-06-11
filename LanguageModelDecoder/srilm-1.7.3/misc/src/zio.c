/*
    File:   zio.c
    Author: Andreas Stolcke
    Date:   Wed Feb 15 15:19:44 PST 1995
   
    Description:
                 Compressed file stdio extension
*/

#ifndef lint
static char Copyright[] = "Copyright (c) 1995-2010 SRI International.  All Rights Reserved.";
static char RcsId[] = "@(#)$Header: /home/srilm/CVS/srilm/misc/src/zio.c,v 1.31 2011/04/07 07:43:24 stolcke Exp $";
#endif

/*
 * $Log: zio.c,v $
 * Revision 1.31  2011/04/07 07:43:24  stolcke
 * Suppress unused functions if NO_ZIO is defined
 *
 * Revision 1.30  2010/06/02 04:47:32  stolcke
 * avoid compiler warning
 *
 * Revision 1.29  2010/04/05 15:12:03  stolcke
 * avoid using gunzip to avoid script wrapper overhead
 *
 * Revision 1.28  2009/08/22 22:41:19  stolcke
 * support for xz compressed files
 *
 * Revision 1.27  2008/05/27 03:21:41  stolcke
 * avoid compiler warnings about exit()
 *
 * Revision 1.26  2007/11/11 19:49:11  stolcke
 * use  7z e to uncompress (probably doesn't matter)
 *
 * Revision 1.25  2007/11/11 16:06:53  stolcke
 * 7zip compression support
 *
 * Revision 1.24  2006/03/06 05:46:43  stolcke
 * define NO_ZIO in zio.h instead of zio.c
 *
 * Revision 1.23  2006/03/01 00:45:45  stolcke
 * allow disabling of zio for windows environment (NO_ZIO)
 *
 * Revision 1.22  2006/01/09 17:39:03  stolcke
 * MSVC port
 *
 * Revision 1.21  2006/01/05 19:32:42  stolcke
 * ms visual c portability
 *
 * Revision 1.20  2005/12/16 23:30:09  stolcke
 * added support for bzip2-compressed files
 *
 * Revision 1.19  2005/07/28 21:08:15  stolcke
 * include signal.h for portability
 *
 * Revision 1.18  2005/07/28 18:37:47  stolcke
 * portability for systems w/o pipes
 *
 * Revision 1.17  2004/01/31 01:17:51  stolcke
 * don't declare errno, get it from errno.h
 *
 * Revision 1.16  2003/11/09 21:09:11  stolcke
 * use gunzip -f to allow uncompressed files ending in .gz
 *
 * Revision 1.15  2003/11/01 06:18:30  stolcke
 * issue stdin/stdout warning only once
 *
 * Revision 1.14  1999/10/13 09:07:13  stolcke
 * make filename checking functions public
 *
 * Revision 1.13  1997/06/07 15:58:47  stolcke
 * fixed some gcc warnings
 *
 * Revision 1.13  1997/06/07 15:56:24  stolcke
 * fixed some gcc warnings
 *
 * Revision 1.12  1997/01/23 20:38:35  stolcke
 * *** empty log message ***
 *
 * Revision 1.11  1997/01/23 20:02:59  stolcke
 * handle SIGPIPE termination
 *
 * Revision 1.10  1997/01/22 07:52:08  stolcke
 * warn about multiple uses of -
 *
 * Revision 1.9  1996/11/30 21:08:59  stolcke
 * use exec in compress commands
 *
 * Revision 1.8  1995/07/19 16:51:31  stolcke
 * remove PATH assignment to account for local setup
 *
 * Revision 1.7  1995/06/22 20:47:16  stolcke
 * dup stdio descriptors so fclose won't disturb them
 *
 * Revision 1.6  1995/06/22 20:44:39  stolcke
 * return more error info
 *
 * Revision 1.5  1995/06/22 19:58:11  stolcke
 * ansi-fied
 *
 * Revision 1.4  1995/06/12 22:57:12  tmk
 * Added ifdef around the redefinitions of fopen() and fclose().
 *
 */

/*******************************************************************
   Copyright 1994,1997 SRI International.  All rights reserved.
   This is an unpublished work of SRI International and is not to be
   used or disclosed except as provided in a license agreement or
   nondisclosure agreement with SRI International.
 ********************************************************************/

#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#ifndef _MSC_VER
#include <unistd.h>
#include <sys/param.h>
#endif
#include <fcntl.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <signal.h>
#include <errno.h>

#ifndef MAXPATHLEN
#define MAXPATHLEN 1024
#endif

#include "zio.h"

#ifdef ZIO_HACK
#undef fopen
#undef fclose
#endif

#define STDIO_NAME	  "-"

#define STD_PATH    ":"   /* "PATH=/usr/bin:/usr/ucb:/usr/bsd:/usr/local/bin" */

#define COMPRESS_CMD	  "exec compress -c"
#define UNCOMPRESS_CMD	  "exec uncompress -c"

#define GZIP_CMD	  "exec gzip -c"
#define GUNZIP_CMD	  "exec gzip -dcf"

#define BZIP2_CMD	  "exec bzip2"
#define BUNZIP2_CMD	  "exec bzip2 -dcf"

#define SEVENZIP_CMD	  "exec 7z a -si"
#define SEVENUNZIP_CMD	  "exec 7z e -so"

#define XZ_CMD	  	  "exec xz"
#define XZ_DECOMPRESS_CMD "exec xz -dcf"

/*
 * Does the filename refer to stdin/stdout ?
 */
int
stdio_filename_p (const char *name)
{
    return (strcmp(name, STDIO_NAME) == 0);
}

/*
 * Does the filename refer to a compressed file ?
 */
int
compressed_filename_p (const char *name)
{
    unsigned len = strlen(name);

    return
	(sizeof(COMPRESS_SUFFIX) > 1) &&
	    (len > sizeof(COMPRESS_SUFFIX)-1) &&
		(strcmp(name + len - (sizeof(COMPRESS_SUFFIX)-1),
			COMPRESS_SUFFIX) == 0);
}

/*
 * Does the filename refer to a gzipped file ?
 */
int
gzipped_filename_p (const char *name)
{
    unsigned len = strlen(name);

    return 
	((sizeof(GZIP_SUFFIX) > 1) &&
	    (len > sizeof(GZIP_SUFFIX)-1) &&
		(strcmp(name + len - (sizeof(GZIP_SUFFIX)-1),
			GZIP_SUFFIX) == 0)) ||
	((sizeof(OLD_GZIP_SUFFIX) > 1) &&
	    (len > sizeof(OLD_GZIP_SUFFIX)-1) &&
		(strcmp(name + len - (sizeof(OLD_GZIP_SUFFIX)-1),
			OLD_GZIP_SUFFIX) == 0));
}

/*
 * Does the filename refer to a bzipped file ?
 */
int
bzipped_filename_p (const char *name)
{
    unsigned len = strlen(name);

    return 
	(sizeof(BZIP2_SUFFIX) > 1) &&
	    (len > sizeof(BZIP2_SUFFIX)-1) &&
		(strcmp(name + len - (sizeof(BZIP2_SUFFIX)-1),
			BZIP2_SUFFIX) == 0);
}

/*
 * Does the filename refer to a 7-zip file ?
 */
int
sevenzipped_filename_p (const char *name)
{
    unsigned len = strlen(name);

    return 
	(sizeof(SEVENZIP_SUFFIX) > 1) &&
	    (len > sizeof(SEVENZIP_SUFFIX)-1) &&
		(strcmp(name + len - (sizeof(SEVENZIP_SUFFIX)-1),
			SEVENZIP_SUFFIX) == 0);
}


/*
 * Does the filename refer to a xz-compressed file ?
 */
int
xz_filename_p (const char *name)
{
    unsigned len = strlen(name);

    return 
	(sizeof(XZ_SUFFIX) > 1) &&
	    (len > sizeof(XZ_SUFFIX)-1) &&
		(strcmp(name + len - (sizeof(XZ_SUFFIX)-1),
			XZ_SUFFIX) == 0);
}

/*
 * Check file readability
 */
#ifndef NO_ZIO
static int
readable_p (const char *name)
{
    int fd = open(name, O_RDONLY);

    if (fd < 0)
        return 0;
    else {
        close(fd);
	return 1;
    }
}

/*
 * Check file writability
 */
static int
writable_p (const char *name)
{
    int fd = open(name, O_WRONLY|O_CREAT, 0666);

    if (fd < 0)
        return 0;
    else {
        close(fd);
	return 1;
    }
}
#endif /* !NO_ZIO */

/*
 * Open a stdio stream, handling special filenames
 */
FILE *zopen(const char *name, const char *mode)
{
    char command[MAXPATHLEN + 100];

    if (stdio_filename_p(name)) {
	/*
	 * Return stream to stdin or stdout
	 */
	if (*mode == 'r') {
		static int stdin_used = 0;
		static int stdin_warning = 0;
		int fd;

		if (stdin_used) {
		    if (!stdin_warning) {
			fprintf(stderr,
				"warning: '-' used multiple times for input\n");
			stdin_warning = 1;
		    }
		} else {
		    stdin_used = 1;
		}

		fd = dup(0);
		return fd < 0 ? NULL : fdopen(fd, mode);
	} else if (*mode == 'w' || *mode == 'a') {
		static int stdout_used = 0;
		static int stdout_warning = 0;
		int fd;

		if (stdout_used) {
		    if (!stdout_warning) {
			fprintf(stderr,
				"warning: '-' used multiple times for output\n");
			stdout_warning = 1;
		    }
		} else {
		    stdout_used = 1;
		}

		fd = dup(1);
		return fd < 0 ? NULL : fdopen(fd, mode);
	} else {
		return NULL;
	}
    } else {
	char *compress_cmd = NULL;
	char *uncompress_cmd = NULL;
	int zip_to_stdout = 1;
	
	if (compressed_filename_p(name)) {
	    compress_cmd = COMPRESS_CMD;
	    uncompress_cmd = UNCOMPRESS_CMD;
	} else if (gzipped_filename_p(name)) {
	    compress_cmd = GZIP_CMD;
	    uncompress_cmd = GUNZIP_CMD;
	} else if (bzipped_filename_p(name)) {
	    compress_cmd = BZIP2_CMD;
	    uncompress_cmd = BUNZIP2_CMD;
	} else if (sevenzipped_filename_p(name)) {
	    compress_cmd = SEVENZIP_CMD;
	    uncompress_cmd = SEVENUNZIP_CMD;
	    zip_to_stdout = 0;
	} else if (xz_filename_p(name)) {
	    compress_cmd = XZ_CMD;
	    uncompress_cmd = XZ_DECOMPRESS_CMD;
	}

	if (compress_cmd != NULL) {
#ifdef NO_ZIO
	    fprintf(stderr, "Sorry, compressed I/O not available on this machine\n");
	    errno = EINVAL;
	    return NULL;
#else /* !NO_ZIO */
	    /*
	     * Return stream to compress pipe
	     */
	    if (*mode == 'r') {
		if (!readable_p(name))
		    return NULL;
		sprintf(command, "%s;%s %s", STD_PATH, uncompress_cmd, name);
		return popen(command, mode);
	    } else if (*mode == 'w') {
		if (!writable_p(name))
		    return NULL;
		if (zip_to_stdout) {
		    sprintf(command, "%s;%s >%s", STD_PATH, compress_cmd, name);
		} else {
		    /*
		     * This is necessary because the compression program might
		     * complain if a zero-length file already exists.
		     * However, it means that existing file owner & permission
		     * attributes are not preserved.
		     */
		    unlink(name);
		    sprintf(command, "%s;%s %s", STD_PATH, compress_cmd, name);
		}
		return popen(command, mode);
	    } else {
		return NULL;
	    }
#endif /* !NO_ZIO */
	} else {
	    return fopen(name, mode);
	}
    }
}

/*
 * Close a stream created by zopen()
 */
int
zclose(FILE *stream)
{
#ifdef NO_ZIO
     return fclose(stream);
#else /* !NO_ZIO */

    int status;
    struct stat statb;

    /*
     * pclose(), according to the man page, should diagnose streams not 
     * created by popen() and return -1.  however, on SGIs, it core dumps
     * in that case.  So we better be careful and try to figure out
     * what type of stream it is.
     */
    if (fstat(fileno(stream), &statb) < 0)
	return -1;

    /*
     * First try pclose().  It will tell us if stream is not a pipe
     */
    if ((statb.st_mode & S_IFMT) != S_IFIFO ||
        fileno(stream) == 0 || fileno(stream) == 1)
    {
        return fclose(stream);
    } else {
	status = pclose(stream);
	if (status == -1) {
	    /*
	     * stream was not created by popen(), but popen() does fclose
	     * for us in thise case.
	     */
	    return ferror(stream);
	} else if (status == SIGPIPE) {
	    /*
	     * It's normal for the uncompressor to terminate by SIGPIPE,
	     * i.e., if the user program closed the file before reaching
	     * EOF. 
	     */
	     return 0;
	} else {
	    /*
	     * The compressor program terminated with an error, and supposedly
	     * has printed a message to stderr.
	     * Set errno to a generic error code if it hasn't been set already.
	     */
	    if (errno == 0) {
		errno = EIO;
	    }
	    return status;
	}
    }
#endif /* NO_ZIO */
}

#ifdef STAND
int
main (argc, argv)
    int argc;
    char **argv;
{
    int dowrite = 0;
    char buffer[BUFSIZ];
    int nread;
    FILE *stream;

    if (argc < 3) {
	printf("usage: %s file {r|w}\n", argv[0]);
 	exit(2);
    }

    if (*argv[2] == 'r') {
	stream = zopen(argv[1], argv[2]);

	if (!stream) {
		perror(argv[1]);
		exit(1);
	}

	while (!ferror(stream) && !feof(stream) &&!ferror(stdout)) {
		nread = fread(buffer, 1, sizeof(buffer), stream);
		(void)fwrite(buffer, 1, nread, stdout);
	}
    } else {
	stream = zopen(argv[1], argv[2]);

	if (!stream) {
		perror(argv[1]);
		exit(1);
	}

	while (!ferror(stdin) && !feof(stdin) && !ferror(stream)) {
		nread = fread(buffer, 1, sizeof(buffer), stdin);
		(void)fwrite(buffer, 1, nread, stream);
	}
   }
   if (ferror(stdin)) {
	perror("stdin");
   } else if (ferror(stdout)) {
	perror("stdout");
   } else if (ferror(stream)) {
	perror(argv[1]);
   }
   zclose(stream);

   exit(0);
}
#endif /* STAND */
