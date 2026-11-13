pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.containers
import qs.components.controls
import qs.services
import qs.utils
import qs.modules.background.widgets

// Picking a widget to add, from the desktop itself while the layout is being rearranged. The same
// two steps the settings page uses - which widget, then which of its styles - so that adding a card
// and moving it are one job in one place rather than a trip through Panels › Desktop › Widgets.
//
// Every tile is the real card drawn small (see widgets/WidgetPreview.qml), not a name in a list.
Item {
    id: root

    // Which widget's styles are being shown, or "" on the first step
    property string selectedKind: ""

    readonly property var kind: root.selectedKind !== "" ? WidgetCatalog.kindFor(root.selectedKind) : null
    readonly property var types: root.kind?.types ?? []

    // Wide enough that a card scaled into a tile is still readable
    readonly property real minTileWidth: 240
    readonly property real tileSpacing: Tokens.spacing.small
    // Both the column count and the tile width come from the sheet's own width rather than from the
    // grid inside it: a tile measuring its parent while the grid measures its tiles is a binding loop
    readonly property real gridWidth: sheet.width - Tokens.padding.large * 2
    readonly property int tileColumns: Math.max(1, Math.floor(root.gridWidth / root.minTileWidth))
    readonly property real tileWidth: (root.gridWidth - root.tileSpacing * (root.tileColumns - 1)) / root.tileColumns

    signal closed

    function add(id: string, type: string): void {
        GlobalConfig.background.desktopWidgets.entries.insert({
            id: id,
            type: type,
            enabled: true
        });
        root.closed();
    }

    // Each step starts at the top: the grids are different lengths, so carrying the scroll from one
    // into the other can land you looking at empty space below a short one
    onSelectedKindChanged: flickable.contentY = 0

    focus: true

    Keys.onEscapePressed: {
        if (root.selectedKind !== "")
            root.selectedKind = "";
        else
            root.closed();
    }

    // Dims the desktop behind the sheet, and takes a click outside it as "never mind"
    StyledRect {
        anchors.fill: parent
        color: Qt.alpha(Colours.palette.m3scrim, 0.5)

        MouseArea {
            anchors.fill: parent
            onClicked: root.closed()
        }
    }

    StyledRect {
        id: sheet

        anchors.centerIn: parent
        width: Math.min(760, parent.width - Tokens.padding.extraExtraLarge * 2)
        height: Math.min(header.implicitHeight + grid.implicitHeight + Tokens.padding.large * 3, parent.height * 0.75)
        radius: Tokens.rounding.extraLarge
        color: Colours.palette.m3surfaceContainer

        // Swallows clicks that would otherwise reach the dimmer behind and close the sheet
        MouseArea {
            anchors.fill: parent
        }

        RowLayout {
            id: header

            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: Tokens.padding.large
            spacing: Tokens.spacing.medium

            // On the style step the arrow belongs to the picker: it goes back to the widget list
            IconButton {
                visible: !!root.kind
                icon: "arrow_back"
                type: IconButton.Tonal
                isRound: true
                font: Tokens.font.icon.small
                onClicked: root.selectedKind = ""
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                StyledText {
                    Layout.fillWidth: true
                    text: root.kind ? root.kind.name : Tr.tr("Add a widget")
                    font: Tokens.font.title.medium
                    elide: Text.ElideRight
                }

                StyledText {
                    Layout.fillWidth: true
                    text: root.kind ? Tr.tr("Each one is drawn the size it will be on the desktop") : Tr.tr("Pick what to put on the desktop, then choose how it looks")
                    color: Colours.palette.m3onSurfaceVariant
                    font: Tokens.font.label.small
                    elide: Text.ElideRight
                }
            }

            IconButton {
                icon: "close"
                type: IconButton.Text
                isRound: true
                font: Tokens.font.icon.small
                onClicked: root.closed()
            }
        }

        VerticalFadeFlickable {
            id: flickable

            anchors.top: header.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: Tokens.padding.large
            anchors.topMargin: Tokens.spacing.medium

            contentHeight: grid.implicitHeight
            clip: true

            Grid {
                id: grid

                width: root.gridWidth
                columns: root.tileColumns
                spacing: root.tileSpacing

                Repeater {
                    model: root.kind ? [] : WidgetCatalog.kinds

                    Tile {
                        required property var modelData

                        kind: modelData.id
                        // The first style stands for the widget in the list; the next step shows them all
                        variant: WidgetCatalog.typesFor(modelData.id)[0]?.id ?? ""
                        name: modelData.name
                        subtext: {
                            const n = WidgetCatalog.typesFor(modelData.id).length;
                            return n > 1 ? Tr.tr("%1 styles").arg(n) : Tr.tr("One style");
                        }
                        onActivated: root.selectedKind = modelData.id
                    }
                }

                Repeater {
                    model: root.types

                    Tile {
                        required property var modelData

                        kind: root.selectedKind
                        variant: modelData.id
                        name: modelData.name
                        subtext: Tr.tr("%1 rows tall").arg(modelData.height)
                        onActivated: root.add(root.selectedKind, modelData.id)
                    }
                }
            }
        }
    }

    // One pickable widget: the real card drawn small, with what it is underneath
    component Tile: StyledRect {
        id: tile

        required property string kind
        required property string variant
        required property string name
        required property string subtext

        signal activated

        implicitWidth: root.tileWidth
        implicitHeight: preview.implicitHeight + labels.implicitHeight + Tokens.padding.small * 3
        radius: Tokens.rounding.large
        color: Colours.palette.m3surfaceContainerLow

        WidgetPreview {
            id: preview

            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: Tokens.padding.small
            kind: tile.kind
            variant: tile.variant
            height: implicitHeight
        }

        ColumnLayout {
            id: labels

            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: Tokens.padding.small
            spacing: 0

            StyledText {
                Layout.fillWidth: true
                elide: Text.ElideRight
                text: tile.name
                color: Colours.palette.m3onSurface
                font: Tokens.font.label.medium
            }

            StyledText {
                Layout.fillWidth: true
                elide: Text.ElideRight
                text: tile.subtext
                color: Colours.palette.m3outline
                font: Tokens.font.label.small
            }
        }

        StateLayer {
            radius: parent.radius
            onClicked: tile.activated()
        }
    }
}
