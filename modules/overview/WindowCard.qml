pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Wayland
import Caelestia.Config
import qs.components
import qs.services
import qs.utils

// One window inside a workspace tile: a capture of the window drawn at the position and
// size Hyprland reports for it, scaled from its monitor into the tile. Clicking it
// focuses the window and closes the overview.
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

    // Shown while the capture is unavailable, so the window is still identifiable
    MaterialIcon {
        anchors.centerIn: parent
        visible: !view.hasContent && root.width > Tokens.padding.extraLarge && root.height > Tokens.padding.extraLarge
        text: Icons.getAppCategoryIcon(root.ipc?.class, "window")
        color: Colours.palette.m3outline
    }

    StateLayer {
        id: stateLayer

        onClicked: {
            Hypr.focusWindow(root.client?.address ?? "");
            root.screenState.overview = false;
        }
    }
}
