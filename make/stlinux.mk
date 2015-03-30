STLINUX     = stlinux24

# updates / downloads
STL_ARCHIVE = $(ARCHIVE)/stlinux
STL_FTP = http://ftp.stlinux.com/pub/stlinux/2.4
STL_FTP_UPD_SRC  = $(STL_FTP)/updates/SRPMS
STL_FTP_UPD_SH4  = $(STL_FTP)/updates/RPMS/sh4
STL_FTP_UPD_HOST = $(STL_FTP)/updates/RPMS/host
STL_GET = $(WGET)/stlinux

## ordering is important here. The /host/ rule must stay before the less
## specific %.sh4/%.i386/%.noarch rule. No idea if this is portable or
## even reliable :-(
$(STL_ARCHIVE)/host/%.rpm:
	$(STL_GET)/host $(STL_FTP_UPD_HOST)/$(subst $(STL_ARCHIVE)/host/,"",$@)

$(STL_ARCHIVE)/%.src.rpm:
	$(STL_GET) $(STL_FTP_UPD_SRC)/$(subst $(STL_ARCHIVE)/,"",$@)

$(STL_ARCHIVE)/%.sh4.rpm \
$(STL_ARCHIVE)/%.i386.rpm \
$(STL_ARCHIVE)/%.noarch.rpm:
	$(STL_GET) $(STL_FTP_UPD_SH4)/$(subst $(STL_ARCHIVE)/,"",$@)

PATCH_STR = _0210

## rpm versions of packages on the STM server
# binutils 2.21.51-* segfault on linking the kernel
BINUTILS_VER	= 2.22-61
GCC_VER		= 4.6.3-109
STMKERNEL_VER	= 2.6.32.46-45
LIBGCC_VER	= 4.6.3-113
GLIBC_VER	= 2.10.2-34


### those patches are taken from the pingulux-git/tdt checkout
STM24_DVB_PATCH = linux-sh4-linuxdvb_stm24$(PATCH_STR).patch
COMMONPATCHES_24 = \
		$(STM24_DVB_PATCH) \
		linux-sh4-sound_stm24$(PATCH_STR).patch \
		linux-sh4-time_stm24$(PATCH_STR).patch \
		linux-sh4-init_mm_stm24$(PATCH_STR).patch \
		linux-sh4-copro_stm24$(PATCH_STR).patch \
		linux-sh4-strcpy_stm24$(PATCH_STR).patch \
		linux-squashfs-lzma_stm24$(PATCH_STR).patch \
		linux-sh4-ext23_as_ext4_stm24$(PATCH_STR).patch \
		bpa2_procfs_stm24$(PATCH_STR).patch \
		linux-ftdi_sio.c_stm24$(PATCH_STR).patch \
		linux-sh4-lzma-fix_stm24$(PATCH_STR).patch \
		linux-tune_stm24.patch

ifeq ($(PATCH_STR),"_0209")
COMMONPATCHES_24 +=
		linux-sh4-dwmac_stm24_0209.patch
endif

SPARK_PATCHES_24 = $(COMMONPATCHES_24) \
	linux-sh4-stmmac_stm24$(PATCH_STR).patch \
	linux-sh4-lmb_stm24$(PATCH_STR).patch \
	linux-sh4-spark_setup_stm24$(PATCH_STR).patch \
	linux-sh4-seife-revert-spark_setup_stmmac_mdio.patch \
	linux-sh4-spark7162_setup_stm24$(PATCH_STR).patch \
	linux-sh4-linux_yaffs2_stm24_0209.patch

## temporary until I sort out the mess and find a better place...

stlinux-dfb: \
	$(STL_ARCHIVE)/stlinux24-sh4-directfb-1.4.12+STM2011.09.27-1.sh4.rpm \
	$(STL_ARCHIVE)/stlinux24-sh4-directfb-dev-1.4.12+STM2011.09.27-1.sh4.rpm
	unpack-rpm.sh $(BUILD_TMP) $(STM_RELOCATE)/devkit/sh4 $(BUILD_TMP)/dfb \
		$^
	set -e; cd $(BUILD_TMP)/dfb/target; \
		sed -i "s,/usr,$(TARGETPREFIX)/usr,g" usr/lib/*.la; \
		sed -i "s,^libdir=.*,libdir='$(TARGETPREFIX)/usr/lib'," usr/lib/*.la; \
		cp -a usr $(TARGETPREFIX);
		rm -f $(TARGETPREFIX)/include/directfb; \
		ln -s ../usr/include/directfb $(TARGETPREFIX)/include
	set -e; cd $(TARGETPREFIX)/usr/lib/pkgconfig; \
		for i in *; do \
			sed -e "s,^prefix=.*,prefix='$(TARGETPREFIX)/usr'," $$i > $(TARGETPREFIX)/lib/pkgconfig/$$i; \
			rm $$i; \
		done

TDT_TOOLS ?= $(BUILD_TMP)/tdt-tools
$(TDT_TOOLS)/config.status:
	test -d $(TDT_TOOLS)|| mkdir $(TDT_TOOLS)
	$(TDT_SRC)/tdt/cvs/apps/misc/tools/autogen.sh
	set -e; cd $(shell dirname $@); \
		export PKG_CONFIG=$(PKG_CONFIG); \
		export PKG_CONFIG_PATH=$(PKG_CONFIG_PATH); \
		CC=$(TARGET)-gcc \
		CFLAGS="$(TARGET_CFLAGS)" \
		CXXFLAGS="$(TARGET_CFLAGS)" \
		$(TDT_SRC)/tdt/cvs/apps/misc/tools/configure \
			--host=$(TARGET) --build=$(BUILD) --prefix= \
			--enable-silent-rules --enable-maintainer-mode \
			;

ustslave: $(TARGETPREFIX)/bin/ustslave
fp_control: $(TARGETPREFIX)/bin/fp_control
stfbcontrol: $(TARGETPREFIX)/bin/stfbcontrol

# BUILD_TMP/tdt-driver "provides" include/linux/stmfb.h
$(TARGETPREFIX)/bin/ustslave \
$(TARGETPREFIX)/bin/fp_control \
$(TARGETPREFIX)/bin/stfbcontrol: \
	$(TDT_TOOLS)/config.status \
	| $(BUILD_TMP)/tdt-driver
	$(MAKE) -C $(TDT_TOOLS) install \
		SUBDIRS=$(lastword $(subst /, ,$@)) DESTDIR=$(TARGETPREFIX)
