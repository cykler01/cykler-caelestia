pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.services

// After KDE Plasma's fuzzy clock and the word clocks it borrows from: the time written out the way
// it's said, to the nearest five minutes ("quarter past four"), set huge and left-aligned like a
// poster, with the hour word in the accent. The exact time and the date sit under
// it, the sign-in in the bottom-left corner, and the weather, status pills and session actions in
// the others
Item {
    id: root

    required property var lock

    readonly property real uiScale: Math.max(0.6, Math.min(1.6, height / 1080))
    readonly property real margin: 96 * uiScale

    // Five-minute steps past the hour, 0-12; 12 rounds up to the next hour on the dot
    readonly property int step: Math.round(Time.minutes / 5)
    // Past the half hour the phrase counts down to the next hour instead
    readonly property int hour: (Time.hours + (step > 6 ? 1 : 0)) % 12
    readonly property list<string> hourWords: [Tr.tr("twelve"), Tr.tr("one"), Tr.tr("two"), Tr.tr("three"), Tr.tr("four"), Tr.tr("five"), Tr.tr("six"), Tr.tr("seven"), Tr.tr("eight"), Tr.tr("nine"), Tr.tr("ten"), Tr.tr("eleven")]
    // TRANSLATORS: %1 = the hour as a word ("four"). A fuzzy clock, rounded to five minutes
    readonly property list<string> phrases: [Tr.tr("%1 o'clock"), Tr.tr("five past %1"), Tr.tr("ten past %1"), Tr.tr("quarter past %1"), Tr.tr("twenty past %1"), Tr.tr("twenty-five past %1"), Tr.tr("half past %1"), Tr.tr("twenty-five to %1"), Tr.tr("twenty to %1"), Tr.tr("quarter to %1"), Tr.tr("ten to %1"), Tr.tr("five to %1")]

    readonly property string phrase: {
        const parts = phrases[step % 12].split("%1");
        const accent = `<font color="${Colours.palette.m3primary}">${hourWords[hour]}</font>`;
        return parts.join(accent);
    }

    WeatherPill {
        x: root.margin
        y: root.margin * 0.75
        uiScale: root.uiScale * 0.9
    }

    StatusChips {
        x: root.width - width - root.margin
        y: root.margin * 0.75
        uiScale: root.uiScale * 0.9
        layoutDirection: Qt.RightToLeft
    }

    SessionBar {
        x: root.width - width - root.margin
        y: root.height - height - root.margin
        uiScale: root.uiScale
    }

    ColumnLayout {
        x: root.margin
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: -root.height * 0.08
        width: Math.min(root.width - root.margin * 2, 1100 * root.uiScale)
        spacing: Tokens.spacing.extraLarge * root.uiScale

        StyledText {
            Layout.fillWidth: true
            text: root.phrase
            textFormat: Text.StyledText
            wrapMode: Text.WordWrap
            lineHeight: 0.92
            color: Colours.palette.m3onSurface
            font: Tokens.font.headline.builders.large.scale(root.uiScale * 3.4).weight(Font.Bold).build()
        }

        RowLayout {
            spacing: Tokens.spacing.large * root.uiScale

            StyledText {
                text: Time.format(Units.twelveHourClock ? "h:mm A" : "hh:mm")
                color: Colours.palette.m3primary
                font: Tokens.font.title.builders.large.scale(root.uiScale * 1.2).weight(Font.Bold).build()
            }

            StyledRect {
                Layout.fillHeight: true
                Layout.topMargin: Tokens.padding.small * root.uiScale
                Layout.bottomMargin: Tokens.padding.small * root.uiScale
                implicitWidth: 1
                color: Qt.alpha(Colours.palette.m3onSurface, 0.3)
            }

            StyledText {
                text: Time.format("dddd, d MMMM")
                color: Colours.palette.m3onSurface
                font: Tokens.font.title.builders.large.scale(root.uiScale * 1.2).weight(Font.DemiBold).build()
            }
        }
    }

    LoginCard {
        x: root.margin
        y: root.height - height - root.margin
        width: 400 * root.uiScale
        lock: root.lock
        uiScale: root.uiScale
        framed: false
        inline: true
        avatarSize: 56 * root.uiScale
    }
}
