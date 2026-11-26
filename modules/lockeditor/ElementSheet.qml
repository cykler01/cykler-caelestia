pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.services
import qs.modules.lock.canvas

// The "Add element" sheet: every kind there is (ElementCatalog), grouped by what it's for, each
// with what it shows. Picking one puts it in the middle of the screen, selected, ready to move
StyledRect {
    id: root

    signal picked(kind: string)
    signal dismissed

    implicitWidth: 820
    implicitHeight: Math.min(column.implicitHeight + Tokens.padding.extraLarge * 2, 760)
    radius: Tokens.rounding.extraLarge
    color: Colours.palette.m3surfaceContainer

    layer.enabled: true
    layer.effect: MultiEffect {
        shadowEnabled: true
        blurMax: 24
        shadowColor: Qt.alpha(Colours.palette.m3shadow, 0.7)
    }

    MouseArea {
        anchors.fill: parent
    }

    Flickable {
        id: flick

        anchors.fill: parent
        anchors.margins: Tokens.padding.extraLarge
        contentHeight: column.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: column

            width: flick.width
            spacing: Tokens.spacing.medium

            RowLayout {
                Layout.fillWidth: true

                StyledText {
                    Layout.fillWidth: true
                    text: Tr.tr("Add to the lock screen")
                    color: Colours.palette.m3onSurface
                    font: Tokens.font.headline.small
                }

                EditorButton {
                    icon: "close"
                    tone: "plain"
                    onActivated: root.dismissed()
                }
            }

            Repeater {
                model: ElementCatalog.groups

                ColumnLayout {
                    id: group

                    required property var modelData

                    Layout.fillWidth: true
                    spacing: Tokens.spacing.small

                    StyledText {
                        Layout.topMargin: Tokens.spacing.medium
                        text: group.modelData.name
                        color: Colours.palette.m3primary
                        font: Tokens.font.label.large
                    }

                    GridLayout {
                        Layout.fillWidth: true
                        columns: 3
                        rowSpacing: Tokens.spacing.small
                        columnSpacing: Tokens.spacing.small

                        Repeater {
                            // The password field is already there and can't be had twice
                            model: ElementCatalog.kinds.filter(k => k.group === group.modelData.id && k.id !== "password")

                            StyledRect {
                                id: tile

                                required property var modelData

                                Layout.fillWidth: true
                                Layout.preferredWidth: 1
                                implicitHeight: tileRow.implicitHeight + Tokens.padding.medium * 2
                                radius: Tokens.rounding.large
                                color: Colours.tPalette.m3surfaceContainerHigh

                                StateLayer {
                                    radius: tile.radius
                                    onClicked: root.picked(tile.modelData.id)
                                }

                                RowLayout {
                                    id: tileRow

                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.margins: Tokens.padding.medium
                                    spacing: Tokens.spacing.medium

                                    StyledRect {
                                        Layout.alignment: Qt.AlignTop
                                        implicitWidth: 40
                                        implicitHeight: 40
                                        radius: Tokens.rounding.medium
                                        color: Colours.palette.m3secondaryContainer

                                        MaterialIcon {
                                            anchors.centerIn: parent
                                            text: tile.modelData.icon
                                            color: Colours.palette.m3onSecondaryContainer
                                            fontStyle: Tokens.font.icon.medium
                                        }
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 2

                                        StyledText {
                                            Layout.fillWidth: true
                                            text: tile.modelData.name
                                            color: Colours.palette.m3onSurface
                                            font: Tokens.font.body.medium
                                            elide: Text.ElideRight
                                        }

                                        StyledText {
                                            Layout.fillWidth: true
                                            text: tile.modelData.description
                                            color: Colours.palette.m3onSurfaceVariant
                                            font: Tokens.font.label.medium
                                            wrapMode: Text.WordWrap
                                            maximumLineCount: 3
                                            elide: Text.ElideRight
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
