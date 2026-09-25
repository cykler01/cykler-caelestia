# Window overview

A full-screen overview of every workspace and the windows on it, so you can see everything at a glance
and jump straight to it.

[▶ Demo](https://cykler.dev/caelestia/demos/overview.mp4)

Workspaces are shown ten to a page in a centred 2x5 grid. Each tile takes the shape of your monitor
(its usable area, so the bar's space is not counted) and every window is drawn at the position and
size Hyprland gives it, scaled to fit, with the app's own icon over the middle of it. A workspace on a
differently shaped monitor is letterboxed rather than stretched. Occupied workspaces are brighter than
empty ones, all of them are outlined, and the focused one is outlined in the accent colour. Clicking a
window focuses it and closes the overview; clicking anywhere else on a tile switches to that
workspace. It slides up from the bottom of the screen when it opens.

## Opening it

- **Four-finger swipe up** on the trackpad (swipe down closes it). Registered with Hyprland by the
  shell, the same as the notification popout swipes, so there is nothing to set up.
- **Top-left hot corner** - move the pointer into the top-left corner of the screen and hold it there
  briefly. The bar's logo sits below the corner, so this does not get in its way.

Without a trackpad, bind a key to the `caelestia:overview` global shortcut (it toggles the overview):

```lua
hl.bind("SUPER + Up", hl.dsp.global("caelestia:overview"))
```

It can also be driven with:

```sh
qs -c caelestia ipc call overview open
qs -c caelestia ipc call overview close
qs -c caelestia ipc call overview toggle
```

Or by binding `caelestia:overviewOpen` / `caelestia:overviewClose`.

## Using it

- **Arrow keys** move the highlight between workspaces (a second outline, apart from the focused one)
  and carry on into the next or previous page at the edges; **Enter** or **Space** jumps to the
  highlighted workspace. The pointer moves the highlight too.
- **Home** / **End** go to the first or last tile of the page, and **Page Up** / **Page Down** - or the
  mouse wheel, the arrow buttons either side of the grid, or the dots under it - change page.
- With the overview open, a four-finger swipe **left** / **right** turns the page (instead of driving
  the notification popout) and swiping **down** closes it.
- The background is blurred rather than just dimmed, and where blur has been switched off (battery
  saving, game mode) it is dimmed instead.
- **Drag a whole workspace** by the number in its top-left corner onto another tile to trade their
  contents. The previews refresh while the overview is open, so moves and swaps show up.
- **Drag a window** (you carry its app icon) onto another tile to move it to that workspace, or onto
  another window of the same workspace to trade places with it. Hold it out past either side of the
  grid to turn the page. A plain click still focuses the window.
- `1`-`9` and `0` jump to that tile on the current page, and **Esc** closes it.

## Pages

Pages cover every workspace in groups of ten (1-10, 11-20 and so on, matching the workspace groups the
keybinds use) out to the last group with a window on it or the focused one, plus one empty group so a
fresh one is always reachable.

With *Only workspaces in use* switched on, the overview lists just the workspaces that have windows,
the focused one and the first free number instead. It is still shown ten to a page, and the number
keys then pick the n-th tile on the page.

## Config

*Settings → Panels → Overview*, or `shell.json`:

```json
"overview": {
    "enabled": true,
    "gestures": true,
    "gestureFingers": 4,
    "hotCorner": true,
    "hotCornerSize": 10,
    "onlyInUse": false
}
```

`gestures` off stops the shell registering the swipes (they go away on the next Hyprland reload), for
example if you already bind those swipes yourself. `hotCorner` off turns the corner off, and
`hotCornerSize` is the corner's size in pixels.
