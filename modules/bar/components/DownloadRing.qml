pragma ComponentBehavior: Bound

import QtQuick
import Caelestia.Config
import Caelestia.Services
import qs.components
import qs.components.controls
import qs.services

// NOTE(fork): the notch's download ring, drawn in the bar while the notch is not showing it - the
// same fallback the countdown takes (see modules/bar/components/TimerRing.qml), and beside its ring.
// A ring filling as the transfer goes, with the percentage in the middle; a source that cannot say
// how big the file will be (a Chromium part file only grows) gets a quarter arc that turns instead.
// See plugin/src/Caelestia/Services/downloads.cpp for where the figures come from.
StyledRect {
    id: root

    readonly property var item: Downloads.primary
    readonly property real progress: root.item.progress ?? -1
    readonly property bool known: root.progress >= 0
    readonly property bool steam: (root.item.kind ?? "") === "steam"
    readonly property int size: Tokens.sizes.bar.innerWidth

    implicitWidth: root.size
    implicitHeight: root.size

    color: Colours.tPalette.m3surfaceContainer
    radius: Tokens.rounding.full

    CircularProgress {
        id: ring

        anchors.fill: parent
        anchors.margins: Tokens.padding.extraSmall / 2

        strokeWidth: 3
        // A quarter arc to turn while there is nothing to fill in proportion
        value: root.known ? root.progress : 0.25
        fgColour: Colours.palette.m3primary
        bgColour: Qt.alpha(Colours.palette.m3outlineVariant, 0.6)

        RotationAnimator on rotation {
            running: !root.known && PowerSaving.animations
            loops: Animation.Infinite
            from: 0
            to: 360
            duration: 1400
        }

        // The animator leaves the ring wherever it stopped, which would offset a real progress arc
        Binding {
            target: ring
            property: "rotation"
            value: 0
            when: root.known || !PowerSaving.animations
        }
    }

    StyledText {
        anchors.centerIn: parent

        visible: root.known
        width: ring.width - ring.strokeWidth * 2
        horizontalAlignment: Text.AlignHCenter
        text: Math.round(root.progress * 100)
        color: Colours.palette.m3onSurface
        // The bar's ring is only as wide as the bar's inner width, so this takes the small label size
        // and keeps a little more of the ring's inside: at the large size a two-digit percentage sat
        // right against the stroke
        font: Tokens.font.label.small
        fontSizeMode: Text.Fit
        minimumPixelSize: 8
    }

    MaterialIcon {
        anchors.centerIn: parent

        visible: !root.known
        text: root.steam ? "sports_esports" : "download"
        color: Colours.palette.m3primary
        fontStyle: Tokens.font.icon.small
    }
}
