pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Caelestia.Config
import qs.components
import qs.services
import qs.utils
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

    // The same icon box the plain app list draws (see AppItem): the app list is the launcher's
    // resting state, and a row has no business growing just because something was typed. AppItem
    // works it out from the padded row it sits in, so this does too
    readonly property int iconSize: Math.round((Tokens.sizes.launcher.itemHeight - Tokens.padding.small * 2) * 0.8)

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
                        implicitSize: root.iconSize
                        source: Quickshell.iconPath(root.modelData.iconSource, "image-missing")
                    }
                }

                MaterialIcon {
                    Layout.alignment: Qt.AlignVCenter
                    // Boxed to the same width as an app's icon, so the text starts in the same
                    // place whichever kind of row it is
                    Layout.preferredWidth: root.iconSize
                    horizontalAlignment: Text.AlignHCenter
                    visible: root.modelData.kind !== "app" || !root.modelData.iconSource
                    text: root.modelData.icon || "help_outline"
                    color: Colours.palette.m3onSurface
                    // Point sizes, so this lands a glyph of about iconSize next to the app icons
                    fontStyle: Tokens.font.icon.large
                    fill: root.modelData.kind === "setting" ? 1 : 0
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    StyledText {
                        Layout.fillWidth: true
                        text: root.modelData.title
                        font: Tokens.font.body.medium
                        elide: Text.ElideRight
                    }

                    StyledText {
                        Layout.fillWidth: true
                        visible: !!root.modelData.subtitle
                        text: root.modelData.subtitle
                        color: Colours.palette.m3outline
                        font: Tokens.font.body.small
                        elide: Text.ElideRight
                    }
                }

                // Favourites are marked in the app list, so they are marked here too
                Loader {
                    Layout.alignment: Qt.AlignVCenter
                    asynchronous: true
                    active: root.modelData.kind === "app" && !!root.modelData.payload && Strings.testRegexList(GlobalConfig.launcher.favouriteApps, root.modelData.payload.id)

                    sourceComponent: MaterialIcon {
                        text: "favorite"
                        fill: 1
                        color: Colours.palette.m3primary
                    }
                }
            }
        }
    }
}
