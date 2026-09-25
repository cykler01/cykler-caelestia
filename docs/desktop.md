# Desktop widgets & app shortcuts

Widget cards and application shortcuts that sit on the wallpaper, underneath everything else. Both are
off by default and configured from *Settings → Panels → Desktop*.

[▶ Demo](https://cykler.dev/caelestia/demos/desktop.mp4)

## Widget cards

```json
"background": {
    "desktopWidgets": {
        "enabled": false,
        "position": "top-right",
        "columns": 2,
        "entries": [
            { "id": "calendar", "enable": true },
            { "id": "weather", "enable": true },
            { "id": "pomodoro", "enable": true },
            { "id": "resources", "enable": true },
            { "id": "media", "enable": true },
            { "id": "battery", "enable": true }
        ],
        "hideWithWindows": true,
        "opacity": 0.7,
        "blur": true
    }
}
```

| Option | What it does |
|---|---|
| `position` | Which corner of the wallpaper they sit in: `top-left`, `top-right`, `bottom-left` or `bottom-right` |
| `columns` | How many columns the grid uses; rows stretch to an even height |
| `entries` | Which widgets show, and in what order - drag to reorder on the settings page |
| `hideWithWindows` | Fade out while the active workspace has windows on it |
| `opacity`, `blur` | How opaque the card backgrounds are, and whether the wallpaper is blurred behind them |

Widgets available: **Calendar**, **Weather**, **Focus timer**, **System resources**, **Now playing**
and **Battery**.

The focus timer is a pomodoro-style countdown (25 minutes by default) that can be started, paused and
reset, and its countdown keeps running while the card is unloaded - so hiding the widgets when windows
open does not stop it.

## App shortcuts

```json
"background": {
    "desktopIcons": {
        "enabled": false,
        "apps": [],
        "position": "top-left",
        "iconSize": 48,
        "showLabels": true,
        "hideWithWindows": true
    }
}
```

`apps` is a list of desktop entry ids (`firefox`, `org.kde.dolphin`, ...) shown in order, with add,
remove and drag-to-reorder on the settings page. `iconSize` is in pixels, and `showLabels` switches the
app names under the icons.

## Related

- [layout.md](layout.md) - moving the widgets and icons to another corner by dragging
- The desktop clock that shares the wallpaper is an upstream feature (`background.desktopClock`).
