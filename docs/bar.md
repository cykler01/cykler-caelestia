# Taskbar

The bar is no longer fixed to the top: it goes on any screen edge, in a vertical or horizontal
layout, and it can cut its own middle away to let the wallpaper through.

[▶ Demo](https://cykler.dev/caelestia/demos/bar.mp4)

## Moving it

*Nexus → Layout* moves it by dragging ([layout.md](layout.md)), or set it directly:

```json
"bar": {
    "position": "left"
}
```

`position` takes `left`, `right`, `top` or `bottom`. A horizontal bar gets its own components - a
horizontal workspaces strip with window icons, a horizontal clock, status icons and a tray with a
compact hidden menu - rather than the vertical ones being rotated, so it stays readable whichever edge
it is on.

Each screen edge is also inset correctly as the bar moves, so the panels and popouts that live inside
the frame (dashboard, launcher, sidebar, OSD) follow it instead of assuming the bar is at the top.

With the bar on the right, the panels that normally sit on the right edge would be sitting under it, so
`bar.mirrorPanels` (off by default) opens them on the left instead. It is off because it changes where
you expect to find the OSD, sidebar, session menu and notification popout - switch it on if you move
the bar to the right edge and want them out of its way.

## The middle cut away

```json
"bar": {
    "hideMiddleOnDesktop": true
}
```

On an empty workspace, the stretch of the bar between its first and last spacer is dropped so the
wallpaper shows through and the two ends stay as capsules. It comes back as soon as there are windows,
and the bar's clock yields to the notch's clock while the notch is standing.

## Default content

The default bar entries are logo, workspaces, spacer, tray, clock, status icons and power. The active
window entry is no longer part of the default set - add it back from *Settings → Panels → Taskbar* if
you want it.

## Related

- [layout.md](layout.md) - moving the bar, panels, popups and toasts by dragging
- [overview.md](overview.md), [notch.md](notch.md) - the panels that follow the bar's edge
