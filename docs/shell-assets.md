# Shell assets

*Nexus → Shell assets* (under *Appearance*) changes the images the shell uses, which previously could
only be changed by editing the files or the config by hand.

[▶ Demo](https://cykler.dev/caelestia/demos/shell-assets.mp4)

| Row | Config option | Default |
|---|---|---|
| System logo | `general.logo` | the shell's own logo |
| Session screen gif | `paths.sessionGif` | `root:/assets/kurukuru.gif` |
| Dashboard media gif | `paths.mediaGif` | `root:/assets/bongocat.gif` |
| Sidebar placeholder | `paths.noNotifsPic` | `root:/assets/dino.png` |
| Lock screen placeholder | `paths.lockNoNotifsPic` | `root:/assets/dino.png` |
| Profile picture | `~/.face` | - |

Each row previews the current image, and the reset button restores the shell's default.

## How uploading works

Choosing a file copies it into `~/.local/share/caelestia/assets/` and points the option at that copy,
the same way the profile picture is handled. The shell's own assets are never written to - they can be
read-only, for example under `/etc/xdg` - and the copy means the asset survives the original file
being moved or deleted.

## Shell-relative paths

The shipped defaults use the `root:` prefix (e.g. `root:/assets/kurukuru.gif`), which is resolved
against the shell's asset directory. Upstream stopped resolving that prefix for a while, which left
the default logo, gifs and placeholder images blank; the fork restores it, so `root:` paths work as
well as `file://` and plain paths.
