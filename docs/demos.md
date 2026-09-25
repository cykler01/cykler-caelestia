# Feature demos

Video walkthroughs of everything this fork adds. **The clips are not uploaded yet** - this page is the
manifest for making them, and every link in the [README](../README.md) and these docs points at where
a clip will be.

## Where the clips live

| | |
|---|---|
| Base URL | `https://cykler.dev/caelestia/` |
| Showcase | `https://cykler.dev/caelestia/showcase.mp4` |
| Per-feature clips | `https://cykler.dev/caelestia/demos/<slug>.mp4` |

The README links the showcase, and each feature page and README table row links its own clip. If the
base URL ever changes, it appears verbatim in `README.md` and `docs/*.md`, so a single find and
replace across those files is enough.

## Recording

One clip per feature section, so keep each one short and to the point - 15 to 40 seconds is plenty,
and a clip should show the thing working rather than explain it. Suggested setup:

- Record at your normal resolution and scale, 60 fps if the machine can, and trim the dead time at
  both ends.
- Start each clip with the feature already reachable (the panel open, the launcher showing), and do
  the action once rather than several times.
- No audio needed, and no narration: the caption in the docs says what is being shown.
- If the feature changes the screen a lot (overview, notch, popout), a short second take showing the
  closed state first is worth it.

`wf-recorder` on Wayland is the obvious tool for the captures, and `ffmpeg` for trimming and
re-encoding to mp4 (h264 + faststart, so the browser can play it without downloading the whole file).

## Clip manifest

| Slug | Feature | What the clip should show | Doc |
|---|---|---|---|
| `showcase` | Everything | A single walkthrough of the features below, in the order of the README table | - |
| `battery` | Battery & power management | The Power & battery page, then unplugging and the power-saving changes landing with their toasts, then a threshold being set | [battery.md](battery.md) |
| `idle` | Keep awake | Cycling the utilities card through off, prevent sleep, prevent lock, and the active-since chip appearing | [idle.md](idle.md) |
| `game-mode` | Game mode mouse acceleration | Turning game mode on and off with the mouse acceleration change visible in Hyprland | [input.md](input.md) |
| `input` | Input settings | Dragging the sensitivity and touchpad scroll sliders, then a Hyprland reload with the values staying put | [input.md](input.md) |
| `media-player` | Unified media tab | Switching the media tab's source between an external player and the built-in player, driving playback from the tab | [media.md](media.md) |
| `music-library` | Local music player & library | Browsing folders, playing a folder through, searching an artist, selecting several tracks and adding them to the queue | [media.md](media.md) |
| `equalizer` | Equalizer | Opening the equalizer drawer, moving a band, applying a preset, and the switch in Settings | [equalizer.md](equalizer.md) |
| `notch` | Notch | A track change dropping the pill down, the standing notch showing the clock and now playing, and the bar dropping its own clock while it stands | [notch.md](notch.md) |
| `notification-popout` | Notification popout | The 4-finger swipe opening it, moving between the two tabs, swiping right to close | [notification-popout.md](notification-popout.md) |
| `notifications` | Notification dock | A chat app sending several messages and each being kept, with the group showing each message's picture | [notifications.md](notifications.md) |
| `overview` | Window overview | Swipe up to open, switching pages, dragging a window to another workspace, dragging a workspace onto another, clicking a window to jump | [overview.md](overview.md) |
| `special-workspaces` | Special workspaces switch | Switching them off, then opening one and the shell closing it and moving the window out | [special-workspaces.md](special-workspaces.md) |
| `keybinds` | Keybinds | Rebinding a shortcut, the clash warning on a shared one, and resetting it | [keybinds.md](keybinds.md) |
| `launcher-ocr-lens` | OCR & Google Lens | `>ocr` on a region and the text landing in the clipboard, then `>lens` and the Lens tab opening | [launcher.md](launcher.md) |
| `launcher-todo` | To-do list | `>todo`, adding a task through the prompt, then marking one done | [launcher.md](launcher.md) |
| `launcher-ssh` | SSH hosts | `>ssh`, filtering the list, connecting to a host in the terminal | [launcher.md](launcher.md) |
| `launcher-gpu` | GPU modes | `>gpu`, picking a mode, and the restart prompt it raises | [launcher.md](launcher.md) |
| `launcher-wallpaper` | Wallpaper arrow keys | Stepping through the wallpaper list with the left and right arrows | [launcher.md](launcher.md) |
| `screenshot` | Screenshots | Taking a screenshot, the preview appearing, clicking it to edit in swappy, saving it | [screenshot.md](screenshot.md) |
| `shell-assets` | Shell assets | Changing the logo and the media gif from the page, and the previews updating | [shell-assets.md](shell-assets.md) |
| `settings-app` | Colour schemes in Settings | Picking a scheme, flavour and variant from Nexus and the shell restyling | [nexus.md](nexus.md) |
| `displays` | Displays page | Dragging a monitor into place with the snap, applying, keeping the change, then identifying a display | [displays.md](displays.md) |
| `dashboard` | Dashboard performance graph | The combined graph, switching a resource off and it leaving the graph, changing the graph colours | [dashboard.md](dashboard.md) |
| `layout` | Layout editor | Dragging the launcher, notification popups and toasts tiles around the miniature screen, switching to the desktop layer, resetting the layout | [layout.md](layout.md) |
| `bar` | Taskbar | Moving the bar to another edge, the horizontal layout with its own workspaces strip, the middle cut away on an empty workspace | [bar.md](bar.md) |
| `desktop` | Desktop widgets & shortcuts | Showing the widget cards, dragging one to another corner, starting the focus timer, adding an app shortcut | [desktop.md](desktop.md) |
| `corners` | Popup and toast corners | Moving the notification popups to another corner, then the toasts into the same one and the two sharing a column | [notifications.md](notifications.md) |
| `updates` | Updates page | Checking and it reporting the commits behind, installing and the shell coming back on the new build | [updates.md](updates.md) |

## Once the clips are up

When the showcase is uploaded, the README can show a poster instead of a bare link, since GitHub will
not play a video from another host inline:

```markdown
[![Feature showcase](https://cykler.dev/caelestia/showcase-poster.png)](https://cykler.dev/caelestia/showcase.mp4)
```

That needs one still frame at `showcase-poster.png` next to the video. The individual clips are fine as
plain links, since they are opened from the docs rather than played inline.
