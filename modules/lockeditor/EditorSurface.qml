pragma ComponentBehavior: Bound

import "../../utils/widgetgrid.js" as WidgetGrid
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.services
import qs.modules.lock.canvas

// NOTE(fork): the lock screen editor itself. The side panel is docked along one edge and the bar
// along the top, and the lock screen is shown as a picture of the whole screen in the space they
// leave, scaled to fit, so neither ever covers any of it. Press an element to pick it up and drag
// it; it is pulled onto the edges and middles of the other elements, the screen's middle and
// margins and the grid as it comes near them, and the guide it lines up with is drawn. Pull the
// round corner of the selected one to resize it. The bar adds elements, starts over from a
// preset, undoes, mirrors and saves, and the side panel has everything else about the selected
// element.
//
// Positions in here are in the screen's own pixels (the stage is the screen's size, scaled), so
// what's saved doesn't depend on how big the editor happens to draw it.
//
// Changes are made to a copy and only written to Config.lock.elements on Save, so the editor can
// be left without keeping anything
Item {
    id: root

    // The working copy, as plain objects (LockPresets.plain)
    property var elements: LockPresets.effective(GlobalConfig.lock)

    // The element the side panel edits: the one last clicked
    property int selected: -1
    // Everything picked, the selected one among them: several can be picked by Shift+clicking or
    // by dragging a box over them on empty space, and picking one member of a group picks the lot.
    // They move, nudge, mirror, align, copy and go together
    property var selection: []
    // The element whose row in the side panel's list is under the pointer, outlined on the screen
    property int hovered: -1

    property var undoStack: []

    property var redoStack: []

    property bool dirty: false

    // Elements are pulled onto guides, each other and the grid while this is on
    property bool snap: true

    // Which side of a curtain to show: "" both, "rest" or "active"
    property string phase: ""

    property bool inspectorOnLeft: false

    property bool inspectorShown: true

    // "", "add" or "presets": which sheet is open over the editor
    property string sheet: ""

    property bool confirmingDiscard: false

    // A plugin built before elements existed has nowhere to save them
    readonly property bool canSave: !!GlobalConfig.lock.elements

    readonly property bool hasCurtain: root.elements.some(e => (e.showOn ?? "always") !== "always")

    // Only with one element picked: with several the side panel shows what can be done to them all
    readonly property var selectedElement: root.selection.length === 1 && root.selected >= 0 ? root.elements[root.selected] ?? null : null
    readonly property bool multiple: root.selection.length > 1
    // The box round everything picked, in screen pixels, following a drag in progress
    readonly property rect selectionBox: root.boxOf(root.selection)

    readonly property real uiScale: canvas.uiScale

    // How the editor is laid out: the side panel, the bar, and the stage in what's left
    readonly property real gap: Tokens.padding.large
    readonly property real inspectorWidth: Math.min(380, root.width * 0.26)
    readonly property real areaLeft: root.inspectorShown && root.inspectorOnLeft ? root.gap * 2 + root.inspectorWidth : root.gap
    readonly property real areaRight: root.inspectorShown && !root.inspectorOnLeft ? root.width - root.gap * 2 - root.inspectorWidth : root.width - root.gap
    readonly property real areaTop: toolbar.y + toolbar.height + root.gap
    readonly property real areaBottom: root.height - root.gap
    // How big the screen is drawn: as big as fits in the space left
    readonly property real zoom: Math.max(0.1, Math.min((root.areaRight - root.areaLeft) / Math.max(1, root.width), (root.areaBottom - root.areaTop) / Math.max(1, root.height)))

    // The grid: the desktop widgets' own square one (utils/widgetgrid.js), drawn every cell, with
    // elements stepping along it every half cell
    readonly property real cell: WidgetGrid.unit
    readonly property real step: WidgetGrid.unit / 2
    // How near, on the screen as drawn, an edge has to come to another element, the middle or a
    // margin to be caught by it
    readonly property real catchDistance: 14 / root.zoom

    // The lines a drag is lined up with right now, in screen pixels, or -1
    property real guideX: -1

    property real guideY: -1

    // The last change made through a slider, so a slider dragged across its range is one undo step
    // rather than one per position it passed through
    property string lastChangeKey

    property real lastChangeAt

    signal closed

    // Picking an element another way (the list, a new one, undo) picks its group along with it
    onSelectedChanged: {
        if (root.selected < 0) {
            if (root.selection.length > 0)
                root.selection = [];
        } else if (!root.selection.includes(root.selected)) {
            root.selection = root.groupOf(root.selected);
        }
    }

    // ---- Picking ----

    // The element and the rest of its group, if it's in one
    function groupOf(index: int): var {
        const g = root.elements[index]?.options?.group ?? "";
        if (g === "")
            return [index];
        const out = [];
        root.elements.forEach((e, i) => {
            if ((e.options?.group ?? "") === g)
                out.push(i);
        });
        return out;
    }

    // Picks an element and its group; with `add`, adds them to what's picked, or takes them out if
    // they're in it already
    function pick(index: int, add: bool): void {
        const members = root.groupOf(index);
        if (!add) {
            root.selection = members;
            root.selected = index;
            return;
        }
        const inAlready = root.selection.includes(index);
        const next = inAlready ? root.selection.filter(i => !members.includes(i)) : [...root.selection, ...members.filter(i => !root.selection.includes(i))];
        root.selection = next;
        root.selected = inAlready ? (next[next.length - 1] ?? -1) : index;
    }

    // Picks just this one, leaving the rest of its group, to change it on its own
    function pickOnly(index: int): void {
        root.selection = [index];
        root.selected = index;
    }

    function pickAll(): void {
        const all = [];
        root.elements.forEach((e, i) => {
            const h = canvas.hostAt(i);
            if (e.enabled !== false && h && h.shown > 0.5)
                all.push(i);
        });
        root.selection = all;
        root.selected = all[all.length - 1] ?? -1;
    }

    function clearPick(): void {
        root.selection = [];
        root.selected = -1;
    }

    // The box round some elements, in screen pixels
    function boxOf(indices: var): rect {
        let l = Infinity, t = Infinity, r = -Infinity, b = -Infinity;
        for (const i of indices) {
            const h = canvas.hostAt(i);
            if (!h || root.elements[i]?.enabled === false)
                continue;
            l = Math.min(l, h.x);
            t = Math.min(t, h.y);
            r = Math.max(r, h.x + h.width);
            b = Math.max(b, h.y + h.height);
        }
        return l === Infinity ? Qt.rect(0, 0, 0, 0) : Qt.rect(l, t, r - l, b - t);
    }

    // ---- Changing everything picked at once ----

    // Moves what's picked one way with the arrow keys: onto the next grid step that way while
    // snapping is on (ten pixels while it's off), or a single pixel `fine` (Shift). Kept on the
    // screen, and one undo step for a run of presses
    function nudge(dx: int, dy: int, fine: bool): void {
        if (root.selection.length === 0)
            return;
        const box = root.selectionBox;
        const next = (at, dir) => {
            if (fine)
                return at + dir;
            if (!root.snap)
                return at + dir * 10;
            const k = at / root.step;
            return (dir > 0 ? Math.floor(k + 1e-6) + 1 : Math.ceil(k - 1e-6) - 1) * root.step;
        };
        let mx = dx !== 0 ? next(box.x, dx) - box.x : 0;
        let my = dy !== 0 ? next(box.y, dy) - box.y : 0;
        mx = Math.max(0, Math.min(root.width - box.width, box.x + mx)) - box.x;
        my = Math.max(0, Math.min(root.height - box.height, box.y + my)) - box.y;
        if (mx !== 0 || my !== 0)
            root.moveBy(root.selection, mx, my, "nudge");
    }

    // Where an element goes for its box's top-left corner to be at (left, top)
    function placeAt(index: int, left: real, top: real): var {
        const h = canvas.hostAt(index);
        return {
            x: (left + h.ax * h.width) / root.width,
            y: (top + h.ay * h.height) / root.height
        };
    }

    // Moves elements by (dx, dy) screen pixels, as one change
    function moveBy(indices: var, dx: real, dy: real, key): void {
        const next = root.elements.slice();
        for (const i of indices)
            next[i] = Object.assign({}, next[i], {
                x: next[i].x + dx / root.width,
                y: next[i].y + dy / root.height
            });
        root.commit(next, key ?? "");
    }

    function removeSelection(): void {
        const gone = root.selection.filter(i => root.elements[i]?.id !== "password");
        if (gone.length === 0)
            return;
        root.commit(root.elements.filter((_, i) => !gone.includes(i)));
        root.clearPick();
    }

    // Copies of everything picked, a little down and to the right, picked in their place. Copies
    // of a group make a group of their own
    function duplicateSelection(): void {
        const from = root.selection.filter(i => root.elements[i]?.id !== "password").sort((a, b) => a - b);
        if (from.length === 0)
            return;
        const renamed = {};
        const copies = from.map(i => {
            const copy = JSON.parse(JSON.stringify(root.elements[i]));
            copy.x = Math.min(1, copy.x + 0.02);
            copy.y = Math.min(1, copy.y + 0.02);
            const g = copy.options?.group ?? "";
            if (g !== "") {
                renamed[g] = renamed[g] ?? `g${Date.now().toString(36)}${Object.keys(renamed).length}`;
                copy.options.group = renamed[g];
            }
            return copy;
        });
        const start = root.elements.length;
        root.commit([...root.elements, ...copies]);
        root.selection = copies.map((_, k) => start + k);
        root.selected = start + copies.length - 1;
    }

    // Puts everything picked in one group, so it's picked and moved as one from then on
    function groupSelection(): void {
        if (root.selection.length < 2)
            return;
        const id = `g${Date.now().toString(36)}`;
        const next = root.elements.slice();
        for (const i of root.selection)
            next[i] = Object.assign({}, next[i], {
                options: Object.assign({}, next[i].options ?? {}, {
                    group: id
                })
            });
        root.commit(next);
    }

    function ungroupSelection(): void {
        const next = root.elements.slice();
        for (const i of root.selection) {
            const options = Object.assign({}, next[i].options ?? {});
            delete options.group;
            next[i] = Object.assign({}, next[i], {
                options: options
            });
        }
        root.commit(next);
    }

    readonly property bool selectionGrouped: root.selection.some(i => (root.elements[i]?.options?.group ?? "") !== "")

    // A panel and everything sitting wholly on it, as one group
    function groupWithContents(index: int): void {
        const p = canvas.hostAt(index);
        if (!p)
            return;
        const inside = [index];
        root.elements.forEach((e, i) => {
            const h = canvas.hostAt(i);
            if (i === index || !h || e.enabled === false)
                return;
            if (h.x >= p.x - 1 && h.y >= p.y - 1 && h.x + h.width <= p.x + p.width + 1 && h.y + h.height <= p.y + p.height + 1)
                inside.push(i);
        });
        root.selection = inside;
        root.selected = index;
        root.groupSelection();
    }

    // Mirrors what's picked left to right: across the middle of the screen, to the other side, or
    // `inPlace` across the middle of its own box, to turn it round where it is
    function mirrorSelection(inPlace: bool): void {
        const box = root.selectionBox;
        const axis = inPlace ? (box.x + box.width / 2) / root.width : 0.5;
        const flipped = LockPresets.mirror(root.selection.map(i => root.elements[i]));
        const next = root.elements.slice();
        root.selection.forEach((i, k) => {
            // LockPresets.mirror flips across the screen's middle; moved over to the axis asked for
            next[i] = Object.assign(flipped[k], {
                x: flipped[k].x + (axis - 0.5) * 2
            });
        });
        root.commit(next);
    }

    // Lines up what's picked along one side or middle of the box round it all. `how`: left,
    // hcentre, right, top, vcentre or bottom
    function alignSelection(how: string): void {
        const box = root.selectionBox;
        const next = root.elements.slice();
        for (const i of root.selection) {
            const h = canvas.hostAt(i);
            if (!h)
                continue;
            let left = h.x, top = h.y;
            if (how === "left")
                left = box.x;
            else if (how === "hcentre")
                left = box.x + (box.width - h.width) / 2;
            else if (how === "right")
                left = box.x + box.width - h.width;
            else if (how === "top")
                top = box.y;
            else if (how === "vcentre")
                top = box.y + (box.height - h.height) / 2;
            else if (how === "bottom")
                top = box.y + box.height - h.height;
            next[i] = Object.assign({}, next[i], root.placeAt(i, left, top));
        }
        root.commit(next);
    }

    // Spaces what's picked out evenly between the first and the last, across or down
    function distributeSelection(horizontal: bool): void {
        const items = root.selection.map(i => ({
                    i: i,
                    h: canvas.hostAt(i)
                })).filter(o => !!o.h);
        if (items.length < 3)
            return;
        const pos = o => horizontal ? o.h.x : o.h.y;
        const len = o => horizontal ? o.h.width : o.h.height;
        items.sort((a, b) => pos(a) - pos(b));
        const first = pos(items[0]);
        const end = Math.max(...items.map(o => pos(o) + len(o)));
        const total = items.reduce((n, o) => n + len(o), 0);
        const gap = (end - first - total) / (items.length - 1);
        const next = root.elements.slice();
        let at = first;
        for (const o of items) {
            next[o.i] = Object.assign({}, next[o.i], root.placeAt(o.i, horizontal ? at : o.h.x, horizontal ? o.h.y : at));
            at += len(o) + gap;
        }
        root.commit(next);
    }

    // Every change goes through here, so each can be undone. Changes with the same key in quick
    // succession are folded into one
    function commit(next: var, key): void {
        const now = Date.now();
        if (key && key === root.lastChangeKey && now - root.lastChangeAt < 1000) {
            root.lastChangeAt = now;
            root.elements = next;
            root.dirty = true;
            return;
        }
        root.lastChangeKey = key ?? "";
        root.lastChangeAt = now;
        root.undoStack = [...root.undoStack.slice(-79), JSON.stringify(root.elements)];
        root.redoStack = [];
        root.elements = next;
        root.dirty = true;
    }

    function undo(): void {
        if (root.undoStack.length === 0)
            return;
        root.redoStack = [...root.redoStack, JSON.stringify(root.elements)];
        root.elements = JSON.parse(root.undoStack[root.undoStack.length - 1]);
        root.undoStack = root.undoStack.slice(0, -1);
        root.selection = [];
        root.selected = Math.min(root.selected, root.elements.length - 1);
        root.dirty = true;
    }

    function redo(): void {
        if (root.redoStack.length === 0)
            return;
        root.undoStack = [...root.undoStack, JSON.stringify(root.elements)];
        root.elements = JSON.parse(root.redoStack[root.redoStack.length - 1]);
        root.redoStack = root.redoStack.slice(0, -1);
        root.selection = [];
        root.selected = Math.min(root.selected, root.elements.length - 1);
        root.dirty = true;
    }

    function update(index: int, changes: var, key): void {
        if (index < 0 || index >= root.elements.length)
            return;
        const next = root.elements.slice();
        next[index] = Object.assign({}, next[index], changes);
        root.commit(next, key ? `${index}:${key}` : "");
    }

    function setOption(index: int, key: string, value: var, coalesce): void {
        const el = root.elements[index];
        if (!el)
            return;
        const options = Object.assign({}, el.options ?? {});
        options[key] = value;
        root.update(index, {
            options: options
        }, coalesce ? `options.${key}` : "");
    }

    function add(kind: string): void {
        root.commit([...root.elements, ElementCatalog.create(kind)]);
        root.pickOnly(root.elements.length - 1);
        root.sheet = "";
    }

    function remove(index: int): void {
        const el = root.elements[index];
        if (!el || el.id === "password")
            return;
        root.commit(root.elements.filter((_, i) => i !== index));
        root.clearPick();
    }

    function duplicate(index: int): void {
        const el = root.elements[index];
        if (!el || el.id === "password")
            return;
        const copy = JSON.parse(JSON.stringify(el));
        copy.x = Math.min(1, copy.x + 0.02);
        copy.y = Math.min(1, copy.y + 0.02);
        // A copy of one member doesn't join its group
        if (copy.options)
            delete copy.options.group;
        const next = root.elements.slice();
        next.splice(index + 1, 0, copy);
        root.commit(next);
        root.pickOnly(index + 1);
    }

    // Later in the list is drawn on top
    function restack(index: int, by: int): void {
        const to = Math.max(0, Math.min(root.elements.length - 1, index + by));
        if (to === index)
            return;
        const next = root.elements.slice();
        const [el] = next.splice(index, 1);
        next.splice(to, 0, el);
        root.commit(next);
        root.selection = [];
        root.selected = to;
    }

    function applyPreset(id: string): void {
        root.commit(LockPresets.build(id));
        root.clearPick();
        root.sheet = "";
    }

    // With something picked, just that, across the screen; otherwise the whole layout
    function mirror(): void {
        if (root.selection.length > 0)
            root.mirrorSelection(false);
        else
            root.commit(LockPresets.mirror(root.elements));
    }

    // Moves the anchor point to another corner or edge of the element without moving the element
    function setAnchor(index: int, anchor: string): void {
        const host = canvas.hostAt(index);
        if (!host)
            return;
        const ax = anchor.endsWith("l") ? 0 : anchor.endsWith("r") ? 1 : 0.5;
        const ay = anchor.startsWith("t") ? 0 : anchor.startsWith("b") ? 1 : 0.5;
        root.update(index, {
            anchor: anchor,
            x: (host.x + ax * host.width) / root.width,
            y: (host.y + ay * host.height) / root.height
        });
    }

    function centre(index: int, horizontal: bool): void {
        const host = canvas.hostAt(index);
        if (!host)
            return;
        if (horizontal)
            root.update(index, {
                x: (root.width / 2 - host.width / 2 + host.ax * host.width) / root.width
            });
        else
            root.update(index, {
                y: (root.height / 2 - host.height / 2 + host.ay * host.height) / root.height
            });
    }

    function save(): void {
        if (!root.canSave)
            return;
        const list = GlobalConfig.lock.elements;
        list.clear();
        for (const el of root.elements)
            list.insert(el);
        root.dirty = false;
        root.closed();
    }

    function requestClose(): void {
        if (root.dirty)
            root.confirmingDiscard = true;
        else
            root.closed();
    }

    // The grid step nearest `at`
    function cellAt(at: real): real {
        return Math.round(at / root.step) * root.step;
    }

    // What an edge or middle on one axis can be pulled onto: the screen's middle and margins, and
    // the edges and middles of every element in sight but those in `except` (the ones being moved)
    function targets(horizontal: bool, except: var): var {
        const size = horizontal ? root.width : root.height;
        const margin = horizontal ? LockPresets.mx : LockPresets.my;
        const out = [size / 2, margin * size, (1 - margin) * size];
        for (let i = 0; i < root.elements.length; i++) {
            if (except.includes(i) || root.elements[i].enabled === false)
                continue;
            const h = canvas.hostAt(i);
            if (!h || h.shown < 0.5)
                continue;
            const at = horizontal ? h.x : h.y;
            const len = horizontal ? h.width : h.height;
            out.push(at, at + len / 2, at + len);
        }
        return out;
    }

    // Where one axis of an element starting at `start`, `size` long, goes: lined up with the nearest
    // target that one of its `ends` (0 start, 0.5 middle, 1 end) comes within reach of, with that
    // target as the guide to draw; failing that, its first end on the nearest grid step. Always the
    // first end, so it moves in even steps rather than jumping between its two edges
    function pull(start: real, size: real, targets: var, ends: var): var {
        let best = null;
        for (const p of ends)
            for (const t of targets) {
                const d = t - (start + p * size);
                if (Math.abs(d) <= root.catchDistance && (!best || Math.abs(d) < Math.abs(best.d)))
                    best = {
                        d: d,
                        guide: t
                    };
            }
        if (best)
            return {
                at: start + best.d,
                guide: best.guide
            };
        const edge = start + ends[0] * size;
        return {
            at: start + root.cellAt(edge) - edge,
            guide: -1
        };
    }

    // Where a drag would put the box round the elements in `moving`, `w` by `h`, asked to have its
    // top-left corner at (left, top): pulled onto whatever it comes near unless snapping is off or
    // `free`, and kept on the screen
    function snapped(moving: var, w: real, h: real, left: real, top: real, free: bool): point {
        root.guideX = -1;
        root.guideY = -1;
        let x = left;
        let y = top;
        if (root.snap && !free) {
            const px = root.pull(left, w, root.targets(true, moving), [0, 0.5, 1]);
            const py = root.pull(top, h, root.targets(false, moving), [0, 0.5, 1]);
            x = px.at;
            y = py.at;
            root.guideX = px.guide;
            root.guideY = py.guide;
        }
        // Never off the screen, where it couldn't be seen or got back
        x = w <= root.width ? Math.max(0, Math.min(root.width - w, x)) : x;
        y = h <= root.height ? Math.max(0, Math.min(root.height - h, y)) : y;
        return Qt.point(x, y);
    }

    // The right or bottom edge of element `index` being pulled by its corner, pulled onto whatever
    // it comes near and kept on the screen
    function snappedEdge(index: int, horizontal: bool, edge: real, free: bool): real {
        let at = edge;
        if (root.snap && !free) {
            const p = root.pull(edge, 0, root.targets(horizontal, [index]), [0]);
            at = p.at;
            if (horizontal)
                root.guideX = p.guide;
            else
                root.guideY = p.guide;
        }
        return Math.min(horizontal ? root.width : root.height, at);
    }

    Keys.onPressed: event => {
        const ctrl = event.modifiers & Qt.ControlModifier;
        const shift = event.modifiers & Qt.ShiftModifier;
        const any = root.selection.length > 0;
        if (event.key === Qt.Key_Escape) {
            if (root.confirmingDiscard)
                root.confirmingDiscard = false;
            else if (root.sheet !== "")
                root.sheet = "";
            else if (any)
                root.clearPick();
            else
                root.requestClose();
        } else if (ctrl && event.key === Qt.Key_Z) {
            if (shift)
                root.redo();
            else
                root.undo();
        } else if (ctrl && event.key === Qt.Key_Y) {
            root.redo();
        } else if (ctrl && event.key === Qt.Key_S) {
            root.save();
        } else if (ctrl && event.key === Qt.Key_A) {
            root.pickAll();
        } else if (ctrl && event.key === Qt.Key_G && any) {
            if (shift)
                root.ungroupSelection();
            else
                root.groupSelection();
        } else if (ctrl && event.key === Qt.Key_D && any) {
            root.duplicateSelection();
        } else if ((event.key === Qt.Key_Delete || event.key === Qt.Key_Backspace) && any) {
            root.removeSelection();
        } else {
            return;
        }
        event.accepted = true;
    }

    // The arrow keys, wherever the keyboard is in the editor (a slider or switch in the side panel
    // keeps it after being clicked), but not while typing in a text field, where they move the
    // cursor, or while a sheet is open
    readonly property bool typing: Window.activeFocusItem?.cursorPosition !== undefined

    Nudge { sequence: "Left"; dx: -1 }
    Nudge { sequence: "Right"; dx: 1 }
    Nudge { sequence: "Up"; dy: -1 }
    Nudge { sequence: "Down"; dy: 1 }
    Nudge { sequence: "Shift+Left"; dx: -1; fine: true }
    Nudge { sequence: "Shift+Right"; dx: 1; fine: true }
    Nudge { sequence: "Shift+Up"; dy: -1; fine: true }
    Nudge { sequence: "Shift+Down"; dy: 1; fine: true }

    component Nudge: Shortcut {
        property int dx
        property int dy
        property bool fine

        enabled: root.selection.length > 0 && !root.typing && root.sheet === "" && !root.confirmingDiscard
        autoRepeat: true
        context: Qt.WindowShortcut
        onActivated: root.nudge(dx, dy, fine)
    }

    // Behind the stage
    Rectangle {
        anchors.fill: parent
        color: Colours.palette.m3surfaceContainerLowest
    }

    // Empty space around the stage: dropping the selection
    MouseArea {
        anchors.fill: parent
        onPressed: {
            root.clearPick();
            root.forceActiveFocus();
        }
    }

    // The screen's frame and shadow, under the stage
    Rectangle {
        x: stage.x - 1
        y: stage.y - 1
        width: stage.width * root.zoom + 2
        height: stage.height * root.zoom + 2
        color: Colours.palette.m3outlineVariant

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            blurMax: 24
            shadowColor: Qt.alpha(Colours.palette.m3shadow, 0.7)
        }
    }

    // The lock screen at the screen's own size, scaled down into the space the panel and bar leave
    Item {
        id: stage

        x: Math.round(root.areaLeft + (root.areaRight - root.areaLeft - root.width * root.zoom) / 2)
        y: Math.round(root.areaTop + (root.areaBottom - root.areaTop - root.height * root.zoom) / 2)
        width: root.width
        height: root.height
        scale: root.zoom
        transformOrigin: Item.TopLeft
        clip: true

        Behavior on x {
            Anim {
                type: Anim.DefaultSpatial
            }
        }

        // The wallpaper and the lock screen. Not drawn through a layer: the clock and the equalizer
        // change every frame, and redrawing the whole screen into one for each was what made
        // dragging stutter
        Item {
            anchors.fill: parent

            // The wallpaper as the lock shows it: the lock's own if it has one, blurred as strongly
            // as the lock blurs it, under the same dark scrim
            Item {
                id: backdrop

                readonly property real blur: Math.max(0, Math.min(1, Config.lock.blur ?? 1))

                anchors.fill: parent

                Image {
                    anchors.fill: parent
                    source: (Config.lock.wallpaper ?? "") !== "" ? Config.lock.wallpaper : Wallpapers.current
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    sourceSize: Qt.size(root.width / 4, root.height / 4)

                    layer.enabled: backdrop.blur > 0
                    layer.effect: MultiEffect {
                        autoPaddingEnabled: false
                        blurEnabled: true
                        blur: backdrop.blur
                        blurMax: 32
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    color: Colours.palette.m3scrim
                    opacity: 0.4 * backdrop.blur
                }
            }

            // The grid, faint, while snapping is on, between the wallpaper and the elements so it never
            // draws over them. Lines a pixel wide as drawn, whatever the scale
            Canvas {
                id: grid

                anchors.fill: parent
                visible: root.snap
                opacity: 0.3

                onPaint: {
                    const ctx = getContext("2d");
                    ctx.clearRect(0, 0, width, height);
                    ctx.lineWidth = 1 / root.zoom;
                    // Faint lines at every step, stronger ones at every cell
                    for (const [every, alpha] of [[root.step, 0.25], [root.cell, 1]]) {
                        ctx.strokeStyle = Qt.alpha(Colours.palette.m3outline, alpha);
                        ctx.beginPath();
                        for (let x = every; x < width; x += every) {
                            ctx.moveTo(x, 0);
                            ctx.lineTo(x, height);
                        }
                        for (let y = every; y < height; y += every) {
                            ctx.moveTo(0, y);
                            ctx.lineTo(width, y);
                        }
                        ctx.stroke();
                    }
                }

                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()

                Connections {
                    target: root

                    function onZoomChanged(): void {
                        grid.requestPaint();
                    }
                }
            }

            LockCanvas {
                id: canvas

                anchors.fill: parent
                elements: root.elements
                editing: true
                phase: root.phase
            }
        }

        // Empty space on the screen: a click drops what's picked, a drag draws a box and picks
        // everything it touches (with Shift, as well as what's picked already)
        MouseArea {
            id: band

            property point from
            property var before: []
            property bool banding

            anchors.fill: parent

            onPressed: mouse => {
                root.forceActiveFocus();
                band.from = Qt.point(mouse.x, mouse.y);
                band.before = mouse.modifiers & Qt.ShiftModifier ? root.selection : [];
                band.banding = false;
                if (!(mouse.modifiers & Qt.ShiftModifier))
                    root.clearPick();
            }

            onPositionChanged: mouse => {
                if (!pressed)
                    return;
                if (!band.banding && Math.hypot(mouse.x - band.from.x, mouse.y - band.from.y) * root.zoom < 4)
                    return;
                band.banding = true;
                const l = Math.min(band.from.x, mouse.x), r = Math.max(band.from.x, mouse.x);
                const t = Math.min(band.from.y, mouse.y), b = Math.max(band.from.y, mouse.y);
                bandRect.x = l;
                bandRect.y = t;
                bandRect.width = r - l;
                bandRect.height = b - t;
                const hit = [...band.before];
                root.elements.forEach((e, i) => {
                    const h = canvas.hostAt(i);
                    if (e.enabled === false || !h || h.shown < 0.5 || hit.includes(i))
                        return;
                    if (h.x < r && h.x + h.width > l && h.y < b && h.y + h.height > t)
                        for (const m of root.groupOf(i))
                            if (!hit.includes(m))
                                hit.push(m);
                });
                root.selection = hit;
                root.selected = hit[hit.length - 1] ?? -1;
            }

            onReleased: band.banding = false
            onCanceled: band.banding = false
        }

        // A handle over each element, in the same order, so whatever is drawn on top is what's
        // picked. Inside the stage, so even the selected one stays under the sheets
        Repeater {
            model: root.elements.length

            ElementHandle {
                // Read so this is looked up again once the canvas has built the element's host
                host: canvas.hostsRevision, canvas.hostAt(index)
                editor: root
                canvas: canvas
                stage: stage
            }
        }

        // The box round everything picked, when that's more than one element
        Rectangle {
            readonly property real pad: 8 / root.zoom

            visible: root.multiple
            x: root.selectionBox.x - pad
            y: root.selectionBox.y - pad
            width: root.selectionBox.width + pad * 2
            height: root.selectionBox.height + pad * 2
            radius: 8 / root.zoom
            color: Qt.alpha(Colours.palette.m3primary, 0.06)
            border.width: 1.5 / root.zoom
            border.color: Qt.alpha(Colours.palette.m3primary, 0.8)
        }

        // The box being drawn over empty space
        Rectangle {
            id: bandRect

            visible: band.banding
            color: Qt.alpha(Colours.palette.m3primary, 0.12)
            border.width: 1.5 / root.zoom
            border.color: Colours.palette.m3primary
        }

        // The guides a drag is lined up with, while it is
        Rectangle {
            visible: root.guideX >= 0
            x: root.guideX - width / 2
            width: 1.5 / root.zoom
            height: stage.height
            color: Colours.palette.m3tertiary
        }

        Rectangle {
            visible: root.guideY >= 0
            y: root.guideY - height / 2
            width: stage.width
            height: 1.5 / root.zoom
            color: Colours.palette.m3tertiary
        }
    }

    Toolbar {
        id: toolbar

        x: Math.round(Math.max(root.gap, (root.areaLeft + root.areaRight) / 2 - width / 2))
        y: root.gap
        editor: root

        Behavior on x {
            Anim {
                type: Anim.DefaultSpatial
            }
        }
    }

    Inspector {
        id: inspector

        visible: root.inspectorShown
        x: root.inspectorOnLeft ? root.gap : root.width - width - root.gap
        y: root.gap
        width: root.inspectorWidth
        height: root.height - root.gap * 2
        editor: root
        canvas: canvas
    }

    // The sheets: a dim over everything, and the sheet in the middle
    Rectangle {
        anchors.fill: parent
        visible: root.sheet !== "" || root.confirmingDiscard
        color: Qt.alpha(Colours.palette.m3scrim, 0.5)

        MouseArea {
            anchors.fill: parent
            onPressed: {
                root.sheet = "";
                root.confirmingDiscard = false;
            }
        }
    }

    // Each sheet at its own size, or as much of it as the screen has room for
    Loader {
        anchors.centerIn: parent
        width: Math.min(item?.implicitWidth ?? 0, root.width - root.gap * 4)
        height: Math.min(item?.implicitHeight ?? 0, root.height - root.gap * 4)
        active: root.sheet === "add"

        sourceComponent: ElementSheet {
            screenSize: Qt.size(root.width, root.height)
            uiScale: root.uiScale
            onPicked: kind => root.add(kind)
            onDismissed: root.sheet = ""
        }
    }

    Loader {
        anchors.centerIn: parent
        width: Math.min(item?.implicitWidth ?? 0, root.width - root.gap * 4)
        height: Math.min(item?.implicitHeight ?? 0, root.height - root.gap * 4)
        active: root.sheet === "presets"

        sourceComponent: PresetSheet {
            screenSize: Qt.size(root.width, root.height)
            onPicked: id => root.applyPreset(id)
            onDismissed: root.sheet = ""
        }
    }

    // Leaving with changes not saved
    StyledRect {
        anchors.centerIn: parent
        visible: root.confirmingDiscard
        implicitWidth: discard.implicitWidth + Tokens.padding.extraLarge * 2
        implicitHeight: discard.implicitHeight + Tokens.padding.extraLarge * 2
        radius: Tokens.rounding.extraLarge
        color: Colours.palette.m3surfaceContainerHigh

        ColumnLayout {
            id: discard

            anchors.centerIn: parent
            spacing: Tokens.spacing.large

            StyledText {
                text: Tr.tr("Leave without saving?")
                color: Colours.palette.m3onSurface
                font: Tokens.font.title.large
            }

            StyledText {
                text: Tr.tr("The changes made since opening the editor will be lost.")
                color: Colours.palette.m3onSurfaceVariant
                font: Tokens.font.body.medium
            }

            RowLayout {
                Layout.alignment: Qt.AlignRight
                spacing: Tokens.spacing.small

                EditorButton {
                    icon: "edit"
                    text: Tr.tr("Keep editing")
                    onActivated: root.confirmingDiscard = false
                }

                EditorButton {
                    icon: "delete"
                    text: Tr.tr("Discard")
                    tone: "error"
                    onActivated: root.closed()
                }
            }
        }
    }
}
