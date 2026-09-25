pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.services

// Horizontal clock used by top/bottom bars
StyledRect {
    id: root

    readonly property color colour: Colours.palette.m3tertiary
    readonly property int padding: Config.bar.clock.background ? Tokens.padding.medium : Tokens.padding.extraSmall

    implicitWidth: layout.implicitWidth + padding * 2
    implicitHeight: Tokens.sizes.bar.innerWidth

    color: Qt.alpha(Colours.tPalette.m3surfaceContainer, Config.bar.clock.background ? Colours.tPalette.m3surfaceContainer.a : 0)
    radius: Tokens.rounding.full

    RowLayout {
        id: layout

        anchors.centerIn: parent
        spacing: Tokens.spacing.small

        MaterialIcon {
            visible: Config.bar.clock.showIcon
            text: "calendar_month"
            color: root.colour
        }

        StyledText {
            visible: Config.bar.clock.showDate
            text: Time.format("ddd d")
            font: Tokens.font.body.builders.small.scale(0.95).build()
            color: root.colour
        }

        StyledRect {
            visible: Config.bar.clock.showDate
            Layout.preferredWidth: 1
            Layout.preferredHeight: Tokens.font.body.small.pointSize
            color: Colours.palette.m3outlineVariant
        }

        StyledText {
            text: Config.bar.clock.showSeconds ? `${Time.hourStr}:${Time.minuteStr}:${Time.format("ss")}` : `${Time.hourStr}:${Time.minuteStr}`
            font: Tokens.font.body.builders.small.scale(1.1).build()
            color: root.colour
        }

        StyledText {
            visible: Units.twelveHourClock
            text: Time.amPmStr.toLowerCase()
            font: Tokens.font.body.builders.small.scale(0.9).build()
            color: root.colour
        }
    }
}
