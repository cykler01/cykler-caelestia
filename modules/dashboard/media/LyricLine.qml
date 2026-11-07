pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import Caelestia.Config
import Caelestia.Services
import qs.components
import qs.services

// One line of the lyrics: its words, swept as they are sung, or the line whole when the source
// only knew where it started.
//
// The sweep is the whole reason the word timings are fetched. A line lighting up all at once tells
// you which line is being sung; a line whose words light one by one tells you where in it you are,
// which is the difference between following along and reading ahead. Two copies of each word are
// drawn, one dim and one bright, with the bright one clipped to how far through the word the voice
// has got.
//
// A line with no words lights whole, and the shell does not spread its words across the span to
// fake a sweep: that guess would read as the lyrics being out of time rather than as an estimate,
// because a sweep is a claim about where in the line the voice is. The source that timed only the
// line knows no more than that the line is being sung, so that is all this claims.
Item {
    id: root

    // One entry of Lyrics.lines.
    property var line
    // Where this line sits in Lyrics.lines, and where playback is: both are needed to place the
    // sweep, since the timings are the words' own.
    property int lineIndex: -1
    property real time: 0
    // Whether this is the line being sung. Nothing sweeps on the lines around it.
    property bool current: false
    // Centred rather than left-aligned, for the places that centre their lines.
    property bool center: false
    property color dim: Colours.palette.m3outline
    property color lit: Colours.palette.m3primary
    // A soft halo around the line while it is being sung; 0 for the lines that are only context.
    property real glow: 0

    readonly property var words: root.line?.words ?? []
    readonly property string plain: root.line?.text ?? ""

    implicitHeight: flow.implicitHeight

    layer.enabled: root.glow > 0
    layer.effect: MultiEffect {
        shadowEnabled: true
        shadowColor: root.lit
        shadowBlur: 0.6
        shadowOpacity: 0.5 * root.glow
        blur: 0
    }

    // Hidden, and outside the flow so it is never laid out: it is here to hand the words the font
    // the rest of the shell's body text uses.
    Text {
        id: probe

        visible: false
        text: "Ag"
        font: Tokens.font.body.medium
        renderType: Text.NativeRendering
    }

    // The width of a word space in that font. Measured rather than padded to a share of the type
    // size, because Qt leaves a trailing space out of a Text's implicitWidth: a word whose text
    // ended in a space was laid out without one, which runs every word into the next.
    TextMetrics {
        id: space

        font: probe.font
        text: " "
    }

    // The line as one run of text, unwrapped. Used to centre the swept row: the words and the
    // spaces between them are the same shapes, so this is the row's width before it has to wrap,
    // and once it is wider than the line there is nothing left to shift.
    Text {
        id: ruler

        visible: false
        text: root.plain
        font: Tokens.font.body.medium
        renderType: Text.NativeRendering
    }

    Flow {
        id: flow

        width: root.width
        x: root.center && root.words.length > 0 ? Math.max(0, Math.round((root.width - ruler.implicitWidth) / 2)) : 0
        spacing: 0

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
                    font: Tokens.font.body.medium
                }

                // The sung part, clipped from the left so the edge travels through the word. The
                // text inside keeps its full width: squeezing it to the clip would draw the glyphs
                // narrower instead of hiding the part not reached yet.
                Item {
                    width: Math.round(label.implicitWidth * Math.max(0, Math.min(1, word.progress)))
                    height: label.implicitHeight
                    clip: true
                    visible: width > 0

                    StyledText {
                        width: label.implicitWidth
                        text: word.modelData.text
                        color: root.lit
                        font: Tokens.font.body.medium
                    }
                }
            }
        }

        // The line with nothing to sweep with: lit or not, never part-lit.
        StyledText {
            visible: root.words.length === 0
            width: flow.width
            horizontalAlignment: root.center ? Text.AlignHCenter : Text.AlignLeft
            wrapMode: Text.WrapAtWordBoundaryOrAnywhere
            text: root.plain.length > 0 ? root.plain : ". . ."
            color: root.current ? root.lit : root.dim
            font: Tokens.font.body.medium
        }
    }
}
