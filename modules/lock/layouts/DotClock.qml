pragma ComponentBehavior: Bound

import QtQuick
import Caelestia.Config
import qs.components
import qs.services

// After Nothing OS and the LED dot-matrix displays it borrows its look from: the time drawn as
// digits five dots wide and seven tall, with the unlit dots of each digit still faintly there so
// it reads as a panel rather than a typeface
Row {
    id: root

    property real faceScale: 1
    property bool accent: true
    readonly property real dot: 20 * faceScale
    readonly property real dotGap: 6 * faceScale
    readonly property color minuteColour: accent ? Colours.palette.m3primary : Colours.palette.m3onSurface

    // 5x7 glyphs, one string of five 0/1 per row, top to bottom
    readonly property var glyphs: ({
            "0": ["01110", "10001", "10011", "10101", "11001", "10001", "01110"],
            "1": ["00100", "01100", "00100", "00100", "00100", "00100", "01110"],
            "2": ["01110", "10001", "00001", "00010", "00100", "01000", "11111"],
            "3": ["11111", "00010", "00100", "00010", "00001", "10001", "01110"],
            "4": ["00010", "00110", "01010", "10010", "11111", "00010", "00010"],
            "5": ["11111", "10000", "11110", "00001", "00001", "10001", "01110"],
            "6": ["00110", "01000", "10000", "11110", "10001", "10001", "01110"],
            "7": ["11111", "00001", "00010", "00100", "01000", "01000", "01000"],
            "8": ["01110", "10001", "10001", "01110", "10001", "10001", "01110"],
            "9": ["01110", "10001", "10001", "01111", "00001", "00010", "01100"]
        })

    spacing: root.dot

    Repeater {
        model: Time.hourStr.split("")

        Glyph {}
    }

    // The colon: two lit dots on rows 2 and 4
    Column {
        anchors.verticalCenter: parent.verticalCenter
        spacing: root.dot + root.dotGap * 2

        Repeater {
            model: 2

            Rectangle {
                width: root.dot
                height: root.dot
                radius: width / 2
                color: root.minuteColour
            }
        }
    }

    Repeater {
        model: Time.minuteStr.split("")

        Glyph {
            lit: root.minuteColour
        }
    }

    // One digit on its 5x7 grid of dots; anything without a glyph (a stray character from the
    // locale's clock format) is left as an unlit grid
    component Glyph: Grid {
        id: glyph

        required property string modelData
        property color lit: Colours.palette.m3onSurface
        readonly property var rows: root.glyphs[modelData] ?? []

        columns: 5
        spacing: root.dotGap

        Repeater {
            model: 35

            Rectangle {
                required property int index

                readonly property bool on: (glyph.rows[Math.floor(index / 5)] ?? "")[index % 5] === "1"

                width: root.dot
                height: root.dot
                radius: width / 2
                color: on ? glyph.lit : Qt.alpha(Colours.palette.m3onSurface, 0.07)

                Behavior on color {
                    CAnim {}
                }
            }
        }
    }
}
