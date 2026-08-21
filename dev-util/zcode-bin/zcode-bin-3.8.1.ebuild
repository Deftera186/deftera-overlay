# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit desktop pax-utils xdg

DESCRIPTION="Agentic Development Environment desktop app from Z.ai (GLM harness)"
HOMEPAGE="https://zcode.z.ai/"
SRC_URI="
	amd64? (
		https://cdn-zcode.z.ai/zcode/electron/releases/${PV}/linux-x64/ZCode-${PV}-linux-x64.deb
			-> ${P}_amd64.deb
	)
"

S="${WORKDIR}"

LICENSE="ZCode-EULA"
SLOT="0"
KEYWORDS="-* ~amd64"

# The deb's internal Version: is 3.8.1-5310 (upstream build number,
# not encoded in the CDN path or filename). If a same-PV re-spin ever
# changes the archive, the Manifest digest mismatch is the symptom;
# re-pin by re-hashing the new artifact.

# Proprietary binary blob: the terms forbid redistribution, and the .deb
# ships prebuilt ELFs (the Electron app, its bundled Chromium libs,
# ffmpeg, Vulkan/SwiftShader, plus vendored ripgrep/bfs/ugrep tools)
# that must NOT be stripped.
RESTRICT="bindist mirror strip"

# Runtime deps. ZCode bundles its own Electron under /opt/ZCode, so this
# list is the set of host libraries those prebuilt ELFs actually link
# against, derived from DT_NEEDED across every ELF in the archive plus
# the extra libraries upstream's own .deb `Depends:` field and the
# Electron runtime dlopen() at launch (libnotify, libsecret, libXtst,
# libXScrnSaver). libudev is consumed via the systemd/eudev split.
RDEPEND="
	app-accessibility/at-spi2-core
	app-crypt/libsecret
	dev-libs/expat
	dev-libs/glib:2
	dev-libs/nspr
	dev-libs/nss
	media-libs/alsa-lib
	media-libs/mesa
	net-print/cups
	sys-apps/dbus
	sys-apps/util-linux
	virtual/libudev
	x11-libs/cairo
	x11-libs/gtk+:3
	x11-libs/libnotify
	x11-libs/libX11
	x11-libs/libxcb
	x11-libs/libXcomposite
	x11-libs/libXdamage
	x11-libs/libXext
	x11-libs/libXfixes
	x11-libs/libxkbcommon
	x11-libs/libXrandr
	x11-libs/libXScrnSaver
	x11-libs/libXtst
	x11-libs/pango
	x11-misc/xdg-utils
"
BDEPEND="
	app-arch/xz-utils
"

# The whole application tree is prebuilt; skip QA on it.
QA_PREBUILT="opt/ZCode/*"

src_unpack() {
	local deb="${DISTDIR}/${P}_amd64.deb"

	mkdir -p "${S}" || die
	cd "${S}" || die

	# .deb is an ar archive of {debian-binary, control.tar.*, data.tar.xz}.
	ar x "${deb}" || die "ar x failed on ${deb}"
	unpack ./data.tar.xz
}

src_install() {
	# Application tree -> /opt/ZCode (upstream's own install prefix, as
	# referenced by the shipped .desktop Exec= and the /usr/bin/zcode
	# symlink in the .deb postinst). cp -a preserves the executable bits
	# on the bundled ELFs (zcode, chrome-sandbox, chrome_crashpad_handler,
	# the *.so blobs, and the vendored ripgrep/bfs/ugrep tools).
	mkdir -p "${ED}/opt" || die
	cp -a "${S}/opt/ZCode" "${ED}/opt/" || die "Failed to install /opt/ZCode tree"

	# Electron's setuid sandbox helper: upstream's .deb postinst chmods
	# it 4755 only when unprivileged user namespaces are unavailable;
	# on a kernel with working user namespaces Chromium does not need
	# the helper at all. Install it setuid anyway (tightened to 4711 as
	# ::gentoo's Electron packages do) so the sandbox also works under
	# hardened kernels with user namespaces disabled.
	fperms 4711 /opt/ZCode/chrome-sandbox

	# The main binary is a V8/JIT engine: mark it so a PaX/hardened kernel
	# permits RWX/mprotect. No-op on a vanilla kernel.
	pax-mark m "${ED}/opt/ZCode/zcode"

	# Convenience launcher on PATH (mirrors the .deb postinst symlink).
	dosym ../../opt/ZCode/zcode /usr/bin/zcode

	# Desktop file. Upstream's copy is already valid; normalise Exec= to
	# the PATH name so the menu entry and the CLI agree.
	local desktop="${S}/usr/share/applications/zcode.desktop"
	[[ -f "${desktop}" ]] || die "expected desktop file missing: ${desktop}"
	sed -i \
		-e 's|^Exec=/opt/ZCode/zcode |Exec=zcode |' \
		"${desktop}" \
		|| die "sed on desktop file failed"
	domenu "${desktop}"

	# Icons. Upstream ships a full set of sized hicolor PNGs; install
	# each into its matching bucket so icon themes resolve `Icon=zcode`.
	local icon size
	for icon in "${S}"/usr/share/icons/hicolor/*/apps/zcode.png; do
		size=$(basename "$(dirname "$(dirname "${icon}")")")
		newicon -s "${size%x*}" "${icon}" zcode.png
	done
}

pkg_postinst() {
	xdg_pkg_postinst

	elog ""
	elog "ZCode stores its configuration, plugins, and workspaces under"
	elog "~/.zcode. Launch it from your menu or by running: zcode"
	elog ""
	elog "Signing in with a Z.ai account is required to use the bundled"
	elog "GLM models. See https://zcode.z.ai/en/docs/install for setup."
	elog ""
	elog "Updates arrive as new ebuild versions: the in-app auto-updater"
	elog "cannot write to /opt/ZCode under the package manager."
	elog ""
	elog "Per the ZCode terms, use of the service and its output without"
	elog "a paid subscription is limited to non-commercial, personal"
	elog "research and study purposes."
	elog ""
}
