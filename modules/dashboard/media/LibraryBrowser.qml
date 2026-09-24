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

// NOTE(fork): the media library. Browsing lists the folders under the music folder, or - with
// the artist grouping on - one playlist per artist the tracks are tagged with, and every row
// carries that entry's cover art beside the name. Searching reads titles, artists and albums
// over the whole library as well as paths, so an artist brings up everything by them. Lists
// rather than a cover gallery, since what this mostly gets opened in is the sidebar.
StyledClippingRect {
    id: root

    // Grouping: the folders on disk, or the artists the tracks are tagged with
    property bool byArtist
    // The artist whose playlist is open, empty at the list of artists
    property string artistFilter

    readonly property string query: search.text.trim().toLowerCase()
    readonly property bool searching: root.query.length > 0
    // Read here so every list below rebuilds once the tag scan lands. A few hundred files is
    // a fraction of a second, so the artist side is only ever briefly empty.
    readonly property var tags: Music.tags
    readonly property bool readingTags: Music.tagsScanning

    // Folders and artists both list their contents, so both navigate the same way
    readonly property bool atGroupRoot: root.byArtist ? root.artistFilter === "" : Music.atRoot
    readonly property string title: {
        if (root.searching)
            return Tr.tr("Search results");
        if (root.byArtist)
            return root.artistFilter === "" ? Tr.tr("Artists") : root.artistLabel(root.artistFilter);
        return Music.relativeDir ? Music.relativeDir.split("/").join(" › ") : Tr.tr("Music");
    }
    readonly property string emptyIcon: root.searching ? "search_off" : root.readingTags && root.byArtist ? "hourglass_empty" : "music_off"
    readonly property string emptyText: root.searching ? Tr.tr("No matches") : root.readingTags && root.byArtist ? Tr.tr("Reading tags") : Tr.tr("No music here")

    // What the list is showing, one plain object per row so the row doesn't have to care
    // whether it is looking at a folder, an artist or a track
    readonly property var items: {
        const tags = root.tags;

        if (root.searching)
            return root.searchItems(tags);

        if (root.byArtist) {
            if (root.artistFilter === "")
                return Music.artistPlaylists.map(playlist => root.artistRow(playlist));

            const playlist = Music.artistPlaylists.find(playlist => playlist.name === root.artistFilter);
            return playlist ? playlist.tracks.map(entry => root.trackRow(entry)) : [];
        }

        const rows = [];
        const dirs = Music.subDirs;
        for (let i = 0; i < dirs.length; i++)
            rows.push(root.folderRow(dirs[i]));
        const tracks = Music.folderTracks;
        for (let i = 0; i < tracks.length; i++)
            rows.push(root.trackRow(tracks[i]));
        return rows;
    }

    signal trackPlayed

    // The tags are only read once something opens the library, so a session that never does
    // pays nothing for them
    Component.onCompleted: Music.ensureTags()

    onVisibleChanged: {
        // The sidebar unmaps this as it closes, which drops the search field's focus, so it
        // is taken back when the library comes round again
        if (root.visible)
            search.forceActiveFocus();
    }

    function countLabel(count: int): string {
        return Tr.trN("%1 track", "%1 tracks", count).arg(count);
    }

    // A track with no artist tag would otherwise show a blank line where the artist goes
    function artistLabel(artist: string): string {
        return artist === "" ? Tr.tr("No artist") : artist;
    }

    // Path of an entry relative to the music folder, for telling search results apart
    function relativeDirOf(entry: FileSystemEntry): string {
        const dir = entry.parentDir;
        if (!dir.startsWith(Music.rootDir))
            return dir;
        return dir.slice(Music.rootDir.length).replace(/^\//, "");
    }

    function trackRow(entry: FileSystemEntry): var {
        const current = entry.path === Music.currentFile;
        return {
            kind: "track",
            name: Music.titleFor(entry),
            // Where a result lives, when it has no artist to show instead
            subtitle: Music.artistFor(entry) || (root.searching ? root.relativeDirOf(entry) : ""),
            cover: Music.coverForEntry(entry),
            entry: entry,
            current: current,
            playing: current && Music.playing
        };
    }

    function folderRow(entry: FileSystemEntry): var {
        return {
            kind: "folder",
            name: entry.name,
            subtitle: root.countLabel(Music.tracksByDir[entry.path]?.length ?? 0),
            cover: Music.folderCoversFor(entry.path)[0] ?? "",
            entry: entry,
            current: false,
            playing: false
        };
    }

    function artistRow(playlist: var): var {
        return {
            kind: "artist",
            name: root.artistLabel(playlist.name),
            subtitle: root.countLabel(playlist.tracks.length),
            cover: playlist.tracks.length > 0 ? Music.coverForEntry(playlist.tracks[0]) : "",
            artist: playlist.name,
            current: false,
            playing: false
        };
    }

    // Searched over the path, so an album or folder name finds its tracks, and over the tags,
    // so an artist brings up their songs
    function matches(entry: FileSystemEntry, tag: var): bool {
        if (entry.relativePath.toLowerCase().includes(root.query))
            return true;
        if (tag === undefined)
            return false;

        return (tag.title ?? "").toLowerCase().includes(root.query) || (tag.artist ?? "").toLowerCase().includes(root.query) || (tag.album ?? "").toLowerCase().includes(root.query);
    }

    function searchItems(tags: var): var {
        const results = [];
        const library = Music.library;
        for (let i = 0; i < library.length; i++) {
            if (root.matches(library[i], tags[library[i].path]))
                results.push(root.trackRow(library[i]));
        }
        return results;
    }

    function stopSearching(): void {
        search.text = "";
    }

    // Going up leaves a search behind rather than navigating under it, so the list you land
    // back on is the one you were looking at
    function goUp(): void {
        root.stopSearching();
        if (root.byArtist) {
            root.artistFilter = "";
            return;
        }
        Music.cdUp();
    }

    function goRoot(): void {
        root.stopSearching();
        if (root.byArtist) {
            root.artistFilter = "";
            return;
        }
        Music.cdRoot();
    }

    // Playing a track queues whatever else is on the list behind it, so a folder or an
    // artist's playlist plays through instead of stopping after one song
    function activate(item: var): void {
        if (item.kind === "artist") {
            root.stopSearching();
            root.artistFilter = item.artist;
            return;
        }

        if (item.kind === "folder") {
            root.stopSearching();
            Music.cd(item.entry.path);
            return;
        }

        const rows = root.items;
        const paths = [];
        let index = -1;
        for (let i = 0; i < rows.length; i++) {
            if (rows[i].kind !== "track")
                continue;
            if (rows[i].entry.path === item.entry.path)
                index = paths.length;
            paths.push(rows[i].entry.path);
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
                disabled: root.atGroupRoot && !root.searching
                onClicked: root.goUp()
            }

            StyledText {
                Layout.fillWidth: true
                text: root.title
                color: Colours.palette.m3onSurfaceVariant
                font: Tokens.font.body.medium
                elide: Text.ElideMiddle
            }

            // Grouped by folder, as the files are on disk
            IconButton {
                icon: "folder"
                isToggle: true
                checked: !root.byArtist
                type: root.byArtist ? IconButton.Tonal : IconButton.Filled
                disabled: root.searching
                onClicked: root.byArtist = false
            }

            // Grouped into one playlist per artist, from the tags
            IconButton {
                icon: "person"
                isToggle: true
                checked: root.byArtist
                type: root.byArtist ? IconButton.Filled : IconButton.Tonal
                disabled: root.searching
                onClicked: root.byArtist = true
            }

            IconButton {
                icon: "home"
                type: IconButton.Text
                disabled: root.atGroupRoot && !root.searching
                onClicked: root.goRoot()
            }
        }

        SearchBar {
            id: search

            anchors.top: header.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.topMargin: Tokens.spacing.small

            // Takes focus whenever the library does, so the field can be typed into without
            // reaching for it first
            focus: root.enabled
            placeholderText: Tr.tr("Search songs and artists")
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
            // Clamped so the list never gets a negative height while a drawer animates
            height: Math.max(0, body.height - y)
            clip: true

            // Only the rows on screen are ever built, so a folder of a few thousand tracks
            // doesn't build a few thousand rows in one go and lock the shell up while it does
            StyledListView {
                id: list

                anchors.fill: parent
                // Gutter for the scrollbar, so the rows don't sit under it
                anchors.rightMargin: Tokens.padding.small
                clip: true
                spacing: Tokens.spacing.extraSmall / 2

                StyledScrollBar.vertical: StyledScrollBar {
                    flickable: list
                }

                model: root.items

                delegate: LibraryRow {
                    required property var modelData

                    width: list.width
                    item: modelData
                    onClicked: root.activate(modelData)
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
                    text: root.emptyIcon
                    color: Colours.palette.m3outline
                    fontStyle: Tokens.font.icon.extraLarge
                }

                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: root.emptyText
                    color: Colours.palette.m3outline
                    font: Tokens.font.body.medium
                }
            }
        }
    }
}
