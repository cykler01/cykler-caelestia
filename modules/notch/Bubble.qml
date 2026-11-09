import QtQuick
import Caelestia.Config
import qs.components
import qs.services

// NOTE(fork): a detached round island standing beside the notch pill, the way a live activity
// does on a phone's island: the pill keeps the clock and the music, and anything with an end to it
// (a countdown, a download) gets a circle of its own at either side. Same surface colour as the
// frame, so it reads as part of the same family, but separated from the pill by a gap.
//
// Size is the Wrapper's to give (it matches the pill's height); this only draws, and eases in
// and out by growing from the middle rather than sliding.
Item {
    id: root

    property bool shown
    property real prog: shown ? 1 : 0

    default property alias content: holder.data

    visible: prog > 0.001
    opacity: prog
    scale: 0.4 + 0.6 * prog

    Behavior on prog {
        Anim {
            type: Anim.DefaultEffects
        }
    }

    StyledRect {
        anchors.fill: parent

        radius: Tokens.rounding.full
        color: Colours.tPalette.m3surface
    }

    Item {
        id: holder

        anchors.fill: parent
    }
}
