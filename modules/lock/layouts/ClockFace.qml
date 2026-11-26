pragma ComponentBehavior: Bound

import QtQuick
import Caelestia.Config
import qs.components
import qs.services
import qs.modules.lock.center

// The clock element's face (modules/lock/canvas): one line, stacked, the classic card's clock, an
// analogue dial, the time in words, flip cards or LED dots
Item {
    id: root

    required property string face
    property real faceScale: 1
    property bool accent: true
    // Qt.AlignLeft, Qt.AlignHCenter or Qt.AlignRight: which way stacked digits and wrapped words line up
    property int alignment: Qt.AlignHCenter

    implicitWidth: loader.implicitWidth
    implicitHeight: loader.implicitHeight

    Loader {
        id: loader

        anchors.centerIn: parent
        sourceComponent: ({
                line: lineFace,
                stacked: stackedFace,
                classic: classicFace,
                analogue: analogueFace,
                words: wordsFace,
                flip: flipFace,
                dots: dotsFace
            })[root.face] ?? lineFace
    }

    Component {
        id: lineFace

        BigClock {
            fontScale: 6.5 * root.faceScale
            stacked: false
            accent: root.accent
        }
    }

    Component {
        id: stackedFace

        BigClock {
            fontScale: 6.5 * root.faceScale
            stacked: true
            alignment: root.alignment
            accent: root.accent
        }
    }

    // The clock the classic card had, sized as it was there on a 1080p screen
    Component {
        id: classicFace

        Clock {
            centerScale: 0.75 * root.faceScale
        }
    }

    // The dial on a disc of its own, like a watch face, so the hands read against any wallpaper
    Component {
        id: analogueFace

        StyledRect {
            implicitWidth: dial.implicitWidth + Tokens.padding.extraLarge * 2 * root.faceScale
            implicitHeight: implicitWidth
            radius: implicitWidth / 2
            color: Qt.alpha(Colours.palette.m3surface, 0.45)

            AnalogueClock {
                id: dial

                anchors.centerIn: parent
                centerScale: 1.75 * root.faceScale
            }
        }
    }

    Component {
        id: wordsFace

        WordsClock {
            faceScale: root.faceScale
            accent: root.accent
            horizontalAlignment: root.alignment === Qt.AlignLeft ? Text.AlignLeft : root.alignment === Qt.AlignRight ? Text.AlignRight : Text.AlignHCenter
        }
    }

    Component {
        id: flipFace

        FlipClock {
            faceScale: root.faceScale
            accent: root.accent
        }
    }

    Component {
        id: dotsFace

        DotClock {
            faceScale: root.faceScale
            accent: root.accent
        }
    }
}
