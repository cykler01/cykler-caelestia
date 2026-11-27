pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.services
import qs.modules.lock.canvas

// The "Add element" sheet: every kind there is (ElementCatalog), grouped by what it's for, down the
// left, and the one under the pointer drawn for real on the right, over the lock's own wallpaper,
// at the size it would come in at. Clicking one, or Add under the preview, puts it in the middle
// of the screen, selected, ready to move
StyledRect {
    id: root

    // The screen being edited, so the preview is drawn at the size it'll really be
    required property size screenSize
    required property real uiScale

    // The kind being previewed: the last one pointed at
    property string previewKind: "clock"

    readonly property var previewInfo: ElementCatalog.kind(root.previewKind)

    signal picked(kind: string)
    signal dismissed

    implicitWidth: 1120
    implicitHeight: 720
    radius: Tokens.rounding.extraLarge
    color: Colours.palette.m3surfaceContainer

    // An outline rather than a drop shadow: a shadow would have the whole sheet, live previews and
    // all, redrawn through a layer every time any of them changed
    border.width: 1
    border.color: Colours.palette.m3outlineVariant

    MouseArea {
        anchors.fill: parent
    }

    // The title, with the close button pinned to the right edge
    Item {
        id: header

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Tokens.padding.extraLarge
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
                text: Tr.tr("Add to the lock screen")
                color: Colours.palette.m3onSurface
                font: Tokens.font.headline.small
                elide: Text.ElideRight
            }

            StyledText {
                Layout.fillWidth: true
                text: Tr.tr("Point at one to preview it, click it to add it.")
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

    // The kinds, grouped
    Flickable {
        id: flick

        anchors.left: parent.left
        anchors.top: header.bottom
        anchors.bottom: parent.bottom
        anchors.right: preview.left
        anchors.leftMargin: Tokens.padding.extraLarge
        anchors.rightMargin: Tokens.padding.large
        anchors.topMargin: Tokens.padding.large
        anchors.bottomMargin: Tokens.padding.extraLarge
        contentHeight: column.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: column

            width: flick.width
            spacing: Tokens.spacing.small

            Repeater {
                model: ElementCatalog.groups

                ColumnLayout {
                    id: group

                    required property var modelData
                    required property int index

                    Layout.fillWidth: true
                    spacing: Tokens.spacing.small

                    StyledText {
                        Layout.topMargin: group.index === 0 ? 0 : Tokens.spacing.large
                        text: group.modelData.name
                        color: Colours.palette.m3primary
                        font: Tokens.font.label.large
                    }

                    GridLayout {
                        Layout.fillWidth: true
                        columns: 2
                        rowSpacing: Tokens.spacing.small
                        columnSpacing: Tokens.spacing.small

                        Repeater {
                            // The password field is already there and can't be had twice
                            model: ElementCatalog.kinds.filter(k => k.group === group.modelData.id && k.id !== "password")

                            StyledRect {
                                id: tile

                                required property var modelData
                                readonly property bool current: root.previewKind === modelData.id

                                Layout.fillWidth: true
                                Layout.preferredWidth: 1
                                Layout.alignment: Qt.AlignTop
                                implicitHeight: 56
                                radius: Tokens.rounding.large
                                color: tile.current ? Colours.palette.m3secondaryContainer : Colours.palette.m3surfaceContainerHigh

                                StateLayer {
                                    radius: tile.radius
                                    color: tile.current ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurface
                                    onContainsMouseChanged: {
                                        if (containsMouse)
                                            root.previewKind = tile.modelData.id;
                                    }
                                    onClicked: root.picked(tile.modelData.id)
                                }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: Tokens.padding.small
                                    anchors.rightMargin: Tokens.padding.medium
                                    spacing: Tokens.spacing.medium

                                    StyledRect {
                                        implicitWidth: 40
                                        implicitHeight: 40
                                        radius: Tokens.rounding.medium
                                        color: tile.current ? Colours.palette.m3primary : Colours.palette.m3surfaceContainerHighest

                                        MaterialIcon {
                                            anchors.centerIn: parent
                                            text: tile.modelData.icon
                                            color: tile.current ? Colours.palette.m3onPrimary : Colours.palette.m3onSurfaceVariant
                                            fontStyle: Tokens.font.icon.medium
                                        }
                                    }

                                    StyledText {
                                        Layout.fillWidth: true
                                        text: tile.modelData.name
                                        color: tile.current ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurface
                                        font: Tokens.font.body.medium
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

    // The kind pointed at, for real
    ColumnLayout {
        id: preview

        anchors.right: parent.right
        anchors.top: header.bottom
        anchors.bottom: parent.bottom
        anchors.rightMargin: Tokens.padding.extraLarge
        anchors.topMargin: Tokens.padding.large
        anchors.bottomMargin: Tokens.padding.extraLarge
        width: Math.round(root.width * 0.46)
        spacing: Tokens.spacing.medium

        ClipRect {
            id: stageClip

            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: Tokens.rounding.large

            // The lock's wallpaper, small enough to come out soft, under the lock's dark scrim
            Image {
                anchors.fill: parent
                source: (Config.lock.wallpaper ?? "") !== "" ? Config.lock.wallpaper : Wallpapers.current
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                sourceSize: Qt.size(96, 54)
                smooth: true
            }

            Rectangle {
                anchors.fill: parent
                color: Colours.palette.m3scrim
                opacity: 0.4
            }

            // A screen the size of the real one, with the element in its middle, shrunk around
            // that middle only as far as it takes to fit
            Item {
                id: virtualScreen

                readonly property real fit: host.width > 0 && host.height > 0 ? Math.min(1, stageClip.width * 0.85 / host.width, stageClip.height * 0.85 / host.height) : 1

                anchors.centerIn: parent
                width: root.screenSize.width
                height: root.screenSize.height
                scale: fit

                ElementHost {
                    id: host

                    index: 0
                    element: Object.assign(ElementCatalog.create(root.previewKind), {
                        x: 0.5,
                        y: 0.5,
                        anchor: "c"
                    })
                    screenW: root.screenSize.width
                    screenH: root.screenSize.height
                    uiScale: root.uiScale
                    editing: true
                    enabled: false
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.medium

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                StyledText {
                    Layout.fillWidth: true
                    text: root.previewInfo?.name ?? ""
                    color: Colours.palette.m3onSurface
                    font: Tokens.font.title.medium
                    elide: Text.ElideRight
                }

                StyledText {
                    Layout.fillWidth: true
                    text: root.previewInfo?.description ?? ""
                    color: Colours.palette.m3onSurfaceVariant
                    font: Tokens.font.body.small
                    wrapMode: Text.WordWrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                }
            }

            EditorButton {
                icon: "add"
                text: Tr.tr("Add")
                tone: "primary"
                onActivated: root.picked(root.previewKind)
            }
        }
    }
}
