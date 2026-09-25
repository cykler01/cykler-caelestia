pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services
import qs.modules.nexus.common

// A miniature screen showing where every part of the shell sits. Drag a tile to move it: it snaps to the
// places that element supports and writes the matching options (bar.position, launcher.edge/align, ...).
PageBase {
    id: root

    readonly property real aspect: root.nState.screen && root.nState.screen.height > 0 ? root.nState.screen.width / root.nState.screen.height : 16 / 10

    readonly property var elements: [
        {
            id: "bar",
            label: Tr.tr("Taskbar"),
            icon: "dock_to_bottom",
            kind: "bar"
        },
        {
            id: "launcher",
            label: Tr.tr("Launcher"),
            icon: "apps",
            kind: "panel"
        },
        {
            id: "dashboard",
            label: Tr.tr("Dashboard"),
            icon: "dashboard",
            kind: "panel"
        },
        {
            id: "notch",
            label: Tr.tr("Notch"),
            icon: "queue_music",
            kind: "panel"
        },
        {
            id: "osd",
            label: Tr.tr("Volume & brightness"),
            icon: "volume_up",
            kind: "side"
        },
        {
            id: "session",
            label: Tr.tr("Session menu"),
            icon: "power_settings_new",
            kind: "side"
        },
        {
            id: "sidebar",
            label: Tr.tr("Notifications & utilities"),
            icon: "notifications",
            kind: "side"
        },
        {
            id: "popout",
            label: Tr.tr("Notification popout"),
            icon: "forum",
            kind: "side"
        },
        {
            id: "widgets",
            label: Tr.tr("Desktop widgets"),
            icon: "widgets",
            kind: "desktop"
        },
        {
            id: "icons",
            label: Tr.tr("Desktop icons"),
            icon: "grid_view",
            kind: "desktop"
        }
    ]

    readonly property var defaults: ({
            bar: "left",
            launcher: "bottom-center",
            dashboard: "top-center",
            notch: "top-center",
            osd: "right",
            session: "right",
            sidebar: "right",
            popout: "right",
            widgets: "top-right",
            icons: "top-left"
        })

    // Which element is being dragged, and where its centre is (preview coordinates)
    property string dragId
    property point dragCentre

    readonly property string barSlot: currentSlot("bar")
    readonly property real barThickness: preview.height * 0.075
    // The part of the screen the bar doesn't cover
    readonly property var inner: {
        const t = barThickness;
        const w = preview.width;
        const h = preview.height;
        const left = barSlot === "left" ? t : 0;
        const top = barSlot === "top" ? t : 0;
        return {
            x: left,
            y: top,
            w: w - left - (barSlot === "right" ? t : 0),
            h: h - top - (barSlot === "bottom" ? t : 0)
        };
    }

    function slotsFor(id: string): var {
        switch (id) {
        case "bar":
            return ["left", "right", "top", "bottom"];
        case "launcher":
        case "dashboard":
            return ["top-start", "top-center", "top-end", "bottom-start", "bottom-center", "bottom-end"];
        case "notch":
            return ["top-start", "top-center", "top-end"];
        case "widgets":
        case "icons":
            return ["top-left", "top-right", "bottom-left", "bottom-right"];
        default:
            return ["left", "right"];
        }
    }

    function currentSlot(id: string): string {
        const edges = ["top", "bottom"];
        const aligns = ["start", "center", "end"];
        switch (id) {
        case "bar":
            return ["left", "right", "top", "bottom"][Config.bar.position] ?? "left";
        case "launcher":
            return `${edges[Config.launcher.edge] ?? "bottom"}-${aligns[Config.launcher.align] ?? "center"}`;
        case "dashboard":
            return `${edges[Config.dashboard.edge] ?? "top"}-${aligns[Config.dashboard.align] ?? "center"}`;
        case "notch":
            return `top-${aligns[Config.notch.align] ?? "center"}`;
        case "osd":
            return ["left", "right"][Config.osd.side] ?? "right";
        case "session":
            return ["left", "right"][Config.session.side] ?? "right";
        case "sidebar":
            return ["left", "right"][Config.sidebar.side] ?? "right";
        case "popout":
            return ["left", "right"][GlobalConfig.notifPopout.side] ?? "right";
        case "widgets":
            return Config.background.desktopWidgets.position;
        case "icons":
            return Config.background.desktopIcons.position;
        }
        return "";
    }

    function applySlot(id: string, slot: string): void {
        const edges = ["top", "bottom"];
        const aligns = ["start", "center", "end"];
        const sides = ["left", "right"];
        const parts = slot.split("-");
        switch (id) {
        case "bar":
            GlobalConfig.bar.position = ["left", "right", "top", "bottom"].indexOf(slot);
            break;
        case "launcher":
            GlobalConfig.launcher.edge = edges.indexOf(parts[0]);
            GlobalConfig.launcher.align = aligns.indexOf(parts[1]);
            break;
        case "dashboard":
            GlobalConfig.dashboard.edge = edges.indexOf(parts[0]);
            GlobalConfig.dashboard.align = aligns.indexOf(parts[1]);
            break;
        case "notch":
            GlobalConfig.notch.align = aligns.indexOf(parts[1]);
            break;
        case "osd":
            GlobalConfig.osd.side = sides.indexOf(slot);
            break;
        case "session":
            GlobalConfig.session.side = sides.indexOf(slot);
            break;
        case "sidebar":
            GlobalConfig.sidebar.side = sides.indexOf(slot);
            break;
        case "popout":
            GlobalConfig.notifPopout.side = sides.indexOf(slot);
            break;
        case "widgets":
            GlobalConfig.background.desktopWidgets.position = slot;
            break;
        case "icons":
            GlobalConfig.background.desktopIcons.position = slot;
            break;
        }
    }

    function resetAll(): void {
        for (const e of elements)
            applySlot(e.id, defaults[e.id]);
    }

    // Tile size in the preview
    function sizeOf(id: string): size {
        const w = preview.width;
        const h = preview.height;
        const r = inner;
        switch (id) {
        case "launcher":
            return Qt.size(w * 0.30, h * 0.20);
        case "dashboard":
            return Qt.size(w * 0.36, h * 0.26);
        case "notch":
            return Qt.size(w * 0.14, h * 0.07);
        case "osd":
            return Qt.size(w * 0.045, h * 0.26);
        case "session":
            return Qt.size(w * 0.05, h * 0.30);
        case "sidebar":
            return Qt.size(w * 0.15, r.h - 12);
        case "popout":
            return Qt.size(w * 0.11, r.h - 12);
        case "widgets":
            return Qt.size(w * 0.26, h * 0.42);
        case "icons":
            return Qt.size(w * 0.07, h * 0.30);
        }
        return Qt.size(0, 0);
    }

    // Where a tile sits for a given slot, in preview coordinates
    function slotRect(id: string, slot: string): rect {
        const w = preview.width;
        const h = preview.height;
        const t = barThickness;

        if (id === "bar") {
            switch (slot) {
            case "right":
                return Qt.rect(w - t, 0, t, h);
            case "top":
                return Qt.rect(0, 0, w, t);
            case "bottom":
                return Qt.rect(0, h - t, w, t);
            }
            return Qt.rect(0, 0, t, h);
        }

        const m = 6;
        const r = inner;
        const sz = sizeOf(id);
        const parts = slot.split("-");
        let x = r.x + m;
        let y = r.y + (r.h - sz.height) / 2;

        if (parts.length === 1) {
            // Side panels: left or right, centred vertically (the tall ones fill the height). Ones sharing an
            // edge sit in columns, nearest the edge first, so none hides another.
            const order = ["sidebar", "popout", "session", "osd"];
            let inset = m;
            for (const other of order) {
                if (other === id)
                    break;
                if (currentSlot(other) === slot && !(other === dragId))
                    inset += sizeOf(other).width + 4;
            }
            x = parts[0] === "left" ? r.x + inset : r.x + r.w - sz.width - inset;
            if (id === "sidebar" || id === "popout")
                y = r.y + m;
        } else {
            const horizontal = parts[1];
            x = (horizontal === "start" || horizontal === "left") ? r.x + m : horizontal === "center" ? r.x + (r.w - sz.width) / 2 : r.x + r.w - sz.width - m;
            y = parts[0] === "top" ? r.y + (id === "notch" ? 0 : m) : r.y + r.h - sz.height - m;
        }
        return Qt.rect(x, y, sz.width, sz.height);
    }

    function nearestSlot(id: string, centre: point): string {
        let best = "";
        let bestDist = Infinity;
        for (const slot of slotsFor(id)) {
            const r = slotRect(id, slot);
            const dx = centre.x - (r.x + r.width / 2);
            const dy = centre.y - (r.y + r.height / 2);
            const d = dx * dx + dy * dy;
            if (d < bestDist) {
                bestDist = d;
                best = slot;
            }
        }
        return best;
    }

    function prettySlot(slot: string): string {
        const names = {
            left: Tr.trCtx("Left", "layout position"),
            right: Tr.trCtx("Right", "layout position"),
            top: Tr.trCtx("Top", "layout position"),
            bottom: Tr.trCtx("Bottom", "layout position"),
            start: Tr.trCtx("Left", "layout position"),
            center: Tr.trCtx("Centre", "layout position"),
            end: Tr.trCtx("Right", "layout position")
        };
        return slot.split("-").map(p => names[p] ?? p).join(" · ");
    }

    title: Tr.tr("Layout")

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.large

        StyledText {
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            text: Tr.tr("Drag a tile to move that part of the shell. It snaps to the places it supports, and the change applies straight away.")
            color: Colours.palette.m3onSurfaceVariant
            font: Tokens.font.body.small
        }

        StyledClippingRect {
            id: preview

            Layout.fillWidth: true
            Layout.preferredHeight: width / root.aspect
            color: Colours.palette.m3surfaceContainerLowest
            radius: Tokens.rounding.large
            border.color: Colours.palette.m3outlineVariant
            border.width: 1

            // Slots the dragged tile can land on
            Repeater {
                model: root.dragId ? root.slotsFor(root.dragId) : []

                Rectangle {
                    id: ghost

                    required property string modelData

                    readonly property rect r: root.slotRect(root.dragId, modelData)
                    readonly property bool hot: root.nearestSlot(root.dragId, root.dragCentre) === modelData

                    x: r.x
                    y: r.y
                    width: r.width
                    height: r.height
                    radius: Tokens.rounding.small
                    color: ghost.hot ? Qt.alpha(Colours.palette.m3primary, 0.25) : "transparent"
                    border.color: ghost.hot ? Colours.palette.m3primary : Colours.palette.m3outline
                    border.width: ghost.hot ? 2 : 1
                    opacity: ghost.hot ? 1 : 0.5
                    z: 50
                }
            }

            Repeater {
                model: root.elements

                Item {
                    id: tile

                    required property var modelData
                    required property int index

                    readonly property string elementId: modelData.id
                    readonly property string slot: root.currentSlot(elementId)
                    readonly property rect rest: root.slotRect(elementId, slot)
                    property bool dragging
                    property real dragDX
                    property real dragDY

                    readonly property color fill: modelData.kind === "bar" ? Colours.palette.m3primary : modelData.kind === "panel" ? Colours.palette.m3secondaryContainer : modelData.kind === "side" ? Colours.palette.m3tertiaryContainer : Colours.palette.m3surfaceContainerHighest
                    readonly property color onFill: modelData.kind === "bar" ? Colours.palette.m3onPrimary : modelData.kind === "panel" ? Colours.palette.m3onSecondaryContainer : modelData.kind === "side" ? Colours.palette.m3onTertiaryContainer : Colours.palette.m3onSurface

                    x: rest.x + (dragging ? dragDX : 0)
                    y: rest.y + (dragging ? dragDY : 0)
                    width: rest.width
                    height: rest.height
                    z: dragging ? 100 : (modelData.kind === "desktop" ? 5 : 10 + index)

                    Behavior on x {
                        enabled: !tile.dragging

                        Anim {}
                    }

                    Behavior on y {
                        enabled: !tile.dragging

                        Anim {}
                    }

                    Behavior on width {
                        enabled: !tile.dragging

                        Anim {}
                    }

                    Behavior on height {
                        enabled: !tile.dragging

                        Anim {}
                    }

                    StyledRect {
                        anchors.fill: parent
                        radius: tile.modelData.kind === "bar" ? Tokens.rounding.small : Tokens.rounding.medium
                        color: Qt.alpha(tile.fill, tile.dragging ? 1 : 0.85)
                        border.width: tile.dragging ? 2 : 1
                        border.color: tile.dragging ? Colours.palette.m3primary : Qt.alpha(tile.onFill, 0.3)
                    }

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: Tokens.spacing.extraSmall
                        // Vertical strips only have room for the icon
                        visible: tile.width > 18 && tile.height > 18

                        MaterialIcon {
                            text: tile.modelData.icon
                            color: tile.onFill
                            fontStyle: Tokens.font.icon.small
                        }

                        StyledText {
                            visible: tile.width > 110 && tile.height > 30
                            Layout.maximumWidth: tile.width - 40
                            text: tile.modelData.label
                            color: tile.onFill
                            font: Tokens.font.label.small
                            elide: Text.ElideRight
                        }
                    }

                    MouseArea {
                        id: mouse

                        property point start

                        anchors.fill: parent
                        cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor

                        onPressed: event => {
                            start = mapToItem(preview, event.x, event.y);
                            tile.dragDX = 0;
                            tile.dragDY = 0;
                            tile.dragging = true;
                            root.dragId = tile.elementId;
                            root.dragCentre = Qt.point(tile.rest.x + tile.rest.width / 2, tile.rest.y + tile.rest.height / 2);
                        }

                        onPositionChanged: event => {
                            if (!pressed)
                                return;
                            const p = mapToItem(preview, event.x, event.y);
                            tile.dragDX = p.x - start.x;
                            tile.dragDY = p.y - start.y;
                            root.dragCentre = Qt.point(tile.rest.x + tile.rest.width / 2 + tile.dragDX, tile.rest.y + tile.rest.height / 2 + tile.dragDY);
                        }

                        onReleased: {
                            const target = root.nearestSlot(tile.elementId, root.dragCentre);
                            tile.dragging = false;
                            tile.dragDX = 0;
                            tile.dragDY = 0;
                            root.dragId = "";
                            if (target && target !== tile.slot)
                                root.applySlot(tile.elementId, target);
                        }

                        onCanceled: {
                            tile.dragging = false;
                            root.dragId = "";
                        }
                    }
                }
            }
        }

        // Where everything currently is
        Repeater {
            model: root.elements

            ConnectedRect {
                id: row

                required property var modelData
                required property int index

                Layout.fillWidth: true
                first: index === 0
                last: index === root.elements.length - 1
                implicitHeight: rowLayout.implicitHeight + rowLayout.anchors.margins * 2

                RowLayout {
                    id: rowLayout

                    anchors.fill: parent
                    anchors.margins: Tokens.padding.medium
                    anchors.leftMargin: Tokens.padding.largeIncreased
                    anchors.rightMargin: Tokens.padding.largeIncreased
                    spacing: Tokens.spacing.medium

                    MaterialIcon {
                        text: row.modelData.icon
                        color: Colours.palette.m3onSurfaceVariant
                        fontStyle: Tokens.font.icon.medium
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: row.modelData.label
                        font: Tokens.font.body.small
                        elide: Text.ElideRight
                    }

                    StyledText {
                        text: root.prettySlot(root.currentSlot(row.modelData.id))
                        color: Colours.palette.m3primary
                        font: Tokens.font.label.medium
                    }
                }
            }
        }

        StyledText {
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            text: Tr.tr("The sidebar, notifications, utilities and toasts share one side. With \"Mirror panels with a right-hand bar\" on in the Taskbar settings, every side panel also flips when the bar is on the right.")
            color: Colours.palette.m3outline
            font: Tokens.font.label.small
        }

        TextButton {
            Layout.alignment: Qt.AlignRight
            text: Tr.tr("Reset layout")
            type: TextButton.Tonal
            onClicked: root.resetAll()
        }
    }
}
