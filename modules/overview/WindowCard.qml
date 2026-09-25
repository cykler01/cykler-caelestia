pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import Caelestia.Config
import qs.components
import qs.services
import qs.utils

// One window inside a workspace tile: a capture of the window drawn at the position and
// size Hyprland reports for it, scaled from its monitor into the tile, with the app's
// own icon over the middle of it. Clicking it focuses the window and closes the overview.
StyledRect {
    id: root

    required property var client
    required property ScreenState screenState
    // Where the monitor's usable area sits in the tile: layout coordinates are moved to the
    // origin, scaled by fit and shifted by the offsets that centre it
    required property real fit
    required property real offsetX
    required property real offsetY
    required property real originX
    required property real originY
    required property real tileWidth
    required property real tileHeight

    // Dimmed in its tile while it is being dragged out of it
    property bool ghosted

    // Pressed, so the overview can start dragging this window if the pointer then moves
    signal grabbed(real grabX, real grabY)

    readonly property var ipc: root.client?.lastIpcObject
    readonly property bool hovered: stateLayer.containsMouse
    // Clamped to the tile, so a fullscreen window (which also covers the bar's reserved
    // area) or one dragged partly off the monitor is trimmed rather than spilling out of it
    readonly property real edgeLeft: Math.max(0, Math.round(root.offsetX + ((root.ipc?.at?.[0] ?? 0) - root.originX) * root.fit))
    readonly property real edgeTop: Math.max(0, Math.round(root.offsetY + ((root.ipc?.at?.[1] ?? 0) - root.originY) * root.fit))
    readonly property real edgeRight: Math.min(root.tileWidth, Math.round(root.offsetX + ((root.ipc?.at?.[0] ?? 0) + (root.ipc?.size?.[0] ?? 0) - root.originX) * root.fit))
    readonly property real edgeBottom: Math.min(root.tileHeight, Math.round(root.offsetY + ((root.ipc?.at?.[1] ?? 0) + (root.ipc?.size?.[1] ?? 0) - root.originY) * root.fit))
    // Only capture while the overview is up, so nothing is recorded otherwise
    readonly property var captureSource: root.screenState.overview ? root.client?.wayland ?? null : null
    // Kept in proportion to the window it sits on, so it does not swamp a small one
    readonly property real iconSize: Math.round(Math.min(44, Math.min(root.width, root.height) * 0.22))
    // Below this a window has no room for an icon without covering the whole preview
    readonly property bool showIcon: root.iconSize >= 12
    // The icon is looked up and resolved here rather than through Icons.getAppIcon,
    // which hands the icon theme a fallback name and always ends up rendering that
    // fallback instead of the app's own icon
    readonly property string appIconName: DesktopEntries.heuristicLookup(root.ipc?.class ?? "")?.icon ?? ""
    readonly property string appIcon: root.appIconName !== "" && Quickshell.hasThemeIcon(root.appIconName) ? Quickshell.iconPath(root.appIconName) : ""

    x: root.edgeLeft
    y: root.edgeTop
    width: Math.max(2, root.edgeRight - root.edgeLeft)
    height: Math.max(2, root.edgeBottom - root.edgeTop)

    radius: Tokens.rounding.extraSmall
    color: Colours.tPalette.m3surfaceContainerHighest
    border.width: 1
    border.color: root.hovered ? Colours.palette.m3primary : Qt.alpha(Colours.palette.m3outline, 0.5)
    clip: true
    opacity: root.ghosted ? 0.35 : 1

    Behavior on opacity {
        Anim {
            type: Anim.FastEffects
        }
    }

    ScreencopyView {
        id: view

        anchors.fill: parent
        captureSource: root.captureSource
        // A still frame per window: a live stream of every window on screen would
        // capture at full resolution on every frame
        live: false
    }

    // The app's own icon over the middle of its window, so a glance at a tile says which
    // app is where. It also stands in for a window whose capture is not available.
    StyledRect {
        anchors.centerIn: parent
        visible: root.showIcon
        implicitWidth: root.iconSize + Tokens.padding.extraSmall * 2
        implicitHeight: root.iconSize + Tokens.padding.extraSmall * 2
        radius: Tokens.rounding.full
        // Keeps a dark logo readable over a bright window without hiding it
        color: Qt.alpha(Colours.palette.m3surfaceContainerLowest, 0.45)

        IconImage {
            anchors.centerIn: parent
            visible: root.appIcon !== ""
            asynchronous: true
            implicitSize: root.iconSize
            source: root.appIcon
        }

        // Nothing themed for this app, so fall back to its category glyph
        MaterialIcon {
            anchors.centerIn: parent
            visible: root.appIcon === ""
            text: Icons.getAppCategoryIcon(root.ipc?.class, "window")
            color: Colours.palette.m3onSurface
            fontStyle: Tokens.font.icon.size(root.iconSize * 0.8).build()
        }
    }

    StateLayer {
        id: stateLayer

        onPressed: e => root.grabbed(e.x, e.y)
        onClicked: {
            Hypr.focusWindow(root.client?.address ?? "");
            root.screenState.overview = false;
        }
    }
}
