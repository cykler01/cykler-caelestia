pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.components
import qs.components.controls
import qs.services

// Two side-by-side mini columns mirroring the lock screen's own left/right widget stacks
// (modules/lock/Content.qml). Drag a tile's handle to reorder it, or drag it across the gap to
// move it to the other column; drag the thin strip under a tile to resize it against its
// neighbour below. A switch per tile shows or hides it without removing it from the list.
//
// Built on a ListView + DelegateModel + ScriptModel per column (the same combination
// ListEditor.qml uses for its own reorderable list) rather than a plain Repeater, specifically so
// add/remove/move get real, animated transitions instead of the list being torn down and rebuilt
// from scratch on every toggle, resize or reorder.
Item {
    id: root

    // The live Config.lock.widgets list node itself (not a snapshot) - mutated directly, the
    // same way a ToggleRow writes straight to GlobalConfig
    required property var list
    // id -> display name / material icon
    required property var names
    required property var icons

    // Fixed design height for the two mini columns; only used to turn a drag's pixel delta into
    // a weight delta, and to size tiles for feedback while editing - not tied to any real screen
    readonly property real previewHeight: 320
    readonly property real minWeight: 0.2
    readonly property real tileSpacing: Tokens.spacing.extraSmall / 2

    // Every entry's enabled/column/weight is read here so this is worked out again whenever
    // one changes, same trick Content.qml's own WidgetColumn uses
    readonly property var entries: {
        const vals = root.list.values;
        for (const e of vals)
            void [e.enabled, e.column, e.weight];
        return vals;
    }

    readonly property var leftEntries: root.entries.filter(e => e.column === "left")
    readonly property var rightEntries: root.entries.filter(e => e.column === "right")

    // While a resize handle is being dragged, the two affected weights live here instead of
    // being written to `list` on every mouse move - that would thrash the view (rebuilding tiles
    // mid-drag) and corrupt the config if a write ever raced a read. Committed on release. Also
    // doubles as the "a resize is in progress" flag the tiles' height Behaviors check, so the
    // live drag isn't laggy behind the mouse
    property var activeResize: null

    function realIndexOf(id: string): int {
        return root.list.values.findIndex(e => e.id === id);
    }

    function entriesFor(column: string): var {
        return column === "left" ? root.leftEntries : root.rightEntries;
    }

    // The entry (other than `excludeId`) whose tile in `column` sits closest to the drop point
    // (root's coordinates); null if that column has nothing there. Dropping onto this spot swaps
    // the dragged entry into its place
    function nearestOther(column: string, globalY: real, excludeId: string): var {
        const view = column === "left" ? leftArea : rightArea;
        const local = view.mapFromItem(root, view.width / 2, globalY);
        const item = view.itemAt(local.x, local.y) as Tile;
        if (!item || item.entry.id === excludeId)
            return null;
        return item.entry;
    }

    readonly property real framePadding: Tokens.padding.large

    implicitHeight: screenFrame.height

    // A dark "screen" frame so this reads as a miniature of the real lock screen rather than a
    // plain settings list - the gap in the middle is where the clock and password field live
    // (modules/lock/Center.qml), which isn't part of this editor since it can't be moved
    StyledRect {
        id: screenFrame

        anchors.left: parent.left
        anchors.right: parent.right
        height: row.implicitHeight + root.framePadding * 2
        radius: Tokens.rounding.extraLarge
        color: Colours.palette.m3shadow
        border.width: 1
        border.color: Qt.alpha(Colours.palette.m3outlineVariant, 0.4)

        RowLayout {
            id: row

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: root.framePadding
            spacing: Tokens.spacing.large

            WidgetColumnArea {
                id: leftArea

                Layout.fillWidth: true
                column: "left"
            }

            ColumnLayout {
                Layout.alignment: Qt.AlignVCenter
                spacing: Tokens.spacing.extraSmall

                MaterialIcon {
                    Layout.alignment: Qt.AlignHCenter
                    text: "lock_clock"
                    color: Qt.alpha(Colours.palette.m3onSurface, 0.35)
                    fontStyle: Tokens.font.icon.large
                }

                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.maximumWidth: 64
                    text: qsTr("Clock stays here")
                    color: Qt.alpha(Colours.palette.m3onSurface, 0.35)
                    font: Tokens.font.label.small
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                }
            }

            WidgetColumnArea {
                id: rightArea

                Layout.fillWidth: true
                column: "right"
            }
        }
    }

    component WidgetColumnArea: ListView {
        id: columnArea

        required property string column

        Layout.fillWidth: true
        implicitHeight: columnArea.contentHeight
        spacing: root.tileSpacing
        interactive: false

        readonly property var items: root.entriesFor(columnArea.column)
        readonly property real totalWeight: columnArea.items.filter(e => e.enabled).reduce((sum, e) => sum + e.weight, 0) || 1

        Behavior on implicitHeight {
            Anim {}
        }

        model: ScriptModel {
            values: columnArea.items
        }

        delegate: Tile {
            required property var modelData
            required property int index

            area: columnArea
            entry: modelData
            tileIndex: index
            isLast: index === columnArea.count - 1
        }

        add: Transition {
            Anim {
                properties: "opacity"
                type: Anim.DefaultEffects
                from: 0
                to: 1
            }
        }

        remove: Transition {
            Anim {
                properties: "opacity"
                type: Anim.DefaultEffects
                to: 0
            }
        }

        move: Transition {
            Anim {
                properties: "opacity"
                type: Anim.DefaultEffects
                to: 1
            }
            Anim {
                properties: "y"
            }
        }

        displaced: Transition {
            Anim {
                properties: "opacity"
                type: Anim.DefaultEffects
                to: 1
            }
            Anim {
                properties: "y"
            }
        }
    }

    // One row: drag handle + icon + label + switch, with a resize strip under it
    component Tile: Item {
        id: tile

        required property var area
        required property var entry
        required property int tileIndex
        required property bool isLast

        // The live config weight, unless this tile is one half of an in-progress resize drag
        readonly property real liveWeight: {
            const r = root.activeResize;
            if (!r)
                return tile.entry.weight;
            if (r.aboveId === tile.entry.id)
                return r.aboveWeight;
            if (r.belowId === tile.entry.id)
                return r.belowWeight;
            return tile.entry.weight;
        }

        readonly property real shareHeight: tile.entry.enabled ? tile.liveWeight / tile.area.totalWeight * root.previewHeight : 44
        readonly property bool resizable: tile.entry.enabled && !tile.isLast && root.entriesFor(tile.area.column)[tile.tileIndex + 1]?.enabled

        property bool held

        width: ListView.view ? ListView.view.width : 0
        height: Math.max(44, tile.shareHeight) + (tile.resizable ? 10 : 0)

        // Smooths toggles and weight changes settling into place - but not while a resize is
        // actively being dragged, or the visual feedback would lag behind the pointer
        Behavior on height {
            enabled: !root.activeResize
            Anim {}
        }

        Item {
            id: content

            width: parent.width
            height: tileBody.height
            z: tile.held ? 1 : 0

            Behavior on x {
                enabled: !tile.held
                Anim {}
            }

            Behavior on y {
                enabled: !tile.held
                Anim {}
            }

            StyledRect {
                id: tileBody

                width: parent.width
                implicitHeight: Math.max(44, tile.shareHeight)
                radius: Tokens.rounding.extraLarge
                color: tile.held ? Colours.palette.m3primaryContainer : Colours.tPalette.m3surfaceContainer
                opacity: tile.entry.enabled ? 1 : 0.5

                Behavior on implicitHeight {
                    enabled: !root.activeResize
                    Anim {}
                }

                // Declared before the row below so the row (and its switch/delete-style
                // controls) sits on top and gets first dibs on clicks - otherwise this swallows
                // every click meant for the switch and treats it as a (zero-movement) drag
                MouseArea {
                    id: dragHandle

                    anchors.fill: parent
                    enabled: tile.entry.enabled
                    preventStealing: true

                    property point pressPos

                    onPressed: e => {
                        tile.held = true;
                        dragHandle.pressPos = Qt.point(e.x, e.y);
                    }

                    onPositionChanged: e => {
                        if (!tile.held)
                            return;
                        content.x += e.x - dragHandle.pressPos.x;
                        content.y += e.y - dragHandle.pressPos.y;
                    }

                    onReleased: e => {
                        tile.held = false;

                        const globalPos = content.mapToItem(root, dragHandle.pressPos.x, dragHandle.pressPos.y);
                        const targetColumn = globalPos.x < root.width / 2 ? "left" : "right";

                        content.x = 0;
                        content.y = 0;

                        const sourceColumn = tile.entry.column;
                        if (targetColumn !== sourceColumn)
                            root.list.at(root.realIndexOf(tile.entry.id)).column = targetColumn;

                        // Swap places with whichever other tile in the target column sits
                        // closest to the drop point
                        const swapWith = root.nearestOther(targetColumn, globalPos.y, tile.entry.id);
                        if (swapWith)
                            root.list.move(root.realIndexOf(tile.entry.id), root.realIndexOf(swapWith.id));
                    }
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: Tokens.padding.medium
                    spacing: Tokens.spacing.medium

                    MaterialIcon {
                        text: "drag_indicator"
                        color: Colours.palette.m3onSurfaceVariant
                        fontStyle: Tokens.font.icon.small
                    }

                    MaterialIcon {
                        text: root.icons[tile.entry.id] ?? "widgets"
                        color: Colours.palette.m3onSurfaceVariant
                        fontStyle: Tokens.font.icon.small
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: root.names[tile.entry.id] ?? tile.entry.id
                        color: Colours.palette.m3onSurface
                        elide: Text.ElideRight
                    }

                    StyledSwitch {
                        checked: tile.entry.enabled
                        onToggled: root.list.at(root.realIndexOf(tile.entry.id)).enabled = checked
                    }
                }
            }
        }

        // Resize strip: drags the split between this tile and the next enabled one below it
        MouseArea {
            id: resizeHandle

            visible: tile.resizable
            anchors.top: content.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            height: 10
            cursorShape: Qt.SizeVerCursor
            preventStealing: true
            hoverEnabled: true

            property real pressY
            property string belowId
            property real aboveWeight0
            property real belowWeight0

            StyledRect {
                anchors.centerIn: parent
                width: parent.width * 0.3
                implicitHeight: 4
                radius: Tokens.rounding.full
                color: resizeHandle.pressed || resizeHandle.containsMouse ? Colours.palette.m3primary : Colours.palette.m3outlineVariant
            }

            onPressed: e => {
                pressY = e.y;
                const belowEntry = root.entriesFor(tile.area.column)[tile.tileIndex + 1];
                belowId = belowEntry.id;
                aboveWeight0 = tile.entry.weight;
                belowWeight0 = belowEntry.weight;
                root.activeResize = {
                    aboveId: tile.entry.id,
                    belowId: belowId,
                    aboveWeight: aboveWeight0,
                    belowWeight: belowWeight0
                };
            }

            // hoverEnabled above (for the highlight) makes this fire on mere hover too - only
            // the actual drag should move anything
            onPositionChanged: e => {
                if (!resizeHandle.pressed)
                    return;

                const dy = e.y - pressY;
                const totalW = aboveWeight0 + belowWeight0;
                const deltaWeight = dy / root.previewHeight * tile.area.totalWeight;
                const newAbove = Math.max(root.minWeight, Math.min(totalW - root.minWeight, aboveWeight0 + deltaWeight));
                const newBelow = totalW - newAbove;

                root.activeResize = {
                    aboveId: tile.entry.id,
                    belowId: belowId,
                    aboveWeight: newAbove,
                    belowWeight: newBelow
                };
            }

            onReleased: e => {
                const r = root.activeResize;
                if (r) {
                    root.list.at(root.realIndexOf(r.aboveId)).weight = r.aboveWeight;
                    root.list.at(root.realIndexOf(r.belowId)).weight = r.belowWeight;
                }
                root.activeResize = null;
            }
        }
    }
}
