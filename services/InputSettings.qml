pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.services
import qs.utils

// NOTE(fork): mouse, scroll and touchpad options live in Hyprland, and changing them from Nexus
// is a runtime keyword, which is forgotten the moment the config is reloaded or the session
// restarts. Anything changed here is therefore both applied straight away and written into
// ~/.config/caelestia/hypr-user.lua, the user config the dots' hyprland.lua requires last - that
// is what makes the choices survive a reboot. Only the options that were actually touched are
// written, so everything else in the user's own hyprland config still wins.
Singleton {
    id: root

    readonly property string sensitivityKey: "input:sensitivity"
    readonly property string accelProfileKey: "input:accel_profile"
    readonly property string forceNoAccelKey: "input:force_no_accel"
    readonly property string scrollFactorKey: "input:scroll_factor"
    readonly property string touchpadScrollFactorKey: "input:touchpad:scroll_factor"
    readonly property string naturalScrollKey: "input:touchpad:natural_scroll"

    // Sourced last by ~/.config/hypr/hyprland.lua, and created empty by it if it is missing
    readonly property string configPath: `${Paths.config}/hypr-user.lua`

    // Kept in memory while a slider is dragged so the UI follows it. Applying makes the shell
    // re-read every Hyprland option, so it is only done once the value settles rather than on
    // every mouse move.
    property var overrides: ({})
    // The config file as it is on disk, so the managed block can be rewritten without touching
    // anything else the user has in there
    property string savedText: ""
    property bool loaded: false
    // The managed block parsed back off disk. overrides only ever holds what was changed in this
    // session, and a write replaces the whole block, so without this a setting changed today
    // would delete every setting made before the last restart - which is what stopped these
    // surviving a reboot.
    property var fileOverrides: ({})

    readonly property real sensitivity: root.current(root.sensitivityKey, 0)
    readonly property string accelProfile: root.current(root.accelProfileKey, "")
    readonly property real scrollFactor: root.current(root.scrollFactorKey, 1)
    readonly property real touchpadScrollFactor: root.current(root.touchpadScrollFactorKey, 1)
    readonly property bool naturalScroll: root.current(root.naturalScrollKey, false)

    // The override if the option was changed here, otherwise whatever Hyprland reports
    function current(key: string, fallback: var): var {
        return root.overrides[key] ?? Hypr.options[key] ?? fallback;
    }

    function set(key: string, value: var): void {
        const next = Object.assign({}, root.overrides);
        next[key] = value;
        root.overrides = next;
        commitTimer.restart();
    }

    // Acceleration is two Hyprland options: the profile, and the flag that switches acceleration
    // off outright. A config that pins force_no_accel - the dots' own user config does - would
    // otherwise ignore whatever the profile says, so both move with the switch.
    function setAccel(enabled: bool): void {
        root.set(root.accelProfileKey, enabled ? "adaptive" : "flat");
        root.set(root.forceNoAccelKey, !enabled);
    }

    function apply(): void {
        if (Object.keys(root.overrides).length > 0)
            Hypr.extras.applyOptions(root.overrides);
    }

    function commit(): void {
        props.overrides = root.overrides;
        root.apply();
        root.write();
    }

    readonly property string blockStart: "-- >>> caelestia input settings"
    readonly property string blockEnd: "-- <<< caelestia input settings"

    // "input:touchpad:scroll_factor" -> { input: { touchpad: { scroll_factor: ... } } }, which is
    // the table shape hl.config takes and the same one Hypr.extras builds for its own eval
    function nest(overrides: var): var {
        const nested = {};
        for (const key in overrides) {
            const parts = key.split(":");
            let node = nested;
            for (let i = 0; i < parts.length - 1; i++) {
                if (!node[parts[i]])
                    node[parts[i]] = {};
                node = node[parts[i]];
            }
            node[parts[parts.length - 1]] = overrides[key];
        }
        return nested;
    }

    // Lua strings are quoted, everything else is written as it is, so true/false and numbers
    // land in the config as the types Hyprland expects
    function luaValue(value: var): string {
        if (typeof value === "string")
            return `"${value.replace(/\\/g, "\\\\").replace(/"/g, "\\\"")}"`;
        return String(value);
    }

    function luaTable(table: var, indent: string): string {
        // Sorted, so the block comes out the same no matter which settings were moved in what
        // order and a change only ever touches the lines it has to
        return Object.keys(table).sort().map(key => {
            const value = table[key];
            if (value !== null && typeof value === "object")
                return `${indent}${key} = {\n${root.luaTable(value, indent + "    ")}\n${indent}},`;
            return `${indent}${key} = ${root.luaValue(value)},`;
        }).join("\n");
    }

    // Reads a value back out of the block exactly as luaValue() wrote it
    function parseLuaValue(raw: string): var {
        const value = raw.trim();
        if (value === "true")
            return true;
        if (value === "false")
            return false;
        if (/^".*"$/.test(value))
            return value.slice(1, -1).replace(/\\"/g, "\"").replace(/\\\\/g, "\\");
        const num = Number(value);
        return value !== "" && Number.isFinite(num) ? num : value;
    }

    // The block is written by block() below, so its shape is known exactly: an hl.config({ ... })
    // wrapper around nested `key = {` tables and `key = value,` leaves. Parsed back into the flat
    // "input:touchpad:scroll_factor" keys that set() and Hypr.extras.applyOptions() both use.
    function parseBlock(text: string): var {
        const start = text.indexOf(root.blockStart);
        if (start === -1)
            return ({});
        const end = text.indexOf(root.blockEnd, start);
        if (end === -1)
            return ({});

        const parsed = {};
        const path = [];
        for (const raw of text.slice(start + root.blockStart.length, end).split("\n")) {
            const line = raw.trim();
            if (line === "" || line.startsWith("--") || line.startsWith("hl.config") || line === "})")
                continue;
            if (line === "}," || line === "}") {
                path.pop();
                continue;
            }

            const open = /^([A-Za-z_][A-Za-z0-9_]*)\s*=\s*\{$/.exec(line);
            if (open) {
                path.push(open[1]);
                continue;
            }

            const leaf = /^([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*?),?$/.exec(line);
            if (leaf)
                parsed[path.concat(leaf[1]).join(":")] = root.parseLuaValue(leaf[2]);
        }
        return parsed;
    }

    // What the block already held, with this session's changes on top
    function merged(): var {
        return Object.assign({}, root.fileOverrides, root.overrides);
    }

    function block(): string {
        return `${root.blockStart}\nhl.config({\n${root.luaTable(root.nest(root.merged()), "    ")}\n})\n${root.blockEnd}\n`;
    }

    // Appended to the end of the file, so it is read after whatever the user wrote there and wins
    // for the options it names. The previous block is matched by its markers and replaced, so
    // changing a setting twice does not leave two of them behind.
    function replaced(text: string): string {
        const body = text.replace(/-- >>> caelestia input settings[\s\S]*?-- <<< caelestia input settings\n?/g, "").replace(/\s+$/, "");
        return `${body}${body ? "\n\n" : ""}${root.block()}`;
    }

    function write(): void {
        // Without the file's own contents a write would throw the user's config away, and an
        // empty override set would leave an empty - and broken - block behind
        if (!root.loaded || Object.keys(root.overrides).length === 0)
            return;

        const next = root.replaced(root.savedText);
        // Rewriting identical content would only churn the file
        if (next !== root.savedText)
            storage.setText(next);
    }

    Timer {
        id: commitTimer

        interval: 150
        onTriggered: root.commit()
    }

    Connections {
        function onConfigReloaded(): void {
            // A reload puts the config file's own values back, so anything changed here that has
            // not been written down yet would be lost without this
            root.apply();
        }

        target: Hypr
    }

    FileView {
        id: storage

        path: root.configPath
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            root.savedText = text();
            root.fileOverrides = root.parseBlock(root.savedText);
            root.loaded = true;
            // Anything changed before this could be written down lands in the config now
            root.write();
        }
        onLoadFailed: err => {
            // The dots create the file on the next Hyprland start, so there is nothing to
            // preserve - only the block to add
            if (err === FileViewError.FileNotFound) {
                root.savedText = "";
                root.fileOverrides = ({});
                root.loaded = true;
                root.write();
            }
        }
    }

    PersistentProperties {
        id: props

        property var overrides: ({})

        reloadableId: "inputSettings"
    }
}
