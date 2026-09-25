# Battery & power management

A battery pane in the settings app and a background service that makes the shell save power when it
should, without you having to change any Hyprland options by hand.

[▶ Demo](https://cykler.dev/caelestia/demos/battery.mp4)

*Nexus → Power & battery*, under *Shell*.

## The page

- **Power status card** - charge level, charge state, power draw, and the power profile switcher.
- **Automatic power management** - the master switch for everything below. It is **off by default**,
  so updating the shell never changes how your machine behaves on its own.
- **Notify when settings change** - toasts describing what was applied after each automatic change.
- **Power Saver** - what to pause while the Power Saver profile is active:
  - *Pause the performance graph* stops the background usage recording and the dashboard falls back to
    its separate cards ([dashboard.md](dashboard.md)).
  - *Pause audio visualisers* stops audio capture for the notch, dashboard and wallpaper visualisers.
- **When plugged in** / **On battery** - the actions to apply per plug state.
- **Battery level thresholds** - actions to apply automatically as the battery drains while on
  battery power.
- **Profile behaviours** - actions to apply whenever a profile is switched to, whether by you or by
  something outside the shell (the bar's battery popout, for instance), in three tabs: Power Saver,
  Balanced and Performance.
- **Critical battery shutdown** - warning at a level, then the shell unloads itself after a countdown
  so what is left of the battery goes to the session.
- **Screen & lock** - the lock, display-off and sleep idle timeouts, and the session controls toggle
  for the lock screen.

## What can be applied

Each of the plug states, thresholds and profile behaviours can set any of:

| Option | Values |
|---|---|
| Power profile | *Unchanged*, *Power Saver*, *Balanced*, *Performance*, or *Previous* / *Restore* on the plug states |
| Refresh rate | *Unchanged*, *Restore*, *Auto* (the lowest rate the display offers) or a specific rate |
| Animations, blur, rounding, shadows | *Leave alone*, *Enable* or *Disable* |

Decisions are sorted from the most severe setting down, so a threshold lower than the battery level
does not override the one that actually applies, and the plug-state and threshold settings take
priority over the profile behaviours. Anything set to *Restore* goes back to what it was before the
shell changed it, which is what makes unplugging and plugging back in non-destructive.

Settings are applied when the battery state is first known, not only on the next plug or unplug, so
they hold after a shell restart.

## Low battery warnings

`general.battery.warnLevels` in `shell.json` is the list of warnings (default 20%, 10% and 5%), each
with a title, message, icon and optionally `critical: true`, and `general.battery.criticalLevel`
(default 3%) is the level at which the shell treats the battery as critical.

## Critical battery shutdown

At a critical level the shell can unload itself, so what is left of the battery goes to the session
rather than to the shell's animations and polling. It warns first, then shuts the shell down after a
countdown, and it is enabled by default:

```json
"general": {
    "battery": {
        "powerManagement": {
            "shellShutdown": {
                "enabled": true,
                "level": 5,
                "delay": 60
            }
        }
    }
}
```

`level` is the battery percentage the countdown starts at while unplugged, and `delay` is the seconds
between the warning and the shell being unloaded. Plugging in cancels it.

## Config

```json
"general": {
    "battery": {
        "powerManagement": {
            "enabled": false,
            "pauseGraphInPowerSaver": true,
            "pauseVisualisersInPowerSaver": true,
            "thresholds": [
                { "level": 20, "setPowerProfile": "power-saver", "disableAnimations": "disable" }
            ],
            "onCharging": {
                "setPowerProfile": "restore",
                "setRefreshRate": "restore"
            },
            "onUnplugged": {
                "setPowerProfile": "power-saver",
                "setRefreshRate": "auto",
                "disableBlur": "disable",
                "evaluateThresholds": true
            },
            "profileBehaviors": {
                "powerSaver": { "setRefreshRate": "auto" },
                "balanced": {},
                "performance": { "setRefreshRate": "restore" }
            }
        }
    }
}
```

Effect options (`disableAnimations`, `disableBlur`, `disableRounding`, `disableShadows`) take
`""` to leave the option alone, `"disable"` or `"enable"`. Profiles take `""`, `"power-saver"`,
`"balanced"`, `"performance"` or `"restore"`, and `setRefreshRate` also takes `"auto"` or a number.

The lock, display and sleep timeouts are `general.idle.timeouts`, and the lock screen's session
controls are `lock.enableSessionControls`.

## Notes

- The visual effect options are changed as Hyprland runtime keywords, so the shell re-applies them
  after a Hyprland reload or a shell restart. A config reload on its own drops them, which is why the
  shell keeps its own copy.
- Work on this builds on the `feat/battery-power-management` branch from
  [@PixelKhaos](https://github.com/PixelKhaos) - see the credits in the [README](../README.md).
