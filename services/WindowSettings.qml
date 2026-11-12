pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.utils

// NOTE(fork): how see-through the windows themselves are - terminals, browsers, everything on
// screen. This is nothing to do with Colours.transparency, which only covers the shell's own
// panels and popups.
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
Singleton {
    id: root

    // What variables.lua itself defaults to, used until hypr-vars.lua has been read
    readonly property real defaultValue: 0.95

    // Follows the slider as it moves; the file and the reload catch up once it settles
    property real value: root.defaultValue
    property bool loaded: false
    property string savedText: ""

    // Matches the key only where it sits on its own line in the returned table, so a longer name
    // containing it, or a mention in a comment, is left alone
    readonly property var pattern: /^([ \t]*)windowOpacity([ \t]*)=[ \t]*([0-9.]+)[ \t]*,?/m

    function set(v: real): void {
        // Hyprland rejects an opacity outside 0-1, and a stray extra decimal from the slider's
        // arithmetic is not worth writing into someone's config
        root.value = Math.max(0, Math.min(1, Math.round(v * 100) / 100));
        commitTimer.restart();
    }

    // Rewrites just the one assignment, or adds it at the top of the table when the user has
    // never set it, leaving the rest of their file exactly as it was
    function replaced(text: string, v: real): string {
        if (root.pattern.test(text))
            return text.replace(root.pattern, `$1windowOpacity$2= ${v},`);
        // `return {` is how hyprland.lua creates the file and how the dots document it; without
        // it there is nothing to add a key to, so the file is left alone rather than mangled
        if (/^return[ \t]*\{/m.test(text))
            return text.replace(/^return[ \t]*\{/m, `return {\n\twindowOpacity = ${v},`);
        return text;
    }

    function commit(): void {
        if (!root.loaded)
            return;

        const next = root.replaced(root.savedText, root.value);
        if (next === root.savedText) {
            // Nothing to write, so nothing to reload for either
            return;
        }

        storage.setText(next);
        root.savedText = next;
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

    FileView {
        id: storage

        path: `${Paths.config}/hypr-vars.lua`
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            root.savedText = text();
            const found = root.pattern.exec(root.savedText);
            root.value = found ? Number(found[3]) : root.defaultValue;
            root.loaded = true;
        }
        onLoadFailed: err => {
            // hyprland.lua creates it as `return {}` on the next start, so there is nothing to
            // preserve and nothing to read a value out of
            if (err === FileViewError.FileNotFound) {
                root.savedText = "";
                root.value = root.defaultValue;
                root.loaded = true;
            }
        }
    }
}
