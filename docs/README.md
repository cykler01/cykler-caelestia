# cykler-caelestia docs

Documentation for everything this fork adds on top of
[caelestia-dots/shell](https://github.com/caelestia-dots/shell). The [README](../README.md) has the
short version of each feature; these pages are the detail.

- [Feature demos](demos.md) - every feature on video, and the clip manifest
- [Install](install.md) - dependencies, building, Arch and Nix
- [Updating](updating.md) - `update.sh` and merging upstream by hand
- [Troubleshooting](troubleshooting.md) - the things that usually go wrong

## Features

### Power

- [Battery & power management](battery.md) - automatic power saving on plug and profile changes,
  battery level thresholds, refresh rate, per-profile behaviour, critical battery shutdown
- [Keep awake](idle.md) - the tri-state idle inhibitor

### Input

- [Input settings](input.md) - mouse and touchpad settings in Nexus, and game mode's flat
  acceleration

### Media

- [Media player](media.md) - the unified media tab, the in-shell player, the music library, the queue,
  and following or pinning a player
- [Equalizer](equalizer.md) - the opt-in system-wide ten-band equalizer and its PipeWire setup
- [Notch](notch.md) - the standing notch, the track-change pill and its spectrum

### Panels

- [Notification popout](notification-popout.md) - the gesture-driven panel and its library tab
- [Notifications](notifications.md) - chat history, per-message pictures, and any-corner placement

### Layout & desktop

- [Layout](layout.md) - the drag-and-drop editor for where every part of the shell sits
- [Taskbar](bar.md) - the bar on any edge, the middle cut away on an empty workspace
- [Desktop widgets & app shortcuts](desktop.md) - widget cards and shortcuts on the wallpaper

### Workspaces

- [Window overview](overview.md) - the workspace and window grid
- [Special workspaces](special-workspaces.md) - turning them off entirely, and doing it without a
  flash
- [Keybinds](keybinds.md) - editing the Hyprland Lua binds from Settings

### Launcher

- [Launcher actions](launcher.md) - OCR, Google Lens, to-do, SSH, GPU modes and the wallpaper arrows

### Capture

- [Screenshots](screenshot.md) - the clipboard-first capture and its preview

### Appearance

- [Shell assets](shell-assets.md) - changing the shell's images from Settings
- [Settings app](nexus.md) - how the settings sidebar is organised, and the smaller fixes
- [Displays](displays.md) - arranging monitors, modes and mirroring
- [Dashboard](dashboard.md) - the combined performance graph

### System

- [Updates](updates.md) - checking, pulling, rebuilding and installing from the settings app

## Where the code lives

Everything ours is marked in the source with a `NOTE(fork)` comment, so `git grep 'NOTE(fork)'` lists
the interesting parts. The short version:

| Area | Files |
|---|---|
| Power | `modules/BatteryMonitor.qml`, `services/PowerSaving.qml`, `services/ResourceHistory.qml`, `modules/nexus/pages/BatteryPage.qml` |
| Media | `services/Music.qml`, `services/Equalizer.qml`, `modules/dashboard/media/`, `plugin/src/Caelestia/Models/musictags.*` |
| Panels | `modules/notch/`, `modules/notifpopout/`, `modules/overview/` |
| Layout | `modules/nexus/pages/LayoutPage.qml`, `modules/background/Desktop*.qml`, `modules/bar/HBar.qml` |
| Settings | `modules/nexus/pages/{AssetsPage,BatteryPage,InputPage,KeybindsPage,UpdatesPage,monitors/}` |
| Launcher | `modules/launcher/services/{SSH,Supergfxctl,Todo}.qml`, `assets/{ocr,lens}.sh` |
| Scripts | `install.sh`, `install-deps.sh`, `update.sh`, `scripts/shell-update.sh` |

New config options are declared in `plugin/src/Caelestia/Config/` (`overviewconfig.hpp`,
`notifpopoutconfig.hpp`, `notchconfig.hpp`, `backgroundconfig.hpp` and the fork additions inside
`generalconfig.hpp`, `barconfig.hpp`, `dashboardconfig.hpp`, `notifsconfig.hpp`, `osdconfig.hpp`,
`serviceconfig.hpp`, `sessionconfig.hpp`, `sidebarconfig.hpp`, `utilitiesconfig.hpp`,
`userpaths.hpp`).

Settings live in `~/.config/caelestia/shell.json` as usual, with per-monitor overrides in
`~/.config/caelestia/monitors/<monitor>/shell.json`.
