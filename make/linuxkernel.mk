###############################################################
# stuff needed to build kernel modules(very experimental...)  #
# DO NOT TRY TO USE THIS KERNEL, IT WILL MOST LIKELY NOT WORK #
#                                                             #
# ATTENTION: the modules will probably only work with a       #
#            crosstool-built arm-cx2450x-linux-gnueabi-gcc,   #
#            or to be more precise, with the same compiler    #
#            that also built the running kernel!              #
#                                                             #
# modules are installed in $(TARGETPREFIX)/mymodules and can  #
# be picked from there.                                       #
###############################################################

KVERSION = 2.6.26.8
KVERSION_FULL = $(KVERSION)-nevis
SOURCE_MODULE = $(TARGETPREFIX)/mymodules/lib/modules/$(KVERSION_FULL)
TARGET_MODULE = $(TARGETPREFIX)/lib/modules/$(KVERSION_FULL)

# try to build a compiler that's similar to the one that built the kernel...
# this should be only needed if you are using e.g. an external toolchain with gcc4
kernelgcc: $(CROSS_BASE)/gcc-3.4.1-glibc-2.3.2/powerpc-405-linux-gnu/bin/powerpc-405-linux-gnu-gcc

# powerpc-405-linux-gnu-gcc is the "marker file" for crosstool
$(CROSS_BASE)/gcc-3.4.1-glibc-2.3.2/powerpc-405-linux-gnu/bin/powerpc-405-linux-gnu-gcc:
	@if test "$(shell basename $(shell readlink /bin/sh))" != bash; then \
		echo "crosstool needs bash as /bin/sh!. Please fix."; false; fi
	tar -C $(BUILD_TMP) -xzf $(ARCHIVE)/crosstool-0.43.tar.gz
	cp $(PATCHES)/glibc-2.3.3-allow-gcc-4.0-configure.patch $(BUILD_TMP)/crosstool-0.43/patches/glibc-2.3.2
	cd $(BUILD_TMP)/crosstool-0.43 && \
		$(PATCH)/crosstool-0.43-fix-build-with-FORTIFY_SOURCE-default.diff && \
		export TARBALLS_DIR=$(ARCHIVE) && \
		export RESULT_TOP=$(CROSS_BASE) && \
		export GCC_LANGUAGES="c,c++" && \
		export PARALLELMFLAGS="-j 3" && \
		export QUIET_EXTRACTIONS=y && \
		eval `cat powerpc-405.dat gcc-3.4.1-glibc-2.3.2.dat` LINUX_DIR=linux-2.6.12 sh all.sh --notest

$(BUILD_TMP)/linux-$(KVERSION):
	tar -C $(BUILD_TMP) -xf $(ARCHIVE)/linux-$(KVERSION).tar.bz2
	cd $(BUILD_TMP)/linux-$(KVERSION) && \
		$(PATCH)/linux-2.6.26.8-new-make.patch
	cp $(PATCHES)/kernel.config $@/.config

$(D)/cskernel: $(BUILD_TMP)/linux-$(KVERSION)
	pushd $(BUILD_TMP)/linux-$(KVERSION) && \
		make ARCH=arm CROSS_COMPILE=$(TARGET)- oldconfig && \
		$(MAKE) ARCH=arm CROSS_COMPILE=$(TARGET)- && \
		make ARCH=arm CROSS_COMPILE=$(TARGET)- INSTALL_MOD_PATH=$(TARGETPREFIX)/mymodules modules_install
	touch $@

# rule for the autofs4 module - needed by the automounter
# installs the already built module into the "proper" path
$(TARGET_MODULE)/kernel/fs/autofs4/autofs4.ko: $(D)/cskernel
	install -m 644 -D $(SOURCE_MODULE)/kernel/fs/autofs4/autofs4.ko $@
	make depmod

# input drivers: usbhid, evdev
inputmodules: $(D)/cskernel
	mkdir -p $(TARGET_MODULE)/kernel/drivers
	cp -a	$(SOURCE_MODULE)/kernel/drivers/input $(SOURCE_MODULE)/kernel/drivers/hid \
		$(TARGET_MODULE)/kernel/drivers/
	make depmod

# helper target...
depmod:
	PATH=$(PATH):/sbin:/usr/sbin depmod -b $(TARGETPREFIX) $(KVERSION_FULL)
	mv $(TARGET_MODULE)/modules.dep $(TARGET_MODULE)/.modules.dep
	rm $(TARGET_MODULE)/modules.*
	mv $(TARGET_MODULE)/.modules.dep $(TARGET_MODULE)/modules.dep
