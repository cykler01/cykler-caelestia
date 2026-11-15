pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia.Config
import qs.services
import qs.utils

// NOTE(fork): how see-through the windows themselves are - terminals, browsers, everything on
// screen - and how round their corners are. The opacity is nothing to do with Colours.transparency,
// which only covers the shell's own panels and popups.
//
// It cannot go through decoration:active_opacity the way you would expect, because the dots
// apply a blanket rule in hyprland/rules.lua:
//
//     hl.window_rule({ match = { fullscreen = false }, opacity = vars.windowOpacity .. " override" })
//
// Hyprland's `override` means exactly what it says: the rule wins and the decoration opacities
// are ignored, so setting them has no effect at all while that rule is in place. What the rule
// reads is vars.windowOpacity, so that is what gets set here - in the user's own
// ~/.config/caelestia/hypr-vars.lua, which hyprland.lua merges over variables.lua.
//
// A Lua variable is only read while the config is being evaluated, and on this setup nothing
// moves an already-open window's opacity at runtime - a windowrulev2 keyword only applies to
// windows mapped after it, and this Hyprland build has no `setprop`. So the value is written to
// the file and picked up by `hyprctl reload`, which is debounced so dragging the slider doesn't
// reload the config on every frame.
//
// The rounding is a plain decoration option, so unlike the opacity it can also be applied to
// every window the moment it moves; variables.lua feeds the same windowRounding into
// decoration.lua, which is what brings it back after a restart.
Singleton {
    id: root

    // What variables.lua itself defaults to, used until hypr-vars.lua has been read
    readonly property real defaultOpacity: 0.95
    // NOTE(fork): variables.lua rounded windows to 15, tighter than everything the shell draws
    // beside them (Tokens.rounding.large is 16, and the launcher, dashboard and lock screen use
    // extraLarge, 28). 20 sits among those, and the frame's corners are then this plus the
    // border's thickness, so the two curves run parallel where a window meets the frame.
    readonly property int defaultRounding: 20

    // Follows the slider as it moves; the file and the reload catch up once it settles
    property real value: root.defaultOpacity
    property int rounding: root.defaultRounding
    property bool loaded: false
    property string savedText: ""

    // Matches the key only where it sits on its own line in the returned table, so a longer name
    // containing it, or a mention in a comment, is left alone
    readonly property var opacityPattern: /^([ \t]*)windowOpacity([ \t]*)=[ \t]*([0-9.]+)[ \t]*,?/m
    readonly property var roundingPattern: /^([ \t]*)windowRounding([ \t]*)=[ \t]*([0-9]+)[ \t]*,?/m

    function set(v: real): void {
        // Hyprland rejects an opacity outside 0-1, and a stray extra decimal from the slider's
        // arithmetic is not worth writing into someone's config
        root.value = Math.max(0, Math.min(1, Math.round(v * 100) / 100));
        commitTimer.restart();
    }

    function setRounding(v: real): void {
        // Whole layout pixels, and a corner rounder than the window is tall has nothing left to
        // round, so it stops short of that rather than being given a nonsensical value
        root.rounding = Math.max(0, Math.min(40, Math.round(v)));
        root.syncFrame();
        commitTimer.restart();
    }

    // The shell draws its own frame around the desktop at these corners, and for them to look
    // parallel to a window's they have to be the window radius plus the border between the two
    function syncFrame(): void {
        const rounding = root.rounding + GlobalConfig.border.thickness;
        if (GlobalConfig.border.rounding !== rounding)
            GlobalConfig.border.rounding = rounding;
    }

    // Applied to every open window straight away. Game mode pins the rounding to 0 and puts its
    // own options back on every reload, so its choice is left alone while it is on
    function apply(): void {
        if (!root.loaded || GameMode.enabled)
            return;
        Hypr.extras.applyOptions({
            "decoration:rounding": root.rounding
        });
    }

    // Rewrites just the one assignment, or adds it at the top of the table when the user has
    // never set it, leaving the rest of their file exactly as it was
    function replaced(text: string, pattern: var, key: string, v: var): string {
        if (pattern.test(text))
            return text.replace(pattern, `$1${key}$2= ${v},`);
        // `return {` is how hyprland.lua creates the file and how the dots document it; without
        // it there is nothing to add a key to, so the file is left alone rather than mangled
        if (/^return[ \t]*\{/m.test(text))
            return text.replace(/^return[ \t]*\{/m, `return {\n\t${key} = ${v},`);
        return text;
    }

    function commit(): void {
        if (!root.loaded)
            return;

        let next = root.replaced(root.savedText, root.opacityPattern, "windowOpacity", root.value);
        next = root.replaced(next, root.roundingPattern, "windowRounding", root.rounding);
        if (next === root.savedText) {
            // Nothing to write, so nothing to reload for either
            return;
        }

        storage.setText(next);
        root.savedText = next;
        root.apply();
        reloader.running = true;
    }

    Timer {
        id: commitTimer

        // Long enough that dragging the slider end to end reloads the config once, at the end,
        // rather than on every step of the way
        interval: 500
        onTriggered: root.commit()
    }

    Process {
        id: reloader

        command: ["hyprctl", "reload"]
    }

    // A reload puts variables.lua's own values back, so the rounding is put back afterwards
    Connections {
        function onConfigReloaded(): void {
            root.apply();
        }

        target: Hypr
    }

    FileView {
        id: storage

        path: `${Paths.config}/hypr-vars.lua`
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            root.savedText = text();
            const opacity = root.opacityPattern.exec(root.savedText);
            const rounding = root.roundingPattern.exec(root.savedText);
            root.value = opacity ? Number(opacity[3]) : root.defaultOpacity;
            root.rounding = rounding ? Number(rounding[3]) : root.defaultRounding;
            root.loaded = true;
            // variables.lua's own 15 is what would be in force otherwise
            root.apply();
        }
        onLoadFailed: err => {
            // hyprland.lua creates it as `return {}` on the next start, so there is nothing to
            // preserve and nothing to read a value out of
            if (err === FileViewError.FileNotFound) {
                root.savedText = "";
                root.value = root.defaultOpacity;
                root.rounding = root.defaultRounding;
                root.loaded = true;
                root.apply();
            }
        }
    }
}
