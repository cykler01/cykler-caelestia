<h1 align=center>cykler-caelestia</h1>

<div align=center>

A personal fork of [`caelestia-dots/shell`](https://github.com/caelestia-dots/shell) with the features I wanted.

</div>

This is my take on the Caelestia shell - upstream's desktop shell with my own features layered on top. It's built for my machine and my workflow first.

> [!WARNING]
> These features are **not guaranteed to work everywhere or reliably**. This fork tracks my
> hardware (an AMD laptop with a USB DAC) and my setup, so things may behave differently on
> your system. Use at your own risk.

## What's different from upstream
 
| Area | Upstream | This fork |
|---|---|---|
| Battery management | --- | `BatteryMonitor` service, auto power-saving on profile change, battery pane in control center |
| Game mode | Derived from animation state | Fixed false-trigger; also sets flat mouse accel |
| Launcher | Standard actions | Adds OCR (`>ocr`) and Google Lens (`>lens`) region-capture actions |
| Music player | External players only | In-shell local music player in the dashboard media tab |


## Features added on top of upstream

### Battery optimization suite

-   **`BatteryMonitor` service** - manages power profiles and per-profile effects
-   **Automatic Hyprland power saving** - when the power profile changes (e.g. switching to
    battery saver), the shell automatically disables animations, blur, gaps and shadows, and
    can adjust the screen refresh rate to save power. Changes are announced via toasts.
-   **Control center battery pane** - a new battery pane in the control center with:
    -   Power profile selector (with configurable behaviors per profile)
    -   Charging behavior settings
    -   Battery charge threshold configuration (for laptops that expose charge limits)
    -   Refresh rate selector
-   **Game mode false-trigger fix** - game mode state is no longer derived from whether
    animations are disabled, so the battery monitor disabling animations for power saving no
    longer makes the shell think game mode is on

### Game mode mouse acceleration

-   Game mode now also sets `input:accel_profile: flat` in Hyprland, disabling mouse
    acceleration while gaming (and restores it when game mode is turned off)

### Launcher image tools

-   **OCR action** - select a screen region with `slurp`, recognize it with `tesseract`,
    and copy the detected text to the clipboard with `wl-copy`.
-   **Google Lens action** - select a screen region with `slurp`, upload the capture to
    Uguu, and open the result in Google Lens.
-   Launch either tool from the command panel by selecting its action or searching for
    `>ocr` / `>lens`.

### Launcher wallpaper switching

-   **Left/right arrow keys** — the `>wallpaper` list is laid out horizontally, so plain
    left/right arrows now step through wallpapers, matching the existing up/down arrows and
    scroll wheel. Modified arrows (`shift` / `ctrl` / `alt`) keep their usual caret and
    selection behaviour in the search field.

### Screenshot preview

-   **Clipboard by default** — a screenshot goes straight to the clipboard, so it can be
    pasted immediately without touching the temporary file it is written to first.
-   **Preview instead of a notification** — a framed thumbnail of the capture appears in
    the bottom left of the screen for 3 seconds. Clicking the capture opens it in `swappy`
    to annotate, and the save button writes a copy to `~/Desktop`. If it is left alone, the
    temporary file is cleared and the clipboard keeps the image.

### Shell assets

-   **Settings page** — a new "Shell assets" page under *Settings → Appearance* that
    changes the images the shell uses: the system logo, the session screen and
    dashboard media gifs, the sidebar and lock screen placeholder images, and the profile
    picture (`~/.face`) shown on the dashboard and lock screen. Previously these could only
    be changed by editing the files (or the config) by hand.
-   **Upload like the profile picture** — choosing a file copies it to
    `~/.local/share/caelestia/assets/` and points the option at the copy, so the shell's
    own assets (which can be read only, e.g. under `/etc/xdg`) are left alone. Each row
    previews the current image, and the reset button restores the shell's default.
-   **Shell-relative asset paths fixed** — the shipped defaults use the `root:` prefix
    (e.g. `root:/assets/kurukuru.gif`), which stopped being resolved to the shell's asset
    directory, leaving the default logo, gifs and placeholder images blank.

### Local music player

-   **Music section in the dashboard media tab** — the media tab now has a source switch
    between the usual MPRIS players and a built in player. The player browses the folder set
    by `paths.musicDir` (defaults to `~/Music`) and plays the files in-shell, with seek,
    volume, shuffle and repeat (off / all / one) controls alongside the basic media
    controls.
-   **Folder and search browsing** — the library panel lists folders before tracks and can
    step back up to the music folder, while typing in the search box switches to a flat list
    of every track found under it. Searching matches the whole path, so an album name finds
    its tracks too.
-   **Cover art** — art embedded in the track is shown on the cover next to the controls,
    falling back to an image named after the track (what yt-dlp leaves behind, since opus
    cannot hold one) and then to a `cover`, `folder` or `album` image in the track's folder.
    Embedded art arrives from QtMultimedia as a `QImage`, which `Image.source` cannot take
    directly, so it goes through the image cache first (keyed by content, so the same
    artwork is only written once).
-   **Known gap** — Qt's ffmpeg backend only surfaces container level tags. mp3 (ID3), flac
    and m4a tags are read correctly, but Ogg/Opus puts its Vorbis comments on the stream
    instead, so those tracks show their file name with no artist or album. Cover art is
    unaffected.

## Feature requests

Any feature requests are welcome - open an [issue](https://github.com/CYKLER01/cykler-caelestia/issues) and I will try to get onto them quickly.

## Keeping up to date
 
I try to keep this fork merged with upstream `caelestia-dots/shell` regularly, so you should
get upstream fixes and features here too (best effort, no promises).
 
Run the included script from inside your clone - by default it just pulls any new commits
on this fork and rebuilds/reinstalls:
 
```sh
./update.sh
```
 
Flags:
 
-   `--upstream` - also merge in `caelestia-dots/shell` (adding the `upstream` remote if
    needed, and showing you what changed before merging)
-   `--yes` / `-y` - skip the confirmation prompts
It refuses to run if you have uncommitted local changes, so commit or stash first.
 
<details>
<summary>Doing it manually instead</summary>

```sh
cd cykler-caelestia
git pull
cmake --build build
sudo cmake --install build
```
 
To pull in upstream yourself:
 
```sh
git remote add upstream https://github.com/caelestia-dots/shell.git
git fetch upstream
git merge upstream/main
```
 
</details>

## Installation
 
> [!NOTE]
> This installs the shell only. For the full Caelestia dotfiles (themes, Hyprland config,
> keybinds, etc.), see [the main dotfiles repo](https://github.com/caelestia-dots/caelestia).
 
> [!IMPORTANT]
> If you previously installed `caelestia-shell` or `caelestia-shell-git` from the AUR, remove
> it first - this fork conflicts with and provides the same package.
 
### Arch Linux
 
#### 1. Clone the repo
 
```sh
git clone https://github.com/CYKLER01/cykler-caelestia.git
cd cykler-caelestia
```
 
#### 2. Install dependencies
 
Run the included script, which installs official-repo packages via `pacman` and AUR packages
via `yay`/`paru` (installing `yay` for you if you don't have an AUR helper). It prints each
package list and asks for confirmation before installing anything:
 
```sh
./install-deps.sh
```
 
Flags:
 
-   `--repo-only` - skip AUR packages entirely, if you'd rather install those yourself or use a different helper
-   `--yes` / `-y` - skip the confirmation prompts (useful for scripting)
<details>
<summary>Manual dependency list (if you'd rather not run the script)</summary>

##### Official repos:
 
-   `glibc`, `gcc-libs` (base, usually already installed)
-   `ddcutil`, `brightnessctl`
-   `networkmanager`, `lm_sensors`, `aubio`, `libpipewire`, `libqalculate`, `power-profiles-daemon`
-   `qt6-base`, `qt6-declarative`, `qt6-imageformats`, `qt6-multimedia`
-   `swappy`, `fish`, `bash`, `grim`, `slurp`, `tesseract`, `wl-clipboard`, `libnotify`, `curl`, `jq`, `xdg-utils`
-   Build deps: `git`, `cmake`, `ninja`, `qt6-shadertools`
##### AUR:
 
-   [`caelestia-cli`](https://github.com/caelestia-dots/cli)
-   [`quickshell-git`](https://git.outfoxxed.me/quickshell/quickshell) — must be the git version
-   [`qt6-m3shapes-git`](https://github.com/soramanew/m3shapes)
-   `libcava`
-   Fonts: `ttf-material-symbols-variable`, `ttf-rubik-vf`, `ttf-cascadia-code-nerd`
</details>

#### 3. Build and install
 
```sh
cmake -B build -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/
cmake --build build
sudo cmake --install build
```
 
Then start the shell with `caelestia shell -d` (preferred) or `qs -c caelestia -n -d`.
 
> [!TIP]
> You can customise the installation location via the CMake flags `INSTALL_LIBDIR`,
> `INSTALL_QMLDIR`, and `INSTALL_QSCONFDIR`. See the
> [upstream README](https://github.com/caelestia-dots/shell#manual-installation) for details.
 
### Arch Linux (local package)
 
I build my own system package from this repo. If you want the same approach, create a
`PKGBUILD` that clones this repo (instead of the upstream source) and otherwise mirrors the
[`caelestia-shell-git`](https://aur.archlinux.org/packages/caelestia-shell-git) PKGBUILD.
 
### Nix
 
The upstream flake is kept in this fork, so you can try it with:
 
```sh
nix run github:CYKLER01/cykler-caelestia#with-cli
```
 
If you've cloned the repo and use [direnv](https://direnv.net/), it comes with an `.envrc`
that loads the flake's dev shell automatically - just approve it once after cloning:
 
```sh
direnv allow
```
 
This is best-effort - I don't run Nix daily, so I can't guarantee it stays working.



## Configuration

Configuration is unchanged from upstream: everything lives in `~/.config/caelestia/shell.json`
and per-monitor overrides in `~/.config/caelestia/monitors/<monitor>/shell.json`. See the
[upstream configuring section](https://github.com/caelestia-dots/shell#configuring) for the full list of options and an example config.

## Troubleshooting
 
-   **`install-deps.sh` can't find an AUR helper and you don't want it installing `yay`** —
    run with `--repo-only`, then install the AUR packages yourself with your preferred helper.
-   **Build fails after pulling upstream changes** — try a clean build: `rm -rf build` then
    repeat the `cmake -B build ...` step.
-   **`update.sh` stops with a merge conflict** — resolve the conflicting files with
    `git status` / `git mergetool`, commit the merge, then rerun `./update.sh` (it'll skip
    straight to the rebuild since you're already up to date).
-   **`update.sh` refuses to run** — it requires a clean working tree; commit or `git stash`
    your local changes first.
-   **Shell won't start / blank output** — confirm you're on `quickshell-git` (not the
    stable `quickshell` package) and check `caelestia shell -d` output for the actual error.


## Credits

All credit for the shell itself goes to [Caelestia](https://github.com/caelestia-dots/shell) - this fork is just my additions on top of their excellent work. The battery power-management work also builds on the `feat/battery-power-management` branch contributed by [@PixelKhaos](https://github.com/PixelKhaos).
