# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit desktop xdg

DESCRIPTION="Local-first Warframe collection and relic companion"
HOMEPAGE="https://github.com/Deftera186/tennoscope"
SRC_URI="
	https://github.com/Deftera186/tennoscope/archive/refs/tags/v${PV}.tar.gz
		-> ${P}.tar.gz
"

LICENSE="GPL-3"
SLOT="0"
KEYWORDS="~amd64"

# pnpm and cargo both resolve their lockfiles over the network during the build (npm registry,
# crates.io). The network sandbox must be disabled when emerging this:
#   FEATURES="-network-sandbox" emerge games-util/tennoscope
RESTRICT="mirror network-sandbox"

# Taken from ldd on the resulting binary: GTK3, WebKitGTK 4.1, libsoup 3, glib, cairo, pango
# and gdk-pixbuf, and notably *not* openssl.
RDEPEND="
	dev-libs/glib:2
	net-libs/libsoup:3.0
	net-libs/webkit-gtk:4.1
	x11-libs/cairo
	x11-libs/gdk-pixbuf:2
	x11-libs/gtk+:3
	x11-libs/pango
	!games-util/tennoscope-bin
"

# The relic overlay shells out to these; the collection browser runs without them. imagemagick
# needs USE=X for `import`, and 7.x is what provides `magick`. tesseract installs eng data
# unconditionally, so no L10N constraint is needed.
RDEPEND+="
	app-text/tesseract
	media-gfx/imagemagick[X]
	x11-apps/xwininfo
"

DEPEND="${RDEPEND}"

# sys-apps/pnpm-bin lives in the ::guru overlay. Enable ::guru (or provide pnpm by other means)
# before emerging this.
BDEPEND="
	|| (
		>=dev-lang/rust-1.85.0
		>=dev-lang/rust-bin-1.85.0
	)
	>=net-libs/nodejs-20.19
	sys-apps/pnpm-bin
	virtual/pkgconfig
"

src_compile() {
	export CARGO_HOME="${T}/cargo"
	export CARGO_TARGET_DIR="${WORKDIR}/target"

	pnpm --dir app install --frozen-lockfile || die "pnpm install failed"

	# Build the Vite bundle into app/dist first. Tauri's `frontendDist` embeds that directory
	# into the binary at compile time; without it the binary has nothing to serve.
	pnpm --dir app build || die "frontend build failed"

	# tauri/custom-protocol is mandatory. generate_context!() picks between the embedded
	# frontendDist bundle and the devUrl dev server on `cfg!(not(feature = "custom-protocol"))`.
	# The `tauri build` CLI passes it implicitly; bare cargo does not, so without it the release
	# binary bakes in http://localhost:5173 and the WebView fails with connection refused.
	cargo build --release --locked -p tennoscope --features tauri/custom-protocol \
		|| die "cargo build failed"

	[[ -x ${CARGO_TARGET_DIR}/release/tennoscope ]] \
		|| die "binary not produced at expected path"
}

src_test() {
	export CARGO_HOME="${T}/cargo"
	export CARGO_TARGET_DIR="${WORKDIR}/target"

	# The reward-reader tests shell out to magick and tesseract for real; both are in RDEPEND.
	cargo test --workspace --locked || die "cargo test failed"
	pnpm --dir app check || die "frontend checks failed"
}

src_install() {
	newbin "${WORKDIR}/target/release/tennoscope" tennoscope

	domenu packaging/tennoscope.desktop
	newicon -s 128 app/src-tauri/icons/128x128.png tennoscope.png

	dodoc README.md CHANGELOG.md THIRD_PARTY_NOTICES.md
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
