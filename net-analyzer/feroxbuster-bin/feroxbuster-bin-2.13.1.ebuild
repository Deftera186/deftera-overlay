# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

DESCRIPTION="Fast, simple, recursive content discovery tool (prebuilt binary)"
HOMEPAGE="https://github.com/epi052/feroxbuster"
SRC_URI="
	amd64? (
		https://github.com/epi052/feroxbuster/releases/download/v${PV}/x86_64-linux-feroxbuster.tar.gz
			-> ${P}-amd64.tar.gz
	)
"

S="${WORKDIR}"

LICENSE="MIT"
SLOT="0"
KEYWORDS="-* ~amd64"

RESTRICT="bindist mirror strip test"

QA_PREBUILT="usr/bin/feroxbuster"

src_install() {
	dobin feroxbuster
}
