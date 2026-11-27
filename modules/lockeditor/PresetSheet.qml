pragma ComponentBehavior: Bound

import QtQuick
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

    // Three to a row, as big as fits in most of the screen's width
    readonly property real tileWidth: Math.floor(Math.max(160, Math.min(340, (root.screenSize.width * 0.8 - Tokens.padding.extraLarge * 2 - Tokens.spacing.large * 2) / 3)))
    readonly property real thumbHeight: Math.round(root.screenSize.height * root.thumbScale)
    readonly property real thumbScale: root.tileWidth / Math.max(1, root.screenSize.width)
    readonly property string wallpaper: (Config.lock.wallpaper ?? "") !== "" ? Config.lock.wallpaper : Wallpapers.current

    signal picked(id: string)
    signal dismissed

    implicitWidth: root.tileWidth * 3 + Tokens.spacing.large * 2 + Tokens.padding.extraLarge * 2
    implicitHeight: Math.min(column.implicitHeight + Tokens.padding.extraLarge * 2, root.screenSize.height * 0.85)
    radius: Tokens.rounding.extraLarge
    color: Colours.palette.m3surfaceContainer

    // An outline rather than a drop shadow: a shadow would have the whole sheet, live previews and
    // all, redrawn through a layer every time any of them changed
    border.width: 1
    border.color: Colours.palette.m3outlineVariant

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

            // The title, with the close button pinned to the right edge
            Item {
                Layout.fillWidth: true
                implicitHeight: Math.max(heading.implicitHeight, closeButton.implicitHeight)

                ColumnLayout {
                    id: heading

                    anchors.left: parent.left
                    anchors.right: closeButton.left
                    anchors.rightMargin: Tokens.spacing.medium
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2

                    StyledText {
                        Layout.fillWidth: true
                        text: Tr.tr("Start from a preset")
                        color: Colours.palette.m3onSurface
                        font: Tokens.font.headline.small
                        elide: Text.ElideRight
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: Tr.tr("Replaces the current layout. Undo brings it back.")
                        color: Colours.palette.m3onSurfaceVariant
                        font: Tokens.font.body.small
                        elide: Text.ElideRight
                    }
                }

                EditorButton {
                    id: closeButton

                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    icon: "close"
                    tone: "plain"
                    onActivated: root.dismissed()
                }
            }

            GridLayout {
                Layout.fillWidth: true
                columns: 3
                rowSpacing: Tokens.spacing.large
                columnSpacing: Tokens.spacing.large

                Repeater {
                    model: LockPresets.list

                    Item {
                        id: tile

                        required property var modelData

                        // Tops in line across a row, however many lines each one's note takes
                        Layout.alignment: Qt.AlignTop
                        implicitWidth: root.tileWidth
                        implicitHeight: tileColumn.implicitHeight

                        ColumnLayout {
                            id: tileColumn

                            width: parent.width
                            spacing: Tokens.spacing.small

                            // The preset at the screen's own size over the lock's wallpaper,
                            // shrunk to the tile
                            ClipRect {
                                id: thumb

                                Layout.preferredWidth: root.tileWidth
                                Layout.preferredHeight: root.thumbHeight
                                radius: Tokens.rounding.large

                                Image {
                                    anchors.fill: parent
                                    source: root.wallpaper
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                    // Small, so it comes out as soft as the lock's blur
                                    sourceSize: Qt.size(96, 54)
                                    smooth: true
                                }

                                Rectangle {
                                    anchors.fill: parent
                                    color: Colours.palette.m3scrim
                                    opacity: 0.4
                                }

                                // Drawn into a texture a couple of times the tile's size and
                                // mipmapped down from there, so text and edges come out smooth
                                // rather than as broken pixels
                                LockCanvas {
                                    width: root.screenSize.width
                                    height: root.screenSize.height
                                    scale: root.thumbScale
                                    transformOrigin: Item.TopLeft
                                    elements: LockPresets.build(tile.modelData.id)
                                    enabled: false

                                    layer.enabled: true
                                    layer.smooth: true
                                    layer.mipmap: true
                                    layer.textureSize: Qt.size(Math.round(root.tileWidth * 2), Math.round(root.thumbHeight * 2))
                                }
                            }

                            StyledText {
                                Layout.fillWidth: true
                                Layout.topMargin: Tokens.spacing.extraSmall
                                text: tile.modelData.name
                                color: tileState.containsMouse ? Colours.palette.m3primary : Colours.palette.m3onSurface
                                font: Tokens.font.title.small
                                elide: Text.ElideRight
                            }

                            StyledText {
                                Layout.fillWidth: true
                                text: tile.modelData.note
                                color: Colours.palette.m3onSurfaceVariant
                                font: Tokens.font.body.small
                                wrapMode: Text.WordWrap
                                maximumLineCount: 2
                                elide: Text.ElideRight
                            }
                        }

                        // An outline round the picture while pointed at
                        Rectangle {
                            width: root.tileWidth
                            height: root.thumbHeight
                            radius: Tokens.rounding.large
                            color: "transparent"
                            border.width: 3
                            border.color: Colours.palette.m3primary
                            opacity: tileState.containsMouse ? 1 : 0

                            Behavior on opacity {
                                Anim {
                                    type: Anim.DefaultEffects
                                }
                            }
                        }

                        MouseArea {
                            id: tileState

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.picked(tile.modelData.id)
                        }
                    }
                }
            }
        }
    }
}
