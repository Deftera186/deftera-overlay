# deftera overlay

Personal [Gentoo](https://www.gentoo.org/) overlay maintained by
[@Deftera186](https://github.com/Deftera186), packaging a small set of
desktop applications, game utilities and proprietary clients that are
not (yet) in the main `::gentoo` tree.

## Status

* **Quality:** experimental — best-effort, no warranty.
* **Architectures:** `~amd64` only.
* **Masters:** `gentoo`. Some packages additionally depend on packages
  from the [`::guru`](https://wiki.gentoo.org/wiki/Project:GURU) overlay
  (notably `sys-apps/pnpm-bin`); enable `::guru` if you intend to build
  `games-util/deadlock-modmanager` from source.

## Packages

| Category / package                         | Description                                          |
|--------------------------------------------|------------------------------------------------------|
| `games-util/deadlock-modmanager`           | Mod manager for Valve's Deadlock (Tauri + Rust)      |
| `games-util/deadlock-modmanager-bin`       | Mod manager for Valve's Deadlock (prebuilt binary)   |
| `games-util/twintaillauncher-bin`          | Multi-platform launcher for anime games (binary)     |
| `media-fonts/material-symbols-variable`    | Google Material Symbols variable fonts (TTF)         |
| `net-vpn/awsvpnclient`                     | Official AWS Client VPN GUI desktop client (.deb)    |

## Installation

### Using `eselect-repository` (recommended)

```sh
sudo emerge --ask app-eselect/eselect-repository
sudo eselect repository add deftera git https://github.com/Deftera186/deftera-overlay.git
sudo emaint sync --repo deftera
```

### Using `layman`

```sh
sudo layman -o https://raw.githubusercontent.com/Deftera186/deftera-overlay/main/repositories.xml -f -a deftera
```

### Manual

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
