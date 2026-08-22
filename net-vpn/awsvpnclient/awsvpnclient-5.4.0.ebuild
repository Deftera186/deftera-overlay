# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit desktop systemd xdg

DESCRIPTION="AWS Client VPN GUI desktop client (GTK)"
HOMEPAGE="https://aws.amazon.com/vpn/client-vpn-download/"

# Upstream only publishes the *current* release at /GTK/latest/.
# Versioned URLs return 403, so we fetch via the floating URL and
# rely on Manifest verification (sha256 + size) for reproducibility.
# Bump PV + run `ebuild ... manifest` whenever AWS publishes a new release.
SRC_URI="https://d20adtppz83p9s.cloudfront.net/GTK/latest/awsvpnclient_amd64.deb -> ${P}_amd64.deb"

S="${WORKDIR}"

# AWS proprietary EULA + bundled .NET (MIT) + bundled OpenSSL (Apache-2.0)
# + bundled OpenVPN (GPL-2). Treat overall package as restricted/proprietary.
LICENSE="AWS-EULA Apache-2.0 BSD GPL-2 MIT"
SLOT="0"
KEYWORDS="-* ~amd64"

# Binary blob: cannot redistribute, contains prebuilt ELFs and .NET assemblies
# (also musl-linked openssl + acvc-openvpn that must NOT be stripped).
RESTRICT="bindist mirror strip test"

# Runtime deps: AWS ships its own .NET runtime + OpenSSL inside /opt, so the
# only hard runtime deps are the GTK stack + standard system libs the apphost
# links against, plus iproute2 (the daemon shells out to /sbin/ip). The
# bundled .NET apphost is glibc-linked: this package is glibc-only.
RDEPEND="
	x11-libs/gtk+:3
	dev-libs/glib:2
	x11-libs/cairo
	x11-libs/gdk-pixbuf:2
	x11-libs/pango
	sys-apps/iproute2
	virtual/libiconv
"
BDEPEND="
	app-arch/zstd
"

# Skip QA on prebuilt blobs.
QA_PREBUILT="opt/awsvpnclient/*"
QA_FLAGS_IGNORED="opt/awsvpnclient/.*"

src_unpack() {
	mkdir -p "${S}" || die
	cd "${S}" || die

	ar x "${DISTDIR}/${P}_amd64.deb" || die "Failed to extract .deb archive"
	tar --zstd -xf data.tar.zst || die "Failed to extract data.tar.zst"
	rm -f data.tar.zst control.tar.zst debian-binary _gpgbuilder || die
}

src_install() {
	# Drop the upstream systemd unit shipped under /etc - we install our own
	# copy via systemd_newunit to /lib/systemd/system (Gentoo convention).
	rm -rf "${S}/etc" || die

	# Application tree: /opt/awsvpnclient/...
	# cp -a preserves the executable bits on the bundled ELFs
	# (apphosts, openssl, acvc-openvpn, the musl loader, etc.).
	cp -a "${S}/opt" "${ED}/" || die "Failed to install /opt tree"

	# Desktop file (uses Icon=acvc-64.png with Path=/opt/awsvpnclient,
	# so Icon resolves via the working directory at launch time).
	domenu "${S}/usr/share/applications/awsvpnclient.desktop"

	# Convenience launcher on PATH. We install a wrapper rather than a
	# symlink because the privileged ACVC.GTK.Service identifies the GUI
	# process via Process.GetProcessesByName("AWS VPN Client"), matched
	# against /proc/<pid>/comm. The kernel derives comm from argv[0]'s
	# basename (truncated to TASK_COMM_LEN-1 = 15 chars), so a symlink
	# named "awsvpnclient" produces comm="awsvpnclient", the service
	# counts zero matching processes, and the GUI surfaces the
	# misleading "Multiple active users detected on operating system"
	# error. The wrapper uses `exec -a` to set argv[0] to the literal
	# string the service expects.
	newbin "${FILESDIR}/awsvpnclient.wrapper" awsvpnclient

	# Hicolor icon for the menu/launcher.
	newicon -s 64 "${S}/opt/awsvpnclient/Resources/acvc-64.png" awsvpnclient.png

	# Privileged daemon unit (runs as root, hosts the DBus socket the GUI
	# talks to). We do NOT auto-enable it - pkg_postinst tells the user how.
	systemd_newunit "${FILESDIR}/awsvpnclient.service" awsvpnclient.service

	# Log directory expected by the bundled service code paths.
	keepdir /var/log/aws-vpn-client
}

pkg_postinst() {
	xdg_pkg_postinst

	# Replicate AWS's own .deb postinst step: provision the FIPS module
	# integrity file. Without this, the bundled OpenSSL only loads the
	# `default` provider, the daemon's IsFipsProviderUsable check fails,
	# and the GUI surfaces a useless "Unknown error occurred" dialog.
	#
	# (/opt/awsvpnclient/Service/Resources/openvpn/openssl.cnf .includes
	# fipsmodule.cnf - that file is generated below.)
	local rdir="${EROOT}/opt/awsvpnclient/Service/Resources/openvpn"
	if [[ -x "${rdir}/openssl" && -f "${rdir}/fips.so" ]]; then
		einfo "Provisioning FIPS module (openssl fipsinstall)..."
		if ( cd "${rdir}" && \
			LD_LIBRARY_PATH="${rdir}" \
			./openssl fipsinstall \
				-out "${rdir}/fipsmodule.cnf" \
				-module "${rdir}/fips.so" >/dev/null 2>&1 ); then
			einfo "FIPS module provisioned."
		else
			eerror "openssl fipsinstall FAILED."
			eerror "VPN connections will fail with 'Unable to enforce FIPS mode'."
			eerror "Reproduce manually:"
			eerror "  cd ${rdir} && LD_LIBRARY_PATH=. ./openssl fipsinstall \\"
			eerror "    -out ./fipsmodule.cnf -module ./fips.so"
		fi
	else
		ewarn "Bundled OpenSSL or fips.so missing - skipping fipsinstall."
	fi

	elog ""
	elog "The AWS VPN Client requires a privileged background daemon."
	elog "It does NOT establish a tunnel by itself - it only spawns openvpn"
	elog "on demand when you click Connect in the GUI."
	elog ""
	elog "Enable persistently:"
	elog "    systemctl enable --now awsvpnclient.service"
	elog ""
	elog "Or start on demand each session before launching the GUI:"
	elog "    systemctl start awsvpnclient.service"
	elog ""
}

pkg_prerm() {
	# Stop the daemon on uninstall (but not on upgrades).
	if [[ -z "${REPLACED_BY_VERSION}" ]] && [[ -d /run/systemd/system ]]; then
		if systemctl is-active --quiet awsvpnclient.service 2>/dev/null; then
			ebegin "Stopping awsvpnclient.service"
			systemctl stop awsvpnclient.service 2>/dev/null
			eend $?
		fi
		if systemctl is-enabled --quiet awsvpnclient.service 2>/dev/null; then
			systemctl disable awsvpnclient.service 2>/dev/null
		fi
	fi
}

pkg_postrm() {
	xdg_pkg_postrm
	# Mirror AWS's own .deb prerm: drop the generated FIPS module file.
	# Skipped on upgrade so the new install can re-provision cleanly.
	if [[ -z "${REPLACING_VERSIONS}" ]]; then
		rm -f "${EROOT}/opt/awsvpnclient/Service/Resources/openvpn/fipsmodule.cnf"
	fi
}
