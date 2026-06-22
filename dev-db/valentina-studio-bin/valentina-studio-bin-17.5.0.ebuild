# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit desktop xdg

# Upstream versions the release directory by major.minor (e.g. "17.5") and
# the .deb basename by major only (e.g. "vstudio_x64_17_lin.deb"); the
# actual binary's internal version is the full three-component PV.
MY_PV_DIR="${PV%.*}"
MY_PV_MAJOR="${PV%%.*}"

DESCRIPTION="GUI client for DuckDB, ValentinaDB, MongoDB, MySQL, PostgreSQL, MSSQL & SQLite"
HOMEPAGE="
	https://www.valentina-db.com/en/valentina-studio-overview
	https://www.valentina-db.com/en/studio/download
"
SRC_URI="
	amd64? (
		https://valentina-db.com/download/prev_releases/${MY_PV_DIR}/lin_64/vstudio_x64_${MY_PV_MAJOR}_lin.deb
			-> ${P}_amd64.deb
	)
"

S="${WORKDIR}"

LICENSE="Valentina-EULA"
SLOT="0"
KEYWORDS="-* ~amd64"

# Proprietary binary blob: cannot redistribute, ships prebuilt ELFs (Qt6,
# ICU, Valentina runtime, DB drivers) that must NOT be stripped.
RESTRICT="bindist mirror strip"

# Runtime deps. The bundle ships its own Qt6, ICU, OpenSSL and Valentina
# runtime under /opt/VStudio/{qt,vcomponents,lib}, so only the libraries
# those prebuilt ELFs actually link against on the host are listed here.
# Derived from ldd on vstudio, libQt6XcbQpa.so.6, libQt6WaylandClient.so.6
# and the bundled driver/plugin .so files.
RDEPEND="
	app-arch/bzip2
	app-arch/zstd
	dev-libs/double-conversion
	dev-libs/expat
	dev-libs/glib:2
	dev-libs/libb2
	dev-libs/libffi
	dev-libs/libpcre2
	dev-libs/wayland
	media-gfx/graphite2
	media-libs/fontconfig
	media-libs/freetype
	media-libs/harfbuzz
	media-libs/libglvnd
	media-libs/libpng:0/16
	media-libs/md4c
	sys-apps/dbus
	sys-apps/systemd
	sys-apps/util-linux
	virtual/zlib
	x11-libs/libX11
	x11-libs/libXau
	x11-libs/libXdmcp
	x11-libs/libxcb
	x11-libs/libxkbcommon
	x11-libs/xcb-util
	x11-libs/xcb-util-cursor
	x11-libs/xcb-util-image
	x11-libs/xcb-util-keysyms
	x11-libs/xcb-util-renderutil
	x11-libs/xcb-util-wm
"
BDEPEND="
	app-arch/xz-utils
"

# Skip QA on the prebuilt blob tree.
QA_PREBUILT="opt/VStudio/*"
QA_FLAGS_IGNORED="opt/VStudio/.*"

src_unpack() {
	local deb="${DISTDIR}/${P}_amd64.deb"

	mkdir -p "${S}" || die
	cd "${S}" || die

	ar x "${deb}" || die "ar x failed on ${deb}"
	unpack ./data.tar.xz
}

src_install() {
	# Application tree: /opt/VStudio/...
	# cp -a preserves the executable bits on the bundled ELFs (the main
	# vstudio binary, Qt6 libs, ICU, OpenSSL, driver/plugin .so files,
	# pg_dump, pg_restore).
	insinto /opt
	# `insinto` + `doins` would clobber file modes; copy by hand instead.
	mkdir -p "${ED}/opt" || die
	cp -a "${S}/opt/VStudio" "${ED}/opt/" || die "Failed to install /opt/VStudio tree"

	# Convenience symlinks on PATH. We ship two basenames so that
	# .desktop-aware launchers (which read Name=) and dmenu/wmenu-run
	# style PATH launchers (which only see basenames) both surface the
	# package under a name the user would actually type. Qt resolves the
	# symlink before locating qt.conf, so the bundled Plugins path keeps
	# working regardless of which symlink is invoked.
	dosym ../../opt/VStudio/vstudio /usr/bin/vstudio
	dosym ../../opt/VStudio/vstudio /usr/bin/valentina-studio

	# Desktop file. Upstream's Icon= uses an absolute path under /opt and
	# its Name/GenericName are both the cryptic "VStudio", so launcher
	# search by "valentina" or "studio" finds nothing. Rewrite to a
	# logical icon name (so themes apply) and to the product's real name
	# (so launchers surface it), then install the upstream 128x128 PNG
	# into hicolor.
	local desktop="${S}/usr/share/applications/vstudio.desktop"
	[[ -f "${desktop}" ]] || die "expected desktop file missing: ${desktop}"
	sed -i \
		-e 's|^Icon=/opt/VStudio/Resources/vstudio\.png$|Icon=vstudio|' \
		-e 's|^Name=VStudio$|Name=Valentina Studio|' \
		-e 's|^GenericName\(\[[^]]*\]\)\?=VStudio$|GenericName\1=Database Manager|' \
		"${desktop}" \
		|| die "sed on desktop file failed"
	domenu "${desktop}"

	newicon -s 128 "${S}/opt/VStudio/Resources/vstudio.png" vstudio.png
}

pkg_postinst() {
	xdg_pkg_postinst

	elog ""
	elog "Valentina Studio Free Edition requires a no-cost serial number"
	elog "from Paradigma Software. On first launch the GUI shows a"
	elog "registration dialog; alternatively, order one in advance at:"
	elog "    https://valentina-db.com/en/store/vstudio"
	elog ""
}
