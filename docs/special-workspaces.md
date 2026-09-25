# Turning special workspaces off

*Settings → Workspaces → Special workspaces* (`bar.workspaces.specialWorkspaces` in `shell.json`) is on
by default. Switching it off does more than hide them from the bar.

[▶ Demo](https://cykler.dev/caelestia/demos/special-workspaces.mp4)

- The shell closes a special workspace the moment it opens and moves its windows to the workspace you
  are on, whether it was opened by a keybind, a gesture or a dispatch.
- A window that opens into a special workspace is moved out too.
- It works with any Hyprland config, so there is nothing to edit. The price is that the workspace can
  flash open for a moment before it is closed.

The switch is enforced by the shell (`services/SpecialWorkspaceGuard.qml`) rather than in a Hyprland
config, because Hyprland always has special workspaces - so it is undone after the fact rather than
prevented. The setting is read live, so flipping it in the shell needs no Hyprland reload.

<details>
<summary>Optional: no flash, and app shortcuts that open on the current workspace</summary>

If you would rather it never flash, have your own Hyprland binds check the setting first. The
Hyprland config is not part of this repo, so this is a change to *your* dotfiles. It assumes the
Caelestia Lua config, whose `utils/functions.lua` already has `toggle`, `get_clients`,
`load_toggle_config`, `shell_join`, `json` and `config_dir`. It also gives the app shortcuts
(Discord, music, to-do, system monitor) a proper "open on the current workspace" mode instead of
the shell moving the window out afterwards.

The setting is read from `shell.json` on every press, so flipping it in the shell needs no Hyprland
reload, and if `shell.json` is missing it counts as on.

**1. `utils/functions.lua`**: add this above the final `return {`, then list `launch`, `app` and
`if_special_workspaces` in the table it returns.

```lua
-- Open an app category's apps on the *current* workspace instead of a special one:
-- spawn the ones that aren't running, and pull running ones here and focus them.
local function launch(category)
    return function()
        local apps = load_toggle_config()[category]
        local active_ws = hl.get_active_workspace()
        if not apps or not active_ws then
            return
        end

        local clients = hl.get_windows() or {}
        local to_focus = nil

        for _, app in pairs(apps) do
            if app.enable then
                -- The default matches can require a special workspace name (sysmon); drop that
                local match = {}
                for _, rule in ipairs(app.match or {}) do
                    local copy = {}
                    for key, value in pairs(rule) do
                        if key ~= "workspace" then
                            copy[key] = value
                        end
                    end
                    table.insert(match, copy)
                end

                local is_running, running = get_clients(clients, { match = match }, category)
                if is_running then
                    for _, entry in ipairs(running) do
                        local ws = entry.window.workspace
                        if not ws or ws.id ~= active_ws.id then
                            hl.dispatch(hl.dsp.window.move({ window = entry.window, workspace = active_ws.id, follow = false }))
                        end
                        to_focus = to_focus or entry.window
                    end
                elseif app.command then
                    hl.dispatch(hl.dsp.exec_cmd(shell_join(app.command)))
                end
            end
        end

        if to_focus then
            hl.dispatch(hl.dsp.focus({ window = to_focus }))
        end
    end
end

-- Mirrors the "Special workspaces" switch in the shell's settings (Workspaces), which is
-- bar.workspaces.specialWorkspaces in shell.json. Read on every press so changing it needs no reload.
local function special_workspaces_enabled()
    local file = io.open(config_dir .. "/caelestia/shell.json", "r")
    if not file then
        return true
    end

    local content = file:read("*a")
    file:close()

    local ok, conf = pcall(json.decode, content)
    if ok and type(conf) == "table" and type(conf.bar) == "table" and type(conf.bar.workspaces) == "table" then
        return conf.bar.workspaces.specialWorkspaces ~= false
    end
    return true
end

-- Only runs the action while special workspaces are switched on in the shell's settings
local function if_special_workspaces(action)
    return function()
        if special_workspaces_enabled() then
            action()
        end
    end
end

-- App shortcuts (Discord, music, ...): a special workspace when the setting is on, the current workspace when off
local function app(category)
    local in_special = toggle(category)
    local in_current = launch(category)
    return function()
        if special_workspaces_enabled() then
            in_special()
        else
            in_current()
        end
    end
end
```

```lua
return {
    -- ...what is already there...
    launch                = launch,
    app                   = app,
    if_special_workspaces = if_special_workspaces,
}
```

**2. `hyprland/keybinds.lua`**: the plain special-workspace toggle only runs while the setting is
on, and the four app shortcuts use `fn.app` instead of `fn.toggle`.

```lua
create_bind(vars.kbSpecialWs, fn.if_special_workspaces(fn.toggle("specialws")))
create_bind(vars.kbSystemMonitorWs, fn.app("sysmon"))
create_bind(vars.kbMusicWs, fn.app("music"))
create_bind(vars.kbCommunicationWs, fn.app("communication"))
create_bind(vars.kbTodoWs, fn.app("todo"))
```

**3. `hyprland/gestures.lua`**: the 3-finger up/down special workspace gestures.

```lua
hl.gesture({
    fingers   = vars.gestureFingers,
    direction = "up",
    action    = fn.if_special_workspaces(function()
        hl.dispatch(hl.dsp.workspace.toggle_special("special"))
    end),
})
hl.gesture({
    fingers   = vars.gestureFingers,
    direction = "down",
    action    = fn.if_special_workspaces(fn.toggle("specialws")),
})
```

The up swipe becomes a plain toggle here: Hyprland's built-in `action = "special"` follows your
fingers as you drag but cannot be made conditional, so if you keep that one the shell will close the
workspace right after it opens when the setting is off. Anything you leave unconverted is still
handled by the shell, so partial changes are fine. Run `hyprctl reload` after editing.

</details>
