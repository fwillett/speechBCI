/*
 * Default SRILMoptions.h
 * 	Should be overridden by automatically generated $(OBJDIR)/SRILMoptions.h
 *
 * $Header: /home/srilm/CVS/srilm/misc/src/SRILMoptions.h,v 1.1 2017/02/01 22:39:39 stolcke Exp $
 */

#ifdef NDEBUG
# define NDEBUG_OPTION "-DNDEBUG"
#else
# define NDEBUG_OPTION ""
#endif

#ifdef USE_SARRAY
# define BUILD_OPTION_1	"-DUSE_SARRAY"
#else
# define BUILD_OPTION_1	""
#endif

#ifdef USE_SARRAY_TRIE
# define BUILD_OPTION_2 "-DUSE_SARRAY_TRIE"
#else
# define BUILD_OPTION_2 ""
#endif

#ifdef USE_SARRAY_MAP2
# define BUILD_OPTION_3 "-DUSE_SARRAY_MAP2"
#else
# define BUILD_OPTION_3 ""
#endif

#define BUILD_OPTIONS	NDEBUG_OPTION " " BUILD_OPTION_1 " " BUILD_OPTION_2 " " BUILD_OPTION_3

