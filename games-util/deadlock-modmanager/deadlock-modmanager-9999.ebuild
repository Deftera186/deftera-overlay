# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit desktop git-r3 xdg

DESCRIPTION="Mod manager for Valve's Deadlock (live git)"
HOMEPAGE="https://github.com/deadlock-mod-manager/deadlock-mod-manager"
EGIT_REPO_URI="https://github.com/deadlock-mod-manager/deadlock-mod-manager.git"
EGIT_CHECKOUT_DIR="${WORKDIR}/${PN}"

S="${WORKDIR}/${PN}/apps/desktop"

LICENSE="GPL-3+"
SLOT="0"
# Live ebuild: no KEYWORDS
PROPERTIES="live"

RESTRICT="mirror network-sandbox"

RDEPEND="
	x11-libs/gtk+:3
	net-libs/webkit-gtk:4.1
	net-libs/libsoup:3.0
	dev-libs/glib:2
	x11-libs/cairo
	x11-libs/pango
	x11-libs/gdk-pixbuf
	dev-libs/openssl:=
	app-arch/bzip2
"
BDEPEND="
	dev-lang/rust:=
	llvm-core/clang
	llvm-core/llvm
	llvm-core/lld
	net-libs/nodejs
	net-misc/curl
	sys-apps/pnpm-bin
	virtual/pkgconfig
"

src_unpack() {
	git-r3_src_unpack
}

src_compile() {
	export VITE_API_URL="https://api.deadlockmods.app"
	export RUSTFLAGS="${RUSTFLAGS} -C link-arg=-fuse-ld=lld"

	pnpm install || die

	cd src-tauri || die
	cargo build --release --frozen || die
}

src_install() {
	newbin src-tauri/target/release/deadlock-mod-manager deadlock-modmanager

	insinto /usr/share/icons/hicolor/32x32/apps
	doins src-tauri/icons/32x32.png

	insinto /usr/share/icons/hicolor/128x128/apps
	doins src-tauri/icons/128x128.png

	insinto /usr/share/icons/hicolor/256x256/apps
	newins src-tauri/icons/128x128@2x.png deadlock-modmanager.png

	domenu "${FILESDIR}/deadlock-modmanager.desktop"
}
