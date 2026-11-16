pragma ComponentBehavior: Bound

import QtQuick
import Caelestia.Config
import Caelestia.Services
import qs.components
import qs.services

// One line of lyrics on a single row in display type, swept word by word as it is sung.
//
// The dashboard's line (modules/dashboard/media/LyricLine.qml) wraps in body text, which is right for a
// pane of lines. The lyric cards' wide, short styles want the opposite: one row, as large as it will go,
// that never wraps. A line too long for the row is set in a smaller size of the same face rather than
// cut off, since an elided lyric loses exactly the words being sung. The sweep follows the same rule as
// the dashboard's: only words the source timed are swept, and a line it timed only as a whole lights whole.
Item {
    id: root

    // One entry of Lyrics.lines, and where it sits in them
    property var line
    property int lineIndex: -1
    property real time: 0
    property bool current: false
    // The size the line is set in when it fits; it only ever gets smaller than this
    property var fontBuilder: Tokens.font.title.builders.large
    property bool center: false
    property color dim: Colours.palette.m3outline
    property color lit: Colours.palette.m3onSurface

    readonly property var words: root.line?.words ?? []
    readonly property string plain: root.line?.text ?? ""

    // How much the line has to shrink to fit the row, measured at full size. Floored, so a very long line
    // still reads as a lyric rather than as small print
    readonly property real fit: ruler.implicitWidth > 0 && root.width > 0 ? Math.max(0.6, Math.min(1, root.width / ruler.implicitWidth)) : 1
    readonly property font face: root.fontBuilder.scale(root.fit).build()

    implicitHeight: ruler.implicitHeight
    clip: true

    // The whole line at full size, never shown: the measure the fit is taken from
    Text {
        id: ruler

        visible: false
        text: root.plain.length > 0 ? root.plain : ". . ."
        font: root.fontBuilder.build()
        renderType: Text.NativeRendering
    }

    TextMetrics {
        id: space

        font: root.face
        text: " "
    }

    Row {
        id: row

        anchors.verticalCenter: parent.verticalCenter
        x: root.center ? Math.max(0, Math.round((root.width - width) / 2)) : 0
        visible: root.words.length > 0

        Repeater {
            model: root.words

            Item {
                id: word

                required property var modelData
                required property int index

                readonly property real progress: root.current ? Lyrics.wordProgress(root.lineIndex, word.index, root.time) : 0

                implicitWidth: label.implicitWidth + (word.modelData.joinNext ? 0 : space.advanceWidth)
                implicitHeight: label.implicitHeight

                StyledText {
                    id: label

                    text: word.modelData.text
                    color: root.dim
                    font: root.face
                }

                // The sung part, clipped from the left so the edge travels through the word
                Item {
                    width: Math.round(label.implicitWidth * Math.max(0, Math.min(1, word.progress)))
                    height: label.implicitHeight
                    clip: true
                    visible: width > 0

                    StyledText {
                        width: label.implicitWidth
                        text: word.modelData.text
                        color: root.lit
                        font: root.face
                    }
                }
            }
        }
    }

    // A line with no word timings: lit or not, never part-lit
    StyledText {
        anchors.verticalCenter: parent.verticalCenter
        width: root.width
        visible: root.words.length === 0
        horizontalAlignment: root.center ? Text.AlignHCenter : Text.AlignLeft
        elide: Text.ElideRight
        text: root.plain.length > 0 ? root.plain : ". . ."
        color: root.current ? root.lit : root.dim
        font: root.face
    }
}
