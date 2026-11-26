pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.services
import qs.modules.lock.canvas

// The presets sheet: every ready-made lock screen (LockPresets) as a live miniature of itself,
// drawn by the same canvas the lock uses. Picking one replaces what's being edited, which Undo
// brings back
StyledRect {
    id: root

    required property size screenSize

    readonly property real tileWidth: 240

    readonly property real thumbScale: root.tileWidth / Math.max(1, root.screenSize.width)

    signal picked(id: string)
    signal dismissed

    implicitWidth: root.tileWidth * 4 + Tokens.spacing.medium * 3 + Tokens.padding.extraLarge * 2
    implicitHeight: Math.min(column.implicitHeight + Tokens.padding.extraLarge * 2, root.screenSize.height * 0.85)
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

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    StyledText {
                        text: Tr.tr("Start from a preset")
                        color: Colours.palette.m3onSurface
                        font: Tokens.font.headline.small
                    }

                    StyledText {
                        text: Tr.tr("Replaces the current layout. Undo brings it back.")
                        color: Colours.palette.m3onSurfaceVariant
                        font: Tokens.font.body.small
                    }
                }

                EditorButton {
                    icon: "close"
                    tone: "plain"
                    onActivated: root.dismissed()
                }
            }

            GridLayout {
                Layout.fillWidth: true
                columns: 4
                rowSpacing: Tokens.spacing.medium
                columnSpacing: Tokens.spacing.medium

                Repeater {
                    model: LockPresets.list

                    StyledRect {
                        id: tile

                        required property var modelData

                        implicitWidth: root.tileWidth
                        implicitHeight: tileColumn.implicitHeight
                        radius: Tokens.rounding.large
                        color: "transparent"

                        ColumnLayout {
                            id: tileColumn

                            width: parent.width
                            spacing: Tokens.spacing.small

                            // The preset at the screen's own size, scaled down to the tile
                            StyledRect {
                                Layout.preferredWidth: root.tileWidth
                                Layout.preferredHeight: root.screenSize.height * root.thumbScale
                                radius: Tokens.rounding.medium
                                color: Colours.palette.m3surfaceContainerLowest
                                clip: true

                                Rectangle {
                                    anchors.fill: parent
                                    gradient: Gradient {
                                        orientation: Gradient.Horizontal

                                        GradientStop {
                                            position: 0
                                            color: Qt.alpha(Colours.palette.m3primaryContainer, 0.5)
                                        }

                                        GradientStop {
                                            position: 1
                                            color: Qt.alpha(Colours.palette.m3tertiaryContainer, 0.5)
                                        }
                                    }
                                }

                                LockCanvas {
                                    width: root.screenSize.width
                                    height: root.screenSize.height
                                    scale: root.thumbScale
                                    transformOrigin: Item.TopLeft
                                    elements: LockPresets.build(tile.modelData.id)
                                    enabled: false
                                }
                            }

                            StyledText {
                                text: tile.modelData.name
                                color: Colours.palette.m3onSurface
                                font: Tokens.font.body.medium
                            }

                            StyledText {
                                Layout.fillWidth: true
                                text: tile.modelData.note
                                color: Colours.palette.m3onSurfaceVariant
                                font: Tokens.font.label.medium
                                wrapMode: Text.WordWrap
                            }
                        }

                        StateLayer {
                            radius: tile.radius
                            onClicked: root.picked(tile.modelData.id)
                        }
                    }
                }
            }
        }
    }
}
