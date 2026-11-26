pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.services
import qs.modules.lock.center

// After the LightDM Unity / slick greeters and the Windows 8 sign-in: one translucent band right
// across the middle of the screen, edge to edge, with everything on it in a single line - the
// clock at one end, the date, greeting and weather beside it, and the sign-in at the other end.
// Above and below the band the wallpaper is left clear but for the status pills and session
// actions. The sign-in's end follows Config.lock.panelSide like the split and sidebar layouts
Item {
    id: root

    required property var lock

    readonly property real uiScale: Math.max(0.6, Math.min(1.6, height / 1080))
    readonly property real margin: 72 * uiScale
    readonly property real inset: 96 * uiScale
    readonly property bool panelRight: (Config.lock.panelSide ?? "right") !== "left"

    // The pills and session actions keep to the sign-in's end of the screen
    StatusChips {
        x: root.panelRight ? root.width - width - root.margin : root.margin
        y: root.margin
        uiScale: root.uiScale
        layoutDirection: root.panelRight ? Qt.RightToLeft : Qt.LeftToRight
    }

    SessionBar {
        x: root.panelRight ? root.width - width - root.margin : root.margin
        y: root.height - height - root.margin
        uiScale: root.uiScale
    }

    StyledRect {
        id: band

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        implicitHeight: row.implicitHeight + Tokens.padding.extraLarge * 3 * root.uiScale
        color: Colours.tPalette.m3surface

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            blurMax: 20
            shadowColor: Qt.alpha(Colours.palette.m3shadow, 0.5)
        }

        // A hairline of the accent along each edge of the band
        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: Math.max(1, 2 * root.uiScale)
            color: Qt.alpha(Colours.palette.m3primary, 0.5)
        }

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: Math.max(1, 2 * root.uiScale)
            color: Qt.alpha(Colours.palette.m3primary, 0.5)
        }
    }

    RowLayout {
        id: row

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: root.inset
        anchors.rightMargin: root.inset
        anchors.verticalCenter: band.verticalCenter
        spacing: Tokens.spacing.extraLarge * 1.5 * root.uiScale
        layoutDirection: root.panelRight ? Qt.LeftToRight : Qt.RightToLeft

        BigClock {
            Layout.alignment: Qt.AlignVCenter
            fontScale: 3.6 * root.uiScale
            stacked: false
        }

        StyledRect {
            Layout.fillHeight: true
            implicitWidth: Math.max(1, 2 * root.uiScale)
            color: Qt.alpha(Colours.palette.m3onSurface, 0.2)
        }

        ColumnLayout {
            Layout.alignment: Qt.AlignVCenter
            spacing: Tokens.spacing.small * root.uiScale

            StyledText {
                text: Time.format("dddd, d MMMM")
                color: Colours.palette.m3onSurface
                font: Tokens.font.title.builders.large.scale(root.uiScale).weight(Font.DemiBold).build()
            }

            Greeting {}

            WeatherPill {
                Layout.topMargin: Tokens.spacing.small * root.uiScale
                uiScale: root.uiScale * 0.8
            }
        }

        Item {
            Layout.fillWidth: true
        }

        LoginCard {
            Layout.alignment: Qt.AlignVCenter
            Layout.preferredWidth: 420 * root.uiScale
            lock: root.lock
            uiScale: root.uiScale
            framed: false
            inline: true
            avatarSize: 64 * root.uiScale
        }
    }
}
