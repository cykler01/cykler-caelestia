# Notch

The notch is both a brief pill that drops down when the playing track changes (replacing the plain
"now playing" toast the shell used to raise) and, optionally, a standing element inside the bar's
middle showing the clock and what is playing.

[▶ Demo](https://cykler.dev/caelestia/demos/notch.mp4)

*Nexus → Panels → Notch*

## The standing notch

While the bar's middle is not otherwise busy, the notch can stay up showing the clock, what is playing,
or both:

| Option | Default | What it does |
|---|---|---|
| `showOnEmptyWorkspace` | `true` | Keep it up while the workspace has no tiled windows (floating ones leave it visible) |
| `showWithWindows` | `true` | Also keep it up on workspaces that have windows |
| `showClock` | `true` | Show the clock in it |
| `showMusic` | `true` | Show what is playing in it, alongside the clock |
| `align` | `center` | Where along the top it sits: `start`, `center` or `end` |

When it is standing in for the clock, the bar drops its own clock so the time is not shown twice - see
[bar.md](bar.md). The brief pill after a track change is separate and shows even when the standing
notch is switched off for that workspace.

Nothing is shown while the workspace is covered by tiled windows unless `showWithWindows` is on, which
is what keeps the notch from sitting over a full-screen window (a floating window leaves the desktop
visible, so the empty-workspace rule still applies there).

## The track-change pill

| Option | Default | What it does |
|---|---|---|
| `enabled` | `true` | Whether the pill shows at all |
| `showDuration` | `4000` | How long it stays up after a track change (ms) |
| `maxTitleWidth` | `320` | How wide the title may get before it is elided (px) |
| `showArtist` | `true` | Show the artist under the title |

It follows whatever has something to say about what is playing - an MPRIS player or the in-shell player
- by the same rule the media tab uses to pick its source, so with nothing external open it is the local
player's pill. See [media.md](media.md).

## The spectrum

The notch's visualiser is the same C++ bar component the background and dashboard use, in a different
mode: the bars read much better centred on the middle line and reflected above and below it than as a
chart rising from a bottom edge, so the notch sets the component's mirrored, single-row mode and draws
one spectrum across its whole width.

The visualiser is audio capture, so it stops entirely while Power Saver has *Pause audio visualisers*
switched on - see [battery.md](battery.md).

## Notes

- When the bar is vertical (left or right edge) the notch sits inside it, rotated to read along the
  bar, for the cases where it still has something to show.
- `hoverExpandDelay` and `collapseDelay` in `shell.json` are left over from an earlier version that
  peeked the media tab on hover. That behaviour is gone, so the two options no longer do anything.
