#
# Top-level Makefile for SRILM
#
# $Header: /home/srilm/CVS/srilm/Makefile,v 1.73 2019/09/10 17:48:09 stolcke Exp $
#

# SRILM = /home/speech/stolcke/project/srilm/devel
MACHINE_TYPE := $(shell $(SRILM)/sbin/machine-type)

RELEASE := $(shell cat RELEASE)

# Include common SRILM variable definitions.
include $(SRILM)/common/Makefile.common.variables

PACKAGE_DIR = ..

INFO = \
	ACKNOWLEDGEMENTS \
	CHANGES \
	Copyright \
	License \
	README \
	RELEASE \
	doc

MODULES = \
	misc \
	dstruct \
	lm \
	flm \
	lattice \
	utils \
	zlib

EXCLUDE = \
	me \
	htk \
	contrib \
	lm/src/test \
	flm/src/test \
	lattice/src/test \
	dstruct/src/test \
	utils/src/fsmtest \
	zlib/orig \
	common/COMPILE-HOSTS

VERSION_HEADER = \
	SRILMversion.h

MAKE_VARS = \
	SRILM=$(SRILM) \
	MACHINE_TYPE=$(MACHINE_TYPE) \
	OPTION=$(OPTION) \
	MAKE_PIC=$(MAKE_PIC)

World:	dirs
	$(MAKE) init
	$(MAKE) release-headers
	$(MAKE) depend
	$(MAKE) release-libraries
	$(MAKE) release-programs
	$(MAKE) release-scripts

# build central include directory and scripts only
msvc:	dirs
	$(MAKE) init
	$(MAKE) release-headers
	(cd misc/src; $(MAKE) $(MAKE_VARS) $(VERSION_HEADER))
	$(MAKE) release-scripts
	cd utils/src; $(MAKE) $(MAKE_VARS) release


depend-all:	dirs release-headers
	@gawk '!/^#/ { print $$1, $$2, $$3 }' common/COMPILE-HOSTS | sort -u | \
	while read prog host type; do \
		rm -f DONE; (set -x; \
		$$prog $$host "cd $(SRILM); $(MAKE) $(MFLAGS) SRILM=$(SRILM) MACHINE_TYPE=$$type OPTION=$(OPTION) init depend && touch DONE" < /dev/null); \
		[ -f DONE ] || exit 1; \
	done; rm -f DONE

compile-all:	dirs
	@gawk '!/^#/' common/COMPILE-HOSTS | \
	while read prog host type option; do \
		rm -f DONE; (set -x; \
		$$prog $$host "cd $(SRILM); $(MAKE) $(MFLAGS) SRILM=$(SRILM) MACHINE_TYPE=$$type OPTION=$$option init release-libraries release-programs && touch DONE" < /dev/null); \
		[ -f DONE ] || exit 1; \
	done; rm -f DONE

clean-all:	dirs
	@gawk '!/^#/' common/COMPILE-HOSTS | \
	while read prog host type option; do \
		rm -f DONE; (set -x; \
		$$prog $$host "cd $(SRILM); $(MAKE) $(MFLAGS) SRILM=$(SRILM) MACHINE_TYPE=$$type OPTION=$$option cleanest && touch DONE" < /dev/null); \
		[ -f DONE ] || exit 1; \
	done; rm -f DONE

dirs:
	-mkdir -p include lib bin

remove-dirs:
	-$(RMDIR) $(SRILM_BINDIR)
	-$(RMDIR) $(SRILM_LIBDIR)
	-$(RMDIR) $(SRILM_BIN)
	-$(RMDIR) $(SRILM_LIB)
	-$(RMDIR) $(SRILM_INCDIR)

init depend all programs release clean cleaner cleanest superclean sanitize desanitize \
release-headers release-libraries release-programs release-scripts:
	for subdir in $(MODULES); do \
		(cd $$subdir/src; $(MAKE) $(MAKE_VARS) $@) || exit 1; \
	done

pristine:
	for subdir in $(MODULES); do \
		(cd $$subdir/src; $(MAKE) $(MAKE_VARS) $@) || exit 1; \
	done
	$(MAKE) $(MAKE_VARS) remove-dirs

test try gzip:
	for subdir in $(MODULES); do \
		[ ! -d $$subdir/test ] || \
		(cd $$subdir/test; $(MAKE) $(MAKE_VARS) $@) || exit 1; \
	done

# files needed for the web page
WWW_DOCS = CHANGES License INSTALL RELEASE
WWW_DIR = /home/spftp/www/DocumentRoot/projects/srilm

www:	$(WWW_DOCS)
	$(INSTALL) -m 444 $(WWW_DOCS) $(WWW_DIR)/docs
	$(INSTALL) -m 444 man/html/*.[1-9].html $(WWW_DIR)/manpages

TAR = tar
INSTALL = install
PACKAGE_FILE = srilm-$(RELEASE).tar.gz
PACKAGE_FILE_NOTEST = srilm-$(RELEASE)-notest.tar.gz
PACKAGE_FILE_BIN = srilm-$(RELEASE)-$(MACHINE_TYPE).tar.gz

package:	$(PACKAGE_DIR)/EXCLUDE
	(cd misc/src; $(MAKE) $(MAKE_VARS) $(VERSION_HEADER))
	$(TAR) cvzXf $(PACKAGE_DIR)/EXCLUDE $(PACKAGE_DIR)/$(PACKAGE_FILE) .
	rm $(PACKAGE_DIR)/EXCLUDE

package_notest:	$(PACKAGE_DIR)/EXCLUDE
	echo test >> $(PACKAGE_DIR)/EXCLUDE
	$(TAR) cvzXf $(PACKAGE_DIR)/EXCLUDE $(PACKAGE_DIR)/$(PACKAGE_FILE_NOTEST) .
	rm $(PACKAGE_DIR)/EXCLUDE

package_bin:	$(PACKAGE_DIR)/EXCLUDE-$(MACHINE_TYPE)
	$(TAR) cvhzXf $(PACKAGE_DIR)/EXCLUDE-$(MACHINE_TYPE) $(PACKAGE_DIR)/$(PACKAGE_FILE_BIN) $(INFO) include lib man bin sbin
	rm $(PACKAGE_DIR)/EXCLUDE
	rm -f $(PACKAGE_DIR)/EXCLUDE-$(MACHINE_TYPE)

package_x:
	$(MAKE) $(MAKE_VARS) sanitize
	$(MAKE) $(MAKE_VARS) RELEASE=$(RELEASE)_x package
	$(MAKE) $(MAKE_VARS) desanitize

$(PACKAGE_DIR)/EXCLUDE:	force
	rm -f DONE
	(find bin/* lib/* */bin/* */obj/* */src/test */test/output */test/logs -type d -print -prune ; \
	ls build* go.build-*; \
	find $(EXCLUDE) include bin -print; \
	find . \( -name Makefile.site.\* -o -name "*.~[0-9]*" -o -name ".#*" -o -name Dependencies.\* -o -name core -o -name "core.[0-9]*" -o -name \*.3rdparty -o -name .gdb_history -o -name out.\* -o -name "*[._]pure[._]*" -o -type l -o -name RCS -o -name CVS -o -name .cvsignore -o -name GZ.files \) -print) | \
	sed 's,^\./,,' > $@

$(PACKAGE_DIR)/EXCLUDE-$(MACHINE_TYPE):	$(PACKAGE_DIR)/EXCLUDE
	fgrep -l /bin/sh bin/* > $(PACKAGE_DIR)/EXCLUDE-shell
	fgrep -v -f $(PACKAGE_DIR)/EXCLUDE-shell $(PACKAGE_DIR)/EXCLUDE | \
	egrep -v 'include|^bin$$|$(MACHINE_TYPE)[^~]*$$' > $@
	-egrep '$(MACHINE_TYPE).*[._]pure[._]' $(PACKAGE_DIR)/EXCLUDE >> $@
	-egrep '$(MACHINE_TYPE)_[gp]' $(PACKAGE_DIR)/EXCLUDE >> $@
	rm -f $(PACKAGE_DIR)/EXCLUDE-shell

force:

