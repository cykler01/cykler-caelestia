# Screenshots

Two changes to what happens after a capture.

[▶ Demo](https://cykler.dev/caelestia/demos/screenshot.mp4)

- **Clipboard by default** - the capture goes straight to the clipboard, so it can be pasted
  immediately without touching the temporary file it is written to first.
- **A preview instead of a notification** - a framed thumbnail of the capture appears in the bottom
  left of the screen for three seconds, sitting to the right of the bar. Its outline matches the
  border Hyprland draws around client windows, in the theme's primary colour, so it reads as another
  window rather than a panel.

## What the preview offers

| Action | Result |
|---|---|
| Click the capture | Opens it in `swappy` to annotate. The file is kept so the edit can be saved into it, and `swappy` then owns the file |
| Save button | Writes a copy to `~/Desktop` as `Screenshot <date> <time>.png`, leaving the original for the editor, and creates the Desktop directory if it does not exist |
| Nothing, for three seconds | The temporary file is cleared and the clipboard keeps the image |

Taking another capture dismisses whichever preview is still up first, so the preview never stacks or
leaves an orphaned temporary file behind.

`swappy` is only needed for the edit path; the clipboard and the save button work without it.
