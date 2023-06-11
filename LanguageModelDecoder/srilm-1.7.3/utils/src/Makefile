#
#    File:   Makefile.example
#    Author: The SRI DECIPHER (TM) System
#    Date:   Thu Sep  9 12:04:47 1993
#
#    Description:
#	This is the example makefile to start from when adding new
#       modules to the DECIPHER System.  To use this makefile, first
#       copy it to your directory as the file "Makefile".  Second,
#       replace the word "Example" in the text below with the real name
#	of your library.  Next replace the the example filenames with
#	the names of your actual declarations and source files in the
#	appropriate variable definitions.  Finally clean up by deleting
#	any lines not relevant to your module and updating this header
#       to describe your new module.  Do not forget to use the proper
#       RCS keywords!
#
#    Copyright (c) 1993, SRI International.  All Rights Reserved.
#
#    $Header: /home/srilm/CVS/srilm/utils/src/Makefile,v 1.76 2019/02/09 07:36:09 stolcke Exp $
#

# Include common SRILM variable definitions.
include $(SRILM)/common/Makefile.common.variables

# This should enable locale-specific string collation for vocabulary sorting
# (it will slow things down somewhat).
#ADDITIONAL_CXXFLAGS = -Dstrcmp=strcoll

# Flags for generating "compact" data structures
COMPACT_FLAGS += -DUSE_SARRAY -DUSE_SARRAY_TRIE -DUSE_SARRAY_MAP2

# Flags for generating "short" data structures
SHORT_FLAGS = $(COMPACT_FLAGS) -DUSE_SHORT_VOCAB -DUSE_XCOUNTS

# Flags for generating "long long" data structures
LLONG_FLAGS = $(COMPACT_FLAGS) -DUSE_LONGLONG_COUNTS -DUSE_XCOUNTS

# enable use of liblbfgs if indicated
ifneq ($(HAVE_LIBLBFGS), )
  ADDITIONAL_CFLAGS += -DHAVE_LIBLBFGS
  ADDITIONAL_CXXFLAGS += -DHAVE_LIBLBFGS
endif

ADDITIONAL_LDFLAGS += \
	$(MATHERR_LINK)

ADDITIONAL_LIBRARIES += \
	$(SRILM_LIBDIR)/$(LIB_PREFIX)oolm$(LIB_SUFFIX) \
	$(SRILM_LIBDIR)/$(LIB_PREFIX)dstruct$(LIB_SUFFIX) \
	$(SRILM_LIBDIR)/$(LIB_PREFIX)misc$(LIB_SUFFIX) \
	$(SRILM_LIBDIR)/$(LIB_PREFIX)z$(LIB_SUFFIX) \
	$(MATH_LIBRARY) \
	$(LBFGS_LIBRARY)

# Exported programs.
REAL_PROGRAM_NAMES = \
	nbest-rover-helper

# Example programs.
PROGRAM_NAMES = $(REAL_PROGRAM_NAMES) 

PROGRAMS = $(PROGRAM_NAMES:%=$(BINDIR)/%$(EXE_SUFFIX))

PROGRAM_SOURCES = $(foreach prog,$(PROGRAM_NAMES),\
			$(wildcard $(SRCDIR)/$(prog).c) \
			$(wildcard $(SRCDIR)/$(prog).cc))
PROGRAM_OBJECTS = $(PROGRAM_NAMES:%=$(OBJDIR)/%$(OBJ_SUFFIX))

# Libraries to be linked with the Example programs.
LIBRARIES = $(LIBRARY) \
	    $(ADDITIONAL_LIBRARIES)

# All of the types of files.

ALL_SOURCES = $(PROGRAM_SOURCES)

ALL_OBJECTS = $(PROGRAM_OBJECTS)

ALL_PROGRAMS = $(PROGRAMS)

ALL_PROGRAM_NAMES = $(PROGRAM_NAMES)

#

SCRIPTS = \
	rescore-nbest \
	wordlat-to-lisp \
	extract-skip-probs \
	$(EXPORTED_SCRIPTS)

EXPORTED_SCRIPTS = \
	change-lm-vocab \
	empty-sentence-lm \
	rescore-decipher \
	rescore-acoustic \
	rescore-reweight \
	rescore-minimize-wer \
	make-batch-counts \
	merge-batch-counts \
	make-big-lm \
	make-multiword-pfsg \
	pfsg-from-ngram \
	nbest-error \
	nbest-rover \
	search-rover-combo \
	rexport.gnumake \
	align-with-tags \
	compute-sclite \
	compute-sclite-nbest \
	compare-sclite \
	cumbin

# scripts that need to be edited before installation
EDIT_SCRIPTS = \
	add-classes-to-pfsg \
	add-dummy-bows \
	add-pauses-to-pfsg \
	add-ppls \
	bytelog-to-log10 \
	classes-to-fsm \
	combine-acoustic-scores \
	combine-rover-controls \
	rover-control-weights \
	rover-control-tying \
	compare-ppls \
	compute-best-mix \
	compute-best-rover-mix \
	compute-best-sentence-mix \
	compute-oov-rate \
	concat-sausages \
	context-ngrams \
	continuous-ngram-count \
	de-vq-lm \
	extract-skip-probs \
	filter-event-counts \
	find-reference-posteriors \
	fix-ctm \
	fsm-to-pfsg \
	get-gt-counts \
	get-unigram-probs \
	hits-from-log \
	log10-to-bytelog \
	make-abs-discount \
	make-diacritic-map \
	make-google-ngrams \
	make-gt-discounts \
	make-kn-discounts \
	make-kn-counts \
	make-hiddens-lm \
	make-lm-subset \
	make-nbest-pfsg \
	make-ngram-pfsg \
	make-sub-lm \
	metadb \
	sort-lm \
	reverse-lm \
	merge-nbest \
	nbest-posteriors \
	nbest2-to-nbest1 \
	nbest-optimize-args-from-rover-control \
	nbest-oov-counts \
	nbest-vocab \
	nbest-words \
	pfsg-to-dot \
	pfsg-to-fsm \
	pfsg-vocab \
	htklat-vocab \
	ppl-from-log \
	remove-lowprob-ngrams \
	replace-unk-words \
	replace-words-with-classes \
	reverse-text \
	reverse-ngram-counts \
	sentid-to-sclite \
	sentid-to-ctm \
	split-tagged-ngrams \
	subset-context-ngrams \
	subtract-ppls \
	tolower-ngram-counts \
	uniform-classes \
	uniq-ngram-counts \
	vp2text \
	wlat-to-dot \
	wlat-to-pfsg \
	wlat-stats \
	wordlat-to-lisp \
	prettify \
	select-vocab 


# Define targets.

all:	$(PROGRAMS)

$(LIBRARY):	$(LIB_OBJECTS)
	$(ARCHIVE) $(AR_OUTPUT_OPTION) $^ $(DEMANGLE_FILTER)
	$(RANLIB) $@ $(DEMANGLE_FILTER)

$(PROGRAMS): $(LIBRARY) $(OTHER_LIBRARIES)

# Variables and Targets for released system

EXPORTED_PROGRAMS  = \
	$(EDIT_SCRIPTS:%=$(BINDIR)/%) \
	$(REAL_PROGRAM_NAMES:%=$(BINDIR)/%$(EXE_SUFFIX))

release:	release-scripts release-programs

# Include common SRILM target definitions.
include $(SRILM)/common/Makefile.common.targets

#
# Rule to create edited gawk script 
#
$(BINDIR)/%: $(SRCDIR)/%.gawk $(BINDIR_STAMP) $(SRILM)/common/Makefile.machine.$(MACHINE_TYPE)
	sed -e '1s,/usr/local/bin/gawk,$(GAWK),' $< >$@.new
	mv $@.new $@

#
# Rule to create edited perl script 
#
$(BINDIR)/%: $(SRCDIR)/%.pl $(BINDIR_STAMP) $(SRILM)/common/Makefile.machine.$(MACHINE_TYPE)
	sed -e '1s,/usr/local/bin/perl,$(PERL),' $< >$@.new
	mv $@.new $@

