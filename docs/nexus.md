# Settings app changes

The pages we added have their own docs - [Power & battery](battery.md), [Input](input.md),
[Keybinds](keybinds.md), [Shell assets](shell-assets.md), [Displays](displays.md) and the
[Panels](overview.md) settings for the overview and [notch](notch.md). This page covers the changes to
the settings app itself.

[▶ Demo](https://cykler.dev/caelestia/demos/settings-app.mp4)

## Colour schemes and variants moved into Settings

The scheme, flavour and Material 3 variant pickers used to live in the launcher (`>scheme`,
`>variant` and the items they listed). They are now part of *Wallpaper & style*, so the same options
are reachable from the settings app, with each scheme showing its surface and primary colours as a
preview.

- The data moved to `services/Schemes.qml`, which the settings page and the launcher both read; the
  current scheme, flavour and variant are still tracked by `Colours`, which watches the generated
  scheme file.
- The launcher's `SchemeItem`, `VariantItem`, `Schemes` and `M3Variants` files are gone.

## Navigation

- The sidebar is grouped into categories - *Look & feel*, *The shell itself: what it shows and where*,
  *Connections*, *Hardware*, *System* and *About* - so related pages sit together.
- Every page has a **key** as well as a position, and anything that wants to open a page asks for it by
  key. That is what lets the update toast jump straight to *Settings → Updates* instead of relying on
  where the page happens to sit in the list.
- The nav items curve and space themselves around the page you are on, rather than sitting as a flat
  list, so the current page is obvious without reading the labels.
- The *Panels* page is split into *Bar & panels* (Taskbar, Dashboard, Launcher, Notch, Sidebar,
  Utilities, Overview) and *Wallpaper* (Desktop), instead of one long list.

## New pages

| Page | Where | What it is for |
|---|---|---|
| **Layout** | *Shell* | Moving the bar, panels, popups, toasts and desktop items by dragging - [layout.md](layout.md) |
| **Desktop** | *Panels → Wallpaper* | Widget cards and app shortcuts on the wallpaper - [desktop.md](desktop.md) |
| **Updates** | *System* | Checking, pulling, rebuilding and installing this shell's repo - [updates.md](updates.md) |

## Update notification

`services/UpdateChecker.qml` asks GitHub for the newest commit on `cykler01/cykler-caelestia` and raises
a toast once when a commit appears that was not there on the previous check. It is **off by default**:

```json
"utilities": {
    "toasts": {
        "repoUpdateAvailable": true
    }
}
```

## Lock screen and idle

- **Session controls on the lock screen** (`lock.enableSessionControls`) - show the power, reboot and
  logout buttons while locked. Also on the [Power & battery](battery.md) page.
- **Lock, display-off and sleep timeouts** - edited from the [Power & battery](battery.md) page, which
  writes them back into `general.idle.timeouts` in the shape the idle service already expected.

## Smaller fixes

- **Dropdown menus flip** to whichever side of the screen has room, instead of being clipped when
  there is no space below or to the right.
- **The power and battery page** was reworked after its first pass: stray and missing rounding fixed,
  redundant rows removed, and the leftover `ProfileBehaviorCard` component deleted.
- **The bar's tray area** no longer overlaps its neighbours, and the launcher services were cleaned up
  to pass the linting rules (`onExited` signatures, property types and import order).
