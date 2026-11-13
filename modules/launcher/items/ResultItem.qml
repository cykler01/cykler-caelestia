pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Caelestia.Config
import qs.components
import qs.services
import qs.modules.launcher.services

// One row of the unified search: an app, a setting, an action or a calculator answer, all drawn the
// same way so the list reads as one answer to one question rather than several lists stacked up.
//
// The heading above a group is part of the row under it rather than a row of its own: ListView
// sections key off a model role, and the model here is a ScriptModel of plain objects which has
// none. Keeping it inside also means the arrow keys never land on a heading.
Item {
    id: root

    required property var modelData
    required property var list

    function onClicked(): void {
        Spotlight.activate(root.modelData, root.list);
    }

    // Laid out by the column rather than by anchoring each piece to an edge, so a heading can never
    // end up drawn over the row it belongs to
    implicitHeight: column.implicitHeight

    anchors.left: parent?.left
    anchors.right: parent?.right

    Column {
        id: column

        anchors.left: parent.left
        anchors.right: parent.right

        StyledText {
            id: heading

            leftPadding: Tokens.padding.medium
            bottomPadding: Tokens.spacing.extraSmall
            height: visible ? implicitHeight : 0
            visible: root.modelData.firstOfGroup
            text: Spotlight.categoryName(root.modelData.category)
            color: Colours.palette.m3onSurfaceVariant
            font: Tokens.font.label.medium
        }

        // Only the row is pressable, so a click on the heading does nothing rather than opening
        // whatever happens to sit under it
        StyledRect {
            anchors.left: parent.left
            anchors.right: parent.right
            implicitHeight: Tokens.sizes.launcher.itemHeight

            color: "transparent"
            radius: Tokens.rounding.large

            StateLayer {
                radius: parent.radius
                onClicked: root.onClicked()
            }

            RowLayout {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.margins: Tokens.padding.medium

                spacing: Tokens.spacing.medium

                // An app has a real icon to show; everything else gets its category's glyph
                Loader {
                    Layout.alignment: Qt.AlignVCenter
                    active: root.modelData.kind === "app" && !!root.modelData.iconSource

                    sourceComponent: IconImage {
                        asynchronous: true
                        implicitSize: Math.round(Tokens.font.icon.extraLarge.pixelSize)
                        source: Quickshell.iconPath(root.modelData.iconSource, "image-missing")
                    }
                }

                MaterialIcon {
                    Layout.alignment: Qt.AlignVCenter
                    visible: root.modelData.kind !== "app" || !root.modelData.iconSource
                    text: root.modelData.icon || "help_outline"
                    color: Colours.palette.m3onSurface
                    fontStyle: Tokens.font.icon.extraLarge
                    fill: root.modelData.kind === "setting" ? 1 : 0
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    StyledText {
                        Layout.fillWidth: true
                        text: root.modelData.title
                        font: Tokens.font.body.large
                        elide: Text.ElideRight
                    }

                    StyledText {
                        Layout.fillWidth: true
                        visible: !!root.modelData.subtitle
                        text: root.modelData.subtitle
                        color: Colours.palette.m3onSurfaceVariant
                        font: Tokens.font.body.small
                        elide: Text.ElideRight
                    }
                }
            }
        }
    }
}
