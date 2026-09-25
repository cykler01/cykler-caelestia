# Notification popout

A separate panel on the right edge of the screen with two tabs - the notification dock and a browser
for the local music library - opened with a four-finger swipe.

[▶ Demo](https://cykler.dev/caelestia/demos/notification-popout.mp4)

- Swipe **left** to open it, swipe **left** again to move between the two tabs, and swipe **right** to
  close it whichever tab it is on.
- The tab you last looked at is remembered, so reopening it comes back to the music library if that is
  where you left it.
- The panel sits on its own blurred layer, so it looks blurrier than the rest of the shell without
  changing Hyprland's blur for any other window.
- The library tab is the one from [media.md](media.md): folders, artists, tracks, search, cover art,
  add to queue, and a transport bar wired to the local player alone.

## Gestures

There is nothing to set up. The shell registers the swipes with Hyprland itself each time it starts and
after every Hyprland config reload, which it only does when Hyprland is using its Lua config. Three
fingers are left alone for workspace swiping.

```json
"notifPopout": {
    "side": "right",
    "gestures": true,
    "gestureFingers": 4
}
```

`side` (`left` or `right`) is which edge the popout opens from, and is also settable by dragging its
tile on *Settings → Layout* ([layout.md](layout.md)). The swipe gestures are registered for the side it
is on, so a left-hand popout opens with a swipe to the right.

Set `gestures` to `false` to stop the shell registering them, for example if you already bind those
swipes yourself. They go away on the next Hyprland reload.

## Without a trackpad

```sh
qs -c caelestia ipc call notifPopout open
qs -c caelestia ipc call notifPopout close
qs -c caelestia ipc call notifPopout toggle
```

Or bind the global shortcuts:

| Shortcut | Effect |
|---|---|
| `caelestia:notifPopoutOpen` | Open the popout |
| `caelestia:notifPopoutClose` | Close it |
| `caelestia:notifPopoutOpenOrNextTab` | The one the left swipe uses: opens the popout when it is closed, moves to the other tab when it is open |
