pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import Caelestia.Models
import qs.components
import qs.components.controls
import qs.services

// NOTE(fork): the media tab's library drawer. Browsing shows the folders under the music
// folder as a cover gallery, and opening one shows its tracks the same way, so a file can
// always be picked without leaving the dashboard.
StyledClippingRect {
    id: root

    readonly property string query: search.text.trim().toLowerCase()
    readonly property bool searching: root.query.length > 0
    // Covers keep this size instead of being stretched across the drawer, so a folder of a few
    // entries doesn't end up with posters. It works out to six per row at the default tab width.
    readonly property real tileTarget: 130
    readonly property real gap: Tokens.spacing.medium
    readonly property int maxColumns: Math.max(1, Math.floor(gridArea.width / (root.tileTarget + root.gap)))
    // Never more columns than there are entries to fill them, so a folder holding five tracks lays
    // those five out rather than leaving the sixth column empty
    readonly property int columns: Math.max(1, Math.min(root.maxColumns, root.items.length))
    // The grid packs each row from the cell width, so the cell is the cover plus the gap to its
    // neighbour. Spreading the columns over the drawer widens the cells, and the covers keep their
    // size through it - only the gap grows, and only up to twice the design gap, so a wide drawer
    // doesn't end up with a couple of covers marooned on their own. A row narrower than the drawer
    // is centred by the grid being only as wide as its columns.
    readonly property real cellWidth: gridArea.width > 0 ? Math.min(Math.floor(gridArea.width / root.columns), root.tileTarget + 2 * root.gap) : root.tileTarget + root.gap
    readonly property real tileSize: Math.max(1, Math.min(root.tileTarget, root.cellWidth - root.gap))
    // One row of cells: the cover, the name under it, and the subtitle that only searching shows,
    // plus the space that keeps the rows apart. The label heights are measured off the components
    // the tiles draw the labels with: a TextMetrics without any text set reports no height at all,
    // which left the labels sitting on the row of covers underneath.
    readonly property real cellHeight: root.tileSize + Tokens.spacing.extraSmall + nameLabelMetrics.implicitHeight + (root.searching ? Tokens.spacing.extraSmall + subtitleLabelMetrics.implicitHeight : 0) + Tokens.spacing.medium
    readonly property string title: Music.relativeDir ? Music.relativeDir.split("/").join(" › ") : Tr.tr("Music")
    readonly property var browseItems: {
        const items = [];
        const dirs = Music.subDirs;
        for (let i = 0; i < dirs.length; i++)
            items.push(dirs[i]);
        const files = Music.folderTracks;
        for (let i = 0; i < files.length; i++)
            items.push(files[i]);
        return items;
    }
    // Searched over the whole path, so an album or folder name finds its tracks too
    readonly property var searchResults: {
        if (!root.searching)
            return [];

        const results = [];
        const library = Music.library;
        for (let i = 0; i < library.length; i++)
            if (library[i].relativePath.toLowerCase().includes(root.query))
                results.push(library[i]);
        return results;
    }
    readonly property var items: root.searching ? root.searchResults : root.browseItems

    signal trackPlayed

    // Path of an entry relative to the music folder, for disambiguating search results
    function relativeDirOf(entry: FileSystemEntry): string {
        const dir = entry.parentDir;
        if (!dir.startsWith(Music.rootDir))
            return dir;
        return dir.slice(Music.rootDir.length).replace(/^\//, "");
    }

    // Covers to show for an entry: a track's own art, or a folder's cover and collage
    function coversFor(entry: FileSystemEntry): var {
        if (entry.isDir)
            return Music.folderCoversFor(entry.path);

        const cover = Music.coverFor(entry.parentDir, entry.baseName);
        return cover ? [cover] : [];
    }

    function stopSearching(): void {
        search.text = "";
    }

    function goUp(): void {
        root.stopSearching();
        Music.cdUp();
    }

    function goRoot(): void {
        root.stopSearching();
        Music.cdRoot();
    }

    // Plays a library entry, queueing the rest of what's on screen behind it
    function playEntry(entry: FileSystemEntry): void {
        if (entry.isDir) {
            root.stopSearching();
            Music.cd(entry.path);
            return;
        }

        const items = root.items;
        const paths = [];
        let index = -1;
        for (let i = 0; i < items.length; i++) {
            if (items[i].isDir)
                continue;
            if (items[i].path === entry.path)
                index = paths.length;
            paths.push(items[i].path);
        }

        if (index < 0)
            return;

        Music.playQueue(paths, index);
        root.trackPlayed();
    }

    clip: true
    color: Colours.tPalette.m3surfaceContainer
    radius: Tokens.rounding.large

    // Off-screen copies of the two label rows a tile draws, kept only to measure them. A single
    // line's height comes from the font rather than the words in it, so one sample with an ascender
    // and a descender measures the same as a track name would. They mirror LibraryItem's labels.
    StyledText {
        id: nameLabelMetrics

        visible: false
        text: "Ag"
        font: Tokens.font.label.builders.small.weight(Font.Medium).build()
    }

    StyledText {
        id: subtitleLabelMetrics

        visible: false
        text: "Ag"
        font: Tokens.font.label.small
    }

    Item {
        id: body

        anchors.fill: parent
        anchors.margins: Tokens.padding.medium
        visible: root.enabled && height > 0

        RowLayout {
            id: header

            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            spacing: Tokens.spacing.extraSmall

            IconButton {
                icon: "arrow_upward"
                type: IconButton.Text
                disabled: Music.atRoot && !root.searching
                onClicked: root.goUp()
            }

            StyledText {
                Layout.fillWidth: true
                text: root.searching ? Tr.tr("Search results") : root.title
                color: Colours.palette.m3onSurfaceVariant
                font: Tokens.font.body.medium
                elide: Text.ElideMiddle
            }

            IconButton {
                icon: "home"
                type: IconButton.Text
                disabled: Music.atRoot && !root.searching
                onClicked: root.goRoot()
            }
        }

        SearchBar {
            id: search

            anchors.top: header.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.topMargin: Tokens.spacing.small

            placeholderText: Tr.tr("Search music")
            font: Tokens.font.body.small
            topPadding: Tokens.padding.small
            bottomPadding: Tokens.padding.small
        }

        Item {
            id: viewport

            anchors.top: search.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.topMargin: Tokens.spacing.medium
            // Clamped so the gallery never gets a negative height while the drawer animates
            height: Math.max(0, body.height - y)
            clip: true

            Item {
                id: gridArea

                anchors.fill: parent
                // Gutter for the scrollbar, so the last column doesn't sit under it
                anchors.rightMargin: Tokens.padding.small

                // Only the tiles on screen are ever built. A delegate is a cover, a shape and a
                // tooltip, so building one per entry means a folder of a few thousand tracks builds
                // a few thousand of them in one go, and the shell stops responding while it does.
                // As wide as its own columns and no wider, so a row that doesn't fill the drawer
                // ends up centred rather than hanging on the left edge.
                GridView {
                    id: grid

                    anchors.horizontalCenter: parent.horizontalCenter
                    width: Math.min(parent.width, root.columns * root.cellWidth)
                    height: parent.height
                    cellWidth: root.cellWidth
                    cellHeight: root.cellHeight
                    clip: true

                    StyledScrollBar.vertical: StyledScrollBar {
                        flickable: grid
                    }

                    model: root.items

                    delegate: LibraryItem {
                        required property FileSystemEntry modelData

                        width: root.tileSize
                        height: root.cellHeight
                        entry: modelData
                        covers: root.coversFor(modelData)
                        current: !modelData.isDir && modelData.path === Music.currentFile
                        subtitle: root.searching && !modelData.isDir ? root.relativeDirOf(modelData) : ""
                        onClicked: root.playEntry(modelData)
                    }
                }
            }

            ColumnLayout {
                anchors.centerIn: parent
                spacing: Tokens.spacing.extraSmall
                opacity: grid.count === 0 ? 1 : 0
                visible: opacity > 0

                Behavior on opacity {
                    Anim {
                        type: Anim.DefaultEffects
                    }
                }

                MaterialIcon {
                    Layout.alignment: Qt.AlignHCenter
                    text: root.searching ? "search_off" : "music_off"
                    color: Colours.palette.m3outline
                    fontStyle: Tokens.font.icon.extraLarge
                }

                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: root.searching ? Tr.tr("No matches") : Tr.tr("No music here")
                    color: Colours.palette.m3outline
                    font: Tokens.font.body.medium
                }
            }
        }
    }
}
