# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit desktop xdg

MY_PN="deadlock-mod-manager"
MY_P_DEB="Deadlock.Mod.Manager_${PV}_amd64.deb"

DESCRIPTION="Mod manager for Valve's Deadlock (Tauri + Rust) - prebuilt binary"
HOMEPAGE="https://github.com/deadlock-mod-manager/deadlock-mod-manager"
SRC_URI="
	amd64? (
		https://github.com/deadlock-mod-manager/deadlock-mod-manager/releases/download/v${PV}/${MY_P_DEB}
			-> ${P}_amd64.deb
	)
"

S="${WORKDIR}"

LICENSE="GPL-3+"
SLOT="0"
KEYWORDS="-* ~amd64"

RESTRICT="bindist mirror strip"

RDEPEND="
	dev-libs/glib:2
	dev-libs/openssl:0/3
	net-libs/libsoup:3.0
	net-libs/webkit-gtk:4.1
	x11-libs/cairo
	x11-libs/gdk-pixbuf:2
	x11-libs/gtk+:3
	x11-libs/pango
	!games-util/deadlock-modmanager
"

QA_PREBUILT="
	usr/bin/${MY_PN}
"

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
	dobin usr/bin/${MY_PN}

	doicon -s 32 usr/share/icons/hicolor/32x32/apps/${MY_PN}.png
	doicon -s 128 usr/share/icons/hicolor/128x128/apps/${MY_PN}.png

	insinto /usr/share/icons/hicolor/256x256/apps
	newins "usr/share/icons/hicolor/256x256@2/apps/${MY_PN}.png" \
		${MY_PN}.png

	# Upstream ships an empty Categories= line; fill it so the launcher
	# is not hidden by desktop environments.
	local desktop_src="usr/share/applications/Deadlock Mod Manager.desktop"
	[[ -f "${desktop_src}" ]] || die "expected desktop file missing: ${desktop_src}"

	sed -i -e 's/^Categories=$/Categories=Game;Utility;/' "${desktop_src}" \
		|| die "sed on desktop file failed"

	newmenu "${desktop_src}" ${MY_PN}.desktop
}
