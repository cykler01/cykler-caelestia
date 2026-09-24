<h1 align=center>cykler-caelestia</h1>

<div align=center>

A personal fork of [`caelestia-dots/shell`](https://github.com/caelestia-dots/shell) with the features I wanted.

</div>

This is my take on the Caelestia shell - upstream's desktop shell with my own features layered on top. It's built for my machine and my workflow first.

> [!WARNING]
> These features are **not guaranteed to work everywhere or reliably**. This fork tracks my
> hardware (an AMD laptop with a USB DAC) and my setup, so things may behave differently on
> your system. Use at your own risk.

## What's different from upstream
 
| Area | Upstream | This fork |
|---|---|---|
| Battery management | --- | `BatteryMonitor` service, auto power-saving on profile change, battery pane in control center |
| Game mode | Derived from animation state | Fixed false-trigger; also sets flat mouse accel |
| Input configuration | Hand-edited Hyprland config | Mouse, scroll and touchpad settings in Nexus |
| Launcher | Standard actions | Adds OCR (`>ocr`) and Google Lens (`>lens`) region-capture actions |
| Music player | External players only | In-shell local music player in the dashboard media tab |
| To-do list | Fuzzel script in the dotfiles | `>todo` list in the launcher |
| Window overview | --- | 4-finger swipe up or the top-left hot corner shows every workspace and its windows, click to jump |


## Features added on top of upstream

### Battery optimization suite

-   **`BatteryMonitor` service** - manages power profiles and per-profile effects
-   **Automatic Hyprland power saving** - when the power profile changes (e.g. switching to
    battery saver), the shell automatically disables animations, blur, gaps and shadows, and
    can adjust the screen refresh rate to save power. Changes are announced via toasts.
-   **Control center battery pane** - a new battery pane in the control center with:
    -   Power profile selector (with configurable behaviors per profile)
    -   Charging behavior settings
    -   Battery charge threshold configuration (for laptops that expose charge limits)
    -   Refresh rate selector
-   **Game mode false-trigger fix** - game mode state is no longer derived from whether
    animations are disabled, so the battery monitor disabling animations for power saving no
    longer makes the shell think game mode is on

### Game mode mouse acceleration

-   Game mode now also sets `input:accel_profile: flat` in Hyprland, disabling mouse
    acceleration while gaming (and restores it when game mode is turned off)

### Input settings

-   **Settings page** - a new "Input" page under *Settings* with sliders for mouse
    sensitivity and scroll speed and for touchpad scroll speed, plus a toggle for mouse
    acceleration.
-   **Applied at runtime, remembered by the shell** - the values are sent to Hyprland as
    runtime keywords, which a config reload would otherwise drop, so the shell puts them back
    when Hyprland reloads or when the shell starts. Only settings changed here are applied, so
    anything left alone keeps whatever `hyprland.conf` sets.

### Launcher image tools

-   **OCR action** - select a screen region with `slurp`, recognize it with `tesseract`,
    and copy the detected text to the clipboard with `wl-copy`.
-   **Google Lens action** - select a screen region with `slurp`, upload the capture to
    Uguu, and open the result in Google Lens.
-   Launch either tool from the command panel by selecting its action or searching for
    `>ocr` / `>lens`.

### Launcher to-do list

-   **Ported from the fuzzel script** - `>todo` lists your tasks with a leading *New task* row.
    Picking a task marks it done, and picking *New task* hands over to a `>todo add ` prompt
    where typed text becomes the new task.
-   **Stored with the shell** - tasks live in `~/.local/share/caelestia/todo.json`. The first
    time it runs, the list is imported once from the old fuzzel cache
    (`~/.local/share/todo-fuzzel/todo.cache`), so existing tasks carry over.

### Launcher wallpaper switching

-   **Left/right arrow keys** — the `>wallpaper` list is laid out horizontally, so plain
    left/right arrows now step through wallpapers, matching the existing up/down arrows and
    scroll wheel. Modified arrows (`shift` / `ctrl` / `alt`) keep their usual caret and
    selection behaviour in the search field.

### Screenshot preview

-   **Clipboard by default** — a screenshot goes straight to the clipboard, so it can be
    pasted immediately without touching the temporary file it is written to first.
-   **Preview instead of a notification** — a framed thumbnail of the capture appears in
    the bottom left of the screen for 3 seconds. Clicking the capture opens it in `swappy`
    to annotate, and the save button writes a copy to `~/Desktop`. If it is left alone, the
    temporary file is cleared and the clipboard keeps the image.

### Shell assets

-   **Settings page** — a new "Shell assets" page under *Settings → Appearance* that
    changes the images the shell uses: the system logo, the session screen and
    dashboard media gifs, the sidebar and lock screen placeholder images, and the profile
    picture (`~/.face`) shown on the dashboard and lock screen. Previously these could only
    be changed by editing the files (or the config) by hand.
-   **Upload like the profile picture** — choosing a file copies it to
    `~/.local/share/caelestia/assets/` and points the option at the copy, so the shell's
    own assets (which can be read only, e.g. under `/etc/xdg`) are left alone. Each row
    previews the current image, and the reset button restores the shell's default.
-   **Shell-relative asset paths fixed** — the shipped defaults use the `root:` prefix
    (e.g. `root:/assets/kurukuru.gif`), which stopped being resolved to the shell's asset
    directory, leaving the default logo, gifs and placeholder images blank.

### Local music player

-   **Unified media tab** — one tab controls whatever is playing, whether that is an
    external MPRIS player (a browser or music app) or the built in player. When nothing is
    loaded the library opens so you can pick something to play, otherwise the cover, lyrics
    and visualiser follow the active source, and the same controls drive it. The source
    picker switches between the open MPRIS players and the built in player, which plays the
    files under `paths.musicDir` (defaults to `~/Music`) in-shell with seek, volume, shuffle
    and repeat (off / all / one).
-   **System-wide equalizer** (opt-in) — a ten band equalizer in the media tab, in the same slot
    under the player as the library. It is off until you switch it on in Settings > Audio, and
    its one-off PipeWire setup (see **Equalizer** below) is a manual step, so updating the shell
    never changes your audio on its own. It equalizes the whole system rather than just the
    player, because the audio path is a PipeWire filter chain. Moving a slider writes the band
    straight into the running node, so a tweak is audible immediately, and there are presets for
    different kinds of music (rock, pop, jazz, classical, electronic, hip hop, bass boost,
    vocal, loudness) alongside flat. The curve and preset are remembered between sessions.
-   **Collapsible library** — the library is a drawer under the player, sitting clear of it
    and growing the tab rather than squeezing the player, and it opens by itself when there is
    nothing to control. It browses the music
    folder as a cover gallery, like the wallpaper picker does: folders first, each named under
    its rounded cover (hovering a name that doesn't fit shows it in full), and opening one
    shows its tracks the same way. A folder with no cover
    image of its own shows a collage of its first few tracks' art instead, and anything with
    no art at all falls back to a rounded folder or music icon. Typing in the search box
    switches to a flat gallery of every track found under the music folder, and searching
    matches the whole path, so an album name finds its tracks too. The dashboard now takes
    keyboard focus on demand, so that search box can actually be typed into.
-   **Cover art** — art embedded in the track is shown on the cover next to the controls,
    falling back to an image named after the track (what yt-dlp leaves behind, since opus
    cannot hold one) and then to a `cover`, `folder` or `album` image in the track's folder.
    Embedded art arrives from QtMultimedia as a `QImage`, which `Image.source` cannot take
    directly, so it goes through the image cache first (keyed by content, so the same
    artwork is only written once).
-   **Known gap** — Qt's ffmpeg backend only surfaces container level tags. mp3 (ID3), flac
    and m4a tags are read correctly, but Ogg/Opus puts its Vorbis comments on the stream
    instead, so those tracks show their file name with no artist or album. Cover art is
    unaffected.

### Equalizer

The equalizer is a PipeWire filter chain, not something the shell can do to its own audio: a
virtual sink with ten peaking bands, made the default output so everything playing is equalized.

It is **opt-in and off by default** (`services.equalizer` in `shell.json`, or the *System-wide
equalizer* switch under Settings > Audio). While it is off the shell does not run `pw-cli` or
`pactl` at all and never touches the default output, so a plain update cannot change anyone's
audio. It also needs a one-off setup before it can do anything, because PipeWire loads that kind
of module at startup:

```sh
mkdir -p ~/.config/pipewire/pipewire.conf.d
cp assets/pipewire/caelestia-eq.conf ~/.config/pipewire/pipewire.conf.d/
systemctl --user restart pipewire pipewire-pulse wireplumber
```

The panel then finds the sink (`caelestia_eq.sink`) and drives its bands with `pw-cli`; until it
is loaded — in the panel or on the settings page — it says so rather than pretending to work.
With the option off the media tab hides the equalizer button entirely, so the feature is only
visible to people who have asked for it.

Everything only passes through the filter chain while that sink is the default output, so turning
the equalizer on points the default at it and turning it off puts the device that was there
before back. That is what makes it system-wide: streams that are already playing, browser audio
included, move across with it, and the chain's own output stays wired to the real device.

### Notification popout and gestures

A 4-finger swipe on the trackpad opens a separate notification panel on the right edge: swipe
**left to open** it, **right to close** it. It sits on its own blurred layer, so it looks blurrier
than the rest of the shell without changing Hyprland's blur for any other window.

There is nothing to set up. The shell registers the swipes with Hyprland itself each time it
starts and after every Hyprland config reload, so a normal install is enough. It only does this
when Hyprland is using its Lua config. Three fingers are left alone for workspace swiping.

Both settings are in `shell.json`:

```json
"notifPopout": {
    "gestures": true,
    "gestureFingers": 4
}
```

Set `gestures` to `false` to stop the shell registering them (they go away on the next Hyprland
reload), for example if you already bind those swipes yourself. The popout can still be driven
without a trackpad with `qs -c caelestia ipc call notifPopout open`, `close` or `toggle`, or by
binding the `caelestia:notifPopoutOpen` / `caelestia:notifPopoutClose` global shortcuts.

### Window overview

A full-screen overview of every workspace and the windows on it, so you can see everything at
glance and jump straight to it. The ten workspaces around the current one are laid out in a
centred 2×5 grid, each tile a 16:9 representation of that workspace: every window is drawn at the
position and size Hyprland gives it, scaled down from its monitor, with the app's own icon over the
middle of it. Occupied workspaces are brighter than empty ones, all of them are outlined, and the
focused one is outlined in the accent colour. Clicking a window focuses it and closes the overview;
clicking anywhere else on a tile switches to that workspace.

Open it either way:

-   **4-finger swipe up** on the trackpad (swipe down closes it). Registered with Hyprland by the
    shell, the same as the notification popout swipes, so there is nothing to set up.
-   **Top-left hot corner** — move the pointer into the top-left corner of the screen and hold it
    there briefly. The bar's logo sits below the corner, so this doesn't get in its way.

It can also be driven without either with `qs -c caelestia ipc call overview open`, `close` or
`toggle`, or by binding the `caelestia:overviewOpen` / `caelestia:overviewClose` global shortcuts.
Escape closes it, and number keys `1`–`9` jump to that workspace.

Settings are in `shell.json`:

```json
"overview": {
    "enabled": true,
    "gestures": true,
    "gestureFingers": 4,
    "hotCorner": true,
    "hotCornerSize": 10
}
```

Set `gestures` to `false` to stop the shell registering the swipes (they go away on the next
Hyprland reload), for example if you already bind those swipes yourself, and `hotCorner` to
`false` to turn the corner off. `hotCornerSize` is the corner's size in pixels.

### Turning special workspaces off

*Settings > Workspaces > Special workspaces* (`bar.workspaces.specialWorkspaces` in `shell.json`) is
on by default. Switching it off does more than hide them from the bar: the shell closes a special
workspace the moment it opens and moves its windows to the workspace you are on, whether it was
opened by a keybind, a gesture or a dispatch, and a window that opens into one is moved out too. It
works with any Hyprland config, so there is nothing to edit; the price is that the workspace can
flash open for a moment before it is closed.

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
fingers as you drag but can't be made conditional, so if you keep that one the shell will close the
workspace right after it opens when the setting is off. Anything you leave unconverted is still
handled by the shell, so partial changes are fine. Run `hyprctl reload` after editing.

</details>

## Feature requests

Any feature requests are welcome - open an [issue](https://github.com/CYKLER01/cykler-caelestia/issues) and I will try to get onto them quickly.

## Keeping up to date
 
I try to keep this fork merged with upstream `caelestia-dots/shell` regularly, so you should
get upstream fixes and features here too (best effort, no promises).
 
Run the included script from inside your clone - by default it just pulls any new commits
on this fork and rebuilds/reinstalls:
 
```sh
./update.sh
```
 
Flags:
 
-   `--upstream` - also merge in `caelestia-dots/shell` (adding the `upstream` remote if
    needed, and showing you what changed before merging)
-   `--yes` / `-y` - skip the confirmation prompts
It refuses to run if you have uncommitted local changes, so commit or stash first.
 
<details>
<summary>Doing it manually instead</summary>

```sh
cd cykler-caelestia
git pull
cmake --build build
sudo cmake --install build
```
 
To pull in upstream yourself:
 
```sh
git remote add upstream https://github.com/caelestia-dots/shell.git
git fetch upstream
git merge upstream/main
```
 
</details>

## Installation
 
> [!NOTE]
> This installs the shell only. For the full Caelestia dotfiles (themes, Hyprland config,
> keybinds, etc.), see [the main dotfiles repo](https://github.com/caelestia-dots/caelestia).
 
> [!IMPORTANT]
> If you previously installed `caelestia-shell` or `caelestia-shell-git` from the AUR, remove
> it first - this fork conflicts with and provides the same package.
 
### Arch Linux

#### Quick install

Installs dependencies, then builds and installs the shell:

```sh
git clone https://github.com/CYKLER01/cykler-caelestia.git
cd cykler-caelestia
./install.sh
```

Flags:

-   `--install-deps false` - skip installing dependencies (default is `true`), if you already have them
-   `--repo-only` - skip AUR packages
-   `--yes` / `-y` - skip the confirmation prompts

Or follow the steps below to do it by hand.

#### 1. Clone the repo
 
```sh
git clone https://github.com/CYKLER01/cykler-caelestia.git
cd cykler-caelestia
```
 
#### 2. Install dependencies
 
Run the included script, which installs official-repo packages via `pacman` and AUR packages
via `yay`/`paru` (installing `yay` for you if you don't have an AUR helper). It prints each
package list and asks for confirmation before installing anything:
 
```sh
./install-deps.sh
```
 
Flags:
 
-   `--repo-only` - skip AUR packages entirely, if you'd rather install those yourself or use a different helper
-   `--yes` / `-y` - skip the confirmation prompts (useful for scripting)
<details>
<summary>Manual dependency list (if you'd rather not run the script)</summary>

##### Official repos:
 
-   `glibc`, `gcc-libs` (base, usually already installed)
-   `ddcutil`, `brightnessctl`
-   `networkmanager`, `lm_sensors`, `aubio`, `libpipewire`, `libqalculate`, `power-profiles-daemon`
-   `qt6-base`, `qt6-declarative`, `qt6-imageformats`, `qt6-multimedia`
-   `swappy`, `fish`, `bash`, `grim`, `slurp`, `tesseract`, `wl-clipboard`, `libnotify`, `curl`, `jq`, `xdg-utils`
-   Build deps: `git`, `cmake`, `ninja`, `qt6-shadertools`
##### AUR:
 
-   [`caelestia-cli`](https://github.com/caelestia-dots/cli)
-   [`quickshell-git`](https://git.outfoxxed.me/quickshell/quickshell) — must be the git version
-   [`qt6-m3shapes-git`](https://github.com/soramanew/m3shapes)
-   `libcava`
-   Fonts: `ttf-material-symbols-variable`, `ttf-rubik-vf`, `ttf-cascadia-code-nerd`
</details>

#### 3. Build and install
 
```sh
cmake -B build -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/
cmake --build build
sudo cmake --install build
```
 
Then start the shell with `caelestia shell -d` (preferred) or `qs -c caelestia -n -d`.
 
> [!TIP]
> You can customise the installation location via the CMake flags `INSTALL_LIBDIR`,
> `INSTALL_QMLDIR`, and `INSTALL_QSCONFDIR`. See the
> [upstream README](https://github.com/caelestia-dots/shell#manual-installation) for details.
 
### Arch Linux (local package)
 
I build my own system package from this repo. If you want the same approach, create a
`PKGBUILD` that clones this repo (instead of the upstream source) and otherwise mirrors the
[`caelestia-shell-git`](https://aur.archlinux.org/packages/caelestia-shell-git) PKGBUILD.
 
### Nix
 
The upstream flake is kept in this fork, so you can try it with:
 
```sh
nix run github:CYKLER01/cykler-caelestia#with-cli
```
 
If you've cloned the repo and use [direnv](https://direnv.net/), it comes with an `.envrc`
that loads the flake's dev shell automatically - just approve it once after cloning:
 
```sh
direnv allow
```
 
This is best-effort - I don't run Nix daily, so I can't guarantee it stays working.



## Configuration

Configuration is unchanged from upstream: everything lives in `~/.config/caelestia/shell.json`
and per-monitor overrides in `~/.config/caelestia/monitors/<monitor>/shell.json`. See the
[upstream configuring section](https://github.com/caelestia-dots/shell#configuring) for the full list of options and an example config.

## Troubleshooting
 
-   **`install-deps.sh` can't find an AUR helper and you don't want it installing `yay`** —
    run with `--repo-only`, then install the AUR packages yourself with your preferred helper.
-   **Build fails after pulling upstream changes** — try a clean build: `rm -rf build` then
    repeat the `cmake -B build ...` step.
-   **`update.sh` stops with a merge conflict** — resolve the conflicting files with
    `git status` / `git mergetool`, commit the merge, then rerun `./update.sh` (it'll skip
    straight to the rebuild since you're already up to date).
-   **`update.sh` refuses to run** — it requires a clean working tree; commit or `git stash`
    your local changes first.
-   **Shell won't start / blank output** — confirm you're on `quickshell-git` (not the
    stable `quickshell` package) and check `caelestia shell -d` output for the actual error.


## Credits

All credit for the shell itself goes to [Caelestia](https://github.com/caelestia-dots/shell) - this fork is just my additions on top of their excellent work. The battery power-management work also builds on the `feat/battery-power-management` branch contributed by [@PixelKhaos](https://github.com/PixelKhaos). The monitor configuration page is based on [PR #1629](https://github.com/caelestia-dots/shell/pull/1629) contributed by [@devalentineomonya](https://github.com/devalentineomonya).
