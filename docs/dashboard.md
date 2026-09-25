# Dashboard

[▶ Demo](https://cykler.dev/caelestia/demos/dashboard.mp4)

## Combined performance graph

The dashboard's performance tab can combine CPU, GPU, memory, network and storage into one card, so the
whole machine is readable at a glance instead of five separate cards.

- `dashboard.performance.graphView` switches between the combined card and the original separate
  cards. It is on by default.
- The card only shows the resources you have enabled. Switching a resource off removes it from the
  graph rather than leaving a flat line, and a resource that is switched off no longer contributes
  anything to it. If you switch all of them off the tab says *No widgets enabled* instead of drawing
  an empty graph.
- Colours come from `dashboard.performance.graphColours`:

| Value | What it uses |
|---|---|
| `scheme` | The theme's scheme colours (the default) |
| `vibrant` | The scheme's terminal colours, which are distinct hues that still follow the wallpaper |
| `monochrome` | Shades of the primary colour |
| `custom` | One colour per resource: `cpuColour`, `gpuColour`, `memoryColour`, `networkColour`, `storageColour`, each a palette role (e.g. `primary`, `term1`) or a `#rrggbb` hex |

- The graph's background recording stops entirely while Power Saver has *Pause the performance graph*
  switched on, and the tab falls back to the original cards - see [battery.md](battery.md).

## Media tab layout

The dashboard's media tab was reworked alongside the [local player](media.md): the browsing UI moved
out to the notification popout so the tab is only about controlling what is playing, the lyrics got
the space that freed up, the player icons were re-squared and re-rounded, hover tooltips show full
names, and text overlaps in the tab were fixed.
