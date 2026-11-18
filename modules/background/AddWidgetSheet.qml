pragma ComponentBehavior: Bound

import "../../utils/widgetgrid.js" as WidgetGrid
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

// Picking a widget to add, from the desktop itself while the layout is being rearranged, and
// changing the style of one already out there.
//
// NOTE(fork): one list, not two steps. It used to show the widgets, then the styles of whichever
// was tapped, which hid ninety-odd styles behind twenty-eight guesses - and the tile standing for a
// widget was only ever its first style, so the list was a poor index of what was actually on offer.
// Every style of every widget is in one scroll now, under the name of the widget it belongs to,
// with a search over both names for when the scroll is the long way round.
//
// Every tile is the real card at its real size (see widgets/WidgetPreview.qml), which is what the
// tiles are sized from, so only the ones near the viewport are actually built: ninety live widgets
// at once is ninety forecasts, CPU readings and visualisers running behind the desktop.
Item {
    id: root

    // Adding a widget (-1), or changing the style of the one already on the desktop at this entry
    property int entryIndex: -1
    // While changing a style: the kind it is, and the style it is wearing now
    property string entryKind: ""
    property string entryType: ""
    readonly property bool switching: root.entryIndex >= 0

    // What the search field holds, matched against both the widget's name and the style's
    property string filter: ""

    // Every kind with the styles that match, in catalog order. A style switch is a swap within one
    // widget, so that mode narrows this to the kind being changed
    readonly property var sections: {
        const needle = root.filter.trim().toLowerCase();
        const out = [];
        for (const kind of WidgetCatalog.kinds) {
            if (root.switching && kind.id !== root.entryKind)
                continue;

            const types = kind.types ?? [];
            // A hit on the widget's own name brings all of its styles with it
            const whole = needle === "" || kind.name.toLowerCase().includes(needle);
            const shown = whole ? types : types.filter(t => t.name.toLowerCase().includes(needle));
            if (shown.length > 0)
                out.push({
                    kind: kind,
                    types: shown
                });
        }
        return out;
    }
    readonly property int shownCount: root.sections.reduce((n, s) => n + s.types.length, 0)

    // Tiles are built at the card's own width where there is room for it, so a style is shown at the
    // size it will actually be rather than blown up to fill a tile
    readonly property real minTileWidth: WidgetGrid.cardCells * WidgetGrid.unit + Tokens.padding.small * 4
    readonly property real tileSpacing: Tokens.spacing.small
    // Both the column count and the tile width come from the sheet's own width rather than from the
    // grid inside it: a tile measuring its parent while the grid measures its tiles is a binding loop
    readonly property real gridWidth: sheet.width - Tokens.padding.large * 2
    readonly property int tileColumns: Math.max(1, Math.floor(root.gridWidth / root.minTileWidth))
    readonly property real tileWidth: (root.gridWidth - root.tileSpacing * (root.tileColumns - 1)) / root.tileColumns

    // How far above and below the viewport a tile still counts as worth building, so scrolling runs
    // into cards that are already there rather than into holes that fill in after it
    readonly property real liveMargin: 600

    signal closed

    function add(id: string, type: string): void {
        GlobalConfig.background.desktopWidgets.entries.insert({
            id: id,
            type: type,
            enabled: true
        });
        root.closed();
    }

    // The same write the settings page makes, so the card re-reads its style and the layout closes
    // up around its new footprint
    function applyStyle(type: string): void {
        const entry = GlobalConfig.background.desktopWidgets.entries.at(root.entryIndex);
        if (entry)
            entry.type = type;
        root.closed();
    }

    function activate(kind: string, type: string): void {
        if (root.switching)
            root.applyStyle(type);
        else
            root.add(kind, type);
    }

    // A narrowed list starts at the top: what was on screen before the search has nothing to do
    // with what matches it
    onFilterChanged: flickable.contentY = 0

    focus: true

    Keys.onEscapePressed: {
        if (root.filter !== "")
            root.filter = "";
        else
            root.closed();
    }

    // How far the picker has come in: the dimmer, then the sheet, then its tiles. Opening used to be
    // a single frame over the desktop; this is what it is brought in with instead, on the same curve
    // the rearrange overlays use (see DesktopWidgets.qml). Kept on an item of its own rather than on
    // the root, since a Behavior on the root's own property is what crashes this shell on Qt 6.12
    Item {
        id: reveal

        property real progress: 0

        Component.onCompleted: progress = 1

        Behavior on progress {
            Anim {
                type: Anim.DefaultEffects
            }
        }
    }

    // Dims the desktop behind the sheet, and takes a click outside it as "never mind"
    StyledRect {
        anchors.fill: parent
        color: Qt.alpha(Colours.palette.m3scrim, 0.5)
        opacity: reveal.progress

        MouseArea {
            anchors.fill: parent
            onClicked: root.closed()
        }
    }

    StyledRect {
        id: sheet

        anchors.centerIn: parent
        // Wide enough for a few cards side by side at their own size, and never wider than the
        // desktop it is laid over
        width: Math.min(Math.max(root.minTileWidth + Tokens.padding.large * 2, 1100), parent.width - Tokens.padding.extraExtraLarge * 2)
        height: Math.min(header.implicitHeight + body.implicitHeight + Tokens.padding.large * 3, parent.height * 0.8)
        radius: Tokens.rounding.extraLarge
        color: Colours.palette.m3surfaceContainer
        // Up a touch small and a little below its place, settling as the dimmer comes in, so the
        // picker arrives as a surface over the desktop rather than as a frame that was always there
        opacity: reveal.progress
        scale: 0.94 + 0.06 * reveal.progress
        transform: Translate {
            y: (1 - reveal.progress) * Tokens.spacing.medium
        }

        // Swallows clicks that would otherwise reach the dimmer behind and close the sheet
        MouseArea {
            anchors.fill: parent
        }

        ColumnLayout {
            id: header

            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: Tokens.padding.large
            spacing: Tokens.spacing.medium

            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.medium

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    StyledText {
                        Layout.fillWidth: true
                        text: root.switching ? Tr.tr("Change style") : Tr.tr("Add a widget")
                        font: Tokens.font.title.medium
                        elide: Text.ElideRight
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: {
                            if (root.switching)
                                return Tr.tr("Every style %1 comes in, at the size it will be").arg(WidgetCatalog.nameFor(root.entryKind));
                            return Tr.tr("Every style of every widget, drawn the size it will be on the desktop");
                        }
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

            // One widget's styles need no searching through
            SearchBar {
                id: search

                Layout.fillWidth: true
                visible: !root.switching
                placeholderText: Tr.tr("Search widgets and styles")
                onTextChanged: root.filter = text
                Keys.onEscapePressed: event => {
                    if (text !== "") {
                        text = "";
                        event.accepted = true;
                    } else {
                        event.accepted = false;
                    }
                }
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

            contentHeight: body.implicitHeight
            clip: true

            StyledText {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: Tokens.padding.large
                visible: root.shownCount === 0
                text: Tr.tr("Nothing matches \"%1\"").arg(root.filter.trim())
                color: Colours.palette.m3outline
                font: Tokens.font.label.medium
            }

            Column {
                id: body

                width: root.gridWidth
                spacing: Tokens.spacing.large

                Repeater {
                    model: root.sections

                    // One widget: its name, then every style it comes in
                    Column {
                        id: section

                        required property var modelData

                        width: body.width
                        spacing: Tokens.spacing.small

                        RowLayout {
                            width: section.width
                            spacing: Tokens.spacing.small

                            MaterialIcon {
                                text: section.modelData.kind.icon
                                color: Colours.palette.m3primary
                                fontStyle: Tokens.font.icon.small
                            }

                            StyledText {
                                text: section.modelData.kind.name
                                color: Colours.palette.m3onSurface
                                font: Tokens.font.body.builders.medium.weight(Font.DemiBold).build()
                            }

                            StyledText {
                                Layout.fillWidth: true
                                text: {
                                    const n = section.modelData.types.length;
                                    return n > 1 ? Tr.tr("%1 styles").arg(n) : Tr.tr("One style");
                                }
                                color: Colours.palette.m3outline
                                font: Tokens.font.label.small
                                elide: Text.ElideRight
                            }
                        }

                        Grid {
                            id: styles

                            width: section.width
                            columns: root.tileColumns
                            spacing: root.tileSpacing

                            Repeater {
                                model: section.modelData.types

                                Tile {
                                    required property var modelData

                                    kind: section.modelData.kind.id
                                    kindIcon: section.modelData.kind.icon
                                    variant: modelData.id
                                    name: modelData.name
                                    subtext: Tr.tr("%1 rows tall").arg(modelData.height)
                                    // Near enough the viewport to be worth building? Every term
                                    // here is a positioner's own assignment or the flickable's own
                                    // scroll, so it follows a search narrowing the list, the sheet
                                    // being resized, and the scroll itself
                                    live: section.y + styles.y + y + height > flickable.contentY - root.liveMargin && section.y + styles.y + y < flickable.contentY + flickable.height + root.liveMargin
                                    current: root.switching && root.entryType === modelData.id
                                    onActivated: root.activate(section.modelData.kind.id, modelData.id)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // One pickable style: the real card at its own size, with what it is underneath
    component Tile: StyledRect {
        id: tile

        required property string kind
        required property string kindIcon
        required property string variant
        required property string name
        required property string subtext
        // Whether the tile is near enough the viewport to draw the real widget rather than its
        // outline; set where the tile is placed, which is where the scroll is in scope
        required property bool live
        // The style this widget is already wearing, while one is being changed
        property bool current: false

        // The tile is sized from the catalog rather than from the card inside it, so a tile that has
        // not built its card yet still holds exactly the room that card will need
        readonly property real previewWidth: root.tileWidth - Tokens.padding.small * 2
        readonly property real cardWidth: WidgetCatalog.widthFor(tile.kind, tile.variant) * WidgetGrid.unit - WidgetGrid.gap
        readonly property real cardHeight: WidgetCatalog.heightFor(tile.kind, tile.variant) * WidgetGrid.unit - WidgetGrid.gap
        readonly property real previewHeight: tile.cardHeight * Math.min(1, tile.previewWidth / tile.cardWidth)

        signal activated

        implicitWidth: root.tileWidth
        implicitHeight: tile.previewHeight + labels.implicitHeight + Tokens.padding.small * 3
        radius: Tokens.rounding.large
        color: tile.current ? Colours.palette.m3secondaryContainer : Colours.palette.m3surfaceContainerLow

        Behavior on color {
            CAnim {}
        }

        // The card's own place in the tile, whether or not the card itself is built yet
        Item {
            id: previewBox

            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: Tokens.padding.small
            height: tile.previewHeight

            // What stands in for a card too far off screen to be worth running: its footprint, and
            // the widget's own mark in the middle of it
            StyledRect {
                anchors.centerIn: parent
                width: Math.min(tile.cardWidth, parent.width)
                height: parent.height
                radius: Tokens.rounding.extraLarge
                color: Qt.alpha(Colours.palette.m3surfaceContainerHighest, 0.5)
                visible: !preview.active || preview.status !== Loader.Ready

                MaterialIcon {
                    anchors.centerIn: parent
                    text: tile.kindIcon
                    color: Colours.palette.m3outline
                    fontStyle: Tokens.font.icon.large
                }
            }

            Loader {
                id: preview

                anchors.fill: parent
                active: tile.live
                asynchronous: true
                opacity: status === Loader.Ready ? 1 : 0

                Behavior on opacity {
                    Anim {
                        type: Anim.FastEffects
                    }
                }

                sourceComponent: WidgetPreview {
                    kind: tile.kind
                    variant: tile.variant
                }
            }
        }

        ColumnLayout {
            id: labels

            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: Tokens.padding.small
            spacing: 0

            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.extraSmall

                StyledText {
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    text: tile.name
                    color: Colours.palette.m3onSurface
                    font: Tokens.font.label.medium
                }

                MaterialIcon {
                    visible: tile.current
                    text: "check"
                    color: Colours.palette.m3onSecondaryContainer
                    fontStyle: Tokens.font.icon.small
                }
            }

            StyledText {
                Layout.fillWidth: true
                elide: Text.ElideRight
                text: tile.current ? Tr.tr("Current style") : tile.subtext
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
