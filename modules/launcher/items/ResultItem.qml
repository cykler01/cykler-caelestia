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
// same way so the list reads as one answer to one question rather than four lists stacked up.
//
// The heading above a group is drawn here rather than through ListView.section, because the model is
// a ScriptModel of plain objects and has no roles for a section to key off.
Item {
    id: root

    required property var modelData
    required property var list

    readonly property real headerHeight: root.modelData.firstOfGroup ? heading.implicitHeight + Tokens.spacing.small : 0

    function onClicked(): void {
        Spotlight.activate(root.modelData, root.list);
    }

    implicitHeight: Tokens.sizes.launcher.itemHeight + root.headerHeight

    anchors.left: parent?.left
    anchors.right: parent?.right

    StyledText {
        id: heading

        anchors.left: parent.left
        anchors.top: parent.top
        anchors.leftMargin: Tokens.padding.medium

        visible: root.modelData.firstOfGroup
        text: Spotlight.categoryName(root.modelData.category)
        color: Colours.palette.m3onSurfaceVariant
        font: Tokens.font.label.medium
    }

    // Only the row itself is pressable, so a click on the heading above it does nothing rather than
    // launching whatever happens to be underneath
    StyledRect {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
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
