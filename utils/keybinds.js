.pragma library

// Reading and editing the `kb*` keybind variables of the Hyprland Lua config: the defaults in
// hypr/variables.lua and the user's overrides in caelestia/hypr-vars.lua. Pure functions on text,
// so the edits can be checked without a running shell.

const modifierNames = ["SUPER", "CTRL", "ALT", "SHIFT"];

// One `kbName = "SUPER + X"` or `kbName = { "a", "b" }` assignment
const assignment = /^[ \t]*(kb\w+)[ \t]*=[ \t]*(\{[^}]*\}|"[^"]*"|'[^']*')[ \t]*,?[ \t]*(?:--.*)?$/;

function values(source) {
    const found = [];
    const strings = /"([^"]*)"|'([^']*)'/g;
    let m;
    while ((m = strings.exec(source)) !== null)
        found.push(m[1] ?? m[2]);
    return found;
}

// Every kb variable in file order: [{ id, section, combos }]
function parse(text) {
    const entries = [];
    let section = "";
    for (const line of text.split("\n")) {
        const heading = line.match(/^[ \t]*--[ \t]+([A-Za-z][^-\n]*?)[ \t]*$/);
        if (heading) {
            section = heading[1];
            continue;
        }

        const m = line.match(assignment);
        if (m)
            entries.push({
                id: m[1],
                section,
                combos: values(m[2])
            });
    }
    return entries;
}

// "kbMoveWinToWsNext" -> "Move window to workspace next", with the usual abbreviations spelt out
function label(id) {
    const spelt = {
        Ws: "workspace",
        Win: "window",
        Del: "delete",
        Pip: "picture-in-picture",
        Color: "colour"
    };
    const words = id.replace(/^kb/, "").replace(/([a-z0-9])([A-Z])/g, "$1 $2").split(" ").map(w => spelt[w] ?? w.toLowerCase());
    const text = words.join(" ");
    return text.charAt(0).toUpperCase() + text.slice(1);
}

// "SUPER + SHIFT + F" -> { mods: ["SUPER", "SHIFT"], key: "F" }. A combo made only of
// modifiers ("SUPER") has an empty key: it is the prefix the number keys are bound under.
function split(combo) {
    const parts = combo.split("+").map(p => p.trim()).filter(p => p !== "");
    if (parts.length === 0)
        return {
            mods: [],
            key: ""
        };

    const last = parts[parts.length - 1];
    if (parts.every(p => modifierNames.includes(p.toUpperCase())))
        return {
            mods: parts.map(p => p.toUpperCase()),
            key: ""
        };

    return {
        mods: parts.slice(0, -1).map(p => p.toUpperCase()),
        key: last
    };
}

function join(mods, key) {
    const ordered = modifierNames.filter(m => mods.includes(m));
    return key ? [...ordered, key].join(" + ") : ordered.join(" + ");
}

// The same shortcut whatever the order or case it was written in
function normalise(combo) {
    const s = split(combo);
    return join(s.mods, s.key.toUpperCase());
}

// "SUPER + SHIFT + F" -> "Super + Shift + F"
function pretty(combo) {
    const s = split(combo);
    const mods = modifierNames.filter(m => s.mods.includes(m)).map(m => m.charAt(0) + m.slice(1).toLowerCase());
    const key = s.key.replace(/^mouse_down$/i, "Scroll down").replace(/^mouse_up$/i, "Scroll up").replace(/^mouse:272$/, "Left click").replace(/^mouse:273$/, "Right click").replace(/_/g, " ");
    const shown = key.length === 1 ? key.toUpperCase() : key.charAt(0).toUpperCase() + key.slice(1);
    return [...mods, ...(key ? [shown] : [])].join(" + ");
}

function sameCombos(a, b) {
    return a.length === b.length && a.every((c, i) => normalise(c) === normalise(b[i]));
}

function literal(combos) {
    const quoted = combos.map(c => `"${c.replace(/\\/g, "\\\\").replace(/"/g, "\\\"")}"`);
    return quoted.length === 1 ? quoted[0] : `{ ${quoted.join(", ")} }`;
}

function withoutAssignment(text, id) {
    return text.split("\n").filter(line => line.match(assignment)?.[1] !== id).join("\n");
}

// The overrides text with `id` set to these combos, or back to its default when combos is null.
// Only that variable's own line is touched, so anything else in the file is left as it was.
function edit(text, id, combos) {
    let base = text.trim() === "" ? "return {\n}\n" : text;
    base = withoutAssignment(base, id);
    if (combos === null)
        return base;

    const line = `\t${id} = ${literal(combos)},`;
    const lines = base.split("\n");
    // Beside the other kb lines if there are any, otherwise straight after `return {`
    let at = -1;
    lines.forEach((l, i) => {
        if (l.match(assignment))
            at = i;
    });
    if (at < 0)
        at = lines.findIndex(l => /^\s*return\s*\{/.test(l));
    if (at < 0)
        return base;

    lines.splice(at + 1, 0, line);
    return lines.join("\n");
}

// Groups the entries by the shortcut they share: { NORMALISED: [id, ...] } for the clashes only
function conflicts(entries) {
    const byCombo = {};
    for (const e of entries) {
        for (const c of e.combos) {
            const s = split(c);
            // A prefix on its own binds the number keys, not the modifier itself
            if (s.key === "")
                continue;
            const k = normalise(c);
            if (!byCombo[k])
                byCombo[k] = [];
            byCombo[k].push(e.id);
        }
    }

    const clashes = {};
    for (const key of Object.keys(byCombo)) {
        const ids = [...new Set(byCombo[key])];
        if (ids.length > 1)
            clashes[key] = ids;
    }
    return clashes;
}

const keyNames = {
    Return: "RETURN",
    Enter: "RETURN",
    Space: "Space",
    Tab: "TAB",
    Backtab: "TAB",
    Escape: "Escape",
    Backspace: "Backspace",
    Delete: "Delete",
    Insert: "Insert",
    Home: "Home",
    End: "End",
    PageUp: "Page_Up",
    PageDown: "Page_Down",
    Up: "Up",
    Down: "Down",
    Left: "Left",
    Right: "Right",
    Minus: "Minus",
    Equal: "Equal",
    Plus: "Equal",
    Comma: "Comma",
    Period: "Period",
    Slash: "Slash",
    Backslash: "Backslash",
    Semicolon: "Semicolon",
    Apostrophe: "Apostrophe",
    BracketLeft: "Bracketleft",
    BracketRight: "Bracketright",
    QuoteLeft: "Grave",
    Print: "Print",
    Pause: "Pause",
    VolumeUp: "XF86AudioRaiseVolume",
    VolumeDown: "XF86AudioLowerVolume",
    VolumeMute: "XF86AudioMute",
    MediaPlay: "XF86AudioPlay",
    MediaTogglePlayPause: "XF86AudioPlay",
    MediaPause: "XF86AudioPause",
    MediaStop: "XF86AudioStop",
    MediaNext: "XF86AudioNext",
    MediaPrevious: "XF86AudioPrev",
    MonBrightnessUp: "XF86MonBrightnessUp",
    MonBrightnessDown: "XF86MonBrightnessDown"
};

// Hyprland's name for a key, from Qt's name for it ("PageUp") and what it typed ("a")
function keyName(qtName, typed) {
    if (qtName in keyNames)
        return keyNames[qtName];
    if (/^F\d{1,2}$/.test(qtName))
        return qtName;
    if (qtName.length === 1 && /[A-Za-z0-9]/.test(qtName))
        return qtName.toUpperCase();
    if (typed && typed.length === 1 && /[A-Za-z0-9]/.test(typed))
        return typed.toUpperCase();
    return "";
}
