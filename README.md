# deftera overlay

[![pkgcheck](https://github.com/Deftera186/deftera-overlay/actions/workflows/pkgcheck.yml/badge.svg)](https://github.com/Deftera186/deftera-overlay/actions/workflows/pkgcheck.yml)
[![Gentoo overlays](https://img.shields.io/badge/gentoo-overlays-54487A?logo=gentoo)](https://api.gentoo.org/overlays/repositories.xml)

Personal [Gentoo](https://www.gentoo.org/) overlay maintained by
[@Deftera186](https://github.com/Deftera186), packaging a small set of
desktop applications, game utilities and proprietary clients that are
not (yet) in the main `::gentoo` tree.

Listed in the [official Gentoo overlays
database](https://api.gentoo.org/overlays/repositories.xml) as
`deftera`.

## Status

* **Quality:** experimental — best-effort, no warranty.
* **Architectures:** `~amd64` only.
* **Masters:** `gentoo`. Some packages additionally depend on the
  [`::guru`](https://wiki.gentoo.org/wiki/Project:GURU) overlay
  (notably `sys-apps/pnpm-bin`); enable `::guru` if you intend to
  build any source-based ebuild here.

## Installation

### Using `eselect-repository` (recommended)

The overlay is listed in the [official Gentoo overlays
database](https://api.gentoo.org/overlays/repositories.xml), so it
can be added by name:

```sh
sudo emerge --ask app-eselect/eselect-repository
sudo eselect repository enable deftera
sudo emaint sync --repo deftera
```

### Using `layman` (legacy)

`layman` is deprecated upstream in favour of `eselect-repository`, but
still works:

```sh
sudo layman -a deftera
```

### Manual

Only needed if you cannot use `eselect-repository` or `layman`:

```sh
sudo mkdir -p /var/db/repos/deftera
sudo git clone https://github.com/Deftera186/deftera-overlay.git /var/db/repos/deftera
sudo tee /etc/portage/repos.conf/deftera.conf <<'EOF'
[deftera]
location = /var/db/repos/deftera
sync-type = git
sync-uri = https://github.com/Deftera186/deftera-overlay.git
auto-sync = yes
EOF
```

## Accepting proprietary licenses

`net-vpn/awsvpnclient` ships under the AWS Customer Agreement. To allow
it to install:

```sh
echo 'net-vpn/awsvpnclient AWS-EULA' | sudo tee /etc/portage/package.license/awsvpnclient
```

`dev-db/valentina-studio-bin` ships under the Paradigma Software Valentina
Studio EULA. To allow it to install:

```sh
echo 'dev-db/valentina-studio-bin Valentina-EULA' | sudo tee /etc/portage/package.license/valentina-studio-bin
```

`sci-ml/lmstudio-bin` ships under the LM Studio Desktop App Terms of
Use. To allow it to install:

```sh
echo 'sci-ml/lmstudio-bin LM-Studio' | sudo tee /etc/portage/package.license/lmstudio-bin
```

## Quality assurance

Every change is scanned with [`pkgcheck`](https://github.com/pkgcore/pkgcheck)
in CI before merge. Run locally with:

```sh
pkgcheck scan -r /var/db/repos/deftera
```

## Reporting issues / contributing

Open an issue or pull request at
<https://github.com/Deftera186/deftera-overlay>.

## License

Overlay metadata (ebuilds, scripts, Manifests) is distributed under the
GNU General Public License v2 — same as the Gentoo main tree. Bundled
upstream packages retain their own licenses (see each package's
`LICENSE` variable).
