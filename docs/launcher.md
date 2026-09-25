# Launcher actions

Everything below is a launcher action, so it is reachable by name from the command panel or by typing
its prefix (the default action prefix is `>`, configurable with `launcher.actionPrefix`).

[▶ Demo: OCR & Lens](https://cykler.dev/caelestia/demos/launcher-ocr-lens.mp4) ·
[▶ Demo: to-do](https://cykler.dev/caelestia/demos/launcher-todo.mp4) ·
[▶ Demo: SSH](https://cykler.dev/caelestia/demos/launcher-ssh.mp4) ·
[▶ Demo: GPU](https://cykler.dev/caelestia/demos/launcher-gpu.mp4) ·
[▶ Demo: wallpapers](https://cykler.dev/caelestia/demos/launcher-wallpaper.mp4)

## OCR (`>ocr`)

Select a screen region with `slurp`, recognize it with `tesseract`, and copy the detected text to the
clipboard with `wl-copy`. If nothing is recognized you get a low-urgency notification saying so
instead of a silent failure.

## Google Lens (`>lens`)

Select a screen region, upload the capture to [Uguu](https://uguu.se), and open the result in Google
Lens in your browser. The temporary capture is removed either way, and a failed upload says so rather
than opening nothing.

Both actions need `slurp`, `grim` and `libnotify`; OCR also needs `tesseract` and `wl-clipboard`, and
Lens needs `curl`, `jq` and `xdg-open`. OCR currently only recognises English (`-l eng` in
`assets/ocr.sh`).

## To-do list (`>todo`)

Ported from the fuzzel script in the dotfiles. `>todo` lists your tasks with a leading *New task* row;
picking a task marks it done, and picking *New task* hands over to a `>todo add ` prompt where the
typed text becomes the new task.

Tasks live in `~/.local/share/caelestia/todo.json`, and the first time it runs the list is imported
once from the old fuzzel cache (`~/.local/share/todo-fuzzel/todo.cache`), so existing tasks carry over.

## SSH hosts (`>ssh`)

Lists the hosts from `~/.ssh/config` - the non-wildcard ones, deduplicated and sorted - and connects
to the chosen one with `ssh` in your configured terminal (`general.apps.terminal`). Typing after `>ssh`
filters the list.

## GPU modes (`>gpu`)

Switches `supergfxctl` graphics modes. **Off by default**: turn on `launcher.enableSupergfxctl` in
`shell.json` first. The modes are read from `supergfxctl -s` (falling back to Integrated, Hybrid and
AsusMuxDgpu), and since a mode change usually needs the session to end, the action waits on
`supergfxctl --pend-action` and offers to restart or log out when that is what is required.

## Wallpaper arrows (`>wallpaper`)

The wallpaper list is laid out horizontally, so plain left/right arrows step through wallpapers,
matching the existing up/down arrows and the scroll wheel. Modified arrows (`shift` / `ctrl` / `alt`)
keep their usual caret and selection behaviour in the search field.
