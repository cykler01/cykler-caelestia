pragma ComponentBehavior: Bound

import "geometry.js" as Geometry
import QtQuick
import Quickshell
import Quickshell.Widgets
import Caelestia.Config
import qs.components
import qs.services

// A scaled-down picture of one workspace: every window on it is drawn at the position
// and size Hyprland reports, scaled down from its monitor into this tile. Clicking a
// window focuses it, clicking anywhere else on the tile focuses the workspace.
ClippingRectangle {
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
    // The window a dragged one would trade places with, if it is on this tile
    property var swapClient: null
    // The whole workspace is being dragged from here
    property bool lifted
    // Position on the page, so the tiles can come in one after another
    property int order
    // How far below its place the tile starts as it comes in. The Grid positions the tiles, so
    // this is a transform rather than a y of its own: moving y would fight the layout
    property real enterOffset

    signal pointerMoved
    // Pressed on the tile itself rather than on a window, so the whole workspace can be dragged
    signal tileGrabbed(real grabX, real grabY)
    signal windowGrabbed(var card, real grabX, real grabY)

    // The window under a point given in the coordinates of `item`, or null
    function windowAt(item: Item, x: real, y: real): var {
        for (let i = 0; i < windowCards.count; ++i) {
            const card = windowCards.itemAt(i);
            if (card && card.contains(card.mapFromItem(item, x, y)))
                return card.client;
        }
        return null;
    }

    // The window under a point and which of its edges the point is nearest, so a window dropped
    // into this tile from elsewhere can split in right where it was dropped near, the same way
    // Hyprland's own click-drag preview picks a side - rather than always landing on a fixed one.
    // Hands back the window too: preselect splits relative to whichever window is focused at
    // the time, not whatever the pointer happens to be over, so the caller needs to focus this
    // one specifically first rather than just the workspace
    function splitTargetAt(item: Item, x: real, y: real): var {
        for (let i = 0; i < windowCards.count; ++i) {
            const card = windowCards.itemAt(i);
            const local = card ? card.mapFromItem(item, x, y) : null;
            if (card && card.contains(local)) {
                const left = local.x / card.width;
                const top = local.y / card.height;
                const right = 1 - left;
                const bottom = 1 - top;
                const closest = Math.min(left, right, top, bottom);
                const dir = closest === left ? "l" : closest === right ? "r" : closest === top ? "u" : "d";
                return {
                    dir,
                    client: card.client
                };
            }
        }
        return null;
    }

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
    // Lifts a little for the keyboard's choice and more for a window about to land on it
    scale: root.dropTarget ? 1.04 : root.lifted ? 0.96 : root.selected ? 1.015 : 1
    transform: Translate {
        y: root.enterOffset
    }

    Behavior on scale {
        Anim {
            type: Anim.FastSpatial
        }
    }

    // Each tile rises into place a moment after the one before it
    Component.onCompleted: enter.start()

    SequentialAnimation {
        id: enter

        PropertyAction {
            target: root
            property: "opacity"
            value: 0
        }

        PropertyAction {
            target: root
            property: "enterOffset"
            value: 14
        }

        PauseAnimation {
            duration: root.order * 30
        }

        ParallelAnimation {
            NumberAnimation {
                target: root
                property: "opacity"
                to: 1
                duration: 220
                easing.type: Easing.OutCubic
            }

            NumberAnimation {
                target: root
                property: "enterOffset"
                to: 0
                duration: 320
                easing.type: Easing.OutCubic
            }
        }
    }

    radius: Tokens.rounding.large
    // Occupied workspaces sit one step up the surface ladder from the empty ones, so the tones
    // read as panel, tile, window preview. Empty tiles only take the plain surface tone, held
    // by their outline, the way an empty slot should read.

    color: root.occupied ? Colours.tPalette.m3surfaceContainerHigh : Colours.tPalette.m3surfaceContainer

    // A hairline, as on every other floating surface in the shell; only the focused workspace
    // takes a colour, and the shadow is left to the panel the tiles sit on
    border.width: 1

    border.color: root.borderColour

    // Animated through a plain property: ClippingRectangle's border is an alias into an
    // inner rectangle, and a Behavior directly on border.color crashes Quickshell
    property color borderColour: root.active ? Colours.palette.m3primary : Qt.alpha(Colours.palette.m3outlineVariant, 0.5)

    Behavior on borderColour {
        CAnim {}
    }

    // Behind the windows, so a click that misses them focuses this workspace
    StateLayer {
        id: stateLayer

        onPressed: e => root.tileGrabbed(e.x, e.y)
        onClicked: {
            Hypr.focusWorkspace(root.wsId);
            root.screenState.overview = false;
        }
    }

    Item {
        anchors.fill: parent

        Repeater {
            id: windowCards

            model: ScriptModel {
                values: root.windows
            }

            WindowCard {
                id: card

                required property var modelData

                client: modelData
                ghosted: root.draggedClient !== null && modelData === root.draggedClient
                dropHighlight: root.swapClient !== null && modelData === root.swapClient
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
    // focused workspace without hiding that it is the focused one. A thin ring alone would all
    // but vanish at a hairline, so the tile is tinted with it as well, the way the drop target
    // below is tinted with the primary.
    StyledRect {
        anchors.fill: parent
        anchors.margins: 3
        radius: root.radius - 3
        color: Qt.alpha(Colours.palette.m3tertiary, 0.12)
        border.width: 1
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
        border.width: 1
        border.color: Colours.palette.m3primary
        opacity: root.dropTarget ? 1 : 0

        Behavior on opacity {
            Anim {
                type: Anim.FastEffects
            }
        }
    }

    // An empty workspace has no preview to put in the tile, so its number is drawn large and
    // faint across the middle instead: a page of free slots then reads as a row of numbers
    // rather than a row of blank boxes. The corner badge is left off for those, so the number
    // isn't said twice.
    StyledText {
        anchors.centerIn: parent
        visible: !root.occupied
        text: root.wsLabel
        color: Qt.alpha(root.active ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant, root.active || root.selected ? 0.55 : 0.28)
        font: Tokens.font.headline.builders.large.scale(Math.max(1, root.cardHeight / 130)).weight(Font.DemiBold).build()
    }

    // The workspace number top left and how many windows it holds top right, both overlaid on
    // the tile so they stay readable over a bright window preview
    StyledRect {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.margins: Tokens.padding.small

        visible: root.occupied
        // Both badges are circles until their contents outgrow one, so a page of tiles has the
        // same shape in both top corners rather than a pill on one side and a circle on the other
        implicitWidth: Math.max(implicitHeight, label.implicitWidth + Tokens.padding.small * 2)
        implicitHeight: label.implicitHeight + Tokens.padding.extraSmall * 2
        radius: Tokens.rounding.full
        // The focused workspace's number is filled in rather than only tinted: a hairline border
        // around the tile alone is easy to miss across a page of ten
        color: root.active ? Colours.palette.m3primary : Qt.alpha(Colours.palette.m3surfaceContainerLowest, 0.65)
        border.width: 1
        border.color: root.active ? "transparent" : Qt.alpha(Colours.palette.m3outline, 0.35)

        // The handle for carrying the whole workspace: a window preview usually covers all of the
        // tile, so there is often no bare part of it to grab. A click here still opens it.
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.OpenHandCursor
            onPressed: e => {
                const at = mapToItem(root, e.x, e.y);
                root.tileGrabbed(at.x, at.y);
            }
            onClicked: {
                Hypr.focusWorkspace(root.wsId);
                root.screenState.overview = false;
            }
        }

        StyledText {
            id: label

            anchors.centerIn: parent
            text: root.wsLabel
            color: root.active ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface
            font: Tokens.font.label.builders.large.weight(Font.DemiBold).build()
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
        color: Qt.alpha(Colours.palette.m3surfaceContainerLowest, 0.65)
        border.width: 1
        border.color: Qt.alpha(Colours.palette.m3outline, 0.35)

        StyledText {
            id: count

            anchors.centerIn: parent
            text: root.windows.length
            color: Colours.palette.m3onSurfaceVariant
            font: Tokens.font.label.builders.large.weight(Font.DemiBold).build()
        }
    }
}
