# Displays

*Nexus → Displays* arranges monitors, sets their modes and can turn them off, without editing a
Hyprland config or remembering `hyprctl` syntax.

[▶ Demo](https://cykler.dev/caelestia/demos/displays.mp4)

## The arrangement

The page draws your displays to scale, on a grid, and you drag them into place.

- Nothing is sent to Hyprland until you press **Apply**, so the arrangement is a draft you can edit
  freely. Dragging does not rebuild the item under your cursor, and positions are kept separately from
  the list of displays, so a drag never gets interrupted.
- Edges **snap** as you drag, so displays line up instead of overlapping by a few pixels. The pull
  feels the same however far the arrangement is zoomed out.
- **Apply** is only enabled when the draft actually differs from what Hyprland has *and* the
  arrangement is valid: no overlaps, everything contiguous and reachable.
- Displays that are turned off are still listed, since listing only the active ones would leave no way
  to turn one back on.

## Per display

Clicking a display opens its details:

| Setting | Notes |
|---|---|
| Enabled | Turning off the only display still enabled is not allowed |
| Extend / Mirror | Mirror the display onto another one, or give it its own place on the desktop |
| Resolution | Only resolutions the display reports |
| Refresh rate | Not independent of the resolution, so the rates offered follow the one you pick |
| Scale | 1.0x to 2.0x |
| Rotation | 0, 90, 180 and 270 degrees |
| Brightness | Where the display exposes brightness control |

**Identify** flashes a marker on each display so you can tell which entry is which monitor, and it
stops on its own.

## Keeping a change

Applying a mode change is the one thing here that can leave you with a black screen, so the shell
confirms it:

- After applying, a countdown with a **Keep** button appears for 15 seconds.
- If you do nothing - or keep the old arrangement - the previous specs are applied again, so a mode
  your display cannot actually show reverts by itself.

The applied specs are also remembered for a Hyprland reload, so a `hyprctl reload` does not throw away
what the page set.
