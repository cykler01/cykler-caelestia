pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Caelestia.Config
import qs.components
import qs.services

// A 16:9 representation of one workspace: every window on it is drawn at the position
// and size Hyprland reports, scaled down from its monitor into this tile. Clicking a
// window focuses it, clicking anywhere else on the tile focuses the workspace.
StyledClippingRect {
    id: root

    required property int wsId
    required property bool active
    required property int cardWidth
    required property int cardHeight
    required property ScreenState screenState

    readonly property var workspace: Hypr.workspaces.values.find(w => w.id === root.wsId) ?? null
    // A plain array of toplevels. The Repeater below cannot take a `list<HyprlandToplevel>`
    // directly, it has to be handed something it can turn into model data.
    readonly property var windows: {
        const windows = [];
        const list = Hypr.toplevelsForWs(root.wsId, GlobalConfig.bar.workspaces.ignoredTags);
        for (let i = 0; i < list.length; ++i)
            windows.push(list[i]);

        // Least recently focused first, so the focused window ends up on top
        windows.sort((a, b) => (b?.lastIpcObject?.focusHistoryID ?? 0) - (a?.lastIpcObject?.focusHistoryID ?? 0));
        return windows;
    }
    readonly property bool occupied: root.windows.length > 0
    readonly property string wsLabel: {
        const name = root.workspace?.name;
        return name && name !== String(root.wsId) ? name : String(root.wsId);
    }

    // Windows report layout coordinates, so they are placed relative to the monitor
    // they sit on and scaled from that monitor's size into this tile. A tile is 16:9
    // while a monitor is usually a little taller, so the axes are scaled separately:
    // the workspace ends up fractionally squashed rather than cropped.
    readonly property var wsMonitor: root.workspace?.monitor ?? null
    readonly property real scaleX: root.wsMonitor?.width ? root.contentWidth / root.wsMonitor.width : 0
    readonly property real scaleY: root.wsMonitor?.height ? root.contentHeight / root.wsMonitor.height : 0
    readonly property real originX: root.wsMonitor?.x ?? 0
    readonly property real originY: root.wsMonitor?.y ?? 0
    // The tile's content is inset by its border, so window geometry has to match
    readonly property real contentWidth: root.cardWidth - root.border.width * 2
    readonly property real contentHeight: root.cardHeight - root.border.width * 2

    implicitWidth: root.cardWidth
    implicitHeight: root.cardHeight
    radius: Tokens.rounding.large
    // Occupied workspaces read brighter than the empty ones, which stay dark
    color: root.occupied ? Colours.tPalette.m3surfaceContainerHighest : Colours.tPalette.m3surfaceContainerLowest
    border.width: root.active ? 2 : 1
    border.color: root.active ? Colours.palette.m3primary : root.occupied ? Colours.tPalette.m3outline : Colours.tPalette.m3outlineVariant

    Behavior on border.color {
        CAnim {}
    }

    // Behind the windows, so a click that misses them focuses this workspace
    StateLayer {
        id: stateLayer

        onClicked: {
            Hypr.focusWorkspace(root.wsId);
            root.screenState.overview = false;
        }
    }

    Item {
        anchors.fill: parent

        Repeater {
            model: ScriptModel {
                values: root.windows
            }

            WindowCard {
                required property var modelData

                client: modelData
                screenState: root.screenState
                scaleX: root.scaleX
                scaleY: root.scaleY
                originX: root.originX
                originY: root.originY
                tileWidth: root.contentWidth
                tileHeight: root.contentHeight
            }
        }
    }

    // Overlaid on the tile so it stays readable over a bright window preview
    StyledRect {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.margins: Tokens.padding.small

        implicitWidth: header.implicitWidth + Tokens.padding.small * 2
        implicitHeight: header.implicitHeight + Tokens.padding.extraSmall * 2
        radius: Tokens.rounding.full
        color: Qt.alpha(Colours.palette.m3surfaceContainerLowest, 0.6)

        Row {
            id: header

            anchors.centerIn: parent
            spacing: Tokens.spacing.small

            StyledText {
                text: root.wsLabel
                color: root.active ? Colours.palette.m3primary : root.occupied ? Colours.palette.m3onSurface : Colours.palette.m3onSurfaceVariant
                font: Tokens.font.body.medium
            }

            StyledText {
                visible: root.occupied
                text: root.windows.length
                color: Colours.palette.m3onSurfaceVariant
            }
        }
    }
}
