pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services
import qs.utils

// The photo card's framed print: the picture on a sheet of paper with a deep margin at the foot for its
// caption, set down slightly askew. The paper is one of the scheme's fixed tones, which stay light in a
// dark scheme as well, so the print reads as paper in either
Item {
    id: root

    // One FileSystemEntry from the card's folder, or null when there is nothing to show
    required property var entry
    required property int count

    signal step(int delta)

    // How far the print is turned, in degrees
    readonly property real tilt: -2.5
    readonly property real sin: Math.abs(Math.sin(root.tilt * Math.PI / 180))
    readonly property real cos: Math.cos(root.tilt * Math.PI / 180)
    // The largest print, in the paper's own proportions, whose turned corners still stay inside the card.
    // A turned w x h box takes w cos + h sin across and w sin + h cos down, which is solved for the print's
    // width from whichever of the two runs out first
    readonly property real aspect: 0.7
    readonly property real printWidth: {
        const room = Math.max(0, root.width - Tokens.padding.small);
        const roomY = Math.max(0, root.height - Tokens.padding.small);
        return Math.floor(Math.min(room / (root.cos + root.sin / root.aspect), roomY / (root.sin + root.cos / root.aspect)));
    }

    implicitWidth: 180
    implicitHeight: 250

    Item {
        id: sheet

        anchors.centerIn: parent
        width: root.printWidth
        height: Math.round(root.printWidth / root.aspect)
        rotation: root.tilt
        // Turned edges are left jagged without this
        antialiasing: true

        layer.enabled: PowerSaving.shadows
        layer.smooth: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Colours.palette.m3shadow
            shadowOpacity: 0.4
            shadowBlur: 0.5
            shadowVerticalOffset: 3
        }

        StyledRect {
            id: paper

            anchors.fill: parent
            radius: Tokens.rounding.extraSmall
            color: Colours.palette.m3secondaryFixed
            antialiasing: true

            ClipRect {
                id: picture

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Tokens.padding.medium
                height: parent.height - Tokens.padding.medium - caption.height
                radius: 2
                color: Colours.palette.m3onSecondaryFixedVariant

                MaterialIcon {
                    anchors.centerIn: parent
                    visible: !root.entry
                    text: "photo"
                    color: Colours.palette.m3secondaryFixedDim
                    fontStyle: Tokens.font.icon.large
                }

                Image {
                    anchors.fill: parent
                    asynchronous: true
                    fillMode: Image.PreserveAspectCrop
                    source: root.entry ? Paths.absolutePath(root.entry.path) : ""
                }
            }

            // The caption, written on the margin under the picture: its name, and when it was taken
            // as near as the file can say
            RowLayout {
                id: caption

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.leftMargin: Tokens.padding.extraSmall
                anchors.rightMargin: Tokens.padding.extraSmall
                height: 46
                spacing: 0

                IconButton {
                    visible: root.count > 1
                    icon: "chevron_left"
                    type: IconButton.Text
                    inactiveOnColour: Colours.palette.m3onSecondaryFixedVariant
                    onClicked: root.step(-1)
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    spacing: 0

                    StyledText {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideMiddle
                        text: root.entry ? root.entry.baseName : Tr.tr("No photos in the folder")
                        color: Colours.palette.m3onSecondaryFixed
                        font: Tokens.font.label.builders.medium.weight(Font.DemiBold).build()
                    }

                    StyledText {
                        Layout.fillWidth: true
                        visible: !!root.entry
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                        text: root.entry ? Qt.formatDate(root.entry.lastModified, "d MMM yyyy") : ""
                        color: Colours.palette.m3onSecondaryFixedVariant
                        font: Tokens.font.label.small
                    }
                }

                IconButton {
                    visible: root.count > 1
                    icon: "chevron_right"
                    type: IconButton.Text
                    inactiveOnColour: Colours.palette.m3onSecondaryFixedVariant
                    onClicked: root.step(1)
                }
            }
        }
    }
}
