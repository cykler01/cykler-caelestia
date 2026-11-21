pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.services

// Just the time and a way in: a large one-line clock and the date a little above the middle of
// the screen, the profile picture, greeting and password field under them, the weather and status
// pills in the top corners and the session actions in the bottom one. No widgets at all
Item {
    id: root

    required property var lock

    readonly property real uiScale: Math.max(0.6, Math.min(1.6, height / 1080))
    readonly property real margin: 72 * uiScale

    WeatherPill {
        x: root.margin
        y: root.margin
        uiScale: root.uiScale
    }

    StatusChips {
        x: root.width - width - root.margin
        y: root.margin
        // Quieter than the corner pill opposite: this is a layout about the clock
        uiScale: root.uiScale * 0.8
        layoutDirection: Qt.RightToLeft
    }

    SessionBar {
        x: root.width - width - root.margin
        y: root.height - height - root.margin
        uiScale: root.uiScale
    }

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.verticalCenter
        anchors.bottomMargin: root.height * 0.04
        spacing: Tokens.spacing.large * root.uiScale

        BigClock {
            Layout.alignment: Qt.AlignHCenter
            fontScale: 6.5 * root.uiScale
            stacked: false
        }

        StyledText {
            Layout.alignment: Qt.AlignHCenter
            text: Time.format("dddd, d MMMM")
            color: Colours.palette.m3onSurface
            font: Tokens.font.title.builders.large.scale(root.uiScale * 1.2).weight(Font.DemiBold).build()
        }
    }

    LoginCard {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.verticalCenter
        anchors.topMargin: root.height * 0.08
        width: 380 * root.uiScale
        lock: root.lock
        uiScale: root.uiScale
        framed: false
        showGreeting: true
        avatarSize: 72 * root.uiScale
    }
}
