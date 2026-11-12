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

// Custom binds: an arbitrary { combo, command } list a user can add from the Keybinds page,
// unlike everything above which rebinds a fixed id that already exists in variables.lua. Kept
// as its own `customBinds = { {...}, {...} }` array in the overrides file rather than a kb*
// assignment, since the `assignment` regex above only ever matches a single-level value and
// these need one entry per bind. Parsed and written with their own small brace-aware scanner,
// rather than the `assignment`/`values` regexes, because a shell command can itself contain
// quotes or braces that those would trip over.

// text[i] is the opening quote; returns { value, end } (end is just past the closing quote),
// or null if the string never closes
function stringLiteral(text, i) {
    const quote = text[i];
    let out = "";
    let j = i + 1;
    while (j < text.length) {
        const c = text[j];
        if (c === "\\" && j + 1 < text.length) {
            out += text[j + 1];
            j += 2;
            continue;
        }
        if (c === quote)
            return {
                value: out,
                end: j + 1
            };
        out += c;
        j++;
    }
    return null;
}

// The `name = { ... }` block's inner text (between its braces), skipping past any brace that
// turns up inside a quoted string rather than counting it
function findBlock(text, name) {
    const m = text.match(new RegExp(`[ \\t]*${name}[ \\t]*=[ \\t]*\\{`));
    if (!m)
        return null;

    let i = m.index + m[0].length;
    let depth = 1;
    while (i < text.length && depth > 0) {
        const c = text[i];
        if (c === "\"" || c === "'") {
            const lit = stringLiteral(text, i);
            i = lit ? lit.end : i + 1;
            continue;
        }
        if (c === "{")
            depth++;
        else if (c === "}")
            depth--;
        i++;
    }
    if (depth !== 0)
        return null;
    return {
        content: text.slice(m.index + m[0].length, i - 1),
        from: m.index,
        to: i
    };
}

// Every top-level `{ ... }` entry inside a block's content, same brace/quote awareness as above
function splitEntries(content) {
    const entries = [];
    let i = 0;
    while (i < content.length) {
        if (content[i] === "{") {
            const start = i;
            let depth = 1;
            i++;
            while (i < content.length && depth > 0) {
                const c = content[i];
                if (c === "\"" || c === "'") {
                    const lit = stringLiteral(content, i);
                    i = lit ? lit.end : i + 1;
                    continue;
                }
                if (c === "{")
                    depth++;
                else if (c === "}")
                    depth--;
                i++;
            }
            entries.push(content.slice(start, i));
        } else {
            i++;
        }
    }
    return entries;
}

// The string value of `key = "..."` or `key = '...'` inside one entry's text
function field(entryText, key) {
    const m = entryText.match(new RegExp(`${key}[ \\t]*=[ \\t]*(["'])`));
    if (!m)
        return "";
    const lit = stringLiteral(entryText, m.index + m[0].length - 1);
    return lit ? lit.value : "";
}

// Every customBinds entry in file order: [{ combo, command }]
function parseCustomBinds(text) {
    const block = findBlock(text, "customBinds");
    if (!block)
        return [];

    const entries = [];
    for (const entryText of splitEntries(block.content)) {
        const combo = field(entryText, "combo");
        const command = field(entryText, "command");
        if (combo && command)
            entries.push({
                combo,
                command
            });
    }
    return entries;
}

function customBindLiteral(entry) {
    const escape = s => s.replace(/\\/g, "\\\\").replace(/"/g, "\\\"");
    return `{ combo = "${escape(entry.combo)}", command = "${escape(entry.command)}" }`;
}

// The overrides text with customBinds set to these entries, removed entirely when empty
function withCustomBinds(text, entries) {
    const block = findBlock(text, "customBinds");
    let base = text.trim() === "" ? "return {\n}\n" : text;

    if (block) {
        // Also drop a trailing comma right after the block and the blank line that leaves,
        // so removing the last entry doesn't leave one dangling before the closing brace
        const afterComma = base.slice(block.to).match(/^[ \t]*,?/)[0].length;
        base = base.slice(0, block.from) + base.slice(block.to + afterComma);
        base = base.replace(/\n[ \t]*\n/g, "\n");
    }

    if (entries.length === 0)
        return base;

    const lines = entries.map(e => `\t\t${customBindLiteral(e)},`).join("\n");
    const line = `\tcustomBinds = {\n${lines}\n\t},`;

    const lines2 = base.split("\n");
    const at = lines2.findIndex(l => /^\s*return\s*\{/.test(l));
    if (at < 0)
        return base;

    lines2.splice(at + 1, 0, line);
    return lines2.join("\n");
}

// Gestures: a touchpad swipe mapped to a command, the gesture equivalent of customBinds -
// { fingers, direction, command } instead of { combo, command }. Same block/entry scanner, since
// a command can just as easily contain quotes or braces here too.

// The numeric value of `key = <number>` inside one entry's text
function numberField(entryText, key) {
    const m = entryText.match(new RegExp(`${key}[ \\t]*=[ \\t]*(-?\\d+(?:\\.\\d+)?)`));
    return m ? Number(m[1]) : null;
}

// Every customGestures entry in file order: [{ fingers, direction, command }]
function parseCustomGestures(text) {
    const block = findBlock(text, "customGestures");
    if (!block)
        return [];

    const entries = [];
    for (const entryText of splitEntries(block.content)) {
        const fingers = numberField(entryText, "fingers");
        const direction = field(entryText, "direction");
        const command = field(entryText, "command");
        if (fingers && direction && command)
            entries.push({
                fingers,
                direction,
                command
            });
    }
    return entries;
}

function customGestureLiteral(entry) {
    const escape = s => s.replace(/\\/g, "\\\\").replace(/"/g, "\\\"");
    return `{ fingers = ${Math.round(entry.fingers)}, direction = "${escape(entry.direction)}", command = "${escape(entry.command)}" }`;
}

// The overrides text with customGestures set to these entries, removed entirely when empty
function withCustomGestures(text, entries) {
    const block = findBlock(text, "customGestures");
    let base = text.trim() === "" ? "return {\n}\n" : text;

    if (block) {
        const afterComma = base.slice(block.to).match(/^[ \t]*,?/)[0].length;
        base = base.slice(0, block.from) + base.slice(block.to + afterComma);
        base = base.replace(/\n[ \t]*\n/g, "\n");
    }

    if (entries.length === 0)
        return base;

    const lines = entries.map(e => `\t\t${customGestureLiteral(e)},`).join("\n");
    const line = `\tcustomGestures = {\n${lines}\n\t},`;

    const lines2 = base.split("\n");
    const at = lines2.findIndex(l => /^\s*return\s*\{/.test(l));
    if (at < 0)
        return base;

    lines2.splice(at + 1, 0, line);
    return lines2.join("\n");
}

// A plain `name = <number>` top-level assignment, unlike the kb*-prefixed ones above - used for
// the touchpad gesture finger counts (gestureFingers, workspaceSwipeFingers, gestureFingersMore),
// which aren't kb* ids and aren't combo strings
function numberVar(text, name) {
    const m = text.match(new RegExp(`[ \\t]*${name}[ \\t]*=[ \\t]*(-?\\d+(?:\\.\\d+)?)`));
    return m ? Number(m[1]) : null;
}

// The overrides text with that variable set to this value, or removed (back to the default) when
// value is null. Only that line is touched, same as edit() above.
function withNumberVar(text, name, value) {
    let base = text.trim() === "" ? "return {\n}\n" : text;
    const re = new RegExp(`^[ \\t]*${name}[ \\t]*=[ \\t]*-?\\d+(?:\\.\\d+)?[ \\t]*,?[ \\t]*(?:--.*)?$`, "m");

    if (value === null)
        return base.replace(re, "").replace(/\n[ \t]*\n/g, "\n");

    const line = `\t${name} = ${value},`;
    if (re.test(base))
        return base.replace(re, line);

    const lines = base.split("\n");
    const at = lines.findIndex(l => /^\s*return\s*\{/.test(l));
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

// The keyboard view (modules/nexus/pages/KeyboardMap.qml) needs to match a key drawn on its
// keyboard against the key half of a combo, and those two are not spelt the same way: the
// drawing uses one fixed name per key while a config may use any of the names X11 and Hyprland
// accept for it ("Return" or "Enter", "Page_Up" or "Prior"). Both sides go through this.
const keyAliases = {
    enter: "return",
    esc: "escape",
    prior: "page_up",
    pgup: "page_up",
    pageup: "page_up",
    next: "page_down",
    pgdn: "page_down",
    pagedown: "page_down",
    del: "delete",
    ins: "insert",
    backtick: "grave",
    quoteleft: "grave",
    super: "super_l",
    meta: "super_l",
    mod4: "super_l",
    win: "super_l",
    control: "control_l",
    ctrl: "control_l",
    alt: "alt_l",
    shift: "shift_l",
    caps: "caps_lock",
    capslock: "caps_lock",
    sysrq: "print",
    scrolllock: "scroll_lock",
    numlock: "num_lock"
};

// The one name a key answers to, whichever of its spellings was written
function normaliseKey(key) {
    const k = String(key ?? "").trim().toLowerCase();
    return keyAliases[k] ?? k;
}

// The modifiers as a bitmask, so two combos on the same key can be compared without
// worrying about the order they were written in
const modBits = {
    SUPER: 1,
    CTRL: 2,
    ALT: 4,
    SHIFT: 8
};

function maskOf(mods) {
    let mask = 0;
    for (const m of mods)
        mask |= modBits[String(m).toUpperCase()] ?? 0;
    return mask;
}

// The digits a modifier-only prefix ("SUPER", with the real binds being SUPER + 0-9) covers
function prefixDigits() {
    return ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"];
}
