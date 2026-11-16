pragma ComponentBehavior: Bound

import QtQuick
import Caelestia.Components
import Caelestia.Config
import qs.components
import qs.components.effects
import qs.services

// The visualiser's wide style: the spectrum standing on a floor line, with a faint reflection of it in
// the floor. On a card this wide the bars have room to be bars, and the reflection is what keeps the
// lower edge from reading as a chart's axis
Item {
    id: root

    required property var levels
    required property int barCount

    // How much of the height the reflection takes under the floor line
    readonly property real floorShare: 0.24

    implicitWidth: 600
    implicitHeight: 110

    Item {
        id: stage

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: Math.round(parent.height * (1 - root.floorShare))

        // The shell's own painted spectrum (plugin/src/Caelestia/Components/visualiserbars.hpp), as a single
        // row rising from the floor, primary at the tips running into tertiary at the foot
        VisualiserBars {
            id: bars

            anchors.fill: parent
            singleRow: true
            values: root.levels
            primaryColor: Colours.palette.m3primary
            secondaryColor: Colours.palette.m3tertiary
            rounding: Tokens.rounding.small
            spacing: root.barCount > 1 ? Math.max(1, stage.width / root.barCount * 0.3) : 0
            animationDuration: Tokens.anim.durations.normal
        }

        // Stepped every frame while the bars are easing, the same as the mirrored style; at rest
        // advance() returns at once and asks for no repaint
        FrameAnimation {
            running: root.visible && !bars.settled
            onTriggered: bars.advance(frameTime)
        }
    }

    StyledRect {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: stage.bottom
        height: 1
        color: Qt.alpha(Colours.palette.m3outlineVariant, 0.8)
    }

    // The reflection: the bars again, upside down, fading out as they go down into the floor
    Item {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: stage.bottom
        anchors.topMargin: 2
        anchors.bottom: parent.bottom
        clip: true
        opacity: 0.3

        ShaderEffectSource {
            id: mirror

            width: stage.width
            height: stage.height
            sourceItem: stage
            visible: false
        }

        // Flipped as a whole, so the feet of the bars meet the floor line and the tips hang lowest
        Mask {
            width: stage.width
            height: stage.height
            source: mirror
            maskSource: fade

            transform: Scale {
                origin.y: stage.height / 2
                yScale: -1
            }
        }

        Rectangle {
            id: fade

            width: stage.width
            height: stage.height
            visible: false
            layer.enabled: true

            gradient: Gradient {
                GradientStop {
                    position: 1 - root.floorShare / (1 - root.floorShare)
                    color: Qt.rgba(0, 0, 0, 0)
                }
                GradientStop {
                    position: 1
                    color: Qt.rgba(0, 0, 0, 1)
                }
            }
        }
    }
}
