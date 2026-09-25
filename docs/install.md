# Install

> [!NOTE]
> This installs the shell only. For the full Caelestia dotfiles (themes, Hyprland config, keybinds,
> etc.), see [the main dotfiles repo](https://github.com/caelestia-dots/caelestia).

> [!IMPORTANT]
> If you previously installed `caelestia-shell` or `caelestia-shell-git` from the AUR, remove it
> first - this fork conflicts with and provides the same package.

## Quick install (Arch Linux)

Installs dependencies, then builds and installs the shell:

```sh
git clone https://github.com/cykler01/cykler-caelestia.git
cd cykler-caelestia
./install.sh
```

Flags:

- `--install-deps false` - skip installing dependencies (default is `true`), if you already have them
- `--repo-only` - skip AUR packages
- `--yes` / `-y` - skip the confirmation prompts

## By hand

### 1. Clone

```sh
git clone https://github.com/cykler01/cykler-caelestia.git
cd cykler-caelestia
```

### 2. Dependencies

The included script installs official-repo packages via `pacman` and AUR packages via `yay`/`paru`
(installing `yay` for you if you have no AUR helper). It prints each package list and asks for
confirmation before installing anything:

```sh
./install-deps.sh
```

Flags: `--repo-only` to skip AUR packages entirely, `--yes` / `-y` to skip the prompts.

<details>
<summary>Manual dependency list</summary>

Official repos:

- `glibc`, `gcc-libs` (base, usually already installed)
- `ddcutil`, `brightnessctl`
- `networkmanager`, `lm_sensors`, `aubio`, `libpipewire`, `libqalculate`, `taglib`, `power-profiles-daemon`
- `qt6-base`, `qt6-declarative`, `qt6-imageformats`, `qt6-multimedia`
- `swappy`, `fish`, `bash`, `grim`, `slurp`, `tesseract`, `wl-clipboard`, `libnotify`, `curl`, `jq`, `xdg-utils`
- Build deps: `git`, `cmake`, `ninja`, `qt6-shadertools`

AUR:

- [`caelestia-cli`](https://github.com/caelestia-dots/cli)
- [`quickshell-git`](https://git.outfoxxed.me/quickshell/quickshell) - must be the git version
- [`qt6-m3shapes-git`](https://github.com/soramanew/m3shapes)
- `libcava`
- Fonts: `ttf-material-symbols-variable`, `ttf-rubik-vf`, `ttf-cascadia-code-nerd`

`tesseract` and `wl-clipboard` are only needed by the launcher's [OCR action](launcher.md), and
`swappy` by the [screenshot preview](screenshot.md).

</details>

### 3. Build and install

```sh
cmake -B build -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/
cmake --build build
sudo cmake --install build
```

Then start the shell with `caelestia shell -d` (preferred) or `qs -c caelestia -n -d`.

> [!TIP]
> You can customise the installation location via the CMake flags `INSTALL_LIBDIR`, `INSTALL_QMLDIR`
> and `INSTALL_QSCONFDIR`. See the
> [upstream README](https://github.com/caelestia-dots/shell#manual-installation) for details.

## Arch Linux (local package)

We build our own system package from this repo. If you want the same approach, create a `PKGBUILD`
that clones this repo (instead of the upstream source) and otherwise mirrors the
[`caelestia-shell-git`](https://aur.archlinux.org/packages/caelestia-shell-git) PKGBUILD.

## Nix

The upstream flake is kept in this fork, so you can try it with:

```sh
nix run github:cykler01/cykler-caelestia#with-cli
```

If you have cloned the repo and use [direnv](https://direnv.net/), the included `.envrc` loads the
flake's dev shell automatically - approve it once after cloning:

```sh
direnv allow
```

This is best-effort: we do not run Nix daily, so we cannot guarantee it stays working.
