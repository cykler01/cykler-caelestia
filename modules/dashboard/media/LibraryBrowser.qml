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

// NOTE(fork): the media tab's collapsible library. Browses the configured music folder
// or searches the whole library, and starts playback through the local player.
ColumnLayout {
    id: root

    readonly property string query: search.text.trim().toLowerCase()
    readonly property bool searching: root.query.length > 0
    readonly property var folderItems: {
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
    readonly property var items: root.searching ? root.searchResults : root.folderItems

    signal trackPlayed

    // Path of an entry relative to the music folder, for disambiguating search results
    function relativeDirOf(entry: FileSystemEntry): string {
        const dir = entry.parentDir;
        if (!dir.startsWith(Music.rootDir))
            return dir;
        return dir.slice(Music.rootDir.length).replace(/^\//, "");
    }

    // Plays a library entry, queueing the rest of the folder or search results behind it
    function playEntry(entry: FileSystemEntry): void {
        if (entry.isDir) {
            Music.cd(entry.path);
            return;
        }

        const entries = root.searching ? root.searchResults : Music.folderTracks;
        const paths = [];
        let index = -1;
        for (let i = 0; i < entries.length; i++) {
            if (entries[i].isDir)
                continue;
            if (entries[i].path === entry.path)
                index = paths.length;
            paths.push(entries[i].path);
        }

        if (index < 0)
            return;

        Music.playQueue(paths, index);
        root.trackPlayed();
    }

    spacing: Tokens.spacing.small

    RowLayout {
        Layout.fillWidth: true
        spacing: Tokens.spacing.extraSmall

        IconButton {
            icon: "arrow_upward"
            type: IconButton.Text
            disabled: Music.atRoot
            onClicked: Music.cdUp()
        }

        StyledText {
            Layout.fillWidth: true
            text: Music.relativeDir || Tr.tr("Music")
            color: Colours.palette.m3onSurfaceVariant
            font: Tokens.font.body.medium
            elide: Text.ElideLeft
        }

        IconButton {
            icon: "home"
            type: IconButton.Text
            disabled: Music.atRoot
            onClicked: Music.cdRoot()
        }
    }

    SearchBar {
        id: search

        Layout.fillWidth: true
        // Takes focus whenever the drawer has it, so the field can be typed into
        focus: root.enabled
        placeholderText: Tr.tr("Search music")
        font: Tokens.font.body.small
        topPadding: Tokens.padding.small
        bottomPadding: Tokens.padding.small
    }

    StyledClippingRect {
        Layout.fillWidth: true
        Layout.fillHeight: true
        radius: Tokens.rounding.large
        color: Colours.tPalette.m3surfaceContainer

        StyledListView {
            id: list

            anchors.fill: parent
            anchors.margins: Tokens.padding.extraSmall
            clip: true
            spacing: Tokens.spacing.extraSmall / 2
            model: root.items

            StyledScrollBar.vertical: StyledScrollBar {
                flickable: list
            }

            delegate: StyledRect {
                id: entry

                required property FileSystemEntry modelData
                required property int index

                readonly property bool isCurrent: !entry.modelData.isDir && entry.modelData.path === Music.currentFile
                readonly property string subtitle: entry.modelData.isDir || !root.searching ? "" : root.relativeDirOf(entry.modelData)

                implicitWidth: ListView.view.width
                implicitHeight: layout.implicitHeight + Tokens.padding.small * 2
                radius: Tokens.rounding.medium
                color: entry.isCurrent ? Colours.palette.m3secondaryContainer : "transparent"

                StateLayer {
                    onClicked: root.playEntry(entry.modelData)
                }

                RowLayout {
                    id: layout

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: Tokens.padding.medium
                    anchors.rightMargin: Tokens.padding.medium
                    spacing: Tokens.spacing.small

                    MaterialIcon {
                        text: entry.modelData.isDir ? "folder" : entry.isCurrent && Music.playing ? "graphic_eq" : "music_note"
                        color: entry.isCurrent ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurfaceVariant
                        fontStyle: Tokens.font.icon.small
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        StyledText {
                            Layout.fillWidth: true
                            text: entry.modelData.isDir ? entry.modelData.name : entry.modelData.baseName
                            color: entry.isCurrent ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurface
                            font: Tokens.font.body.medium
                            elide: Text.ElideRight
                        }

                        StyledText {
                            Layout.fillWidth: true
                            visible: entry.subtitle !== ""
                            text: entry.subtitle
                            color: entry.isCurrent ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3outline
                            font: Tokens.font.label.small
                            elide: Text.ElideRight
                        }
                    }
                }
            }
        }

        ColumnLayout {
            anchors.centerIn: parent
            spacing: Tokens.spacing.extraSmall
            opacity: list.count === 0 ? 1 : 0
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
