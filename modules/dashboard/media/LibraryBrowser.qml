pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import Caelestia.Models
import qs.components
import qs.components.containers
import qs.components.controls
import qs.services

// NOTE(fork): the media tab's library drawer. Browsing shows the folders under the music
// folder as a cover gallery, and opening one shows its tracks the same way, so a file can
// always be picked without leaving the dashboard.
StyledClippingRect {
    id: root

    readonly property string query: search.text.trim().toLowerCase()
    readonly property bool searching: root.query.length > 0
    // Small covers at a fixed size, laid out with a Flow so a row of one or two folders keeps
    // them small instead of stretching them across the drawer. Works out to six per row at the
    // default tab width, and one more or less per row as it changes.
    readonly property real tileTarget: 130
    readonly property int columns: Math.max(1, Math.floor((flow.width + Tokens.spacing.medium) / (root.tileTarget + Tokens.spacing.medium)))
    readonly property real tileSize: flow.width > 0 ? (flow.width - (root.columns - 1) * Tokens.spacing.medium) / root.columns : root.tileTarget
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

            StyledFlickable {
                id: flickable

                anchors.fill: parent
                contentHeight: flow.implicitHeight
                clip: true

                StyledScrollBar.vertical: StyledScrollBar {
                    flickable: flickable
                }

                Flow {
                    id: flow

                    width: flickable.width - Tokens.padding.small
                    spacing: Tokens.spacing.medium

                    Repeater {
                        id: repeater

                        model: root.items

                        LibraryItem {
                            required property FileSystemEntry modelData

                            width: root.tileSize
                            entry: modelData
                            covers: root.coversFor(modelData)
                            current: !modelData.isDir && modelData.path === Music.currentFile
                            subtitle: root.searching && !modelData.isDir ? root.relativeDirOf(modelData) : ""
                            onClicked: root.playEntry(modelData)
                        }
                    }
                }
            }

            ColumnLayout {
                anchors.centerIn: parent
                spacing: Tokens.spacing.extraSmall
                opacity: repeater.count === 0 ? 1 : 0
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
