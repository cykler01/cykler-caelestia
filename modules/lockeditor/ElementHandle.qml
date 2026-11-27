pragma ComponentBehavior: Bound

import QtQuick
import Caelestia.Config
import qs.components
import qs.services
import qs.modules.lock.canvas

// What's over one element in the editor's stage: press it to select it and drag it to move it,
// pulled onto whatever it comes near (EditorSurface.snapped), or anywhere with Ctrl held; the
// selected one gets an outline and a round corner to pull to resize it. Its buttons (copy,
// restack, remove) are in the side panel, so nothing floats over the screen next to it.
//
// The stage is the screen at its own size, scaled down, so everything here is in screen pixels;
// outlines and the corner are divided by the zoom to stay the same size as drawn. A drag is shown
// through the canvas's live offset and written only when it's let go, so the list is changed once
// per drag rather than on every pointer move
Item {
    id: root

    required property int index
    required property var host
    required property var editor
    required property var canvas
    required property Item stage

    readonly property bool selected: editor.selected === index
    // Picked along with others (Shift+click, a box drawn over it, or its group)
    readonly property bool inSelection: editor.selection.includes(index)
    readonly property bool listHovered: editor.hovered === index
    readonly property var element: editor.elements[index] ?? null
    readonly property var kind: ElementCatalog.kind(element?.id ?? "")
    readonly property bool sized: kind?.sized ?? false
    readonly property real zoom: editor.zoom
    // Room to grab something thin (a divider, a hairline) by, as drawn
    readonly property real grabX: Math.max(0, (14 / zoom - width) / 2)
    readonly property real grabY: Math.max(0, (14 / zoom - height) / 2)

    // Where the element was when the drag or resize started
    property real startLeft
    property real startTop
    property real startW
    property real startH
    property point press
    property bool moved
    // What a drag moves (everything picked) and the box round it when the drag started
    property var moving: []
    property rect startBox
    // A Shift+click only changes what's picked; it doesn't start a drag
    property bool toggling

    function begin(px: real, py: real): void {
        // Back from any text field in the side panel, so the editor's keys answer again
        root.editor.forceActiveFocus();
        // Pressing something not yet picked picks it (and its group) instead of what was; pressing
        // something already picked keeps the lot, so it can all be dragged
        if (!root.inSelection)
            root.editor.pick(root.index, false);
        else
            root.editor.selected = root.index;
        root.moving = root.editor.selection.slice();
        root.startBox = root.editor.boxOf(root.moving);
        root.startLeft = root.host.x;
        root.startTop = root.host.y;
        root.startW = root.host.width;
        root.startH = root.host.height;
        root.press = Qt.point(px, py);
        root.moved = false;
    }

    function finish(): void {
        root.canvas.liveIndex = -1;
        root.canvas.liveGroup = [];
        root.canvas.liveOffset = Qt.point(0, 0);
        root.canvas.liveScale = 1;
        root.canvas.liveBox = Qt.size(0, 0);
        root.editor.guideX = -1;
        root.editor.guideY = -1;
    }

    x: host?.x ?? 0
    y: host?.y ?? 0
    width: host?.width ?? 0
    height: host?.height ?? 0
    visible: !!host && (element?.enabled ?? true) && (host.shown > 0.5)
    // The selected one over the rest, so its corner is never under another element
    z: inSelection ? 1 : 0

    // Moving
    MouseArea {
        id: body

        anchors.fill: parent
        anchors.leftMargin: -root.grabX
        anchors.rightMargin: -root.grabX
        anchors.topMargin: -root.grabY
        anchors.bottomMargin: -root.grabY
        preventStealing: true
        hoverEnabled: true
        cursorShape: pressed && root.moved ? Qt.ClosedHandCursor : Qt.PointingHandCursor

        onPressed: mouse => {
            root.toggling = !!(mouse.modifiers & Qt.ShiftModifier);
            if (root.toggling) {
                root.editor.forceActiveFocus();
                root.editor.pick(root.index, true);
                return;
            }
            const p = mapToItem(root.stage, mouse.x, mouse.y);
            root.begin(p.x, p.y);
        }

        // Double-click: just this one, out of its group, to change it on its own
        onDoubleClicked: root.editor.pickOnly(root.index)

        onPositionChanged: mouse => {
            if (!pressed || root.toggling)
                return;
            const p = mapToItem(root.stage, mouse.x, mouse.y);
            const dx = p.x - root.press.x;
            const dy = p.y - root.press.y;
            // A few pixels as drawn before it counts as a drag, so a click never nudges it
            if (!root.moved && Math.hypot(dx, dy) * root.zoom < 4)
                return;
            root.moved = true;
            // The box round everything being moved is what's snapped, so a group lines up as one
            const box = root.startBox;
            const to = root.editor.snapped(root.moving, box.width, box.height, box.x + dx, box.y + dy, !!(mouse.modifiers & Qt.ControlModifier));
            root.canvas.liveGroup = root.moving;
            root.canvas.liveOffset = Qt.point(to.x - box.x, to.y - box.y);
        }

        onReleased: {
            if (root.toggling) {
                root.toggling = false;
                return;
            }
            if (root.moved) {
                // Copied out as numbers: the offset read back is live, and finish() zeroes it
                const dx = root.canvas.liveOffset.x;
                const dy = root.canvas.liveOffset.y;
                const moving = root.moving;
                root.finish();
                root.editor.moveBy(moving, dx, dy);
            } else {
                root.finish();
                // A plain click on one of several picked narrows it down to that one (and its group)
                if (root.editor.multiple)
                    root.editor.pick(root.index, false);
            }
        }
        onCanceled: root.finish()
    }

    // Outlined only while pointed at, picked, or pointed at in the side panel's list, so the
    // outlines of neighbours never cross each other
    Rectangle {
        anchors.fill: parent
        anchors.margins: -3 / root.zoom
        radius: 6 / root.zoom
        color: root.listHovered && !root.inSelection ? Qt.alpha(Colours.palette.m3primary, 0.12) : "transparent"
        border.width: (root.inSelection || root.listHovered ? 2 : 1.5) / root.zoom
        border.color: root.inSelection || root.listHovered ? Colours.palette.m3primary : Qt.alpha(Colours.palette.m3onSurface, 0.7)
        visible: root.inSelection || root.listHovered || body.containsMouse
    }

    // The corner to pull: a box's width and height for the kinds that fill one, the scale for the
    // rest. The top-left corner stays put either way, and the pulled edges are drawn to whatever
    // they come near, as a drag is
    Rectangle {
        id: knob

        readonly property real size: 16 / root.zoom

        // Only with just the one picked: a group is resized member by member
        visible: root.selected && !root.editor.multiple
        x: root.width + 3 / root.zoom - size / 2
        y: root.height + 3 / root.zoom - size / 2
        width: size
        height: size
        radius: size / 2
        color: Colours.palette.m3primary
        border.width: 2 / root.zoom
        border.color: Colours.palette.m3onPrimary

        MouseArea {
            anchors.fill: parent
            anchors.margins: -6 / root.zoom
            preventStealing: true
            cursorShape: Qt.SizeFDiagCursor

            onPressed: mouse => {
                const p = mapToItem(root.stage, mouse.x, mouse.y);
                root.begin(p.x, p.y);
            }

            onPositionChanged: mouse => {
                if (!pressed)
                    return;
                const p = mapToItem(root.stage, mouse.x, mouse.y);
                const free = !!(mouse.modifiers & Qt.ControlModifier);
                root.moved = true;
                root.canvas.liveIndex = root.index;
                root.editor.guideX = -1;
                root.editor.guideY = -1;
                const right = root.editor.snappedEdge(root.index, true, root.startLeft + root.startW + p.x - root.press.x, free);
                if (root.sized) {
                    const bottom = root.editor.snappedEdge(root.index, false, root.startTop + root.startH + p.y - root.press.y, free);
                    // Thin things (a divider, a hairline) keep their own small floor
                    const w = Math.max(8, right - root.startLeft);
                    const h = Math.max(2, bottom - root.startTop);
                    root.canvas.liveBox = Qt.size(w, h);
                    root.canvas.liveOffset = Qt.point(root.host.ax * (w - root.startW), root.host.ay * (h - root.startH));
                } else {
                    // Text and drawings keep their shape, so only the right edge is followed
                    const f = Math.max(0.15, Math.min(6, (right - root.startLeft) / Math.max(1, root.startW)));
                    root.canvas.liveScale = f;
                    root.canvas.liveOffset = Qt.point(root.host.ax * root.startW * (f - 1), root.host.ay * root.startH * (f - 1));
                }
            }

            onReleased: {
                if (!root.moved) {
                    root.finish();
                    return;
                }
                const left = root.startLeft;
                const top = root.startTop;
                // Copied out as numbers before finish() resets them
                const boxW = root.canvas.liveBox.width;
                const boxH = root.canvas.liveBox.height;
                const f = root.canvas.liveScale;
                const el = root.element;
                root.finish();
                if (root.sized) {
                    root.editor.update(root.index, {
                        w: boxW / root.editor.width,
                        h: boxH / root.editor.height,
                        x: (left + root.host.ax * boxW) / root.editor.width,
                        y: (top + root.host.ay * boxH) / root.editor.height
                    });
                } else {
                    root.editor.update(root.index, {
                        scale: Math.round((el.scale ?? 1) * f * 100) / 100,
                        x: (left + root.host.ax * root.startW * f) / root.editor.width,
                        y: (top + root.host.ay * root.startH * f) / root.editor.height
                    });
                }
            }
            onCanceled: root.finish()
        }
    }
}
