# Layout

*Nexus → Layout* is a miniature screen showing where every part of the shell sits. Drag a tile to move
it: it snaps to the places that element supports and the change applies straight away.

[▶ Demo](https://cykler.dev/caelestia/demos/layout.mp4)

## Tiles

| Tile | What it moves | Options written |
|---|---|---|
| Taskbar | The bar to any edge | `bar.position` |
| Launcher | Which edge it hangs from, and where along it | `launcher.edge`, `launcher.align` |
| Dashboard | Same | `dashboard.edge`, `dashboard.align` |
| Notch | Where along the top it sits | `notch.align` |
| Volume & brightness | Side it opens from | `osd.side` |
| Session menu | Side it opens from | `session.side` |
| Sidebar & utilities | Side they open from (they share one) | `sidebar.side` |
| Notification popups | Any of the four corners | `notifs.side`, `notifs.edge` |
| Toasts | Any of the four corners | `utilities.toasts.side`, `utilities.toasts.edge` |
| Notification popout | Side it opens from | `notifPopout.side` |
| Desktop widgets | Corner of the wallpaper | `background.desktopWidgets.position` |
| Desktop icons | Corner of the wallpaper | `background.desktopIcons.position` |

`bar.position` takes `left`, `right`, `top` or `bottom`; the panel edges take `top` or `bottom`, the
alignments take `start`, `center` or `end`, and the sides take `left` or `right`.

## Two layers

The editor separates **Shell** and **Desktop**, so the desktop widgets and app icons - which live on
the wallpaper, underneath everything else - never overlap the panel tiles while you are dragging. The
desktop layer says so when you switch to it, and the tile drags there are corners rather than edges.

The page scroll does not steal a tile drag, so dragging near the edge of the page moves the tile rather
than scrolling the page, and the notch tile is drawn in front of the others so it stays grabbable.

**Reset layout** puts everything back to the defaults.

## Notes

- Notification popups and toasts each go in any corner, and when they pick the same one they share a
  column instead of stacking on top of each other - see [notifications.md](notifications.md).
- The sidebar and utilities always share a side, and with the bar on the right you can mirror the
  right-edge panels to the left instead - see [bar.md](bar.md).
