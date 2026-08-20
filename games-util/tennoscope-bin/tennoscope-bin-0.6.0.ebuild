# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit desktop xdg

DESCRIPTION="Local-first Warframe collection and relic companion (prebuilt binary)"
HOMEPAGE="https://github.com/Deftera186/tennoscope"

MY_DEB="TennoScope_${PV}_amd64.deb"

SRC_URI="
	amd64? (
		https://github.com/Deftera186/tennoscope/releases/download/v${PV}/${MY_DEB}
			-> ${P}_amd64.deb
	)
"

S="${WORKDIR}"

LICENSE="GPL-3"
SLOT="0"
KEYWORDS="-* ~amd64"

RESTRICT="bindist mirror strip"

# Taken from ldd on the shipped binary rather than assumed: it links GTK3, WebKitGTK 4.1,
# libsoup 3, glib, cairo, pango and gdk-pixbuf, and notably *not* openssl.
RDEPEND="
	dev-libs/glib:2
	net-libs/libsoup:3.0
	net-libs/webkit-gtk:4.1
	x11-libs/cairo
	x11-libs/gdk-pixbuf:2
	x11-libs/gtk+:3
	x11-libs/pango
	!games-util/tennoscope
"

# Also from `readelf -d` on the binary inside the released .deb: xcap's capture path links gbm,
# wayland-client and xcb, and glib reaches dbus. All four were satisfied only because webkit-gtk
# and gtk+ pull the same libraries in, so nothing broke -- but this package should not depend on
# another package's dependency list staying the way it is.
RDEPEND+="
	dev-libs/wayland
	media-libs/mesa
	sys-apps/dbus
	x11-libs/libxcb
"

# The relic overlay shells out to tesseract at runtime; the collection browser runs without
# it. tesseract installs eng data unconditionally, so no L10N constraint is needed. Window
# location and the crop pipeline are in-process since 0.5.0, so xwininfo and ImageMagick are
# no longer runtime tools.
RDEPEND+="
	app-text/tesseract
"
# The Diagnostics report block opens the issue form in a browser and reveals the saved report
# folder in a file manager; `tauri-plugin-opener` shells out to xdg-open for both.
RDEPEND+="
	x11-misc/xdg-utils
"

QA_PREBUILT="usr/bin/tennoscope"

src_unpack() {
	local deb="${DISTDIR}/${P}_amd64.deb"

	mkdir -p "${S}" || die
	cd "${S}" || die

	ar x "${deb}" || die "ar x failed on ${deb}"

	local data_tar
	data_tar=$(echo data.tar.*) || die
	[[ -f "${data_tar}" ]] || die "data tarball missing in ${deb}"

	unpack "./${data_tar}"
}

src_install() {
	dobin usr/bin/tennoscope

	doicon -s 128 usr/share/icons/hicolor/128x128/apps/tennoscope.png

	# Upstream ships the 256px icon under a `256x256@2` directory, which is not a hicolor
	# theme directory; install it where the theme spec expects to find it.
	insinto /usr/share/icons/hicolor/256x256/apps
	newins usr/share/icons/hicolor/256x256@2/apps/tennoscope.png tennoscope.png

	newmenu usr/share/applications/TennoScope.desktop tennoscope.desktop
}

pkg_postinst() {
	xdg_pkg_postinst

	elog "TennoScope reads the Warframe process's memory read-only to obtain a session"
	elog "token. Digital Extremes has not endorsed this, and any third-party tool that"
	elog "inspects a game process may carry account-policy risk. The application shows"
	elog "this disclosure on first run and does nothing until it is accepted."
	elog ""
	elog "If acquisition fails with a permission error, see the README section on"
	elog "kernel.yama.ptrace_scope. Do not run TennoScope as root."
}
