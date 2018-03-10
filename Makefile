target = iphone:clang:10.0:8.0
ARCHS ?= armv7 armv7s arm64
debug ?= no
GO_EASY_ON_ME = 1
include theos/makefiles/common.mk

PERLCFGOPTS = --target=$(subst arm64,aarch64,$(ARCH))-apple-darwin --target-tools-prefix="xcrun -sdk iphoneos " -Duseshrplib=true -Dosname=darwin
PERLCFLAGS = -isysroot $(ISYSROOT) $(SDKFLAGS) $(VERSIONFLAGS) $(_THEOS_TARGET_CC_CFLAGS) -w
PERLLDFLAGS = -isysroot $(SYSROOT) $(SDKFLAGS) $(VERSIONFLAGS) $(LEGACYFLAGS) -multiply_defined suppress

SIGN_BINS = $(THEOS_STAGING_DIR)/usr/bin/perl
SIGN_LIBS = $(find $(THEOS_STAGING_DIR) -name *.so)

ARCH = $(basename $@)
PERLBUILD = $(ARCH).perlbuild

.PHONY: configured built staged

perl5: perl5.diff
	rm -rf $@
	git submodule update $@
	cd $@; git checkout v5.26.1; patch -p1 < ../$<

perl-cross: perl-cross.diff
	rm -rf $@
	git submodule update $@
	cd $@; patch -p1 < ../$<

%.configured: perl5 perl-cross
	rm -rf $(PERLBUILD)
	cp -a perl5 $(PERLBUILD)
	cp -a perl-cross/. $(PERLBUILD)
	cd $(PERLBUILD); ./configure $(PERLCFGOPTS) \
		-Dccflags="$(PERLCFLAGS) -arch $(ARCH)" \
		-Dldflags="$(PERLLDFLAGS) -arch $(ARCH)" \
	 	-Dcppflags="$(PERLCFLAGS) -arch $(ARCH) -E" \
	 	-Dlddlflags="$(PERLLDFLAGS) -arch $(ARCH) -dynamiclib" \
	 	-Dsysroot=$(SYSROOT)
	$(ECHO_NOTHING)touch $@$(ECHO_END)

configured: $(foreach ARCH,$(ARCHS), $(ARCH).configured)

%.built: $(foreach ARCH,$(ARCHS), $(ARCH).configured)
	$(MAKE) -C $(PERLBUILD)
	touch $@

built: $(foreach ARCH,$(ARCHS), $(ARCH).built)

internal-all:: built

staged: $(foreach ARCH,$(ARCHS), $(ARCH).staged)
	$(foreach ARCH,$(ARCHS),$(MAKE) -C $(PERLBUILD) DESTDIR=$(THEOS_OBJ_DIR)/$(ARCH)/ install;)
	rsync -a $(foreach ARCH,$(ARCHS), $(THEOS_OBJ_DIR)/$(ARCH)/) $(THEOS_STAGING_DIR)
	rm -f "$(THEOS_STAGING_DIR)/usr/bin/perl"
	$(ECHO_MERGING)$(ECHO_UNBUFFERED)$(_THEOS_PLATFORM_LIPO) $(foreach ARCH,$(TARGET_ARCHS),-arch $(ARCH) $(THEOS_OBJ_DIR)/$(ARCH)/usr/bin/perl) -create -output "$(THEOS_STAGING_DIR)/usr/bin/perl"$(ECHO_END)
	
after-stage:: staged
	$(foreach FILE,$(SIGN_BINS),ldid -Sent.xml $(FILE);)
	$(foreach FILE,$(SIGN_LIBS),ldid -S $(FILE);)

include $(THEOS_MAKE_PATH)/null.mk