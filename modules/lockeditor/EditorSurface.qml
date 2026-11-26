pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.services
import qs.modules.lock.canvas

// NOTE(fork): the lock screen editor itself: the lock screen at full size over a blurred wallpaper,
// as the lock shows it, with a handle over every element. The way it works follows the desktop
// widgets' rearrange mode (modules/background/DesktopWidgets.qml): press an element to pick it up
// and drag it, with a grid to snap to and guides at the screen's middle and margins; pull the
// corner of the selected one to resize it; and the buttons on it remove, copy or restack it. The
// bar along the top adds elements, starts over from a preset, undoes, mirrors and saves, and the
// panel at the side has everything else about the selected element.
//
// Changes are made to a copy and only written to Config.lock.elements on Save, so the editor can
// be left without keeping anything
Item {
    id: root

    // The working copy, as plain objects (LockPresets.plain)
    property var elements: LockPresets.effective(GlobalConfig.lock)

    property int selected: -1

    property var undoStack: []

    property var redoStack: []

    property bool dirty: false

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

    readonly property var selectedElement: root.selected >= 0 ? root.elements[root.selected] ?? null : null

    readonly property real uiScale: canvas.uiScale
    // Snapping: a grid of 1/64 of the width by 1/36 of the height, and guides at the middle and at
    // the 72px margins the presets use, caught within this many pixels

    readonly property real gridX: width / 64

    readonly property real gridY: height / 36

    readonly property real catchDistance: 10

    property real guideX: -1

    property real guideY: -1

    // The last change made through a slider, so a slider dragged across its range is one undo step
    // rather than one per position it passed through
    property string lastChangeKey

    property real lastChangeAt

    signal closed

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
        root.selected = Math.min(root.selected, root.elements.length - 1);
        root.dirty = true;
    }

    function redo(): void {
        if (root.redoStack.length === 0)
            return;
        root.undoStack = [...root.undoStack, JSON.stringify(root.elements)];
        root.elements = JSON.parse(root.redoStack[root.redoStack.length - 1]);
        root.redoStack = root.redoStack.slice(0, -1);
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
        root.selected = root.elements.length - 1;
        root.sheet = "";
    }

    function remove(index: int): void {
        const el = root.elements[index];
        if (!el || el.id === "password")
            return;
        root.commit(root.elements.filter((_, i) => i !== index));
        root.selected = -1;
    }

    function duplicate(index: int): void {
        const el = root.elements[index];
        if (!el || el.id === "password")
            return;
        const copy = JSON.parse(JSON.stringify(el));
        copy.x = Math.min(1, copy.x + 0.02);
        copy.y = Math.min(1, copy.y + 0.02);
        const next = root.elements.slice();
        next.splice(index + 1, 0, copy);
        root.commit(next);
        root.selected = index + 1;
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
        root.selected = to;
    }

    function applyPreset(id: string): void {
        root.commit(LockPresets.build(id));
        root.selected = -1;
        root.sheet = "";
    }

    function mirror(): void {
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

    // Where a drag would put an element whose top-left corner is at (left, top), snapped
    function snapped(host: Item, left: real, top: real): point {
        root.guideX = -1;
        root.guideY = -1;
        if (!root.snap)
            return Qt.point(left, top);

        const w = host.width;
        const h = host.height;
        const xs = [
            [root.width / 2, left + w / 2],
            [LockPresets.mx * root.width, left],
            [(1 - LockPresets.mx) * root.width, left + w]
        ];
        const ys = [
            [root.height / 2, top + h / 2],
            [LockPresets.my * root.height, top],
            [(1 - LockPresets.my) * root.height, top + h]
        ];
        let x = null;
        let y = null;
        for (const [guide, at] of xs)
            if (x === null && Math.abs(guide - at) < root.catchDistance) {
                x = left + guide - at;
                root.guideX = guide;
            }
        for (const [guide, at] of ys)
            if (y === null && Math.abs(guide - at) < root.catchDistance) {
                y = top + guide - at;
                root.guideY = guide;
            }
        // Off the guides, the anchor point snaps to the grid
        if (x === null) {
            const ax = left + host.ax * w;
            x = Math.round(ax / root.gridX) * root.gridX - host.ax * w;
        }
        if (y === null) {
            const ay = top + host.ay * h;
            y = Math.round(ay / root.gridY) * root.gridY - host.ay * h;
        }
        return Qt.point(x, y);
    }

    Keys.onPressed: event => {
        const ctrl = event.modifiers & Qt.ControlModifier;
        const shift = event.modifiers & Qt.ShiftModifier;
        if (event.key === Qt.Key_Escape) {
            if (root.confirmingDiscard)
                root.confirmingDiscard = false;
            else if (root.sheet !== "")
                root.sheet = "";
            else if (root.selected >= 0)
                root.selected = -1;
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
        } else if (ctrl && event.key === Qt.Key_D && root.selected >= 0) {
            root.duplicate(root.selected);
        } else if ((event.key === Qt.Key_Delete || event.key === Qt.Key_Backspace) && root.selected >= 0) {
            root.remove(root.selected);
        } else if (root.selected >= 0 && [Qt.Key_Left, Qt.Key_Right, Qt.Key_Up, Qt.Key_Down].includes(event.key)) {
            // Nudged a pixel at a time, ten with Shift
            const step = shift ? 10 : 1;
            const el = root.elements[root.selected];
            const dx = event.key === Qt.Key_Left ? -step : event.key === Qt.Key_Right ? step : 0;
            const dy = event.key === Qt.Key_Up ? -step : event.key === Qt.Key_Down ? step : 0;
            root.update(root.selected, {
                x: el.x + dx / root.width,
                y: el.y + dy / root.height
            });
        } else {
            return;
        }
        event.accepted = true;
    }

    // The wallpaper as the lock shows it: the lock's own if it has one, blurred as strongly as the
    // lock blurs it, under the same dark scrim
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

    // The grid, faint, while snapping is on
    Canvas {
        anchors.fill: parent
        visible: root.snap
        opacity: 0.5

        onPaint: {
            const ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);
            ctx.strokeStyle = Qt.alpha(Colours.palette.m3outline, 0.25);
            ctx.lineWidth = 1;
            ctx.beginPath();
            for (let i = 1; i < 64; i++) {
                const x = Math.round(i * root.gridX) + 0.5;
                ctx.moveTo(x, 0);
                ctx.lineTo(x, height);
            }
            for (let i = 1; i < 36; i++) {
                const y = Math.round(i * root.gridY) + 0.5;
                ctx.moveTo(0, y);
                ctx.lineTo(width, y);
            }
            ctx.stroke();
        }

        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
    }

    LockCanvas {
        id: canvas

        anchors.fill: parent
        elements: root.elements
        editing: true
        phase: root.phase
    }

    // Empty space: dropping the selection
    MouseArea {
        anchors.fill: parent
        onPressed: {
            root.selected = -1;
            root.forceActiveFocus();
        }
    }

    // A handle over each element, in the same order, so whatever is drawn on top is what's picked
    Repeater {
        model: root.elements.length

        ElementHandle {
            // Read so this is looked up again once the canvas has built the element's host
            host: canvas.hostsRevision, canvas.hostAt(index)
            editor: root
            canvas: canvas
        }
    }

    // The guides a drag is snapped to, while it is
    Rectangle {
        visible: root.guideX >= 0
        x: root.guideX
        width: 1
        height: root.height
        color: Colours.palette.m3tertiary
    }

    Rectangle {
        visible: root.guideY >= 0
        y: root.guideY
        width: root.width
        height: 1
        color: Colours.palette.m3tertiary
    }

    Toolbar {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: Tokens.padding.large
        editor: root
    }

    Inspector {
        visible: root.inspectorShown
        x: root.inspectorOnLeft ? Tokens.padding.large : root.width - width - Tokens.padding.large
        anchors.top: parent.top
        anchors.topMargin: Tokens.padding.large * 2 + 48
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Tokens.padding.large
        width: 360
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

    Loader {
        anchors.centerIn: parent
        active: root.sheet === "add"

        sourceComponent: ElementSheet {
            onPicked: kind => root.add(kind)
            onDismissed: root.sheet = ""
        }
    }

    Loader {
        anchors.centerIn: parent
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
