pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.services
import qs.modules.lock

// One tall panel along an edge (Config.lock.panelSide) with everything in it: the clock and date
// at the top, the login under them, then every enabled widget from both columns in their list
// order, and the session actions at the bottom. The rest of the screen is left to the wallpaper,
// with only the status pills and the weather in its far corners
Item {
    id: root

    required property var lock

    readonly property real uiScale: Math.max(0.6, Math.min(1.6, height / 1080))
    readonly property bool panelRight: (Config.lock.panelSide ?? "right") !== "left"
    readonly property real gap: 16 * uiScale
    // The panel stands off the top and bottom edges further than the side one, so it reads as a
    // card floating beside the screen's edge rather than a strip glued to it
    readonly property real vGap: 56 * uiScale
    // Padding inside the panel, and the gap between its header, widgets and session actions
    readonly property real inset: Tokens.padding.extraLarge * uiScale
    readonly property real margin: 72 * uiScale
    readonly property real panelWidth: 470 * uiScale
    readonly property bool weatherWidgetShown: Config.lock.widgets.values.some(e => e.enabled && e.id === "weather")

    StatusChips {
        x: root.panelRight ? root.margin : root.width - width - root.margin
        y: root.margin
        uiScale: root.uiScale
        layoutDirection: root.panelRight ? Qt.LeftToRight : Qt.RightToLeft
    }

    WeatherPill {
        x: root.panelRight ? root.margin : root.width - width - root.margin
        y: root.height - height - root.margin
        uiScale: root.uiScale
        visible: !!Weather.cc && !root.weatherWidgetShown
        layoutDirection: root.panelRight ? Qt.LeftToRight : Qt.RightToLeft
    }

    StyledRect {
        id: panel

        x: root.panelRight ? root.width - width - root.gap : root.gap
        y: root.vGap
        width: root.panelWidth
        height: root.height - root.vGap * 2
        radius: Tokens.rounding.extraLarge * 1.5
        color: Colours.tPalette.m3surface

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            blurMax: 15
            shadowColor: Qt.alpha(Colours.palette.m3shadow, 0.7)
        }
    }

    // Header (clock, date, login) pinned to the top of the panel, session actions to the bottom,
    // and the widgets given exactly the room between the two - plain anchoring rather than one
    // big layout, so the widgets' budget is known up front and can't feed back on itself
    ColumnLayout {
        id: header

        anchors.left: panel.left
        anchors.right: panel.right
        anchors.top: panel.top
        anchors.margins: root.inset
        spacing: Tokens.spacing.medium * root.uiScale

        BigClock {
            Layout.alignment: Qt.AlignHCenter
            fontScale: 2.3 * root.uiScale
            stacked: false
        }

        StyledText {
            Layout.alignment: Qt.AlignHCenter
            text: Time.format("dddd • d MMM").toUpperCase()
            color: Colours.palette.m3onSurfaceVariant
            font: Tokens.font.title.builders.medium.scale(root.uiScale).weight(Font.DemiBold).build()
        }

        LoginCard {
            Layout.fillWidth: true
            Layout.topMargin: Tokens.spacing.medium * root.uiScale
            lock: root.lock
            uiScale: root.uiScale
            framed: false
            inline: true
            avatarSize: 64 * root.uiScale
        }
    }

    WidgetColumn {
        id: widgets

        // Widgets that don't fit whole in the room left are dropped, last first, so the list
        // never runs off the panel or gets cut part way through a card
        readonly property real room: (session.visible ? session.y - root.inset : panel.y + panel.height - root.inset) - y

        anchors.left: panel.left
        anchors.right: panel.right
        anchors.leftMargin: root.inset
        anchors.rightMargin: root.inset
        y: header.y + header.height + Tokens.spacing.large * root.uiScale
        // The weighted widgets share all the room; with only fixed-size ones it's their own height
        height: hasFlex ? room : Math.min(room, implicitHeight)
        visible: items.length > 0
        side: "all"
        fitHeight: room
        rootHeight: height
        lock: root.lock
    }

    SessionBar {
        id: session

        anchors.horizontalCenter: panel.horizontalCenter
        anchors.bottom: panel.bottom
        anchors.bottomMargin: root.inset
        uiScale: root.uiScale
    }
}
