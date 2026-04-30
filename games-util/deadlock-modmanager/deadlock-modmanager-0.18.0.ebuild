# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit desktop xdg

DESCRIPTION="Mod manager for Valve's Deadlock (Tauri + Rust)"
HOMEPAGE="https://github.com/deadlock-mod-manager/deadlock-mod-manager"
SRC_URI="
	https://github.com/deadlock-mod-manager/deadlock-mod-manager/archive/refs/tags/v${PV}.tar.gz
		-> ${P}.tar.gz
"

# Upstream renamed the project (and the GitHub org) from
# Stormix/deadlock-modmanager to
# deadlock-mod-manager/deadlock-mod-manager, so the tarball top-level
# directory is now ${PN/modmanager/mod-manager}-${PV}. We keep the
# overlay PN as deadlock-modmanager for continuity with already-installed
# users.
S="${WORKDIR}/deadlock-mod-manager-${PV}/apps/desktop"

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

	# Force the GNU toolchain. unrar_sys' bundled C++ uses libc++ ABI
	# symbols (std::__1::*) when built with clang++; gcc-15 also
	# accepts `-stdlib=libc++` (which unrar_sys' build.rs passes via
	# `flag_if_supported`), so the resulting libunrar.a ends up with
	# libc++ symbols regardless of which compiler runs. We therefore
	# always link the final binary against libc++ (provided by
	# dev-libs/libcxx, installed by clang).
	export CC=gcc
	export CXX=g++

	# Prefer bundled implementations; avoid accidental system detection.
	export ZSTD_SYS_USE_PKG_CONFIG=0
	unset ZSTD_LIB_DIR
	export UNRAR_SYS_STATIC=1
	export UNRAR_SYS_FORCE_VENDOR=1
	unset UNRAR_LIB_DIR

	pnpm install || die "pnpm install failed"

	# Build the Vite frontend bundle into apps/desktop/dist/.
	# Tauri's `frontendDist` (../dist relative to src-tauri) embeds
	# this directory into the final binary at compile time. Without
	# it, tauri bakes in the dev server URL and the binary tries to
	# connect to http://localhost:1420 at runtime.
	pnpm ui:build || die "pnpm ui:build failed"

	cd src-tauri || die

	# Two-stage build:
	#
	# 1) Build all dependency crates with `cargo build` (no extra link
	#    flags). This produces the dependency rlibs *and* the per-crate
	#    static archives created by build scripts (most importantly
	#    libring_core_0_17_14_.a from ring's perlasm pipeline and
	#    libunrar.a / libunrar_sys.a from unrar_sys' bundled C++).
	#
	# 2) Re-link the final `deadlock-mod-manager` binary with
	#    `cargo rustc -- <flags>` so the extra link arguments apply
	#    *only* to the leaf binary (avoiding propagation to host build
	#    scripts and dependency dylibs that would otherwise fail).
	#
	# The extra link arguments work around two issues:
	#
	#  - rust-lld bundled with rustc >=1.83 cannot resolve ring's
	#    perlasm-generated symbols, so we force GNU bfd ld.
	#  - rustc/cargo (>= 1.95) does not propagate the
	#    `cargo:rustc-link-lib=static=...` directives emitted by
	#    ring's and unrar_sys' build.rs to the final link line, even
	#    though the matching `-L` search paths are propagated. We
	#    therefore force the missing static libs in by hand.
	#
	# `cargo build` is allowed to fail because its own final link of
	# the binary will hit those same missing symbols - the explicit
	# `cargo rustc` re-link below is what actually produces the
	# binary.
	cargo build --release
	cargo rustc --release --bin deadlock-mod-manager -- \
		-C link-arg=-fuse-ld=bfd \
		-C link-arg=-lbz2 \
		-C link-arg=-lring_core_0_17_14_ \
		-C link-arg=-lunrar \
		-C link-arg=-lc++ \
		-C link-arg=-lgcc \
		|| die "cargo rustc (final link) failed"

	[[ -x ../target/release/deadlock-mod-manager ]] \
		|| die "binary not produced at expected path"
}

src_install() {
	newbin target/release/deadlock-mod-manager deadlock-modmanager

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
