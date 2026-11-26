pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.services

// The free-standing clock the alternative layouts lead with. Stacked puts the hours over the
// minutes (split, sidebar), otherwise it's one line with a colon (minimal). Every piece is
// trimmed to its glyphs' tight bounds so the digits sit close together however big they get,
// the same trick the centre card's Clock.qml uses
GridLayout {
    id: root

    property real fontScale: 6
    property bool stacked: true
    // Which edge the stacked digits line up against: Qt.AlignLeft, Qt.AlignRight or Qt.AlignHCenter
    property int alignment: Qt.AlignLeft
    // The minutes and colon in the accent colour; off, everything is one colour
    property bool accent: true
    readonly property color minuteColour: accent ? Colours.palette.m3primary : Colours.palette.m3onSurface

    readonly property font digitFont: Tokens.font.headline.builders.large.scale(root.fontScale).weight(Font.DemiBold).width(30).build()

    columns: root.stacked ? 1 : 4
    rowSpacing: hours.implicitHeight * 0.16
    columnSpacing: hours.implicitHeight * 0.08

    Tight {
        id: hours

        Layout.alignment: root.stacked ? root.alignment : Qt.AlignVCenter
        text: Time.hourStr
        color: Colours.palette.m3onSurface
        font: root.digitFont
    }

    Tight {
        visible: !root.stacked
        Layout.alignment: Qt.AlignVCenter
        text: ":"
        color: root.minuteColour
        font: root.digitFont
    }

    RowLayout {
        Layout.alignment: root.stacked ? root.alignment : Qt.AlignVCenter
        // On one line AM/PM hangs off the right edge without taking any width, so the digits
        // themselves are what sits centred
        spacing: root.stacked ? hours.implicitHeight * 0.08 : 0
        layoutDirection: root.stacked && root.alignment === Qt.AlignRight ? Qt.RightToLeft : Qt.LeftToRight

        Tight {
            text: Time.minuteStr
            color: root.minuteColour
            font: root.digitFont
        }

        // AM/PM rides along the minutes' baseline, small enough not to compete with them
        Tight {
            visible: Units.twelveHourClock
            Layout.alignment: Qt.AlignBottom
            Layout.preferredWidth: root.stacked ? implicitWidth : 0
            Layout.minimumWidth: root.stacked ? implicitWidth : 0
            Layout.maximumWidth: root.stacked ? implicitWidth : 0
            transform: Translate {
                x: root.stacked ? 0 : hours.implicitHeight * 0.08
            }
            text: Time.amPmStr
            color: Qt.alpha(root.minuteColour, 0.6)
            font: Tokens.font.headline.builders.large.scale(root.fontScale / 4).weight(Font.Medium).build()
        }
    }

    component Tight: Item {
        id: tight

        property alias text: label.text
        property alias font: label.font
        property alias color: label.color

        implicitWidth: metrics.tightBoundingRect.width
        implicitHeight: metrics.tightBoundingRect.height

        StyledText {
            id: label

            x: -metrics.tightBoundingRect.x
            y: -(metrics.tightBoundingRect.y - metrics.boundingRect.y)
        }

        TextMetrics {
            id: metrics

            text: label.text
            font: label.font
        }
    }
}
