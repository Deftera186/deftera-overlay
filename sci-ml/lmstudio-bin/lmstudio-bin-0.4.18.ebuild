# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit desktop pax-utils xdg

# Upstream tags every Linux build with a numeric "build" suffix appended
# after a dash (e.g. 0.4.18-1); the internal app version is the same PV
# with that suffix joined by a plus (0.4.18+1). Both the release directory
# and the .deb basename embed the dashed form, so derive it once here and
# bump BUILD whenever upstream re-spins the same PV.
BUILD=1
MY_PV="${PV}-${BUILD}"

DESCRIPTION="Discover, download, and run LLMs locally (Electron desktop app)"
HOMEPAGE="https://lmstudio.ai/"
SRC_URI="
	amd64? (
		https://installers.lmstudio.ai/linux/x64/${MY_PV}/LM-Studio-${MY_PV}-x64.deb
			-> ${P}_amd64.deb
	)
"

S="${WORKDIR}"

LICENSE="LM-Studio"
SLOT="0"
KEYWORDS="-* ~amd64"

# Proprietary binary blob: the Terms of Use forbid redistribution, and the
# .deb ships prebuilt ELFs (the Electron app, its bundled Chromium libs,
# ffmpeg, Vulkan/SwiftShader) that must NOT be stripped.
RESTRICT="bindist mirror strip test"

# Runtime deps. LM Studio bundles its own Electron 38 / Chromium 140 under
# /opt/LM-Studio, so this list is the set of host libraries those prebuilt
# ELFs actually link against, derived from DT_NEEDED on the `lm-studio`
# binary plus the extra libraries upstream's own .deb `Depends:` field and
# the Electron runtime dlopen() at launch (libnotify, libsecret, libXtst,
# libXScrnSaver, libuuid). libudev is consumed via virtual/libudev: a
# systemd/systemd-utils alternative could be satisfied by a udev-less
# build, which ships no libudev.so.1.
# virtual/libcrypt is pulled by the vendored CPython 3.11 that backs the
# llama.cpp extension (_crypt.cpython-311.so links libcrypt.so).
#
# Intentionally NOT listed: libcuda.so.1. It is needed only by the optional
# NVIDIA CUDA llama.cpp backend and is supplied at runtime by
# x11-drivers/nvidia-drivers (driver-provided; never a package dep). The
# bundled Vulkan and CPU (AVX2) backends need no such library.
RDEPEND="
	virtual/libudev
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
	virtual/libcrypt:=
	x11-libs/cairo
	x11-libs/gdk-pixbuf:2
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
QA_PREBUILT="opt/LM-Studio/*"

src_unpack() {
	local deb="${DISTDIR}/${P}_amd64.deb"

	mkdir -p "${S}" || die
	cd "${S}" || die

	# .deb is an ar archive of {debian-binary, control.tar.*, data.tar.xz}.
	ar x "${deb}" || die "ar x failed on ${deb}"
	unpack ./data.tar.xz
}

src_install() {
	# Application tree -> /opt/LM-Studio (upstream's own install prefix, as
	# referenced by the shipped .desktop Exec= and the update-alternatives
	# symlink in the .deb postinst). cp -a preserves the executable bits on
	# the bundled ELFs (lm-studio, chrome-sandbox, chrome_crashpad_handler,
	# the *.so blobs).
	insinto /opt
	mkdir -p "${ED}/opt" || die
	cp -a "${S}/opt/LM-Studio" "${ED}/opt/" || die "Failed to install /opt/LM-Studio tree"

	# Electron's setuid sandbox helper must be setuid-root with mode 4711;
	# otherwise Chromium aborts at startup with "The SUID sandbox helper
	# binary was found, but is not configured correctly". This mirrors the
	# `chmod 4755` in upstream's .deb postinst, tightened to 4711 (no read
	# bit needed) as ::gentoo's Electron packages do.
	fperms 4711 /opt/LM-Studio/chrome-sandbox

	# The main binary is a V8/JIT engine: mark it so a PaX/hardened kernel
	# permits RWX/mprotect. No-op on a vanilla kernel.
	pax-mark m "${ED}/opt/LM-Studio/lm-studio"

	# Convenience launcher on PATH (upstream's postinst points the
	# update-alternatives symlink at this same target).
	dosym ../../opt/LM-Studio/lm-studio /usr/bin/lm-studio

	# Desktop file. Upstream ships three defects we repair:
	#   * a stray lowercase `category=` line (invalid key) alongside the
	#     real `Categories=`,
	#   * `Categories=Development;` dropping the `Utility;` the bogus key
	#     was meant to carry,
	#   * an absolute Exec= path (fine, but we normalise to the PATH name so
	#     the menu entry and the CLI agree).
	local desktop="${S}/usr/share/applications/lm-studio.desktop"
	[[ -f "${desktop}" ]] || die "expected desktop file missing: ${desktop}"
	sed -i \
		-e '/^category=/d' \
		-e 's|^Exec=/opt/LM-Studio/lm-studio |Exec=lm-studio |' \
		-e 's|^Categories=Development;$|Categories=Development;Utility;|' \
		"${desktop}" \
		|| die "sed on desktop file failed"
	domenu "${desktop}"

	# Icon. Upstream ships a single 1024x1024 PNG in a bogus "0x0" hicolor
	# directory; reinstall it into the correct sized bucket so icon themes
	# resolve `Icon=lm-studio`.
	newicon -s 1024 \
		"${S}/usr/share/icons/hicolor/0x0/apps/lm-studio.png" \
		lm-studio.png
}

pkg_postinst() {
	xdg_pkg_postinst

	elog ""
	elog "LM Studio stores models and settings under ~/.lmstudio."
	elog "Launch it from your menu or by running: lm-studio"
	elog ""
	elog "A modern x86-64 CPU with AVX2 is required."
	elog ""
	elog "GPU acceleration: LM Studio ships Vulkan and ROCm/llama.cpp"
	elog "backends and selects a runtime from its in-app settings. On some"
	elog "AMD cards whose ISA is not recognised by the bundled ROCm libs,"
	elog "export HSA_OVERRIDE_GFX_VERSION to the matching gfx version before"
	elog "launching, e.g. for RDNA2 (gfx1030):"
	elog "    HSA_OVERRIDE_GFX_VERSION=10.3.0 lm-studio"
	elog ""
}
