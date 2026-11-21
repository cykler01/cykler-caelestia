pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.services
import qs.modules.lock

// One tall panel along an edge (Config.lock.panelSide), laid out top to bottom like a sidebar:
// the clock and date left-aligned at the top, every enabled widget from both columns in their list
// order in the middle, and the way in at the bottom, where the eye ends up - the login with the
// session actions under it. The rest of the screen is left to the wallpaper, with only the status
// pills and the weather in its far corners
Item {
    id: root

    required property var lock

    readonly property real uiScale: Math.max(0.6, Math.min(1.6, height / 1080))
    readonly property bool panelRight: (Config.lock.panelSide ?? "right") !== "left"
    // The panel floats the same distance off every edge, so it reads as a card rather than a
    // strip glued to one side
    readonly property real gap: 28 * uiScale
    // Padding inside the panel; sections are separated by dividers and this much air
    readonly property real inset: Tokens.padding.extraLarge * 1.25 * uiScale
    readonly property real sectionGap: Tokens.spacing.medium * uiScale
    readonly property real margin: 72 * uiScale
    readonly property real panelWidth: 460 * uiScale
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
        y: root.gap
        width: root.panelWidth
        height: root.height - root.gap * 2
        radius: Tokens.rounding.extraLarge * 1.5
        color: Colours.tPalette.m3surface

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            blurMax: 15
            shadowColor: Qt.alpha(Colours.palette.m3shadow, 0.7)
        }
    }

    // Header pinned to the top of the panel, the way in to the bottom, and the widgets given
    // exactly the room between the two - plain anchoring rather than one big layout, so the
    // widgets' budget is known up front and can't feed back on itself
    ColumnLayout {
        id: header

        anchors.left: panel.left
        anchors.right: panel.right
        anchors.top: panel.top
        anchors.margins: root.inset
        spacing: 0

        BigClock {
            Layout.alignment: Qt.AlignLeft
            fontScale: 2.5 * root.uiScale
            stacked: false
        }

        StyledText {
            Layout.alignment: Qt.AlignLeft
            Layout.topMargin: Tokens.spacing.medium * root.uiScale
            text: Time.format("dddd, d MMMM")
            color: Colours.palette.m3onSurfaceVariant
            font: Tokens.font.title.builders.medium.scale(root.uiScale).weight(Font.DemiBold).build()
        }
    }

    WidgetColumn {
        id: widgets

        // Widgets that don't fit whole in the room left are dropped, last first, so the list
        // never runs off the panel or gets cut part way through a card
        readonly property real room: footer.y - root.sectionGap * 2 - y

        anchors.left: panel.left
        anchors.right: panel.right
        anchors.leftMargin: root.inset
        anchors.rightMargin: root.inset
        y: header.y + header.height + root.sectionGap * 2
        // The weighted widgets share all the room; with only fixed-size ones it's their own height
        height: hasFlex ? room : Math.min(room, implicitHeight)
        visible: items.length > 0
        side: "all"
        // A weighted widget is clipped below about this, so past it the last widgets are
        // dropped instead (WidgetColumn)
        minFlexHeight: 165 * root.uiScale
        fitHeight: room
        rootHeight: height
        lock: root.lock
    }

    ColumnLayout {
        id: footer

        anchors.left: panel.left
        anchors.right: panel.right
        anchors.bottom: panel.bottom
        anchors.margins: root.inset
        spacing: root.sectionGap

        // A hairline separating the widgets from the way in
        StyledRect {
            Layout.fillWidth: true
            implicitHeight: 1
            color: Qt.alpha(Colours.palette.m3outlineVariant, 0.6)
        }

        LoginCard {
            Layout.fillWidth: true
            lock: root.lock
            uiScale: root.uiScale
            framed: false
            inline: true
            avatarSize: 56 * root.uiScale
        }

        SessionBar {
            Layout.alignment: Qt.AlignHCenter
            uiScale: root.uiScale
        }
    }
}
