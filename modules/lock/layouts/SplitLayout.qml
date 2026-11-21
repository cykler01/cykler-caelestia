pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.services
import qs.modules.lock
import qs.modules.lock.center

// Clock on one side of the screen, login on the other, no card around the whole thing. The far
// side has the weather up in its corner, the stacked clock, date and greeting in the middle and
// the session actions down in its corner. The near side (Config.lock.panelSide) has the status
// pills up in its corner, the login card with that side's widget column under it against the
// edge, and the other widget column in a second stack just inside it. So the widget columns keep
// their left-to-right order on screen, the same as in the classic layout
Item {
    id: root

    required property var lock

    readonly property real uiScale: Math.max(0.6, Math.min(1.6, height / 1080))
    readonly property bool panelRight: (Config.lock.panelSide ?? "right") !== "left"
    readonly property real margin: 72 * uiScale
    readonly property real gap: Tokens.spacing.large * uiScale
    readonly property real panelWidth: 400 * uiScale
    // Height per unit of weight the weighted widgets (weather, media, notifications) get
    readonly property real flexUnit: 150 * uiScale
    readonly property real stackTop: margin + chips.height + Tokens.spacing.extraLarge * uiScale
    readonly property int farAlign: panelRight ? Qt.AlignLeft : Qt.AlignRight
    // The pill is only a stand-in for the weather widget, so it bows out when that's shown
    readonly property bool weatherWidgetShown: Config.lock.widgets.values.some(e => e.enabled && e.id === "weather")

    // Height of the login card with its widget column under it: what the other column is sized to
    readonly property real nearHeight: Math.min(panelStack.height, login.implicitHeight + (panelColumn.visible ? gap + Math.min(panelColumn.naturalHeight(flexUnit), panelStack.height - login.implicitHeight - gap) : 0))

    function sideX(item: Item, onPanelSide: bool): real {
        return onPanelSide === panelRight ? width - item.width - margin : margin;
    }

    WeatherPill {
        x: root.sideX(this, false)
        y: root.margin
        uiScale: root.uiScale
        visible: !!Weather.cc && !root.weatherWidgetShown
        layoutDirection: root.panelRight ? Qt.LeftToRight : Qt.RightToLeft
    }

    StatusChips {
        id: chips

        x: root.sideX(this, true)
        y: root.margin
        uiScale: root.uiScale
        layoutDirection: root.panelRight ? Qt.RightToLeft : Qt.LeftToRight
    }

    SessionBar {
        x: root.sideX(this, false)
        y: root.height - height - root.margin
        uiScale: root.uiScale
    }

    // Far side: the clock block, centred top to bottom
    ColumnLayout {
        x: root.panelRight ? root.margin : root.width - width - root.margin
        anchors.verticalCenter: parent.verticalCenter
        spacing: Tokens.spacing.small * root.uiScale

        BigClock {
            Layout.alignment: root.farAlign
            fontScale: 5.5 * root.uiScale
            stacked: true
            alignment: root.farAlign
        }

        StyledText {
            Layout.alignment: root.farAlign
            Layout.topMargin: Tokens.spacing.large * root.uiScale
            text: Time.format("dddd, d MMMM")
            color: Colours.palette.m3onSurface
            font: Tokens.font.title.builders.large.scale(root.uiScale).weight(Font.DemiBold).build()
        }

        Greeting {
            Layout.alignment: root.farAlign
        }
    }

    // Near side, against the edge: login and that edge's widget column
    ColumnLayout {
        id: panelStack

        x: root.panelRight ? root.width - width - root.margin : root.margin
        y: root.stackTop
        width: root.panelWidth
        height: root.height - y - root.margin
        spacing: root.gap

        LoginCard {
            id: login

            Layout.fillWidth: true
            lock: root.lock
            uiScale: root.uiScale
        }

        WidgetColumn {
            id: panelColumn

            // Sized to its contents, with the weighted widgets at a modest height each, hung
            // from the login card. Never stretched: that only spreads the cards apart
            Layout.fillWidth: true
            Layout.preferredHeight: naturalHeight(root.flexUnit)
            Layout.maximumHeight: naturalHeight(root.flexUnit)
            Layout.minimumHeight: 0
            visible: items.length > 0
            side: root.panelRight ? "right" : "left"
            fitHeight: panelStack.height - login.implicitHeight - root.gap
            rootHeight: height
            lock: root.lock
        }

        Item {
            Layout.fillHeight: true
        }
    }

    // Near side, just inside the login: the other widget column
    ColumnLayout {
        id: innerStack

        x: root.panelRight ? panelStack.x - width - root.gap : panelStack.x + panelStack.width + root.gap
        y: root.stackTop
        width: root.panelWidth
        height: root.height - y - root.margin
        visible: innerColumn.items.length > 0

        WidgetColumn {
            id: innerColumn

            // Exactly as tall as the login-and-widgets stack beside it, so the two share a top
            // and a bottom edge. The weighted widgets (weather, media) soak up the difference
            Layout.fillWidth: true
            Layout.preferredHeight: root.nearHeight
            Layout.maximumHeight: root.nearHeight
            Layout.minimumHeight: 0
            side: root.panelRight ? "left" : "right"
            fitHeight: root.nearHeight
            rootHeight: height
            lock: root.lock
        }

        Item {
            Layout.fillHeight: true
        }
    }
}
