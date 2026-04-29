# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit desktop xdg

MY_PN="twintaillauncher"

DESCRIPTION="A multi-platform launcher for your anime games (binary)"
HOMEPAGE="
	https://twintaillauncher.app
	https://github.com/TwintailTeam/TwintailLauncher
"
SRC_URI="
	amd64? (
		https://github.com/TwintailTeam/TwintailLauncher/releases/download/ttl-v${PV}/${MY_PN}_${PV}_amd64.deb
			-> ${P}_amd64.deb
	)
"

S="${WORKDIR}"

LICENSE="GPL-3"
SLOT="0"
KEYWORDS="~amd64"

# Binary blob: cannot redistribute upstream's deb, contains prebuilt ELFs.
RESTRICT="bindist mirror strip"

RDEPEND="
	x11-libs/gtk+:3
	net-libs/webkit-gtk:4.1
	net-libs/libsoup:3.0
	dev-libs/glib:2
	x11-libs/cairo
	x11-libs/gdk-pixbuf:2
"

QA_PREBUILT="
	usr/bin/${MY_PN}
	usr/lib/${MY_PN}/resources/*
"

src_unpack() {
	local deb="${DISTDIR}/${P}_amd64.deb"
	mkdir -p "${S}" || die
	cd "${S}" || die

	ar x "${deb}" || die "Failed to extract .deb"
	unpack ./data.tar.gz
}

src_install() {
	# Main binary
	into /usr
	dobin usr/bin/${MY_PN}

	# Resources (reaper, hpatchz, game patches)
	insinto /usr/lib/${MY_PN}/resources
	doins -r usr/lib/${MY_PN}/resources/*

	# Mark ELF resources as executable
	fperms 0755 /usr/lib/${MY_PN}/resources/reaper
	fperms 0755 /usr/lib/${MY_PN}/resources/hpatchz

	# Icons
	doicon -s 32 usr/share/icons/hicolor/32x32/apps/${MY_PN}.png
	doicon -s 128 usr/share/icons/hicolor/128x128/apps/${MY_PN}.png

	# HiDPI icon (256x256@2 -> 256x256)
	insinto /usr/share/icons/hicolor/256x256/apps
	newins "usr/share/icons/hicolor/256x256@2/apps/${MY_PN}.png" \
		${MY_PN}.png

	# Desktop file
	domenu usr/share/applications/${MY_PN}.desktop
}
