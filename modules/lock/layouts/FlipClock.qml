pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import Caelestia.Config
import qs.components
import qs.services

// After the Fliqlo screensaver and the split-flap clocks it copies: the hours and the minutes each
// on a big square card with a seam across its middle. When a number changes its card folds shut on
// the old one and opens on the new, like a flap turning over
Row {
    id: root

    property real faceScale: 1
    property bool accent: false
    readonly property real cardSize: 300 * faceScale

    spacing: Tokens.spacing.extraLarge * faceScale

    FlipCard {
        value: Time.hourStr
        // AM/PM tucked into the hour card's corner, the way flip clocks mark it
        corner: Time.amPmStr
    }

    FlipCard {
        value: Time.minuteStr
        digitColour: root.accent ? Colours.palette.m3primary : Colours.palette.m3onSurface
    }

    component FlipCard: StyledRect {
        id: card

        required property string value
        property string corner
        property color digitColour: Colours.palette.m3onSurface
        // What's on the card right now; trails value while the flap is turning
        property string shown: value

        implicitWidth: root.cardSize
        implicitHeight: root.cardSize
        radius: Tokens.rounding.extraLarge * root.faceScale
        color: Colours.tPalette.m3surfaceContainerHigh

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            blurMax: 24
            shadowColor: Qt.alpha(Colours.palette.m3shadow, 0.6)
        }

        onValueChanged: flip.restart()

        // The top half a shade lighter than the bottom, as if lit from above
        StyledRect {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: parent.height / 2
            topLeftRadius: card.radius
            topRightRadius: card.radius
            color: Qt.alpha(Colours.palette.m3onSurface, 0.04)
        }

        StyledText {
            id: digits

            anchors.centerIn: parent
            text: card.shown
            color: card.digitColour
            font: Tokens.font.headline.builders.large.scale(root.faceScale * 5.2).weight(Font.Bold).build()

            transform: Scale {
                id: fold

                origin.x: digits.width / 2
                origin.y: digits.height / 2
            }
        }

        // The seam the flaps turn on
        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            height: Math.max(2, 4 * root.faceScale)
            color: Colours.palette.m3surface
            opacity: 0.9
        }

        StyledText {
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            anchors.margins: Tokens.padding.large * root.faceScale
            visible: text !== ""
            text: card.corner
            color: Colours.palette.m3primary
            font: Tokens.font.label.builders.large.scale(root.faceScale).weight(Font.Bold).build()
        }

        SequentialAnimation {
            id: flip

            NumberAnimation {
                target: fold
                property: "yScale"
                to: 0
                duration: 160
                easing.type: Easing.InQuad
            }

            ScriptAction {
                script: card.shown = card.value
            }

            NumberAnimation {
                target: fold
                property: "yScale"
                to: 1
                duration: 200
                easing.type: Easing.OutBack
            }
        }
    }
}
