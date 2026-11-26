pragma ComponentBehavior: Bound

import QtQuick
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.services

// After KDE Plasma's fuzzy clock and the word clocks it borrows from: the time written out the way
// it's said, to the nearest five minutes ("quarter past four"), set huge, with the hour word in the
// accent. Wraps onto more lines past maxWidth
StyledText {
    id: root

    property real faceScale: 1
    property bool accent: true
    property real maxWidth: 1100 * faceScale

    // Five-minute steps past the hour, 0-12; 12 rounds up to the next hour on the dot
    readonly property int step: Math.round(Time.minutes / 5)
    // Past the half hour the phrase counts down to the next hour instead
    readonly property int hour: (Time.hours + (step > 6 ? 1 : 0)) % 12
    readonly property list<string> hourWords: [Tr.tr("twelve"), Tr.tr("one"), Tr.tr("two"), Tr.tr("three"), Tr.tr("four"), Tr.tr("five"), Tr.tr("six"), Tr.tr("seven"), Tr.tr("eight"), Tr.tr("nine"), Tr.tr("ten"), Tr.tr("eleven")]
    // TRANSLATORS: %1 = the hour as a word ("four"). A fuzzy clock, rounded to five minutes
    readonly property list<string> phrases: [Tr.tr("%1 o'clock"), Tr.tr("five past %1"), Tr.tr("ten past %1"), Tr.tr("quarter past %1"), Tr.tr("twenty past %1"), Tr.tr("twenty-five past %1"), Tr.tr("half past %1"), Tr.tr("twenty-five to %1"), Tr.tr("twenty to %1"), Tr.tr("quarter to %1"), Tr.tr("ten to %1"), Tr.tr("five to %1")]

    readonly property string phrase: {
        const parts = phrases[step % 12].split("%1");
        const word = root.accent ? `<font color="${Colours.palette.m3primary}">${hourWords[hour]}</font>` : hourWords[hour];
        return parts.join(word);
    }

    width: Math.min(implicitWidth, maxWidth)
    text: root.phrase
    textFormat: Text.StyledText
    wrapMode: Text.WordWrap
    lineHeight: 0.92
    color: Colours.palette.m3onSurface
    font: Tokens.font.headline.builders.large.scale(root.faceScale * 3.4).weight(Font.Bold).build()
}
