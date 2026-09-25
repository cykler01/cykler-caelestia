<h1 align=center>cykler-caelestia</h1>

<div align=center>

A personal fork of [caelestia-dots/shell](https://github.com/caelestia-dots/shell) with the features we wanted on top of it.

[**Watch the feature showcase**](https://cykler.dev/caelestia/showcase.mp4) - every feature in this fork, in one clip

[Docs](docs/README.md) - [Feature demos](docs/demos.md) - [Install](docs/install.md) - [Updating](docs/updating.md) - [Troubleshooting](docs/troubleshooting.md) - [Issues](https://github.com/cykler01/cykler-caelestia/issues)

![GitHub last commit](https://img.shields.io/github/last-commit/cykler01/cykler-caelestia?style=flat-square&labelColor=101418&color=9ccbfb)
![GitHub issues](https://img.shields.io/github/issues/cykler01/cykler-caelestia?style=flat-square&labelColor=101418&color=9ccbfb)
![GitHub license](https://img.shields.io/github/license/cykler01/cykler-caelestia?style=flat-square&labelColor=101418&color=9ccbfb)

</div>

> [!WARNING]
> **Built for our machines first.** These features are not guaranteed to work reliably everywhere.
> The fork tracks an AMD laptop with a USB DAC and our own setups, so behaviour may differ on your
> system. Use at your own risk, and please open an [issue](https://github.com/cykler01/cykler-caelestia/issues)
> if something breaks.

## Features added in this fork

Every feature below is our own work on top of upstream, with a clip of it in action in [docs/demos.md](docs/demos.md).

| Feature | What it does | Where | Docs | Demo |
|---|---|---|---|---|
| **Battery & power management** | Automatic Hyprland power saving (animations, blur, gaps, shadows, refresh rate) per plug state and power profile, battery level thresholds, critical battery shell shutdown, and a battery pane in Settings | *Nexus → Power & battery* | [docs](docs/battery.md) | [▶](https://cykler.dev/caelestia/demos/battery.mp4) |
| **Keep awake** | One tri-state control for the idle inhibitor: off, prevent sleep, or also prevent lock | *Utilities card* | [docs](docs/idle.md) | [▶](https://cykler.dev/caelestia/demos/idle.mp4) |
| **Game mode mouse acceleration** | Game mode sets `input:accel_profile: flat`, and no longer false-triggers when power saving disables animations | Automatic | [docs](docs/input.md) | [▶](https://cykler.dev/caelestia/demos/game-mode.mp4) |
| **Input settings** | Mouse sensitivity, scroll speed, touchpad scroll speed and acceleration, applied at runtime and put back after a Hyprland reload | *Nexus → Input* | [docs](docs/input.md) | [▶](https://cykler.dev/caelestia/demos/input.mp4) |
| **Unified media tab** | One tab that drives whatever is playing, and follows your audio between external MPRIS players and the built-in local player, with a hand-picked player pinned so nothing else takes over | *Dashboard → Media* | [docs](docs/media.md) | [▶](https://cykler.dev/caelestia/demos/media-player.mp4) |
| **Local music player & library** | Plays `paths.musicDir` in-shell with a queue, shuffle and repeat, and browses the library by folder, artist, album or search | *Notif popout → Library* | [docs](docs/media.md) | [▶](https://cykler.dev/caelestia/demos/music-library.mp4) |
| **System-wide equalizer** | Opt-in ten-band PipeWire filter chain with presets, equalizing every stream rather than just the player | *Settings → Audio* | [docs](docs/equalizer.md) | [▶](https://cykler.dev/caelestia/demos/equalizer.mp4) |
| **Notch** | A pill that drops down on track change with album art, controls and a mirrored spectrum, plus a standing notch that shows the clock and what is playing while the bar's middle is free (the bar then drops its own clock) | *Nexus → Panels → Notch* | [docs](docs/notch.md) | [▶](https://cykler.dev/caelestia/demos/notch.mp4) |
| **Notification popout** | A gesture-driven panel on its own blurrier layer with a notification dock and the music library, plus IPC | 4-finger swipe left | [docs](docs/notification-popout.md) | [▶](https://cykler.dev/caelestia/demos/notification-popout.mp4) |
| **Notification dock improvements** | Chat apps keep every message instead of only the newest, and grouped notifications show each message's own picture | *Sidebar* | [docs](docs/notifications.md) | [▶](https://cykler.dev/caelestia/demos/notifications.mp4) |
| **Popups and toasts in any corner** | Notification popups and toasts each go in any of the four corners, and share a column when they pick the same one | *Nexus → Layout* | [docs](docs/notifications.md) | [▶](https://cykler.dev/caelestia/demos/corners.mp4) |
| **Window overview** | Every workspace and window in one blurred grid: click to jump, drag windows and whole workspaces, keyboard and page navigation | 4-finger swipe up / hot corner | [docs](docs/overview.md) | [▶](https://cykler.dev/caelestia/demos/overview.mp4) |
| **Special workspaces switch** | Turning special workspaces off makes the shell close them and move their windows to the current workspace, whatever opened them | *Settings → Workspaces* | [docs](docs/special-workspaces.md) | [▶](https://cykler.dev/caelestia/demos/special-workspaces.mp4) |
| **Keybinds page** | Lists every `kb*` bind from the Hyprland Lua config, grouped and searchable, and writes your changes back and reloads | *Nexus → Keybinds* | [docs](docs/keybinds.md) | [▶](https://cykler.dev/caelestia/demos/keybinds.mp4) |
| **OCR & Google Lens** | Select a screen region to copy the text in it with `tesseract`, or upload it and open it in Google Lens | Launcher `>ocr` / `>lens` | [docs](docs/launcher.md) | [▶](https://cykler.dev/caelestia/demos/launcher-ocr-lens.mp4) |
| **To-do list** | A `>todo` list in the launcher, ported from the fuzzel script, importing the old cache once | Launcher `>todo` | [docs](docs/launcher.md) | [▶](https://cykler.dev/caelestia/demos/launcher-todo.mp4) |
| **SSH hosts** | Lists the non-wildcard hosts from `~/.ssh/config` and connects to one in your terminal | Launcher `>ssh` | [docs](docs/launcher.md) | [▶](https://cykler.dev/caelestia/demos/launcher-ssh.mp4) |
| **GPU modes** | Switches `supergfxctl` graphics modes and offers to restart or log out for them to take effect | Launcher `>gpu` | [docs](docs/launcher.md) | [▶](https://cykler.dev/caelestia/demos/launcher-gpu.mp4) |
| **Wallpaper arrow keys** | The horizontal wallpaper list steps with left/right arrows, matching up/down and the scroll wheel | Launcher `>wallpaper` | [docs](docs/launcher.md) | [▶](https://cykler.dev/caelestia/demos/launcher-wallpaper.mp4) |
| **Screenshot preview** | Screenshots go straight to the clipboard and show a framed thumbnail instead of a notification; click it to annotate, save to `~/Desktop`, or let it clear | After a capture | [docs](docs/screenshot.md) | [▶](https://cykler.dev/caelestia/demos/screenshot.mp4) |
| **Shell assets page** | Changes the images the shell uses - logo, session and media gifs, placeholder images and the profile picture - from Settings | *Nexus → Shell assets* | [docs](docs/shell-assets.md) | [▶](https://cykler.dev/caelestia/demos/shell-assets.mp4) |
| **Colour schemes in Settings** | Scheme, flavour and Material 3 variant pickers moved out of the launcher into the settings app | *Nexus → Wallpaper & style* | [docs](docs/nexus.md) | [▶](https://cykler.dev/caelestia/demos/settings-app.mp4) |
| **Displays page** | Arranges monitors by drag and drop, sets resolution, refresh rate, scale and mirroring, identifies a display, and reverts by itself unless you confirm | *Nexus → Displays* | [docs](docs/displays.md) | [▶](https://cykler.dev/caelestia/demos/displays.mp4) |
| **Dashboard performance graph** | CPU, GPU, memory, network and storage combined into a single card with configurable colours, and resources you switch off stay off | *Dashboard → Performance* | [docs](docs/dashboard.md) | [▶](https://cykler.dev/caelestia/demos/dashboard.mp4) |
| **Layout editor** | A miniature screen where every part of the shell is a tile you drag into place - bar, launcher, dashboard, notch, sidebar, OSD, session menu, popups, toasts and the desktop items - with separate Shell and Desktop layers | *Nexus → Layout* | [docs](docs/layout.md) | [▶](https://cykler.dev/caelestia/demos/layout.mp4) |
| **Taskbar on any edge** | The bar moves to left, right, top or bottom with its own horizontal components, cuts its middle away on an empty workspace so the wallpaper shows through, and can mirror the right-edge panels when it is on the right | *Nexus → Layout* | [docs](docs/bar.md) | [▶](https://cykler.dev/caelestia/demos/bar.mp4) |
| **Desktop widgets & app shortcuts** | Widget cards (calendar, weather, focus timer, resources, now playing, battery) in an ordered grid and application shortcuts, both on the wallpaper with their own settings page | *Nexus → Panels → Desktop* | [docs](docs/desktop.md) | [▶](https://cykler.dev/caelestia/demos/desktop.mp4) |
| **Updates page** | Checks this fork's repo for new commits and pulls, rebuilds, installs through `pkexec` and restarts the shell from inside the session | *Nexus → Updates* | [docs](docs/updates.md) | [▶](https://cykler.dev/caelestia/demos/updates.mp4) |

Smaller fixes live in [docs/nexus.md](docs/nexus.md): the dropdown menu that flips to whichever side has
room, the update notification that opens the Updates page, and the settings sidebar rework - the pages
are grouped into categories and have stable keys, so anything can open one by name.

## Installation

> [!NOTE]
> This installs the shell only. For the full Caelestia dotfiles (themes, Hyprland config, keybinds),
> see [the main dotfiles repo](https://github.com/caelestia-dots/caelestia).

> [!IMPORTANT]
> If you previously installed `caelestia-shell` or `caelestia-shell-git` from the AUR, remove it
> first - this fork provides the same package and they conflict.

```sh
git clone https://github.com/cykler01/cykler-caelestia.git
cd cykler-caelestia
./install.sh
```

`install.sh` installs the dependencies and then builds and installs the shell. Pass
`--install-deps false` if you already have the dependencies, `--repo-only` to skip AUR packages, or
`-y` to skip the prompts. Then start it with `caelestia shell -d`.

Nix users can try the upstream flake that this fork keeps:

```sh
nix run github:cykler01/cykler-caelestia#with-cli
```

Manual steps, the full dependency list, the local-package approach and the Nix caveats are all in
[docs/install.md](docs/install.md).

## Keeping up to date

```sh
./update.sh
```

It pulls this fork and rebuilds and reinstalls, and refuses to run with uncommitted changes. Pass
`--upstream` to also merge `caelestia-dots/shell`, or `-y` to skip the prompts. We try to keep the
fork merged with upstream regularly (best effort, no promises); see
[docs/updating.md](docs/updating.md) for the manual route.

Or do the same thing from inside the session: *Settings → Updates* checks the repo, shows what is
incoming, and can pull, rebuild, install and restart the shell for you. See
[docs/updates.md](docs/updates.md).

## Credits

This fork is only worth anything because of the people below.

- **[Caelestia](https://github.com/caelestia-dots/shell)** - the shell itself, by
  [@soramanew](https://github.com/soramanew) and the upstream contributors. Everything here is their
  work with our additions on top.
- **[caelestia-dots/caelestia](https://github.com/caelestia-dots/caelestia)** - the Hyprland config,
  themes and keybind variables our features integrate with, including the `hypr-vars.lua` the
  Keybinds page reads and writes.
- **This fork** - [@CYKLER01](https://github.com/CYKLER01) (Chris): battery and power management,
  game mode, input settings, OCR, Google Lens, SSH and GPU launcher actions, to-do list, screenshots,
  shell assets, wallpaper arrows, the displays page, and the local music player, library, queue and
  equalizer.
  [@imnuclr](https://github.com/imnuclr) (Charlie): install, dependency and update scripts, the
  window overview, the notification popout and notification dock work, the notch, the power and
  battery settings page, the performance graph, and the idle, keybinds and menu behaviour.
- **Battery power management** - based on the `feat/battery-power-management` branch contributed by
  [@PixelKhaos](https://github.com/PixelKhaos) (Robin Seger).
- **Displays page** - based on [PR #1629](https://github.com/caelestia-dots/shell/pull/1629) by
  [@devalentineomonya](https://github.com/devalentineomonya).
- Three commits in this repository carry lost author metadata (the first displays menu, the
  lock/display timeout work and the install flow fix). If you wrote one of them, tell us and we will
  credit you.

## License

GPL-3.0, inherited from [upstream](https://github.com/caelestia-dots/shell).
