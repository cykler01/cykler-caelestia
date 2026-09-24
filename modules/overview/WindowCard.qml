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
    // Monitor geometry and tile size, so layout coordinates can be scaled into the tile
    required property real scaleX
    required property real scaleY
    required property real originX
    required property real originY
    required property real tileWidth
    required property real tileHeight

    readonly property var ipc: root.client?.lastIpcObject
    readonly property bool hovered: stateLayer.containsMouse
    readonly property bool fullscreen: (root.ipc?.fullscreen ?? 0) !== 0
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

    x: root.fullscreen ? 0 : Math.round(((root.ipc?.at?.[0] ?? 0) - root.originX) * root.scaleX)
    y: root.fullscreen ? 0 : Math.round(((root.ipc?.at?.[1] ?? 0) - root.originY) * root.scaleY)
    width: root.fullscreen ? root.tileWidth : Math.max(2, Math.round((root.ipc?.size?.[0] ?? 0) * root.scaleX))
    height: root.fullscreen ? root.tileHeight : Math.max(2, Math.round((root.ipc?.size?.[1] ?? 0) * root.scaleY))

    radius: Tokens.rounding.extraSmall
    color: Colours.tPalette.m3surfaceContainerHighest
    border.width: 1
    border.color: root.hovered ? Colours.palette.m3primary : Qt.alpha(Colours.palette.m3outline, 0.5)
    clip: true

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

        onClicked: {
            Hypr.focusWindow(root.client?.address ?? "");
            root.screenState.overview = false;
        }
    }
}
