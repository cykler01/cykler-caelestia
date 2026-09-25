# Input settings & game mode

[▶ Demo: input settings](https://cykler.dev/caelestia/demos/input.mp4) ·
[▶ Demo: game mode](https://cykler.dev/caelestia/demos/game-mode.mp4)

## Input settings

*Nexus → Input* (under *Shell*) has sliders for mouse sensitivity and scroll speed, and for touchpad
scroll speed, plus a toggle for mouse acceleration.

| Control | Hyprland option |
|---|---|
| Mouse sensitivity | `input:sensitivity` |
| Mouse acceleration | `input:accel_profile` |
| Mouse scroll speed | `input:scroll_factor` |
| Touchpad scroll speed | `input:touchpad:scroll_factor` |

These are runtime keywords, which a config reload would otherwise drop. The shell therefore remembers
every option you change here and puts it back when Hyprland reloads or when the shell starts. Options
you have never touched are left alone, so your own `hyprland.conf` still wins for everything the page
does not manage.

Values are applied once a slider settles rather than on every mouse move, since applying them makes
the shell re-read every Hyprland option.

## Game mode mouse acceleration

Turning game mode on also sets `input:accel_profile: flat` - mouse acceleration off, which is what you
want while gaming - and restores the previous profile when game mode is turned off.

Game mode's state is deliberately *not* derived from whether Hyprland has animations disabled any
more. The [battery monitor](battery.md) may disable animations for power saving, and that used to make
the shell think game mode was on.
