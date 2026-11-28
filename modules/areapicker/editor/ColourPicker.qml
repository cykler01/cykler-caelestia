pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services

// NOTE(fork): picks the screenshot editor's custom colour: saturation and value on the
// square, hue on the bar beneath it, or a hex code typed in.
ColumnLayout {
    id: root

    // The colour being shown; set from outside, and followed whenever it changes there.
    property color colour
    property real hue
    property real sat
    property real val

    readonly property alias hexFocused: hexField.activeFocus

    signal picked(c: color)

    function sync(): void {
        // A grey has no hue of its own, so keep the one already chosen.
        if (root.colour.hsvHue >= 0)
            root.hue = root.colour.hsvHue;
        root.sat = root.colour.hsvSaturation;
        root.val = root.colour.hsvValue;
        if (!hexField.activeFocus)
            hexField.text = root.colour.toString().slice(1, 7);
    }

    function emitPicked(): void {
        root.picked(Qt.hsva(root.hue, root.sat, root.val, 1));
    }

    spacing: Tokens.spacing.small

    onColourChanged: sync()
    Component.onCompleted: sync()

    Rectangle {
        id: square

        Layout.fillWidth: true
        implicitHeight: 120
        radius: Tokens.rounding.small
        gradient: Gradient {
            orientation: Gradient.Horizontal

            GradientStop {
                position: 0
                color: "white"
            }
            GradientStop {
                position: 1
                color: Qt.hsva(root.hue, 1, 1, 1)
            }
        }

        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            gradient: Gradient {
                GradientStop {
                    position: 0
                    color: "transparent"
                }
                GradientStop {
                    position: 1
                    color: "black"
                }
            }
        }

        Rectangle {
            x: root.sat * parent.width - width / 2
            y: (1 - root.val) * parent.height - height / 2
            implicitWidth: 12
            implicitHeight: 12
            radius: 6
            color: "transparent"
            border.width: 2
            border.color: root.val > 0.5 ? "black" : "white"
        }

        MouseArea {
            function pick(x: real, y: real): void {
                root.sat = Math.max(0, Math.min(1, x / width));
                root.val = 1 - Math.max(0, Math.min(1, y / height));
                root.emitPicked();
            }

            anchors.fill: parent
            cursorShape: Qt.CrossCursor
            onPressed: mouse => pick(mouse.x, mouse.y) // qmllint disable signal-handler-parameters
            onPositionChanged: mouse => pick(mouse.x, mouse.y) // qmllint disable signal-handler-parameters
        }
    }

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 14
        radius: height / 2
        gradient: Gradient {
            orientation: Gradient.Horizontal

            GradientStop {
                position: 0
                color: Qt.hsva(0, 1, 1, 1)
            }
            GradientStop {
                position: 1 / 6
                color: Qt.hsva(1 / 6, 1, 1, 1)
            }
            GradientStop {
                position: 2 / 6
                color: Qt.hsva(2 / 6, 1, 1, 1)
            }
            GradientStop {
                position: 3 / 6
                color: Qt.hsva(3 / 6, 1, 1, 1)
            }
            GradientStop {
                position: 4 / 6
                color: Qt.hsva(4 / 6, 1, 1, 1)
            }
            GradientStop {
                position: 5 / 6
                color: Qt.hsva(5 / 6, 1, 1, 1)
            }
            GradientStop {
                position: 1
                color: Qt.hsva(0.9999, 1, 1, 1)
            }
        }

        Rectangle {
            x: root.hue * parent.width - width / 2
            anchors.verticalCenter: parent.verticalCenter
            implicitWidth: 18
            implicitHeight: 18
            radius: 9
            color: Qt.hsva(root.hue, 1, 1, 1)
            border.width: 2
            border.color: "white"
        }

        MouseArea {
            function pick(x: real): void {
                root.hue = Math.max(0, Math.min(0.9999, x / width));
                root.emitPicked();
            }

            anchors.fill: parent
            anchors.margins: -4
            cursorShape: Qt.PointingHandCursor
            onPressed: mouse => pick(mouse.x - 4) // qmllint disable signal-handler-parameters
            onPositionChanged: mouse => pick(mouse.x - 4) // qmllint disable signal-handler-parameters
        }
    }

    StyledTextField {
        id: hexField

        Layout.fillWidth: true
        Layout.topMargin: Tokens.spacing.small
        placeholderText: Tr.tr("Hex")
        leadingIcon: "tag"
        validate: /^[0-9a-fA-F]{6}$/
        onTextEdited: {
            if (valid && text.length === 6)
                root.picked(`#${text}`);
        }
    }
}
