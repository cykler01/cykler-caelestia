pragma ComponentBehavior: Bound

import QtQuick
import Caelestia.Config
import qs.components
import qs.services
import qs.modules.lock.canvas

// A live, read-only miniature of the actual lock screen: the same canvas the lock draws
// (modules/lock/canvas/LockCanvas.qml) with the saved elements, laid out at the real monitor's
// size and scaled down to fit the settings page, so it updates live as things are changed. The
// password field is a dummy here, since the real one would grab the keyboard and drive PAM.
//
// Deliberately non-interactive: an invisible MouseArea on top eats every click so nothing in
// here can accidentally fire a real action (session buttons, media transport) while someone's
// just looking at it
Item {
    id: root

    readonly property real framePadding: Tokens.padding.large

    // The real monitor's size, so the elements land where they will on the lock screen and the
    // widgets make the same decisions about what fits. 1080p until there's a screen to ask
    property real screenHeight: 1080
    property real screenWidth: 1920

    readonly property real factor: (root.width - root.framePadding * 2) / Math.max(1, root.screenWidth)

    implicitHeight: root.screenHeight * root.factor + root.framePadding * 2

    StyledRect {
        anchors.fill: parent
        radius: Tokens.rounding.extraLarge
        color: Colours.palette.m3shadow
        border.width: 1
        border.color: Qt.alpha(Colours.palette.m3outlineVariant, 0.4)
        clip: true

        // The wallpaper, dimmed the way the lock dims it
        Image {
            x: root.framePadding
            y: root.framePadding
            width: root.screenWidth * root.factor
            height: root.screenHeight * root.factor
            source: (Config.lock.wallpaper ?? "") !== "" ? Config.lock.wallpaper : Wallpapers.current
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            sourceSize: Qt.size(width, height)
            opacity: 0.6
        }

        LockCanvas {
            x: root.framePadding
            y: root.framePadding
            width: root.screenWidth
            height: root.screenHeight
            scale: root.factor
            transformOrigin: Item.TopLeft
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        hoverEnabled: true
    }
}
