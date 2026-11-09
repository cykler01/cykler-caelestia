pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import Caelestia.Services
import qs.components
import qs.components.controls
import qs.services
import qs.utils

// NOTE(fork): what is downloading, drawn inside a Bubble: a ring filling as it goes with the
// percentage in the middle. Only the one furthest along is shown, with a small count in the corner
// when others are behind it. A source that cannot say how big the file will be (a Chromium part
// file only grows) gets a ring that turns and an icon instead of a percentage. See
// plugin/src/Caelestia/Services/downloads.cpp for where the figures come from.
//
// Hovering opens the bubble out (see Bubble.qml) and this fills the room with what the ring cannot
// say on its own: what is actually downloading, how far it has got and how fast it is going. There
// is nowhere else in the shell that says, so this is it.
Item {
    id: root

    // How far the bubble has opened, and which way it opened
    property real expandProg
    property bool mirrored

    // What the bubble has to grow by to fit the detail
    readonly property real detailWidth: detail.implicitWidth

    readonly property var item: Downloads.primary
    readonly property bool steam: (root.item.kind ?? "") === "steam"
    readonly property real progress: root.item.progress ?? -1
    readonly property bool known: root.progress >= 0
    readonly property int others: Math.max(0, Downloads.count - 1)

    // A file name can be any length at all, so it gets a budget of its own and elides. Not the
    // notch's maxTitleWidth: that is a track title across the middle of the screen, which has far
    // more room than a bubble hanging off the side of the pill
    readonly property int nameWidth: 200

    // The text only arrives once there is room for it, so it is never drawn squashed
    readonly property real textProg: Math.max(0, Math.min(1, (root.expandProg - 0.4) / 0.6))

    readonly property string name: root.item.name || (root.steam ? Tr.tr("Steam download") : Tr.tr("Download"))
    // How far along, and how fast. A source with no total to go on can still say what has arrived
    readonly property string status: {
        const parts = [];
        if (root.known)
            parts.push(Strings.percentOne(root.progress));
        else if ((root.item.done ?? 0) > 0)
            parts.push(Strings.bytes(root.item.done));

        const speed = root.item.speed ?? 0;
        if (speed > 0)
            // TRANSLATORS: %1 = a size such as 2.4 MB, making a rate such as "2.4 MB/s"
            parts.push(Tr.trCtx("%1/s", "a transfer rate").arg(Strings.bytes(speed)));

        // TRANSLATORS: separates the parts of a download's status, e.g. "63% · 2.4 MB/s"
        return parts.join(Tr.trCtx(" · ", "separates status fields"));
    }

    signal dismissed

    // The circle itself, at the end the bubble grew from so it stays put as the detail opens out
    Item {
        id: circle

        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.left: root.mirrored ? undefined : parent.left
        anchors.right: root.mirrored ? parent.right : undefined

        implicitWidth: height

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

    // What the circle has no room for, uncovered as the bubble opens
    Item {
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.left: root.mirrored ? parent.left : circle.right
        anchors.right: root.mirrored ? circle.left : parent.right

        visible: root.expandProg > 0.001
        clip: true

        RowLayout {
            id: detail

            // The bubble on the notch's left is a mirror image of the one on its right, so what
            // sits at the far end of one sits at the far end of the other
            LayoutMirroring.enabled: root.mirrored
            LayoutMirroring.childrenInherit: true

            anchors.verticalCenter: parent.verticalCenter
            anchors.left: root.mirrored ? undefined : parent.left
            anchors.right: root.mirrored ? parent.right : undefined
            anchors.leftMargin: root.mirrored ? 0 : Tokens.spacing.small
            anchors.rightMargin: root.mirrored ? Tokens.spacing.small : 0

            opacity: root.textProg
            spacing: Tokens.spacing.small

            ColumnLayout {
                Layout.alignment: Qt.AlignVCenter
                spacing: 0

                StyledText {
                    Layout.maximumWidth: root.nameWidth
                    text: root.name
                    color: Colours.palette.m3onSurface
                    font: Tokens.font.label.large
                    elide: Text.ElideRight
                }

                StyledText {
                    Layout.maximumWidth: root.nameWidth
                    visible: text !== ""
                    text: root.status
                    color: Colours.palette.m3onSurfaceVariant
                    font: Tokens.font.label.small
                    elide: Text.ElideRight
                }
            }

            // Tucks the bubble away, leaving the download running with only a mark on the pill to
            // say so (see Pill.qml)
            IconButton {
                Layout.alignment: Qt.AlignVCenter
                Layout.rightMargin: Tokens.spacing.extraSmall

                icon: "close"
                type: IconButton.Text
                padding: Tokens.padding.extraSmall / 2
                font: Tokens.font.icon.small
                onClicked: root.dismissed()
            }
        }
    }
}
