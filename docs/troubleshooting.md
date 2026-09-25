# Troubleshooting

- **`install-deps.sh` can't find an AUR helper and you don't want it installing `yay`** - run with
  `--repo-only`, then install the AUR packages yourself with your preferred helper.
- **Build fails after pulling upstream changes** - try a clean build: `rm -rf build`, then repeat the
  `cmake -B build ...` step.
- **`update.sh` stops with a merge conflict** - resolve the conflicting files with `git status` /
  `git mergetool`, commit the merge, then rerun `./update.sh` (it skips straight to the rebuild when
  you are already up to date).
- **`update.sh` refuses to run** - it requires a clean working tree; commit or `git stash` first.
- **Shell won't start / blank output** - confirm you are on `quickshell-git` (not the stable
  `quickshell` package) and check `caelestia shell -d` output for the actual error.

## Feature-specific

- **The equalizer says the sink is missing.** The PipeWire filter chain has to be installed by hand,
  and it is loaded at startup, so it needs a restart of the PipeWire services to appear. See
  [equalizer.md](equalizer.md).
- **A track shows its file name instead of its artist and album.** Qt's ffmpeg backend only surfaces
  container-level tags, so Ogg/Opus files (whose tags live on the stream) come out untagged. mp3, flac
  and m4a are fine. Cover art is unaffected. See [media.md](media.md).
- **The keybinds page is empty.** It reads the Hyprland Lua config, so it needs the
  [main dotfiles](https://github.com/caelestia-dots/caelestia) and `hypr/variables.lua` to exist. See
  [keybinds.md](keybinds.md).
- **The overview or popout gestures don't fire.** The shell registers them with Hyprland itself, and
  only when Hyprland is using its Lua config. Check `overview.gestures` / `notifPopout.gestures` in
  `shell.json`, and note that they only come back on the next Hyprland reload after you switch them
  back on.
- **Something a feature changed in Hyprland was forgotten after a reload.** Anything the shell applies
  as a runtime keyword (mouse settings, power-saving effects, the refresh rate) is re-applied by the
  shell when Hyprland reloads or when the shell starts. If a value does not come back, that service
  did not see the reload - a shell restart reapplies it.
- **The Updates page says the check failed.** It looks for a git checkout, defaulting to
  `~/Documents/Github/cykler-caelestia`. Set `services.repoPath` to where your clone actually lives.
  See [updates.md](updates.md).
- **The Updates page refuses to install.** It will not pull over uncommitted changes without asking;
  choose to stash and restore them, or commit them first.
- **The desktop widgets or icons are not where you put them.** They are per-monitor config
  (`background.desktopWidgets.position`, `background.desktopIcons.position`), so dragging them on one
  screen does not move them on another. See [desktop.md](desktop.md).
- **The bar's middle is missing.** That is the wallpaper showing through on an empty workspace;
  switch off `bar.hideMiddleOnDesktop` to keep the bar whole. See [bar.md](bar.md).
- **The screen went black after applying a display change.** Do nothing for 15 seconds and the shell
  reverts to the previous arrangement on its own; there is a countdown with a *Keep* button on the
  page. See [displays.md](displays.md).
