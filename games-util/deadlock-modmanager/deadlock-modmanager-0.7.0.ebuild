# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit desktop xdg

DESCRIPTION="Mod manager for Valve's Deadlock (Tauri + Rust)"
HOMEPAGE="https://github.com/Stormix/deadlock-modmanager"
SRC_URI="
	https://github.com/Stormix/deadlock-modmanager/archive/refs/tags/v${PV}.tar.gz
		-> ${P}.tar.gz
"

S="${WORKDIR}/${PN}-${PV}/apps/desktop"

LICENSE="GPL-3+"
SLOT="0"
KEYWORDS="~amd64"

# pnpm + cargo both want network access during build (npm registry,
# crates.io). Network sandbox must be disabled when emerging this:
#   FEATURES="-network-sandbox" emerge games-util/deadlock-modmanager
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
# sys-apps/pnpm-bin lives in the ::guru overlay. Users must enable
# ::guru (or provide pnpm by other means) before emerging this.
BDEPEND="
	dev-lang/rust:=
	llvm-core/clang
	llvm-core/llvm
	llvm-core/lld
	net-libs/nodejs
	net-misc/curl
	sys-apps/pnpm-bin
	virtual/pkgconfig
	dev-lang/perl
	dev-lang/nasm
"

src_compile() {
	export VITE_API_URL="https://api.deadlockmods.app"

	# Prefer bundled implementations; avoid accidental system detection.
	export ZSTD_SYS_USE_PKG_CONFIG=0
	unset ZSTD_LIB_DIR
	export UNRAR_SYS_STATIC=1
	export UNRAR_SYS_FORCE_VENDOR=1
	unset UNRAR_LIB_DIR

	# Disable LTO (causes link issues with libring-core.a) and force
	# explicit -lbz2 link to keep ordering deterministic.
	export RUSTFLAGS="${RUSTFLAGS} -C lto=no -C link-arg=-lbz2"

	pnpm install || die "pnpm install failed"

	cd src-tauri || die
	cargo build --release || die "cargo build failed"
}

src_install() {
	newbin src-tauri/target/release/deadlock-mod-manager deadlock-modmanager

	# Icons
	insinto /usr/share/icons/hicolor/32x32/apps
	doins src-tauri/icons/32x32.png

	insinto /usr/share/icons/hicolor/128x128/apps
	doins src-tauri/icons/128x128.png

	insinto /usr/share/icons/hicolor/256x256/apps
	newins src-tauri/icons/128x128@2x.png deadlock-modmanager.png

	# Desktop entry
	domenu "${FILESDIR}/deadlock-modmanager.desktop"

	dodoc ../../README.md
}
