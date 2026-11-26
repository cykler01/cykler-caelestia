pragma ComponentBehavior: Bound

import QtQuick
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.services
import qs.modules.lock.canvas

// What's over one element in the editor: press it to select it and drag it to move it, snapping
// as the editor says; the selected one gets an outline, a corner to pull to resize it, and a strip
// of buttons over it. A drag is shown through the canvas's live offset and written only when it's
// let go, so the list is changed once per drag rather than on every pointer move
Item {
    id: root

    required property int index
    required property var host
    required property var editor
    required property var canvas

    readonly property bool selected: editor.selected === index
    readonly property var element: editor.elements[index] ?? null
    readonly property var kind: ElementCatalog.kind(element?.id ?? "")
    readonly property bool sized: kind?.sized ?? false

    // Where the element was when the drag or resize started
    property real startLeft
    property real startTop
    property real startW
    property real startH
    property point press
    property bool moved

    function begin(px: real, py: real): void {
        // Back from any text field in the side panel, so the editor's keys answer again
        root.editor.forceActiveFocus();
        root.editor.selected = root.index;
        root.startLeft = root.host.x;
        root.startTop = root.host.y;
        root.startW = root.host.width;
        root.startH = root.host.height;
        root.press = Qt.point(px, py);
        root.moved = false;
    }

    function finish(): void {
        root.canvas.liveIndex = -1;
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
    // The selected one over the rest, so its corner and buttons are never under another element
    z: selected ? 100 : 0

    // Moving
    MouseArea {
        anchors.fill: parent
        preventStealing: true
        hoverEnabled: true
        cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor

        onPressed: mouse => {
            const p = mapToItem(root.editor, mouse.x, mouse.y);
            root.begin(p.x, p.y);
        }

        onPositionChanged: mouse => {
            if (!pressed)
                return;
            const p = mapToItem(root.editor, mouse.x, mouse.y);
            const dx = p.x - root.press.x;
            const dy = p.y - root.press.y;
            if (!root.moved && Math.hypot(dx, dy) < 3)
                return;
            root.moved = true;
            const to = root.editor.snapped(root.host, root.startLeft + dx, root.startTop + dy);
            root.canvas.liveIndex = root.index;
            root.canvas.liveOffset = Qt.point(to.x - root.startLeft, to.y - root.startTop);
        }

        onReleased: {
            if (root.moved) {
                const left = root.startLeft + root.canvas.liveOffset.x;
                const top = root.startTop + root.canvas.liveOffset.y;
                root.finish();
                root.editor.update(root.index, {
                    x: (left + root.host.ax * root.startW) / root.editor.width,
                    y: (top + root.host.ay * root.startH) / root.editor.height
                });
            } else {
                root.finish();
            }
        }
        onCanceled: root.finish()

        // Hover and selection outlines
        StyledRect {
            anchors.fill: parent
            anchors.margins: -4
            radius: Tokens.rounding.small
            color: "transparent"
            border.width: root.selected ? 2 : 1
            border.color: root.selected ? Colours.palette.m3primary : Qt.alpha(Colours.palette.m3onSurface, 0.35)
            visible: root.selected || parent.containsMouse
        }
    }

    // The corner to pull: a box's width and height for the kinds that fill one, the scale for the
    // rest. The top-left corner stays put either way
    StyledRect {
        id: knob

        visible: root.selected
        x: root.width - width / 2 + 4
        y: root.height - height / 2 + 4
        width: 16
        height: 16
        radius: width / 2
        color: Colours.palette.m3primary
        border.width: 2
        border.color: Colours.palette.m3onPrimary

        MouseArea {
            anchors.fill: parent
            anchors.margins: -6
            preventStealing: true
            cursorShape: Qt.SizeFDiagCursor

            onPressed: mouse => {
                const p = mapToItem(root.editor, mouse.x, mouse.y);
                root.begin(p.x, p.y);
            }

            onPositionChanged: mouse => {
                if (!pressed)
                    return;
                const p = mapToItem(root.editor, mouse.x, mouse.y);
                const w = Math.max(8, root.startW + p.x - root.press.x);
                const h = Math.max(2, root.startH + p.y - root.press.y);
                root.moved = true;
                root.canvas.liveIndex = root.index;
                if (root.sized) {
                    root.canvas.liveBox = Qt.size(w, h);
                    root.canvas.liveOffset = Qt.point(root.host.ax * (w - root.startW), root.host.ay * (h - root.startH));
                } else {
                    const f = Math.max(0.15, Math.min(6, (w / root.startW + h / root.startH) / 2));
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
                const box = root.canvas.liveBox;
                const f = root.canvas.liveScale;
                const el = root.element;
                root.finish();
                if (root.sized) {
                    root.editor.update(root.index, {
                        w: box.width / root.editor.width,
                        h: box.height / root.editor.height,
                        x: (left + root.host.ax * box.width) / root.editor.width,
                        y: (top + root.host.ay * box.height) / root.editor.height
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

    // The selected element's own buttons, over it, or under it when it's at the top of the screen
    StyledRect {
        visible: root.selected && root.canvas.liveIndex !== root.index
        x: Math.max(-root.x + 8, Math.min(root.editor.width - root.x - width - 8, 0))
        y: root.y > height + 16 ? -height - 10 : root.height + 14
        implicitWidth: actions.implicitWidth + Tokens.padding.small * 2
        implicitHeight: actions.implicitHeight + Tokens.padding.small * 2
        radius: Tokens.rounding.full
        color: Colours.palette.m3surfaceContainerHigh

        Row {
            id: actions

            anchors.centerIn: parent
            spacing: Tokens.spacing.extraSmall

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                leftPadding: Tokens.padding.medium
                rightPadding: Tokens.padding.small
                text: root.kind?.name ?? ""
                color: Colours.palette.m3onSurface
                font: Tokens.font.label.large
            }

            RoundButton {
                icon: "content_copy"
                tip: Tr.tr("Duplicate")
                visible: root.element?.id !== "password"
                onActivated: root.editor.duplicate(root.index)
            }

            RoundButton {
                icon: "flip_to_front"
                tip: Tr.tr("Bring forward")
                onActivated: root.editor.restack(root.index, 1)
            }

            RoundButton {
                icon: "flip_to_back"
                tip: Tr.tr("Send backward")
                onActivated: root.editor.restack(root.index, -1)
            }

            // The one thing here that throws something away, so it wears the error colour. Not on
            // the password field, which every lock screen has to keep
            RoundButton {
                icon: "close"
                tip: Tr.tr("Remove")
                visible: root.element?.id !== "password"
                fill: Colours.palette.m3error
                onFill: Colours.palette.m3onError
                onActivated: root.editor.remove(root.index)
            }
        }
    }

    component RoundButton: StyledRect {
        id: button

        required property string icon
        property string tip
        property color fill: Colours.palette.m3secondaryContainer
        property color onFill: Colours.palette.m3onSecondaryContainer

        signal activated

        implicitWidth: 30
        implicitHeight: 30
        radius: Tokens.rounding.full
        color: button.fill

        MaterialIcon {
            anchors.centerIn: parent
            text: button.icon
            color: button.onFill
            fontStyle: Tokens.font.icon.small
        }

        StateLayer {
            radius: button.radius
            color: button.onFill
            onClicked: button.activated()
        }
    }
}
