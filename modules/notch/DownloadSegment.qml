pragma ComponentBehavior: Bound

import QtQuick
import Caelestia.Config
import Caelestia.Services
import qs.components
import qs.components.controls
import qs.services
import qs.utils

// NOTE(fork): what is downloading, drawn inside a Bubble: a ring filling as it goes with the
// percentage in the middle. Only the one furthest along is shown, with a small count in the corner
// when others are behind it (the downloads list is for the rest). A source that cannot say how big
// the file will be (a Chromium part file only grows) gets a ring that turns and an icon instead of
// a percentage. See plugin/src/Caelestia/Services/downloads.cpp for where the figures come from.
Item {
    id: root

    readonly property var item: Downloads.primary
    readonly property bool steam: (root.item.kind ?? "") === "steam"
    readonly property real progress: root.item.progress ?? -1
    readonly property bool known: root.progress >= 0
    readonly property int others: Math.max(0, Downloads.count - 1)

    CircularProgress {
        id: ring

        anchors.fill: parent
        anchors.margins: Tokens.padding.extraSmall

        strokeWidth: Math.max(3, Math.round(width / 12))
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
        width: ring.width - ring.strokeWidth * 3
        horizontalAlignment: Text.AlignHCenter
        text: Math.round(root.progress * 100)
        color: Colours.palette.m3onSurface
        font: Tokens.font.label.large
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

    StyledRect {
        anchors.right: parent.right
        anchors.bottom: parent.bottom

        visible: root.others > 0
        implicitWidth: Math.max(implicitHeight, othersText.implicitWidth + Tokens.padding.small)
        implicitHeight: othersText.implicitHeight + Tokens.padding.extraSmall / 2
        radius: Tokens.rounding.full
        color: Colours.palette.m3primary

        StyledText {
            id: othersText

            anchors.centerIn: parent

            text: "+" + root.others
            color: Colours.palette.m3onPrimary
            font: Tokens.font.label.small
        }
    }
}
