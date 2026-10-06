<h1 align=center>cykler-caelestia</h1>

<div align=center>

A personal fork of [caelestia-dots/shell](https://github.com/caelestia-dots/shell) with the features we wanted on top of it.

https://github.com/user-attachments/assets/35d5068b-dca0-414d-b933-bd5a9d548262

![GitHub last commit](https://img.shields.io/github/last-commit/cykler01/cykler-caelestia?style=flat-square&labelColor=101418&color=9ccbfb)
![GitHub issues](https://img.shields.io/github/issues/cykler01/cykler-caelestia?style=flat-square&labelColor=101418&color=9ccbfb)
![GitHub license](https://img.shields.io/github/license/cykler01/cykler-caelestia?style=flat-square&labelColor=101418&color=9ccbfb)

</div>

> [!WARNING]
> **Built for our machines first.** These features are not guaranteed to work reliably everywhere.
> The fork tracks our own setups, so behaviour may differ on your
> system. Use at your own risk, and please open an [issue](https://github.com/cykler01/cykler-caelestia/issues)
> if something breaks.

## Features added in this fork

Every feature below is our own work on top of upstream.

| Feature | What it does | Where | Docs |
|---|---|---|---|
| **Battery & power management** | Automatic Hyprland power saving (animations, blur, gaps, shadows, refresh rate) per plug state and power profile, battery level thresholds, critical battery shell shutdown, and a battery pane in Settings | *Nexus → Power & battery* | [▶](https://cykler.dev/caelestia/demos/battery) |
| **Keep awake** | One tri-state control for the idle inhibitor: off, prevent sleep, or also prevent lock | *Utilities card* | [▶](https://cykler.dev/caelestia/demos/idle) |
| **Input settings** | Mouse sensitivity, scroll speed, touchpad scroll speed and acceleration, applied at runtime and put back after a Hyprland reload | *Nexus → Input* | [▶](https://cykler.dev/caelestia/demos/input) |
| **Unified media tab** | One tab that drives whatever is playing, and follows your audio between external MPRIS players and the built-in local player, with a hand-picked player pinned so nothing else takes over | *Dashboard → Media* |  [▶](https://cykler.dev/caelestia/demos/media-player) |
| **Local music player & library** | Plays `paths.musicDir` in-shell with a queue, shuffle and repeat, and browses the library by folder, artist, album or search | *Notif popout → Library* | [▶](https://cykler.dev/caelestia/demos/music-library) |
| **System-wide equalizer** | Opt-in ten-band PipeWire filter chain with presets, equalizing every stream rather than just the player | *Settings → Audio* | [▶](https://cykler.dev/caelestia/demos/equalizer) |
| **Notch** | A pill that drops down on track change with album art, controls and a mirrored spectrum, plus a standing notch that shows the clock and what is playing while the bar's middle is free (the bar then drops its own clock) | *Nexus → Panels → Notch* | [▶](https://cykler.dev/caelestia/demos/notch) |
| **Notification popout** | A gesture-driven panel on its own blurrier layer with a notification dock and the music library, plus IPC | 4-finger swipe left | [▶](https://cykler.dev/caelestia/demos/notification-popout) |
| **Notification dock improvements** | Chat apps keep every message instead of only the newest, and grouped notifications show each message's own picture | *Sidebar* | [▶](https://cykler.dev/caelestia/demos/notifications) |
| **Popups and toasts in any corner** | Notification popups and toasts each go in any of the four corners, and share a column when they pick the same one | *Nexus → Layout* | [▶](https://cykler.dev/caelestia/demos/corners) |
| **Window overview** | Every workspace and window in one blurred grid: click to jump, drag windows and whole workspaces, keyboard and page navigation | 4-finger swipe up / hot corner | [▶](https://cykler.dev/caelestia/demos/overview) |
| **Configurable hot corners** | Gives each of the four screen corners its own action. | *Nexus → Panels → Hot corners* | [▶](https://cykler.dev/caelestia/demos/hot-corners) |
| **Special workspaces switch** | Turning special workspaces off makes the shell close them and move their windows to the current workspace, whatever opened them | *Settings → Workspaces* | [▶](https://cykler.dev/caelestia/demos/special-workspaces) |
| **Keybinds page** | Lists every `kb*` bind from the Hyprland Lua config, grouped and searchable, and writes your changes back and reloads | *Nexus → Keybinds* | [▶](https://cykler.dev/caelestia/demos/keybinds) |
| **OCR & Google Lens** | Select a screen region to copy the text in it with `tesseract`, or upload it and open it in Google Lens | Launcher `>ocr` / `>lens` | [▶](https://cykler.dev/caelestia/demos/launcher-ocr-lens) |
| **To-do list** | A popout with multiple lists, deadlines and reminders, wrapping task text and inline editing; `>todo` in the launcher still quick-adds and completes tasks | Launcher `>todo` / *popout* | [▶](https://cykler.dev/caelestia/demos/launcher-todo) |
| **SSH hosts** | Lists the non-wildcard hosts from `~/.ssh/config` and connects to one in your terminal | Launcher `>ssh` | [▶](https://cykler.dev/caelestia/demos/launcher-ssh) |
| **GPU modes** | Switches `supergfxctl` graphics modes and offers to restart or log out for them to take effect | Launcher `>gpu` | [▶](https://cykler.dev/caelestia/demos/launcher-gpu) |
| **Screenshot preview** | Screenshots go straight to the clipboard and show a framed thumbnail instead of a notification; click it to annotate, save to `~/Desktop`, or let it clear | After a capture | [▶](https://cykler.dev/caelestia/demos/screenshot) |
| **Shell assets page** | Changes the images the shell uses - logo, session and media gifs, placeholder images and the profile picture - from Settings | *Nexus → Shell assets* | [▶](https://cykler.dev/caelestia/demos/shell-assets) |
| **Colour schemes in Settings** | Scheme, flavour and Material 3 variant pickers moved out of the launcher into the settings app | *Nexus → Wallpaper & style* | [▶](https://cykler.dev/caelestia/demos/settings-app) |
| **Displays page** | Arranges monitors by drag and drop, sets resolution, refresh rate, scale and mirroring, identifies a display, and reverts by itself unless you confirm | *Nexus → Displays* | [▶](https://cykler.dev/caelestia/demos/displays) |
| **Dashboard performance graph** | CPU, GPU, memory, network and storage combined into a single card with configurable colours, and resources you switch off stay off | *Dashboard → Performance* | [▶](https://cykler.dev/caelestia/demos/dashboard) |
| **Layout editor** | A miniature screen where every part of the shell is a tile you drag into place - bar, launcher, dashboard, notch, sidebar, OSD, session menu, popups, toasts and the desktop items - with separate Shell and Desktop layers | *Nexus → Layout*  | [▶](https://cykler.dev/caelestia/demos/layout) |
| **Taskbar on any edge** | The bar moves to left, right, top or bottom with its own horizontal components, cuts its middle away on an empty workspace so the wallpaper shows through, and can mirror the right-edge panels when it is on the right | *Nexus → Layout*  | [▶](https://cykler.dev/caelestia/demos/bar) |
| **Desktop widgets & app shortcuts** | Widget cards (calendar, weather, focus timer, resources, now playing, battery) in an ordered grid and application shortcuts, both on the wallpaper with their own settings page | *Nexus → Panels → Desktop* | [▶](https://cykler.dev/caelestia/demos/desktop) |
| **Updates page** | Checks this fork's repo for new commits and pulls, rebuilds, installs through `pkexec` and restarts the shell from inside the session | *Nexus → Updates* | [▶](https://cykler.dev/caelestia/demos/updates) |
| **Phone integration** | Pairs with an Android phone over KDE Connect: drop files on a device to send them, browse and download its storage, and mirror its screen with `scrcpy` | *Utilities card* | [▶](https://cykler.dev/caelestia/demos/phone-integration) |

Smaller fixes: The dropdown menu that flips to whichever side has
room, the update notification that opens the Updates page, and the settings sidebar rework - the pages
are grouped into categories and have stable keys, so anything can open one by name, mouse acceleration during game mode.

## Installation

> [!NOTE]
> This installs the shell only. For the full Caelestia dotfiles (themes, Hyprland config, keybinds),
> see [the main dotfiles repo](https://github.com/caelestia-dots/caelestia).

Optional dependencies:

-   [`kdeconnect`](https://invent.kde.org/network/kdeconnect-kde) - for the phone share card, which needs a
    systemd user session because the shell runs `kdeconnectd` as its own `caelestia-kdeconnect` unit
-   [`sshfs`](https://github.com/libfuse/sshfs) - for browsing and downloading files from a phone in the
    phone share card. This is KDE Connect's own optional dependency, since its SFTP plugin mounts the phone
-   [`adb`](https://developer.android.com/tools/adb) - for screen mirroring in the phone share card
-   [`scrcpy`](https://github.com/Genymobile/scrcpy) 4.0 or newer - for screen mirroring in the phone share card
-   [`qrencode`](https://fukuchi.org/works/qrencode/) - for the QR code shown when pairing a phone for
    wireless mirroring. Without it the pairing code is shown as text instead

The phone share card is off by default - turn it on under **Cards** in *Nexus → Panels → Utilities*, which
loads KDE Connect and starts its daemon with it.

> [!IMPORTANT]
> If you previously installed `caelestia-shell` or `caelestia-shell-git` from the AUR, remove it
> first - this fork provides the same package and they conflict.

```sh
curl -fsSL https://raw.githubusercontent.com/cykler01/cykler-caelestia/main/bootstrap.sh | bash
```

That clones the repo into `./cykler-caelestia` and hands off to `install.sh`, which installs the
dependencies and then builds and installs the shell. Pass flags through after `--`, e.g.
`| bash -s -- -y`. Or do the same two steps by hand:

```sh
git clone https://github.com/cykler01/cykler-caelestia.git
cd cykler-caelestia
./install.sh
```

`install.sh` takes `--install-deps false` if you already have the dependencies, `--repo-only` to
skip AUR packages, or `-y` to skip the prompts. Then start it with `caelestia shell -d`.

Nix users can try the upstream flake that this fork keeps (although we havent tested it ourselves):

```sh
nix run github:cykler01/cykler-caelestia#with-cli
```

## Keeping up to date

```sh
./update.sh
```

It pulls this fork and rebuilds and reinstalls, and refuses to run with uncommitted changes. Pass
`--upstream` to also merge `caelestia-dots/shell`, or `-y` to skip the prompts. We try to keep the
fork merged with upstream regularly (best effort, no promises);

Or do the same thing from inside the session: *Settings → Updates* checks the repo, shows what is
incoming, and can pull, rebuild, install and restart the shell for you.

## Credits

This fork is only worth anything because of the people below.

- **[Caelestia](https://github.com/caelestia-dots/shell)** - the shell itself, by
  [@soramanew](https://github.com/soramanew) and the upstream contributors. Everything here is their
  work with our additions on top.
- **Battery power management** - based on the `feat/battery-power-management` branch contributed by
  [@PixelKhaos](https://github.com/PixelKhaos).
- **Displays page** - based on [PR #1629](https://github.com/caelestia-dots/shell/pull/1629) by
  [@devalentineomonya](https://github.com/devalentineomonya).
- **KDE-Connect card** - based on [PR #4](https://github.com/cykler01/cykler-caelestia/pull/4) by
  [@Mestane](https://github.com/Mestane).

## License

GPL-3.0, inherited from [upstream](https://github.com/caelestia-dots/shell).
