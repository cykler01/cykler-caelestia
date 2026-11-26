pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.services

// After the macOS lock screen: the date over a wide one-line clock at the top of the screen,
// the wallpaper left clear through the middle, and the user down at the bottom - profile
// picture, name and password field, with the session actions under them. The weather and
// status pills sit in the top corners either side of the clock
Item {
    id: root

    required property var lock

    readonly property real uiScale: Math.max(0.6, Math.min(1.6, height / 1080))
    readonly property real margin: 72 * uiScale

    WeatherPill {
        x: root.margin
        y: root.margin
        uiScale: root.uiScale * 0.9
    }

    StatusChips {
        x: root.width - width - root.margin
        y: root.margin
        uiScale: root.uiScale * 0.9
        layoutDirection: Qt.RightToLeft
    }

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.height * 0.09
        spacing: Tokens.spacing.extraLarge * 1.5 * root.uiScale

        StyledText {
            Layout.alignment: Qt.AlignHCenter
            text: Time.format("dddd d MMMM")
            color: Colours.palette.m3onSurface
            font: Tokens.font.title.builders.large.scale(root.uiScale * 1.15).weight(Font.DemiBold).build()
        }

        BigClock {
            Layout.alignment: Qt.AlignHCenter
            fontScale: 5.5 * root.uiScale
            stacked: false
        }
    }

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: root.height * 0.07
        spacing: Tokens.spacing.large * root.uiScale

        LoginCard {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 340 * root.uiScale
            lock: root.lock
            uiScale: root.uiScale
            framed: false
            avatarSize: 64 * root.uiScale
        }

        SessionBar {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: Tokens.spacing.large * root.uiScale
            uiScale: root.uiScale * 0.85
        }
    }
}
