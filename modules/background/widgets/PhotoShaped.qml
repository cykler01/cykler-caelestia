pragma ComponentBehavior: Bound

import QtQuick
import M3Shapes
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.components.effects
import qs.services
import qs.utils

// The photo card's shaped style: the picture cut into one of the shell's soft shapes, the same family the
// dashboard turns its cover art in. Each picture keeps a shape of its own, taken from its path, so a
// picture always comes back in the shape it had, and stepping to the next one morphs the outline across
Item {
    id: root

    required property var entry
    required property int count

    signal step(int delta)

    // Only the rounded, organic members of the family: the pointed ones read as icons rather than frames
    readonly property list<int> shapes: [MaterialShape.Cookie9Sided, MaterialShape.Cookie12Sided, MaterialShape.Clover4Leaf, MaterialShape.SoftBurst, MaterialShape.Puffy, MaterialShape.Flower, MaterialShape.Cookie7Sided]

    readonly property int shapeIndex: {
        const path = root.entry?.path ?? "";
        let h = 0;
        for (let i = 0; i < path.length; i++)
            h = (h * 31 + path.charCodeAt(i)) | 0;
        return Math.abs(h) % root.shapes.length;
    }
    readonly property real size: Math.min(width, height)

    implicitWidth: 190
    implicitHeight: 190

    Item {
        id: cutout

        anchors.centerIn: parent
        width: root.size
        height: root.size
        visible: false
        layer.enabled: true

        MaterialShape {
            id: outline

            anchors.centerIn: parent
            implicitSize: root.size
            shape: root.shapes[root.shapeIndex]
            animationDuration: PowerSaving.animations ? Tokens.anim.durations.large : 0
            color: "black"
        }
    }

    Item {
        anchors.centerIn: parent
        width: root.size
        height: root.size

        MaterialShape {
            anchors.centerIn: parent
            implicitSize: root.size
            shape: root.shapes[root.shapeIndex]
            animationDuration: PowerSaving.animations ? Tokens.anim.durations.large : 0
            color: Colours.palette.m3surfaceContainerHigh
        }

        MaterialIcon {
            anchors.centerIn: parent
            visible: !root.entry
            text: "photo"
            color: Colours.palette.m3outline
            fontStyle: Tokens.font.icon.large
        }

        Image {
            anchors.fill: parent
            asynchronous: true
            fillMode: Image.PreserveAspectCrop
            source: root.entry ? Paths.absolutePath(root.entry.path) : ""

            layer.enabled: true
            layer.effect: Mask {
                maskSource: cutout
            }
        }

        // Clicking the picture itself moves on as well
        MouseArea {
            anchors.fill: parent
            enabled: root.count > 1
            cursorShape: Qt.PointingHandCursor
            onClicked: root.step(1)
        }
    }

    StyledText {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        width: parent.width
        visible: !root.entry
        horizontalAlignment: Text.AlignHCenter
        text: Tr.tr("No photos in the folder")
        color: Colours.palette.m3outline
        font: Tokens.font.label.medium
        wrapMode: Text.Wrap
    }

    // Back and on, in the corners the shape leaves free
    IconButton {
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        visible: root.count > 1
        icon: "chevron_left"
        type: IconButton.Tonal
        font: Tokens.font.icon.small
        onClicked: root.step(-1)
    }

    IconButton {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        visible: root.count > 1
        icon: "chevron_right"
        type: IconButton.Tonal
        font: Tokens.font.icon.small
        onClicked: root.step(1)
    }
}
