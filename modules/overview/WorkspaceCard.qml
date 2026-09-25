pragma ComponentBehavior: Bound

import QtQuick
import "geometry.js" as Geometry
import Quickshell
import Caelestia.Config
import qs.components
import qs.services

// A scaled-down picture of one workspace: every window on it is drawn at the position
// and size Hyprland reports, scaled down from its monitor into this tile. Clicking a
// window focuses it, clicking anywhere else on the tile focuses the workspace.
StyledClippingRect {
    id: root

    required property int wsId
    required property bool active
    required property int cardWidth
    required property int cardHeight
    required property ScreenState screenState
    // Outlined as the keyboard's current choice, apart from the focused workspace
    property bool selected
    // A window is being dragged over this tile and would land here if let go
    property bool dropTarget
    // The window being dragged, if any, so its preview here can be dimmed
    property var draggedClient: null

    signal pointerMoved
    signal windowGrabbed(var card, real grabX, real grabY)

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

    // Windows report logical layout coordinates, so they are placed relative to the usable part
    // of the monitor they sit on (see geometry.js) and scaled into this tile by one factor for
    // both axes, then centred: a workspace on a monitor shaped differently to the tile is
    // letterboxed rather than stretched, and on a matching monitor it fills the tile.
    readonly property var usable: Geometry.usableRect(root.workspace?.monitor?.lastIpcObject)
    // The tile's content is inset by its border, so window geometry has to match
    readonly property real contentWidth: root.cardWidth - root.border.width * 2
    readonly property real contentHeight: root.cardHeight - root.border.width * 2
    readonly property real fit: root.usable ? Math.min(root.contentWidth / root.usable.width, root.contentHeight / root.usable.height) : 0
    readonly property real offsetX: root.usable ? (root.contentWidth - root.usable.width * root.fit) / 2 : 0
    readonly property real offsetY: root.usable ? (root.contentHeight - root.usable.height * root.fit) / 2 : 0

    implicitWidth: root.cardWidth
    implicitHeight: root.cardHeight
    radius: Tokens.rounding.large
    // Occupied workspaces read brighter than the empty ones, which stay dark
    color: root.occupied ? Colours.tPalette.m3surfaceContainerHighest : Colours.tPalette.m3surfaceContainerLowest
    border.width: root.active ? 2 : 1
    border.color: root.borderColour

    // Animated through a plain property: ClippingRectangle's border is an alias into an
    // inner rectangle, and a Behavior directly on border.color crashes Quickshell
    property color borderColour: root.active ? Colours.palette.m3primary : root.occupied ? Colours.tPalette.m3outline : Colours.tPalette.m3outlineVariant

    Behavior on borderColour {
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
                id: card

                required property var modelData

                client: modelData
                ghosted: root.draggedClient !== null && modelData === root.draggedClient
                onGrabbed: (grabX, grabY) => root.windowGrabbed(card, grabX, grabY)
                screenState: root.screenState
                fit: root.fit
                offsetX: root.offsetX
                offsetY: root.offsetY
                originX: root.usable?.x ?? 0
                originY: root.usable?.y ?? 0
                tileWidth: root.contentWidth
                tileHeight: root.contentHeight
            }
        }
    }

    // Only real pointer movement counts, so a tile that merely ends up under a resting pointer
    // (after the keyboard moves the page, say) doesn't steal the selection back
    HoverHandler {
        onPointChanged: root.pointerMoved()
    }

    // The keyboard's current choice, drawn inside the tile's own outline so it can sit on the
    // focused workspace without hiding that it is the focused one
    StyledRect {
        anchors.fill: parent
        anchors.margins: 3
        radius: root.radius - 3
        color: "transparent"
        border.width: 2
        border.color: Colours.palette.m3tertiary
        opacity: root.selected ? 1 : 0

        Behavior on opacity {
            Anim {
                type: Anim.FastEffects
            }
        }
    }

    // Lit while a dragged window is over the tile
    StyledRect {
        anchors.fill: parent
        radius: root.radius
        color: Qt.alpha(Colours.palette.m3primary, 0.18)
        border.width: 2
        border.color: Colours.palette.m3primary
        opacity: root.dropTarget ? 1 : 0

        Behavior on opacity {
            Anim {
                type: Anim.FastEffects
            }
        }
    }

    // The workspace number top left and how many windows it holds top right, both overlaid on
    // the tile so they stay readable over a bright window preview
    StyledRect {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.margins: Tokens.padding.small

        implicitWidth: label.implicitWidth + Tokens.padding.small * 2
        implicitHeight: label.implicitHeight + Tokens.padding.extraSmall * 2
        radius: Tokens.rounding.full
        color: Qt.alpha(Colours.palette.m3surfaceContainerLowest, 0.6)

        StyledText {
            id: label

            anchors.centerIn: parent
            text: root.wsLabel
            color: root.active ? Colours.palette.m3primary : root.occupied ? Colours.palette.m3onSurface : Colours.palette.m3onSurfaceVariant
            font: Tokens.font.body.medium
        }
    }

    StyledRect {
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Tokens.padding.small

        visible: root.occupied
        implicitWidth: Math.max(implicitHeight, count.implicitWidth + Tokens.padding.small * 2)
        implicitHeight: count.implicitHeight + Tokens.padding.extraSmall * 2
        radius: Tokens.rounding.full
        color: Qt.alpha(Colours.palette.m3surfaceContainerLowest, 0.6)

        StyledText {
            id: count

            anchors.centerIn: parent
            text: root.windows.length
            color: Colours.palette.m3onSurfaceVariant
        }
    }
}
