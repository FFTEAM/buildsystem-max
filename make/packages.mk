glibc-pkg: $(TARGETPREFIX)/sbin/ldconfig
	rm -rf $(PKGPREFIX)
	mkdir -p $(PKGPREFIX)
	cd $(PKGPREFIX) && \
		mkdir lib sbin etc && \
		cp -a $(CROSS_DIR)/$(TARGET)/lib/*so* lib/ && \
		cp -a $(TARGETPREFIX)/sbin/ldconfig sbin/ &&  \
		rm lib/libnss_hesiod* lib/libnss_nis* lib/libnss_compat* \
		   lib/libmudflap* lib/libnsl*
	find $(PKGPREFIX) -type f -print0 | xargs -0 $(TARGET)-strip
	touch $(PKGPREFIX)/etc/ld.so.conf
	$(OPKG_SH) $(CONTROL_DIR)/glibc
	mv $(PKGPREFIX)/glibc-*.opk $(PACKAGE_DIR)
	rm -rf $(PKGPREFIX)

cs-drivers-pkg:
	# we have two directories packed, the newer one determines the package version
	opkg-chksvn.sh $(CONTROL_DIR)/cs-drivers $(SOURCE_DIR)/svn/COOLSTREAM/2.6.26.8-nevis || \
	opkg-chksvn.sh $(CONTROL_DIR)/cs-drivers $(SOURCE_DIR)/svn/THIRDPARTY/lib/firmware
	rm -rf $(PKGPREFIX)
	mkdir -p $(PKGPREFIX)/lib/modules/2.6.26.8-nevis
	mkdir    $(PKGPREFIX)/lib/firmware
	cp -a $(SOURCE_DIR)/svn/COOLSTREAM/2.6.26.8-nevis/* $(PKGPREFIX)/lib/modules/2.6.26.8-nevis
	cp -a $(SOURCE_DIR)/svn/THIRDPARTY/lib/firmware/*   $(PKGPREFIX)/lib/firmware
	$(OPKG_SH) $(CONTROL_DIR)/cs-drivers
	mv $(PKGPREFIX)/cs-drivers-*.opk $(PACKAGE_DIR)
	rm -rf $(PKGPREFIX)

cs-libs-pkg: $(SVN_TP_LIBS)/libnxp/libnxp.so $(SVN_TP_LIBS)/libcs/libcoolstream.so
	opkg-chksvn.sh $(CONTROL_DIR)/cs-libs $(SVN_TP_LIBS)/libnxp/libnxp.so || \
	opkg-chksvn.sh $(CONTROL_DIR)/cs-libs $(SVN_TP_LIBS)/libcs/libcoolstream.so
	rm -rf $(PKGPREFIX)
	mkdir -p $(PKGPREFIX)/lib
	cp -a $(SVN_TP_LIBS)/libnxp/libnxp.so $(SVN_TP_LIBS)/libcs/libcoolstream.so $(PKGPREFIX)/lib
	$(OPKG_SH) $(CONTROL_DIR)/cs-libs
	mv $(PKGPREFIX)/cs-*.opk $(PACKAGE_DIR)
	rm -rf $(PKGPREFIX)

aaa_base-pkg:
	rm -rf $(PKGPREFIX)
	mkdir -p $(PKGPREFIX)
	cp -a skel-root/common/* $(PKGPREFIX)/
	cp -a skel-root/$(PLATFORM)/* $(PKGPREFIX)/
	find $(PKGPREFIX) -name .gitignore | xargs rm
	cd $(PKGPREFIX) && rm etc/ntpd.conf
	$(OPKG_SH) $(CONTROL_DIR)/aaa_base
	mv $(PKGPREFIX)/*.opk $(PACKAGE_DIR)
	rm -rf $(PKGPREFIX)

pkg-index: $(HOSTPREFIX)/bin/opkg-make-index.sh
	cd $(PACKAGE_DIR) && opkg-make-index.sh . > Packages

prepare-pkginstall: pkg-index
	$(REMOVE)/install $(BUILD_TMP)/opkg.conf
	mkdir -p $(BUILD_TMP)/install/var/lib/opkg
	cp $(PATCHES)/opkg.conf $(BUILD_TMP)/
	echo "src local file:/$(PACKAGE_DIR)" >> $(BUILD_TMP)/opkg.conf
	opkg-cl -f $(BUILD_TMP)/opkg.conf -o $(BUILD_TMP)/install update

# install-pkgs installs everything the hard way, just to check dependencies...
install-pkgs: prepare-pkginstall
	opkg-cl -f $(PATCHES)/opkg.conf -o $(BUILD_TMP)/install install $(PACKAGE_DIR)/*
	# postinst does not really work on cross-arch installation... TODO: make more flexible
	test -d $(BUILD_TMP)/install/opt/pkg/lib && \
		echo "/opt/pkg/lib" > $(BUILD_TMP)/install/etc/ld.so.conf || true

# minimal-system-pkgs allows booting, not much else
minimal-system-pkgs: glibc-pkg aaa_base-pkg busybox procps opkg prepare-pkginstall
	opkg-cl -f $(BUILD_TMP)/opkg.conf -o $(BUILD_TMP)/install install \
		aaa_base busybox opkg procps

# system-pkgs installs actually enough to get a TV picture
system-pkgs: neutrino-pkg cs-libs-pkg cs-drivers-pkg minimal-system-pkgs
	opkg-cl -f $(BUILD_TMP)/opkg.conf -o $(BUILD_TMP)/install install \
		neutrino-hd

PHONY += glibc-pkg cs-drivers-pkg cs-libs-pkg aaa_base-pkg pkg-index install-pkgs
PHONY += prepare-pkginstall minimal-system-pkgs system-pkgs