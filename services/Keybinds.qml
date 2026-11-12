pragma Singleton

import "../utils/keybinds.js" as Lua
import QtQuick
import Quickshell
import Quickshell.Io
import qs.utils

// NOTE(fork): the keybinds of the Hyprland Lua config, for the Keybinds page in Nexus. The
// defaults are the `kb*` variables in hypr/variables.lua and the user's own choices are the same
// variables in caelestia/hypr-vars.lua, which is the only file this ever writes (after keeping a
// copy of it the first time). Hyprland is reloaded so a change takes effect straight away.
Singleton {
    id: root

    readonly property string configHome: Quickshell.env("XDG_CONFIG_HOME") || `${Paths.home}/.config`
    readonly property string defaultsPath: `${root.configHome}/hypr/variables.lua`
    readonly property string overridesPath: `${Paths.config}/hypr-vars.lua`

    property string defaultsText
    property string overridesText

    // Every keybind in file order: { id, label, section, prefix, defaults, combos, overridden }
    readonly property var entries: {
        const overrides = {};
        for (const e of Lua.parse(root.overridesText))
            overrides[e.id] = e.combos;

        return Lua.parse(root.defaultsText).map(e => {
            const combos = overrides[e.id] ?? e.combos;
            // Bound under a modifier alone, then a number key: the modifiers are the setting
            const prefix = e.combos.length > 0 && e.combos.every(c => Lua.split(c).key === "");
            return {
                id: e.id,
                label: Lua.label(e.id),
                section: /^kb(GoToWs|MoveWinToWs)(Group)?$/.test(e.id) ? "Workspaces" : e.section,
                prefix,
                defaults: e.combos,
                combos,
                overridden: !Lua.sameCombos(combos, e.combos)
            };
        });
    }
    readonly property bool available: root.entries.length > 0

    // Arbitrary { combo, command } binds added from the settings page, on top of the fixed kb*
    // ids above - see the customBinds functions in keybinds.js for why they're parsed apart
    // from those. Pseudo-ids ("custom:0", "custom:1", ...) let them share the clash detection
    // below without needing a real id of their own; they're recomputed fresh each time, so
    // reordering or removing one is never stale.
    readonly property var customBinds: Lua.parseCustomBinds(root.overridesText)

    // { NORMALISED COMBO: [ids] } for the shortcuts two binds share, kb* ids and custom
    // pseudo-ids together so either kind can warn about clashing with the other
    readonly property var clashes: Lua.conflicts([...root.entries, ...root.customBinds.map((b, i) => ({
                    id: `custom:${i}`,
                    combos: [b.combo]
                }))])

    // Every bind that lands on a key of the keyboard view, grouped by the key it sits on. One
    // entry per shortcut rather than per bind, since a bind with three shortcuts sits on three
    // keys: { id, label, combo, mods, mask, key, kind, index, detail }, where kind is
    //   "bind"    a kb* id from variables.lua, index being which of its shortcuts this is
    //   "prefix"  a kb* id bound under modifiers alone, so it covers the digits 1-0
    //   "custom"  a { combo, command } pair from customBinds, index being its place in them
    readonly property var binds: {
        const byKey = {};
        const add = (key, bind) => {
            const k = Lua.normaliseKey(key);
            if (!byKey[k])
                byKey[k] = [];
            byKey[k].push(bind);
        };

        for (const e of root.entries) {
            e.combos.forEach((combo, index) => {
                const parts = Lua.split(combo);
                const mask = Lua.maskOf(parts.mods);
                if (parts.key === "") {
                    for (const digit of Lua.prefixDigits())
                        add(digit, {
                            id: e.id,
                            label: e.label,
                            combo,
                            mods: parts.mods,
                            mask,
                            key: digit,
                            kind: "prefix",
                            index,
                            detail: ""
                        });
                } else {
                    add(parts.key, {
                        id: e.id,
                        label: e.label,
                        combo,
                        mods: parts.mods,
                        mask,
                        key: parts.key,
                        kind: "bind",
                        index,
                        detail: ""
                    });
                }
            });
        }

        root.customBinds.forEach((b, index) => {
            const parts = Lua.split(b.combo);
            if (parts.key === "")
                return;
            add(parts.key, {
                id: `custom:${index}`,
                label: b.command,
                combo: b.combo,
                mods: parts.mods,
                mask: Lua.maskOf(parts.mods),
                key: parts.key,
                kind: "custom",
                index,
                detail: b.command
            });
        });

        return byKey;
    }

    // How many keys carry two binds under the same modifiers, for the keyboard's summary line
    readonly property int conflictCount: Object.keys(root.binds).filter(k => root.keyState(k, -1) === "conflict").length

    // Which other binds already use this shortcut, as display labels
    function usedBy(id: string, combo: string): list<string> {
        const ids = root.clashes[Lua.normalise(combo)] ?? [];
        return ids.filter(other => other !== id).map(other => other.startsWith("custom:") ? root.customBinds[Number(other.slice(7))]?.command ?? "" : Lua.label(other));
    }

    function addCustomBind(combo: string, command: string): void {
        root.write(Lua.withCustomBinds(root.overridesText, [...root.customBinds, {
                        combo,
                        command
                    }]));
    }

    function setCustomBind(index: int, combo: string, command: string): void {
        if (index < 0 || index >= root.customBinds.length)
            return;

        const next = [...root.customBinds];
        next[index] = {
            combo,
            command
        };
        root.write(Lua.withCustomBinds(root.overridesText, next));
    }

    function removeCustomBind(index: int): void {
        root.write(Lua.withCustomBinds(root.overridesText, root.customBinds.filter((_, i) => i !== index)));
    }

    // Touchpad gestures (hypr/hyprland/gestures.lua). The three built-in swipes' finger counts are
    // plain top-level variables, not kb* ids, so they go through numberVar/withNumberVar rather
    // than the entries/combos machinery above. Defaults come from the same defaultsText FileView
    // already loaded for the kb* ids.
    readonly property var gestureFingerDefaults: ({
            gestureFingers: Lua.numberVar(root.defaultsText, "gestureFingers") ?? 3,
            workspaceSwipeFingers: Lua.numberVar(root.defaultsText, "workspaceSwipeFingers") ?? 3,
            gestureFingersMore: Lua.numberVar(root.defaultsText, "gestureFingersMore") ?? 4
        })

    function gestureFingerCount(name: string): int {
        return Lua.numberVar(root.overridesText, name) ?? root.gestureFingerDefaults[name] ?? 3;
    }

    function gestureFingerOverridden(name: string): bool {
        return Lua.numberVar(root.overridesText, name) !== null;
    }

    function setGestureFingerCount(name: string, value: int): void {
        root.write(Lua.withNumberVar(root.overridesText, name, value === root.gestureFingerDefaults[name] ? null : value));
    }

    function resetGestureFingerCount(name: string): void {
        root.write(Lua.withNumberVar(root.overridesText, name, null));
    }

    // Arbitrary { fingers, direction, command } swipes added from the settings page - the gesture
    // equivalent of customBinds, in the same overrides file, with their own array since a swipe
    // has no key combo to live alongside
    readonly property var customGestures: Lua.parseCustomGestures(root.overridesText)

    function addCustomGesture(fingers: int, direction: string, command: string): void {
        root.write(Lua.withCustomGestures(root.overridesText, [...root.customGestures, {
                        fingers,
                        direction,
                        command
                    }]));
    }

    function setCustomGesture(index: int, fingers: int, direction: string, command: string): void {
        if (index < 0 || index >= root.customGestures.length)
            return;

        const next = [...root.customGestures];
        next[index] = {
            fingers,
            direction,
            command
        };
        root.write(Lua.withCustomGestures(root.overridesText, next));
    }

    function removeCustomGesture(index: int): void {
        root.write(Lua.withCustomGestures(root.overridesText, root.customGestures.filter((_, i) => i !== index)));
    }

    function pretty(combo: string): string {
        return Lua.pretty(combo);
    }

    function split(combo: string): var {
        return Lua.split(combo);
    }

    function join(mods: var, key: string): string {
        return Lua.join(mods, key);
    }

    function keyName(qtName: string, typed: string): string {
        return Lua.keyName(qtName, typed);
    }

    // Saves the new shortcuts for one keybind. Going back to the defaults removes the override.
    function set(id: string, combos: var): void {
        const entry = root.entries.find(e => e.id === id);
        if (!entry)
            return;

        const cleaned = combos.filter(c => c !== "");
        root.write(Lua.edit(root.overridesText, id, Lua.sameCombos(cleaned, entry.defaults) ? null : cleaned));
    }

    function reset(id: string): void {
        root.write(Lua.edit(root.overridesText, id, null));
    }

    // These modifiers as a bitmask, so the keyboard can compare shortcuts without caring which
    // order they were written in
    function maskOf(mods: var): int {
        return Lua.maskOf(mods);
    }

    // Every shortcut on one key of the keyboard view, whatever spelling the config used for it
    function forKey(key: string): var {
        return root.binds[Lua.normaliseKey(key)] ?? [];
    }

    // Only the shortcuts under exactly these modifiers; mask -1 means every combination
    function forKeyMasked(key: string, mask: int): var {
        return mask < 0 ? root.forKey(key) : root.forKey(key).filter(b => b.mask === mask);
    }

    // "free" (nothing on it), "bound", or "conflict": two binds under the same modifiers, which
    // Hyprland fires both of and is almost never what was meant
    function keyState(key: string, mask: int): string {
        const found = root.forKeyMasked(key, mask);
        if (found.length === 0)
            return "free";
        const masks = found.map(b => b.mask);
        return new Set(masks).size < masks.length ? "conflict" : "bound";
    }

    // How many different modifier combinations this key is bound under
    function comboCount(key: string, mask: int): int {
        return new Set(root.forKeyMasked(key, mask).map(b => b.mask)).size;
    }

    // What is already on this exact shortcut, so the keyboard can warn before adding to it
    function bindsOn(mods: var, key: string): var {
        const mask = Lua.maskOf(mods);
        return root.forKey(key).filter(b => b.mask === mask);
    }

    // Drops one of the shortcuts the keyboard shows, whichever kind it turned out to be
    function removeBind(bind: var): void {
        if (bind.kind === "custom") {
            root.removeCustomBind(bind.index);
            return;
        }

        const entry = root.entries.find(e => e.id === bind.id);
        if (!entry)
            return;

        root.set(bind.id, entry.combos.filter((_, i) => i !== bind.index));
    }

    // Gives a keybind that already exists another shortcut, ignoring one it already has
    function addToEntry(id: string, combo: string): void {
        const entry = root.entries.find(e => e.id === id);
        if (!entry || entry.combos.some(c => Lua.normalise(c) === Lua.normalise(combo)))
            return;

        root.set(id, [...entry.combos, combo]);
    }

    // Every kb* id back to its default, in one write so Hyprland reloads once rather than once
    // per bind. Custom binds and gestures are left alone: they have no default to go back to,
    // and throwing them away is not what resetting the shortcuts asks for.
    function resetAll(): void {
        let text = root.overridesText;
        for (const e of root.entries)
            if (e.overridden)
                text = Lua.edit(text, e.id, null);
        root.write(text);
    }

    // Re-reads both files and has Hyprland pick the binds up again
    function reload(): void {
        defaultsFile.reload();
        overridesFile.reload();
        reloadTimer.restart();
    }

    function write(text: string): void {
        if (text === root.overridesText)
            return;

        // The first change keeps the file as it was
        Quickshell.execDetached(["cp", "-n", root.overridesPath, `${root.overridesPath}.bak-keybinds`]);
        root.overridesText = text;
        overridesFile.setText(text);
        reloadTimer.restart();
    }

    Timer {
        id: reloadTimer

        interval: 600
        onTriggered: Quickshell.execDetached(["hyprctl", "reload"])
    }

    FileView {
        id: defaultsFile

        path: root.defaultsPath
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.defaultsText = text()
    }

    FileView {
        id: overridesFile

        path: root.overridesPath
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.overridesText = text()
        // No file yet: nothing is overridden
        onLoadFailed: root.overridesText = ""
    }
}
