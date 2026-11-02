pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services
import qs.utils
import qs.modules.nexus.common
import qs.modules.background.widgets

// Two steps on one page: the widget, then which variant of it to show. Picking a variant adds the card to the
// desktop and goes back to the widget list.
//
// Both steps are grids of real widgets rather than lists of names (see widgets/WidgetPreview.qml): the six
// resources styles are the same four words apart, and "Rings · CPU, RAM and disk" tells you much less about what
// you are about to add than a picture of it does.
PageBase {
    id: root

    property string selectedKind: ""

    readonly property var kind: selectedKind !== "" ? WidgetCatalog.kindFor(root.selectedKind) : null
    readonly property var types: root.kind?.types ?? []

    // Wide enough that a card scaled into it is still readable, and the grid falls to one column on a narrow
    // panel rather than shrinking the previews into illegibility
    readonly property real minTileWidth: 260

    // Both the column count and the tile width come from the page's own width rather than from the grid each
    // tile sits in: a tile measuring its parent while the grid measures its tiles is a binding loop
    readonly property real tileSpacing: Tokens.spacing.small
    readonly property int tileColumns: Math.max(1, Math.floor(root.cappedWidth / root.minTileWidth))
    readonly property real tileWidth: (root.cappedWidth - root.tileSpacing * (root.tileColumns - 1)) / root.tileColumns

    function add(id: string, type: string): void {
        GlobalConfig.background.desktopWidgets.entries.insert({
            id: id,
            type: type,
            enabled: true
        });
        root.nState.closeSubPage();
    }

    title: root.kind ? root.kind.name : Tr.tr("Add widget")
    isSubPage: true

    // On the style step the back arrow belongs to the picker: it returns to the widget list, the same
    // as the title it sits next to. Only from the widget list does it leave the page
    handlesBack: !!root.kind
    onBackPressed: root.selectedKind = ""

    // Each step starts at the top. The grids are different lengths, so carrying the scroll position
    // from one into the other can land you looking at empty space below a short one. The flickable
    // rests at minus its own top margin, not at zero
    onSelectedKindChanged: root.flickable.contentY = -root.flickable.topMargin

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        // ---------- Step one: which widget ----------
        SectionHeader {
            first: true
            visible: !root.kind
            text: Tr.tr("Widget")
        }

        Hint {
            visible: !root.kind
            text: Tr.tr("Pick what to put on the desktop, then choose how it looks. Every preview is the real widget, showing live data.")
        }

        TileGrid {
            visible: !root.kind

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
        }

        // ---------- Step two: which variant ----------
        SectionHeader {
            first: true
            visible: !!root.kind
            text: Tr.tr("Style")
        }

        Hint {
            visible: !!root.kind
            text: Tr.tr("Each one is drawn the size it will be on the desktop.")
        }

        TileGrid {
            visible: !!root.kind

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

        TextButton {
            Layout.alignment: Qt.AlignRight
            Layout.topMargin: Tokens.spacing.small
            visible: !!root.kind
            text: Tr.tr("Back to widgets")
            type: TextButton.Text
            onClicked: root.selectedKind = ""
        }
    }

    component Hint: StyledText {
        Layout.fillWidth: true
        Layout.leftMargin: Tokens.padding.largeIncreased
        Layout.rightMargin: Tokens.padding.largeIncreased
        Layout.bottomMargin: Tokens.spacing.small
        wrapMode: Text.Wrap
        color: Colours.palette.m3outline
        font: Tokens.font.label.small
    }

    // Wraps to as many columns as fit. The page is already inside PageBase's flickable, so this sizes itself to
    // its contents and scrolls with the page rather than scrolling on its own
    component TileGrid: Grid {
        Layout.fillWidth: true
        Layout.bottomMargin: Tokens.spacing.small
        columns: root.tileColumns
        spacing: root.tileSpacing
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
