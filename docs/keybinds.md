# Keybinds

*Nexus → Keybinds* (under *Shell*) lists every `kb*` keybind from the Hyprland Lua config, grouped and
searchable, so you can change a shortcut without editing Lua.

[▶ Demo](https://cykler.dev/caelestia/demos/keybinds.mp4)

- Click a bind to change its modifiers, click its key and press the new one, add a further shortcut,
  or reset it to the default.
- Shortcuts that two binds share are flagged, so you can see which of them will win.
- Your choices are written to `~/.config/caelestia/hypr-vars.lua`, and Hyprland is reloaded so a change
  takes effect straight away.
- The first change keeps a copy of the file as `hypr-vars.lua.bak-keybinds`, so an over-enthusiastic
  edit is recoverable.

## Requirements

It needs the Lua config from the [main dotfiles](https://github.com/caelestia-dots/caelestia):

- The defaults are the `kb*` variables in `hypr/variables.lua`.
- Your overrides are the same variable names in `~/.config/caelestia/hypr-vars.lua`, which is the only
  file the page ever writes.

Without the Lua config the page is empty and says so.

## Notes

- Binds that are only a modifier prefix, followed by a number key, are treated as the workspace
  shortcuts they are (`kbGoToWs`, `kbMoveWinToWs` and their group variants land on the *Workspaces*
  section), rather than as ordinary binds.
- Returning a bind to its default removes the override instead of writing the default value out, so a
  later upstream change to that default is picked up.
